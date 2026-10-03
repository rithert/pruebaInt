import type { FastifyRequest } from 'fastify';

import { Errors } from '../../shared/errors.js';
import type { TokenService } from './tokens.js';

declare module 'fastify' {
  interface FastifyRequest {
    /** Id del cliente autenticado; lo completa `authenticate`. */
    userId: string;
  }
}

export function authGuard(tokens: TokenService) {
  return async function authenticate(request: FastifyRequest): Promise<void> {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw Errors.unauthorized('missing_token', 'Se requiere autenticación.');
    }
    const { userId } = await tokens.verifyAccessToken(header.slice('Bearer '.length));
    request.userId = userId;
  };
}
