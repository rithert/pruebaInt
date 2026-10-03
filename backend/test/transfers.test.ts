import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { bearer, createTestContext, registerUser, type TestContext } from './helpers.js';

describe('Transferencias entre cuentas propias', () => {
  let ctx: TestContext;
  let token: string;
  let main: { id: string; balanceMinor: number };
  let goal: { id: string; balanceMinor: number };

  beforeEach(async () => {
    ctx = await createTestContext();
    token = (await registerUser(ctx.app, { goal: 'save' })).session.accessToken;
    [main, goal] = (
      await ctx.app.inject({ method: 'GET', url: '/v1/accounts', headers: bearer(token) })
    ).json().accounts;
  });
  afterEach(() => ctx.close());

  // `null` = enviar sin header (un `undefined` activaría el valor por defecto).
  const transfer = (payload: object, key: string | null = 'key-00000001') =>
    ctx.app.inject({
      method: 'POST',
      url: '/v1/transfers',
      headers: { ...bearer(token), ...(key ? { 'idempotency-key': key } : {}) },
      payload,
    });

  it('mueve el dinero y devuelve los saldos actualizados', async () => {
    const response = await transfer({ fromAccountId: main.id, toAccountId: goal.id, amountMinor: 1_000_00 });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({
      from: { accountId: main.id, balanceMinor: main.balanceMinor - 1_000_00 },
      to: { accountId: goal.id, balanceMinor: goal.balanceMinor + 1_000_00 },
    });
  });

  it('es idempotente: reintentar con la misma clave no duplica el movimiento', async () => {
    const payload = { fromAccountId: main.id, toAccountId: goal.id, amountMinor: 500_00 };
    const first = await transfer(payload);
    const retry = await transfer(payload);

    expect(retry.statusCode).toBe(200);
    expect(retry.headers['idempotent-replayed']).toBe('true');
    expect(retry.json()).toEqual(first.json());

    const accounts = (
      await ctx.app.inject({ method: 'GET', url: '/v1/accounts', headers: bearer(token) })
    ).json().accounts;
    expect(accounts[0].balanceMinor).toBe(main.balanceMinor - 500_00);
  });

  it('rechaza reutilizar una clave con datos distintos', async () => {
    await transfer({ fromAccountId: main.id, toAccountId: goal.id, amountMinor: 500_00 });
    const response = await transfer({ fromAccountId: main.id, toAccountId: goal.id, amountMinor: 900_00 });

    expect(response.statusCode).toBe(422);
    expect(response.json().error.code).toBe('idempotency_key_reused');
  });

  it('exige el header Idempotency-Key', async () => {
    const response = await transfer({ fromAccountId: main.id, toAccountId: goal.id, amountMinor: 100 }, null);

    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('idempotency_key_required');
  });

  it('rechaza saldo insuficiente sin tocar los saldos', async () => {
    const response = await transfer({
      fromAccountId: main.id,
      toAccountId: goal.id,
      amountMinor: main.balanceMinor + 1,
    });

    expect(response.statusCode).toBe(422);
    expect(response.json().error.code).toBe('insufficient_funds');
  });

  it('rechaza transferir a la misma cuenta', async () => {
    const response = await transfer({ fromAccountId: main.id, toAccountId: main.id, amountMinor: 100 });

    expect(response.json().error.code).toBe('same_account');
  });

  it('emite un evento por cada movimiento creado', async () => {
    const received: string[] = [];
    ctx.deps.events.on('transaction.created', (event) => received.push(event.accountId));

    await transfer({ fromAccountId: main.id, toAccountId: goal.id, amountMinor: 100_00 });

    expect(received).toEqual([main.id, goal.id]);
  });
});
