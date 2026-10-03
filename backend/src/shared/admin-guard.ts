import { timingSafeEqual } from 'node:crypto';

import type { FastifyRequest } from 'fastify';

import { Errors } from './errors.js';

/**
 * preHandler para rutas operativas (/admin). Compara en tiempo constante para
 * no filtrar la clave por diferencias de tiempo de respuesta.
 */
export function requireAdminKey(adminKey: string) {
  const expected = Buffer.from(adminKey);

  return async function adminGuard(request: FastifyRequest): Promise<void> {
    const provided = Buffer.from(String(request.headers['x-admin-key'] ?? ''));
    const valid = provided.length === expected.length && timingSafeEqual(provided, expected);
    if (!valid) throw Errors.forbidden('Clave de administración inválida.');
  };
}
