import type { FastifyBaseLogger } from 'fastify';

import { type Db, inTransaction } from '../../db/database.js';
import type { DomainEvents } from '../../shared/events.js';
import { between, pick, type Random, weightedPick } from '../../shared/random.js';
import type { Segment } from '../../shared/segments.js';
import type { AccountsRepository, TransactionRow } from '../accounts/accounts.repository.js';
import { PEOPLE, SPENDING, SPENDING_WEIGHTS, usd } from './catalog.js';

interface EngineDeps {
  db: Db;
  accounts: AccountsRepository;
  events: DomainEvents;
  now: () => Date;
  random: Random;
  log?: FastifyBaseLogger;
}

/**
 * Simula la actividad del core bancario: cada intervalo genera compras y
 * transferencias recibidas para clientes reales de la BD. Cada movimiento
 * emite `transaction.created`, que alimenta las notificaciones push.
 */
export class ActivityEngine {
  private timer: NodeJS.Timeout | undefined;

  constructor(private readonly deps: EngineDeps) {}

  start(intervalMs: number): void {
    if (intervalMs <= 0 || this.timer) return;
    this.timer = setInterval(() => {
      try {
        this.tick();
      } catch (error) {
        this.deps.log?.error({ err: error }, 'falló el ciclo del motor de actividad');
      }
    }, intervalMs);
    this.timer.unref();
  }

  stop(): void {
    clearInterval(this.timer);
    this.timer = undefined;
  }

  /**
   * Ejecuta un ciclo. Con `userId` fuerza un movimiento para ese cliente
   * (útil en la demo para provocar un push); sin él, cada cliente tiene un
   * 30 % de probabilidad de recibir un movimiento.
   */
  tick(options: { userId?: string } = {}): TransactionRow[] {
    const { db, random } = this.deps;
    const users = (options.userId
      ? db.prepare('SELECT id, segment FROM users WHERE id = ?').all(options.userId)
      : db.prepare('SELECT id, segment FROM users').all()) as unknown as {
      id: string;
      segment: Segment;
    }[];

    const created: TransactionRow[] = [];
    for (const user of users) {
      if (!options.userId && random() > 0.3) continue;
      const tx = this.createMovement(user);
      if (tx) created.push(tx);
    }
    return created;
  }

  private createMovement(user: { id: string; segment: Segment }): TransactionRow | undefined {
    const { db, accounts, events, now, random } = this.deps;
    const main = accounts.listByUser(user.id).find((a) => a.type === 'savings');
    if (!main) return undefined;

    const categoryName = weightedPick(random, SPENDING_WEIGHTS[user.segment]);
    const category = SPENDING[categoryName]!;
    const purchaseMinor = -usd(random, category.min, category.max);

    // Si no alcanza el saldo para el gasto, el ciclo genera un abono: así
    // cada ciclo forzado produce siempre un movimiento (y su push).
    const incoming = random() < 0.3 || main.balance_minor + purchaseMinor < 0;
    const amountMinor = incoming ? usd(random, 10, 120) : purchaseMinor;

    const tx = inTransaction(db, () =>
      accounts.applyTransaction(main.id, {
        amountMinor,
        description: incoming ? 'Transferencia recibida' : 'Compra con tarjeta débito',
        category: incoming ? 'income' : categoryName,
        counterparty: incoming ? pick(random, PEOPLE) : pick(random, category.merchants),
        bookedAt: now().toISOString(),
      }),
    );

    events.emit('transaction.created', {
      userId: user.id,
      accountId: main.id,
      currency: main.currency,
      transaction: tx,
      origin: 'activity',
    });
    return tx;
  }
}
