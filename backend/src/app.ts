import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyInstance } from 'fastify';

import type { Deps } from './container.js';
import { accountsRoutes } from './modules/accounts/accounts.routes.js';
import { activityAdminRoutes } from './modules/activity/activity.routes.js';
import { authGuard } from './modules/auth/auth.guard.js';
import { authRoutes, meRoutes } from './modules/auth/auth.routes.js';
import { transfersRoutes } from './modules/transfers/transfers.routes.js';
import { registerErrorHandler } from './shared/errors.js';
import './shared/services.js';

export interface AppOptions {
  /** Desactiva logs en tests para mantener la salida limpia. */
  logger?: boolean;
}

/**
 * Construye la instancia de Fastify sin abrir el puerto.
 * Separarlo de `server.ts` permite probar rutas con `app.inject()`.
 */
export async function buildApp(deps: Deps, options: AppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({
    logger: options.logger ?? true,
    // Respeta el correlation-id que envía la app para trazar extremo a extremo.
    requestIdHeader: 'x-correlation-id',
    genReqId: () => crypto.randomUUID(),
  });

  app.decorateRequest('userId', '');
  registerErrorHandler(app);
  await app.register(rateLimit, { global: false });

  app.addHook('onSend', async (request, reply) => {
    reply.header('x-correlation-id', request.id);
  });

  // TODO(chaos): registrar aquí el middleware de chaos y sus rutas /admin/chaos.

  app.get('/health', async () => ({
    status: 'ok',
    uptimeSeconds: Math.round(process.uptime()),
  }));

  // API pública (sin sesión).
  await app.register(
    async (scope) => {
      await scope.register(authRoutes, { deps });
    },
    { prefix: '/v1' },
  );

  // API autenticada: todo lo registrado en este scope exige access token.
  await app.register(
    async (scope) => {
      scope.addHook('preHandler', authGuard(deps.tokens));
      await scope.register(meRoutes, { deps });
      await scope.register(accountsRoutes, { deps });
      await scope.register(transfersRoutes, { deps });
    },
    { prefix: '/v1' },
  );

  // Operación (protegida por ADMIN_KEY).
  await app.register(activityAdminRoutes, { deps });

  return app;
}
