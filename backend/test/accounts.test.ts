import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { bearer, createTestContext, registerUser, type TestContext } from './helpers.js';

interface AccountDto {
  id: string;
  type: string;
  name: string;
  maskedNumber: string;
  balanceMinor: number;
}
interface TransactionDto {
  id: string;
  bookedAt: string;
  amountMinor: number;
  category: string;
}

describe('Cuentas y movimientos', () => {
  let ctx: TestContext;
  let token: string;

  beforeEach(async () => {
    ctx = await createTestContext();
    token = (await registerUser(ctx.app, { goal: 'grow_business' })).session.accessToken;
  });
  afterEach(() => ctx.close());

  const get = (url: string, accessToken = token) =>
    ctx.app.inject({ method: 'GET', url, headers: bearer(accessToken) });

  const firstAccount = async () => (await get('/v1/accounts')).json().accounts[0] as AccountDto;

  it('lista las cuentas del cliente con totales y número enmascarado', async () => {
    const response = await get('/v1/accounts');
    const body = response.json();

    expect(response.statusCode).toBe(200);
    expect(body.accounts.map((a: AccountDto) => a.type)).toEqual(['savings', 'business']);
    for (const account of body.accounts as AccountDto[]) {
      expect(account.maskedNumber).toMatch(/^•••• \d{4}$/);
    }
    const sum = (body.accounts as AccountDto[]).reduce((s, a) => s + a.balanceMinor, 0);
    expect(body.totals).toEqual([{ currency: 'COP', balanceMinor: sum }]);
  });

  it('pagina los movimientos por cursor, ordenados y sin duplicados', async () => {
    const account = await firstAccount();
    const seen: TransactionDto[] = [];
    let cursor: string | null = null;

    do {
      const query: string = cursor ? `&cursor=${cursor}` : '';
      const page = (await get(`/v1/accounts/${account.id}/transactions?limit=25${query}`)).json();
      seen.push(...page.items);
      cursor = page.nextCursor;
    } while (cursor);

    expect(seen.length).toBeGreaterThan(25);
    expect(new Set(seen.map((t) => t.id)).size).toBe(seen.length);
    const dates = seen.map((t) => t.bookedAt);
    expect([...dates].sort().reverse()).toEqual(dates);
  });

  it('filtra movimientos por categoría', async () => {
    const account = await firstAccount();
    const body = (await get(`/v1/accounts/${account.id}/transactions?category=income&limit=50`)).json();

    expect(body.items.length).toBeGreaterThan(0);
    expect(body.items.every((t: TransactionDto) => t.category === 'income')).toBe(true);
  });

  it('el saldo de la cuenta coincide con el saldo posterior del último movimiento', async () => {
    const account = await firstAccount();
    const latest = (await get(`/v1/accounts/${account.id}/transactions?limit=1`)).json().items[0];

    expect(latest.balanceAfterMinor).toBe(account.balanceMinor);
  });

  it('muestra el detalle de un movimiento', async () => {
    const account = await firstAccount();
    const tx = (await get(`/v1/accounts/${account.id}/transactions?limit=1`)).json().items[0];
    const detail = await get(`/v1/transactions/${tx.id}`);

    expect(detail.statusCode).toBe(200);
    expect(detail.json()).toMatchObject({ id: tx.id, accountName: account.name, currency: 'COP' });
  });

  it('no permite ver cuentas ni movimientos de otro cliente', async () => {
    const account = await firstAccount();
    const tx = (await get(`/v1/accounts/${account.id}/transactions?limit=1`)).json().items[0];
    const intruder = (await registerUser(ctx.app, { email: 'otro@example.com' })).session.accessToken;

    expect((await get(`/v1/accounts/${account.id}`, intruder)).statusCode).toBe(404);
    expect((await get(`/v1/accounts/${account.id}/transactions`, intruder)).statusCode).toBe(404);
    expect((await get(`/v1/transactions/${tx.id}`, intruder)).statusCode).toBe(404);
  });

  it('rechaza un cursor manipulado', async () => {
    const account = await firstAccount();
    const response = await get(`/v1/accounts/${account.id}/transactions?cursor=basura`);

    expect(response.statusCode).toBe(422);
    expect(response.json().error.code).toBe('invalid_cursor');
  });
});
