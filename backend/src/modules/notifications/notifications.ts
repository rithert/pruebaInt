import type { FastifyBaseLogger, FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import type { Db } from '../../db/database.js';
import type { DomainEventMap, DomainEvents } from '../../shared/events.js';
import { formatUsd } from '../../shared/money.js';
import type { PushMessage, PushSender } from './push-sender.js';

/**
 * Traduce un movimiento en una notificación. Solo se notifican movimientos
 * que el cliente no inició él mismo (las transferencias entre sus cuentas
 * ya las ve en pantalla).
 */
export function messageForTransaction(
  event: DomainEventMap['transaction.created'],
): PushMessage | null {
  if (event.origin !== 'activity') return null;
  const tx = event.transaction;
  const amount = formatUsd(Math.abs(tx.amount_minor));
  const who = tx.counterparty ?? tx.description;
  return {
    title: tx.amount_minor >= 0 ? `Recibiste ${amount}` : `Compra por ${amount}`,
    body: tx.amount_minor >= 0 ? `De ${who}` : `En ${who}`,
    data: { route: `/transactions/${tx.id}`, transactionId: tx.id },
  };
}

/**
 * Escucha `transaction.created` y envía push a los dispositivos del cliente.
 * Los fallos de envío nunca afectan la operación que originó el evento.
 */
export function registerPushNotifications(
  db: Db,
  events: DomainEvents,
  sender: PushSender,
  log?: FastifyBaseLogger,
): void {
  events.on('transaction.created', (event) => {
    const message = messageForTransaction(event);
    if (!message) return;
    const tokens = (
      db
        .prepare('SELECT token FROM device_tokens WHERE user_id = ?')
        .all(event.userId) as unknown as {
        token: string;
      }[]
    ).map((t) => t.token);
    if (tokens.length === 0) return;

    sender
      .send(tokens, message)
      .then(({ invalidTokens }) => {
        const remove = db.prepare('DELETE FROM device_tokens WHERE token = ?');
        for (const token of invalidTokens) remove.run(token);
      })
      .catch((error: unknown) => log?.error({ err: error }, 'falló el envío de push'));
  });
}

const deviceBody = z.object({
  token: z.string().min(20).max(4096),
  platform: z.enum(['android', 'ios']),
});

/** Registro de dispositivos para notificaciones del cliente autenticado. */
export async function devicesRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  const config = { service: 'notifications' as const };

  app.post('/devices', { config }, async (request, reply) => {
    const { token, platform } = deviceBody.parse(request.body);
    // Un token pertenece a un solo cliente: si otro inició sesión en el
    // mismo teléfono, el token pasa a él.
    deps.db
      .prepare(
        `INSERT INTO device_tokens (token, user_id, platform, updated_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, updated_at = excluded.updated_at`,
      )
      .run(token, request.userId, platform, deps.now().toISOString());
    return reply.status(204).send();
  });

  app.delete('/devices/:token', { config }, async (request, reply) => {
    const { token } = z.object({ token: z.string().min(1) }).parse(request.params);
    deps.db
      .prepare('DELETE FROM device_tokens WHERE token = ? AND user_id = ?')
      .run(token, request.userId);
    return reply.status(204).send();
  });
}
