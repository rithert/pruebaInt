import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { openDatabase } from '../src/db/database.js';
import { AccountsRepository } from '../src/modules/accounts/accounts.repository.js';
import { PortfolioGenerator } from '../src/modules/activity/portfolio-generator.js';
import { seededRandom } from '../src/shared/random.js';
import { createTestContext, registerUser, type TestContext } from './helpers.js';

const NOW = new Date('2026-10-03T12:00:00.000Z');

function generateFor(segment: 'saver' | 'investor' | 'entrepreneur', seed: number) {
  const db = openDatabase(':memory:');
  db.prepare(
    `INSERT INTO users VALUES ('u1', 'a@b.co', 'x', 'Ana', 'save', ?, '2026-01-01', '2026-01-01')`,
  ).run(segment);
  const repo = new AccountsRepository(db);
  const accounts = new PortfolioGenerator(repo).generate({ id: 'u1', segment }, NOW, seededRandom(seed));
  return { db, repo, accounts };
}

describe('PortfolioGenerator', () => {
  it.each([
    ['saver', ['savings', 'savings']],
    ['investor', ['savings', 'investment']],
    ['entrepreneur', ['savings', 'business']],
  ] as const)('crea los productos del segmento %s', (segment, types) => {
    const { accounts } = generateFor(segment, 1);
    expect(accounts.map((a) => a.type)).toEqual(types);
  });

  it('genera un historial con saldos coherentes y nunca negativos', () => {
    const { repo, accounts } = generateFor('saver', 7);

    for (const account of accounts) {
      const history = repo.listTransactions(account.id, { limit: 10_000 }).reverse();
      expect(history.length).toBeGreaterThan(0);

      let running = 0;
      for (const tx of history) {
        running += tx.amount_minor;
        expect(tx.balance_after_minor).toBe(running);
        expect(running).toBeGreaterThanOrEqual(0);
      }
      expect(account.balance_minor).toBe(running);
    }
  });

  it('distintas semillas producen historiales distintos (no es un seed fijo)', () => {
    const a = generateFor('investor', 1).accounts[0]!.balance_minor;
    const b = generateFor('investor', 2).accounts[0]!.balance_minor;
    expect(a).not.toBe(b);
  });

  it('no genera movimientos en el futuro', () => {
    const { repo, accounts } = generateFor('entrepreneur', 3);
    const latest = repo.listTransactions(accounts[0]!.id, { limit: 1 })[0]!;
    expect(latest.booked_at < NOW.toISOString()).toBe(true);
  });
});

describe('ActivityEngine', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await createTestContext();
  });
  afterEach(() => ctx.close());

  it('crea un movimiento forzado para un cliente y emite el evento', async () => {
    const { user } = await registerUser(ctx.app);
    const events: string[] = [];
    ctx.deps.events.on('transaction.created', (e) => events.push(e.userId));

    const created = ctx.deps.activityEngine.tick({ userId: user.id });

    expect(created).toHaveLength(1);
    expect(events).toEqual([user.id]);
    expect(created[0]!.booked_at).toBe(ctx.clock.now().toISOString());
  });

  it('un ciclo forzado siempre crea un movimiento, aun sin saldo para gastos', async () => {
    const { user } = await registerUser(ctx.app);
    ctx.deps.db.prepare('UPDATE accounts SET balance_minor = 0 WHERE user_id = ?').run(user.id);

    const created = ctx.deps.activityEngine.tick({ userId: user.id });

    expect(created).toHaveLength(1);
    expect(created[0]!.amount_minor).toBeGreaterThan(0);
  });

  it('el endpoint de administración exige la clave', async () => {
    const response = await ctx.app.inject({ method: 'POST', url: '/admin/activity/tick', payload: {} });

    expect(response.statusCode).toBe(403);
  });

  it('el endpoint de administración fuerza un ciclo', async () => {
    const { user } = await registerUser(ctx.app);
    const response = await ctx.app.inject({
      method: 'POST',
      url: '/admin/activity/tick',
      headers: { 'x-admin-key': 'dev-admin-key' },
      payload: { userId: user.id },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().created).toHaveLength(1);
  });
});
