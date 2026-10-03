import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import { AppError } from '../../shared/errors.js';

const transferBody = z.object({
  fromAccountId: z.string().min(1),
  toAccountId: z.string().min(1),
  amountMinor: z.number().int().positive().max(100_000_000_00),
  description: z.string().max(60).optional(),
});

const idempotencyKey = z.string().min(8).max(64);

export async function transfersRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  app.post('/transfers', { config: { service: 'transfers' } }, async (request, reply) => {
    const key = idempotencyKey.safeParse(request.headers['idempotency-key']);
    if (!key.success) {
      throw new AppError(400, 'idempotency_key_required', 'Falta el header Idempotency-Key (8-64 caracteres).');
    }
    const body = transferBody.parse(request.body);

    const { result, replayed } = deps.transfersService.execute(request.userId, key.data, body);

    if (replayed) reply.header('idempotent-replayed', 'true');
    return reply.status(replayed ? 200 : 201).send(result);
  });
}
