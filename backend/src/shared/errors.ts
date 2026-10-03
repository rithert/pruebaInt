import type { FastifyInstance } from 'fastify';
import { ZodError } from 'zod';

/**
 * Error de negocio con un `code` estable que la app usa para decidir qué
 * hacer (refrescar sesión, reintentar, mostrar un mensaje). El `message`
 * es para humanos y puede cambiar; el `code` es contrato.
 */
export class AppError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const Errors = {
  unauthorized: (code = 'unauthorized', message = 'Se requiere autenticación.') =>
    new AppError(401, code, message),
  forbidden: (message = 'No tienes permiso para esta operación.') =>
    new AppError(403, 'forbidden', message),
  notFound: (resource: string) => new AppError(404, 'not_found', `${resource} no encontrado.`),
  conflict: (code: string, message: string) => new AppError(409, code, message),
  unprocessable: (code: string, message: string) => new AppError(422, code, message),
};

/** Formato único de error: `{ error: { code, message, details?, correlationId } }`. */
export function registerErrorHandler(app: FastifyInstance): void {
  app.setErrorHandler((error, request, reply) => {
    const correlationId = request.id;

    if (error instanceof AppError) {
      return reply.status(error.statusCode).send({
        error: { code: error.code, message: error.message, details: error.details, correlationId },
      });
    }

    if (error instanceof ZodError) {
      return reply.status(400).send({
        error: {
          code: 'validation_error',
          message: 'La solicitud contiene datos inválidos.',
          details: error.issues.map((issue) => ({
            path: issue.path.join('.'),
            message: issue.message,
          })),
          correlationId,
        },
      });
    }

    const statusCode = (error as { statusCode?: number }).statusCode ?? 500;

    if (statusCode === 429) {
      return reply.status(429).send({
        error: {
          code: 'rate_limited',
          message: 'Demasiados intentos. Intenta de nuevo en un momento.',
          correlationId,
        },
      });
    }

    if (statusCode < 500) {
      return reply.status(statusCode).send({
        error: { code: 'bad_request', message: (error as Error).message, correlationId },
      });
    }

    request.log.error({ err: error }, 'error no controlado');
    return reply.status(500).send({
      error: { code: 'internal_error', message: 'Ocurrió un error inesperado.', correlationId },
    });
  });

  app.setNotFoundHandler((request, reply) =>
    reply.status(404).send({
      error: { code: 'route_not_found', message: 'Ruta no encontrada.', correlationId: request.id },
    }),
  );
}
