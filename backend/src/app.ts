import Fastify, { type FastifyInstance } from 'fastify';

export interface AppOptions {
  /** Desactiva logs en tests para mantener la salida limpia. */
  logger?: boolean;
}

/**
 * Construye la instancia de Fastify sin abrir el puerto.
 * Separarlo de `server.ts` permite probar rutas con `app.inject()`.
 */
export function buildApp(options: AppOptions = {}): FastifyInstance {
  const app = Fastify({
    logger: options.logger ?? true,
    // Respeta el correlation-id que envía la app para trazar extremo a extremo.
    requestIdHeader: 'x-correlation-id',
    genReqId: () => crypto.randomUUID(),
  });

  app.addHook('onSend', async (request, reply) => {
    reply.header('x-correlation-id', request.id);
  });

  app.get('/health', async () => ({
    status: 'ok',
    uptimeSeconds: Math.round(process.uptime()),
  }));

  return app;
}
