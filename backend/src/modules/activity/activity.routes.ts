import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import { requireAdminKey } from '../../shared/admin-guard.js';
import { toTransactionDto } from '../accounts/accounts.mapper.js';

const tickBody = z.object({ userId: z.string().min(1).optional() }).default({});

/**
 * Rutas operativas para la demo: fuerzan un ciclo del motor de actividad
 * (p. ej. para provocar un push en vivo) sin esperar al intervalo.
 */
export async function activityAdminRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  app.addHook('preHandler', requireAdminKey(deps.config.adminKey));

  app.post('/admin/activity/tick', async (request) => {
    const { userId } = tickBody.parse(request.body ?? {});
    const created = deps.activityEngine.tick({ userId });
    return { created: created.map((tx) => toTransactionDto(tx, 'COP')) };
  });
}
