import type { Segment } from '../../shared/segments.js';
import { between, pick, type Random, weightedPick } from '../../shared/random.js';
import type {
  AccountRow,
  AccountType,
  AccountsRepository,
} from '../accounts/accounts.repository.js';
import { CLIENTS, CURRENCY, SPENDING, SPENDING_WEIGHTS, SUPPLIERS, usd } from './catalog.js';

const HISTORY_DAYS = 90;
const DAY_MS = 24 * 3600 * 1000;

interface AccountPlan {
  role: 'main' | 'goal' | 'investment' | 'business';
  type: AccountType;
  name: string;
}

const ACCOUNT_PLANS: Record<Segment, AccountPlan[]> = {
  saver: [
    { role: 'main', type: 'savings', name: 'Cuenta de ahorros' },
    { role: 'goal', type: 'savings', name: 'Bolsillo de metas' },
  ],
  investor: [
    { role: 'main', type: 'savings', name: 'Cuenta de ahorros' },
    { role: 'investment', type: 'investment', name: 'Inversión flexible' },
  ],
  entrepreneur: [
    { role: 'main', type: 'savings', name: 'Cuenta de ahorros' },
    { role: 'business', type: 'business', name: 'Cuenta negocio' },
  ],
};

/** Un movimiento planeado; se aplican en orden cronológico para que los saldos cuadren. */
interface PlannedEntry {
  at: number;
  role: AccountPlan['role'];
  amountMinor: number;
  description: string;
  category: string;
  counterparty?: string;
  transferKey?: string;
}

/**
 * Crea las cuentas de un cliente nuevo y un historial de 90 días coherente
 * con su segmento. El historial no es un seed fijo: depende del segmento,
 * de la fecha de registro y de la fuente aleatoria. Debe ejecutarse dentro
 * de una transacción.
 */
export class PortfolioGenerator {
  constructor(private readonly accounts: AccountsRepository) {}

  generate(user: { id: string; segment: Segment }, now: Date, random: Random): AccountRow[] {
    const start = now.getTime() - HISTORY_DAYS * DAY_MS;
    const plans = ACCOUNT_PLANS[user.segment];

    const accountsByRole = new Map<AccountPlan['role'], AccountRow>();
    for (const plan of plans) {
      const account: AccountRow = {
        id: crypto.randomUUID(),
        user_id: user.id,
        type: plan.type,
        name: plan.name,
        number: String(between(random, 1_000_000_000, 9_999_999_999)),
        currency: CURRENCY,
        balance_minor: 0,
        created_at: new Date(start).toISOString(),
      };
      this.accounts.insertAccount(account);
      accountsByRole.set(plan.role, account);
    }

    const entries = planHistory(user.segment, start, random).sort((a, b) => a.at - b.at);
    const balances = new Map<string, number>();
    const transferIds = new Map<string, string>();

    for (const entry of entries) {
      const account = accountsByRole.get(entry.role);
      if (!account) continue;

      // Nunca se deja una cuenta en negativo: si no alcanza, el gasto no ocurre.
      const balance = balances.get(account.id) ?? 0;
      if (balance + entry.amountMinor < 0) continue;

      let transferId: string | null = null;
      if (entry.transferKey) {
        transferId = transferIds.get(entry.transferKey) ?? crypto.randomUUID();
        transferIds.set(entry.transferKey, transferId);
      }

      const row = this.accounts.applyTransaction(account.id, {
        amountMinor: entry.amountMinor,
        description: entry.description,
        category: entry.category,
        counterparty: entry.counterparty,
        bookedAt: new Date(entry.at).toISOString(),
        transferId,
      });
      balances.set(account.id, row.balance_after_minor);
    }

    return this.accounts.listByUser(user.id);
  }
}

function planHistory(segment: Segment, start: number, random: Random): PlannedEntry[] {
  const entries: PlannedEntry[] = [];
  const at = (day: number, hour: number) =>
    start + day * DAY_MS + hour * 3600 * 1000 + between(random, 0, 59) * 60 * 1000;

  // Transferencia entre cuentas propias: dos asientos con la misma clave.
  const internalTransfer = (
    day: number,
    from: PlannedEntry['role'],
    to: PlannedEntry['role'],
    amount: number,
    description: string,
    category: string,
  ) => {
    const key = `${day}-${from}-${to}`;
    const time = at(day, 9);
    entries.push({
      at: time,
      role: from,
      amountMinor: -amount,
      description,
      category: 'transfer',
      transferKey: key,
    });
    entries.push({
      at: time + 1000,
      role: to,
      amountMinor: amount,
      description,
      category,
      transferKey: key,
    });
  };

  for (let day = 0; day < HISTORY_DAYS; day++) {
    const dayOfCycle = day % 30;

    // Ingresos principales.
    if (segment !== 'entrepreneur' && (dayOfCycle === 0 || dayOfCycle === 15)) {
      entries.push({
        at: at(day, 7),
        role: 'main',
        amountMinor: usd(random, 380, 950),
        description: 'Pago de nómina',
        category: 'income',
        counterparty: 'Empleador',
      });
    }
    if (segment === 'entrepreneur') {
      const sales = between(random, 2, 5);
      for (let i = 0; i < sales; i++) {
        entries.push({
          at: at(day, 9 + i * 2),
          role: 'business',
          amountMinor: usd(random, 12, 180),
          description: 'Venta recibida',
          category: 'sales',
          counterparty: pick(random, CLIENTS),
        });
      }
      if (day % 7 === 3) {
        entries.push({
          at: at(day, 16),
          role: 'business',
          amountMinor: -usd(random, 90, 420),
          description: 'Pago a proveedor',
          category: 'suppliers',
          counterparty: pick(random, SUPPLIERS),
        });
      }
      if (dayOfCycle === 28) {
        internalTransfer(
          day,
          'business',
          'main',
          usd(random, 450, 900),
          'Retiro de utilidades',
          'income',
        );
      }
    }

    // Hábitos de ahorro e inversión según el segmento.
    if (segment === 'saver' && day % 7 === 1) {
      internalTransfer(day, 'main', 'goal', usd(random, 15, 60), 'Ahorro programado', 'savings');
    }
    if (segment === 'investor' && dayOfCycle === 2) {
      internalTransfer(
        day,
        'main',
        'investment',
        usd(random, 80, 300),
        'Aporte a inversión',
        'investment',
      );
    }
    if (segment === 'investor' && dayOfCycle === 29) {
      entries.push({
        at: at(day, 6),
        role: 'investment',
        amountMinor: usd(random, 2.5, 9),
        description: 'Rendimientos del mes',
        category: 'returns',
      });
    }

    // Gastos diarios con tarjeta débito.
    const purchases = between(random, 0, 3);
    for (let i = 0; i < purchases; i++) {
      const categoryName = weightedPick(random, SPENDING_WEIGHTS[segment]);
      const category = SPENDING[categoryName]!;
      entries.push({
        at: at(day, 10 + i * 3),
        role: 'main',
        amountMinor: -usd(random, category.min, category.max),
        description: 'Compra con tarjeta débito',
        category: categoryName,
        counterparty: pick(random, category.merchants),
      });
    }
  }

  return entries;
}
