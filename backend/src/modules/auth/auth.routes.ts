import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import { GOALS } from '../../shared/segments.js';

// Se normaliza antes de validar: los teclados móviles suelen agregar
// espacios o mayúsculas al autocompletar el correo.
const email = z.string().trim().toLowerCase().pipe(z.email());

const registerBody = z.object({
  email,
  password: z
    .string()
    .min(8, 'Mínimo 8 caracteres.')
    .max(128)
    .regex(/[A-Za-z]/, 'Debe incluir al menos una letra.')
    .regex(/\d/, 'Debe incluir al menos un número.'),
  fullName: z.string().trim().min(3).max(80),
  goal: z.enum(GOALS),
  acceptTerms: z.literal(true, { error: 'Debes aceptar los términos y condiciones.' }),
});

const loginBody = z.object({
  email,
  password: z.string().min(1).max(128),
});

const refreshBody = z.object({ refreshToken: z.string().min(20).max(200) });

/** Rutas públicas de autenticación, con límite de intentos contra fuerza bruta. */
export async function authRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  const config = {
    service: 'auth' as const,
    rateLimit: { max: deps.config.authRateLimitPerMinute, timeWindow: '1 minute' },
  };

  app.post('/auth/register', { config }, async (request, reply) => {
    const body = registerBody.parse(request.body);
    const result = await deps.authService.register(body);
    return reply.status(201).send(result);
  });

  app.post('/auth/login', { config }, async (request) => {
    const body = loginBody.parse(request.body);
    return deps.authService.login(body.email, body.password);
  });

  app.post('/auth/refresh', { config }, async (request) => {
    const { refreshToken } = refreshBody.parse(request.body);
    return { session: await deps.authService.refresh(refreshToken) };
  });

  app.post('/auth/logout', { config: { service: 'auth' } }, async (request, reply) => {
    const { refreshToken } = refreshBody.parse(request.body);
    deps.authService.logout(refreshToken);
    return reply.status(204).send();
  });
}

/** Rutas del perfil del cliente autenticado. */
export async function meRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  app.get('/me', { config: { service: 'auth' } }, async (request) =>
    deps.authService.getProfile(request.userId),
  );
}
