import type { Db } from '../../db/database.js';
import type { Segment } from '../../shared/segments.js';

const DAY_MS = 24 * 3600 * 1000;

/**
 * Lo que el motor de reglas sabe del cliente. Se calcula desde datos reales
 * (movimientos, saldos, eventos de uso) en cada petición del home.
 */
export interface HomeSignals {
  firstName: string;
  segment: Segment;
  /** Hora local de Ecuador (UTC-5) para el saludo. */
  localHour: number;
  mainAccountId: string | null;
  mainBalanceMinor: number;
  goalBalanceMinor: number | null;
  /** Gasto por categoría (centavos, positivo) en los últimos 30 días y los 30 anteriores. */
  spendCurrent: Record<string, number>;
  spendPrevious: Record<string, number>;
  incomeLast7dMinor: number;
  salesLast7dMinor: number;
  salesPrev7dMinor: number;
  /** Componentes que el cliente descartó en los últimos 7 días. */
  dismissed: Set<string>;
  /** Toques por componente en los últimos 30 días (comportamiento). */
  taps: Record<string, number>;
}

export function collectSignals(db: Db, userId: string, now: Date): HomeSignals {
  const iso = (msAgo: number) => new Date(now.getTime() - msAgo).toISOString();

  const user = db.prepare('SELECT full_name, segment FROM users WHERE id = ?').get(userId) as {
    full_name: string;
    segment: Segment;
  };

  const accounts = db
    .prepare(
      'SELECT id, type, name, balance_minor FROM accounts WHERE user_id = ? ORDER BY created_at, name',
    )
    .all(userId) as unknown as { id: string; type: string; name: string; balance_minor: number }[];
  const main = accounts.find((a) => a.type === 'savings');
  const goal = accounts.find((a) => a.name === 'Bolsillo de metas');

  const spend = (fromMsAgo: number, toMsAgo: number) => {
    const rows = db
      .prepare(
        `SELECT t.category AS category, -SUM(t.amount_minor) AS total
         FROM transactions t JOIN accounts a ON a.id = t.account_id
         WHERE a.user_id = ? AND t.amount_minor < 0 AND t.category NOT IN ('transfer', 'suppliers')
           AND t.booked_at >= ? AND t.booked_at < ?
         GROUP BY t.category`,
      )
      .all(userId, iso(fromMsAgo), iso(toMsAgo)) as unknown as {
      category: string;
      total: number;
    }[];
    return Object.fromEntries(rows.map((r) => [r.category, r.total]));
  };

  const sum = (category: string, fromMsAgo: number, toMsAgo: number) =>
    (
      db
        .prepare(
          `SELECT COALESCE(SUM(t.amount_minor), 0) AS total
           FROM transactions t JOIN accounts a ON a.id = t.account_id
           WHERE a.user_id = ? AND t.category = ? AND t.amount_minor > 0
             AND t.booked_at >= ? AND t.booked_at < ?`,
        )
        .get(userId, category, iso(fromMsAgo), iso(toMsAgo)) as { total: number }
    ).total;

  const dismissed = db
    .prepare(
      `SELECT DISTINCT component_id FROM user_events
       WHERE user_id = ? AND type = 'dismissed' AND created_at >= ?`,
    )
    .all(userId, iso(7 * DAY_MS)) as unknown as { component_id: string }[];

  const taps = db
    .prepare(
      `SELECT component_id, COUNT(*) AS count FROM user_events
       WHERE user_id = ? AND type = 'tapped' AND created_at >= ?
       GROUP BY component_id`,
    )
    .all(userId, iso(30 * DAY_MS)) as unknown as { component_id: string; count: number }[];

  return {
    firstName: user.full_name.split(' ')[0] ?? user.full_name,
    segment: user.segment,
    localHour: (now.getUTCHours() + 24 - 5) % 24,
    mainAccountId: main?.id ?? null,
    mainBalanceMinor: main?.balance_minor ?? 0,
    goalBalanceMinor: goal?.balance_minor ?? null,
    spendCurrent: spend(30 * DAY_MS, 0),
    spendPrevious: spend(60 * DAY_MS, 30 * DAY_MS),
    incomeLast7dMinor: sum('income', 7 * DAY_MS, 0),
    salesLast7dMinor: sum('sales', 7 * DAY_MS, 0),
    salesPrev7dMinor: sum('sales', 14 * DAY_MS, 7 * DAY_MS),
    dismissed: new Set(dismissed.map((d) => d.component_id)),
    taps: Object.fromEntries(taps.map((t) => [t.component_id, t.count])),
  };
}
