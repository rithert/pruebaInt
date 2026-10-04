import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import {
  messageForTransaction,
  registerPushNotifications,
} from '../src/modules/notifications/notifications.js';
import type {
  PushMessage,
  PushResult,
  PushSender,
} from '../src/modules/notifications/push-sender.js';
import { bearer, createTestContext, registerUser, type TestContext } from './helpers.js';

/** Emisor en memoria: registra lo enviado y simula tokens inválidos. */
class FakePushSender implements PushSender {
  readonly enabled = true;
  sent: { tokens: string[]; message: PushMessage }[] = [];
  invalid = new Set<string>();

  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    this.sent.push({ tokens, message });
    return { invalidTokens: tokens.filter((t) => this.invalid.has(t)) };
  }
}

const TOKEN = 'fcm-token-de-prueba-0123456789';
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('messageForTransaction', () => {
  const tx = {
    id: 't1',
    account_id: 'a1',
    amount_minor: -45_20,
    balance_after_minor: 0,
    description: 'Compra con tarjeta débito',
    category: 'groceries',
    counterparty: 'Mercado Fresco',
    booked_at: '2026-10-04T12:00:00.000Z',
    transfer_id: null,
  };

  it('describe una compra con monto es-EC y deep link al detalle', () => {
    const message = messageForTransaction({
      userId: 'u1',
      accountId: 'a1',
      currency: 'USD',
      transaction: tx,
      origin: 'activity',
    });

    expect(message).toEqual({
      title: 'Compra por $45,20',
      body: 'En Mercado Fresco',
      data: { route: '/transactions/t1', transactionId: 't1' },
    });
  });

  it('no notifica transferencias que el propio cliente hizo', () => {
    expect(
      messageForTransaction({
        userId: 'u1',
        accountId: 'a1',
        currency: 'USD',
        transaction: tx,
        origin: 'transfer',
      }),
    ).toBeNull();
  });
});

describe('Push por movimientos', () => {
  let ctx: TestContext;
  let sender: FakePushSender;
  let token: string;
  let userId: string;

  beforeEach(async () => {
    ctx = await createTestContext();
    sender = new FakePushSender();
    registerPushNotifications(ctx.deps.db, ctx.deps.events, sender);
    const registered = await registerUser(ctx.app);
    token = registered.session.accessToken;
    userId = registered.user.id;
  });
  afterEach(() => ctx.close());

  const registerDevice = (deviceToken = TOKEN) =>
    ctx.app.inject({
      method: 'POST',
      url: '/v1/devices',
      headers: bearer(token),
      payload: { token: deviceToken, platform: 'android' },
    });

  it('un movimiento nuevo envía push a los dispositivos del cliente', async () => {
    expect((await registerDevice()).statusCode).toBe(204);

    ctx.deps.activityEngine.tick({ userId });
    await flush();

    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0]!.tokens).toEqual([TOKEN]);
    expect(sender.sent[0]!.message.data.route).toMatch(/^\/transactions\//);
  });

  it('sin dispositivos registrados no intenta enviar', async () => {
    ctx.deps.activityEngine.tick({ userId });
    await flush();

    expect(sender.sent).toHaveLength(0);
  });

  it('elimina los tokens que FCM reporta como inválidos', async () => {
    await registerDevice();
    sender.invalid.add(TOKEN);

    ctx.deps.activityEngine.tick({ userId });
    await flush();
    ctx.deps.activityEngine.tick({ userId });
    await flush();

    expect(sender.sent).toHaveLength(1);
  });

  it('al cerrar sesión el dispositivo se da de baja', async () => {
    await registerDevice();
    const response = await ctx.app.inject({
      method: 'DELETE',
      url: `/v1/devices/${TOKEN}`,
      headers: bearer(token),
    });

    ctx.deps.activityEngine.tick({ userId });
    await flush();

    expect(response.statusCode).toBe(204);
    expect(sender.sent).toHaveLength(0);
  });

  it('exige sesión para registrar dispositivos', async () => {
    const response = await ctx.app.inject({
      method: 'POST',
      url: '/v1/devices',
      payload: { token: TOKEN, platform: 'android' },
    });

    expect(response.statusCode).toBe(401);
  });
});
