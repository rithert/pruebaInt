import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import { requireAdminKey } from '../../shared/admin-guard.js';
import { Errors } from '../../shared/errors.js';
import { toTransactionDto } from '../accounts/accounts.mapper.js';
import { CURRENCY } from './catalog.js';

const tickBody = z
  .object({
    userId: z.string().min(1).optional(),
    /** Más cómodo en la demo que el id interno. */
    email: z.string().trim().toLowerCase().optional(),
  })
  .default({});

/**
 * Rutas operativas para la demo: fuerzan un ciclo del motor de actividad
 * (p. ej. para provocar un push en vivo) sin esperar al intervalo.
 */
export async function activityAdminRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  app.addHook('preHandler', requireAdminKey(deps.config.adminKey));

  app.post('/admin/activity/tick', async (request) => {
    const body = tickBody.parse(request.body ?? {});
    let userId = body.userId;
    if (!userId && body.email) {
      const user = deps.db.prepare('SELECT id FROM users WHERE email = ?').get(body.email) as
        { id: string } | undefined;
      if (!user) throw Errors.notFound('Cliente');
      userId = user.id;
    }
    const created = deps.activityEngine.tick({ userId });
    return { created: created.map((tx) => toTransactionDto(tx, CURRENCY)) };
  });
}
