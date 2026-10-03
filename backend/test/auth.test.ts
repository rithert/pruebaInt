import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import {
  bearer,
  createTestContext,
  registerUser,
  type TestContext,
  validRegistration,
} from './helpers.js';

describe('Autenticación', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await createTestContext();
  });
  afterEach(() => ctx.close());

  describe('registro', () => {
    it('crea el cliente con segmento según su objetivo y abre sesión', async () => {
      const { user, session } = await registerUser(ctx.app, { goal: 'invest' });

      expect(user).toMatchObject({ email: 'ana@example.com', segment: 'investor' });
      expect(session.accessToken).toBeTruthy();
      expect(session.refreshToken).toBeTruthy();
    });

    it('normaliza el correo y rechaza duplicados', async () => {
      await registerUser(ctx.app);
      const response = await ctx.app.inject({
        method: 'POST',
        url: '/v1/auth/register',
        payload: { ...validRegistration, email: '  ANA@Example.com ' },
      });

      expect(response.statusCode).toBe(409);
      expect(response.json()).toMatchObject({ error: { code: 'email_taken' } });
    });

    it.each([
      ['contraseña sin números', { password: 'soloLetras' }],
      ['contraseña corta', { password: 'a1' }],
      ['correo inválido', { email: 'no-es-correo' }],
      ['sin aceptar términos', { acceptTerms: false }],
      ['objetivo desconocido', { goal: 'apostar' }],
    ])('rechaza %s con validation_error', async (_, overrides) => {
      const response = await ctx.app.inject({
        method: 'POST',
        url: '/v1/auth/register',
        payload: { ...validRegistration, ...overrides },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ error: { code: 'validation_error' } });
    });

    it('nunca expone el hash de la contraseña', async () => {
      const response = await ctx.app.inject({
        method: 'POST',
        url: '/v1/auth/register',
        payload: validRegistration,
      });

      expect(response.body).not.toContain('scrypt');
      expect(response.body).not.toContain('password');
    });
  });

  describe('login', () => {
    it('inicia sesión con credenciales válidas', async () => {
      await registerUser(ctx.app);
      const response = await ctx.app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload: { email: 'ana@example.com', password: 'Segura123' },
      });

      expect(response.statusCode).toBe(200);
      expect(response.json()).toHaveProperty('session.accessToken');
    });

    it('responde igual ante correo inexistente y contraseña incorrecta', async () => {
      await registerUser(ctx.app);
      const wrongPassword = await ctx.app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload: { email: 'ana@example.com', password: 'Otra1234' },
      });
      const unknownEmail = await ctx.app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload: { email: 'nadie@example.com', password: 'Otra1234' },
      });

      expect(wrongPassword.statusCode).toBe(401);
      expect(unknownEmail.statusCode).toBe(401);
      expect(wrongPassword.json().error.code).toBe('invalid_credentials');
      expect(unknownEmail.json().error.code).toBe('invalid_credentials');
    });
  });

  describe('access token', () => {
    it('protege las rutas privadas', async () => {
      const response = await ctx.app.inject({ method: 'GET', url: '/v1/me' });

      expect(response.statusCode).toBe(401);
      expect(response.json().error.code).toBe('missing_token');
    });

    it('devuelve el perfil con un token válido', async () => {
      const { session } = await registerUser(ctx.app);
      const response = await ctx.app.inject({
        method: 'GET',
        url: '/v1/me',
        headers: bearer(session.accessToken),
      });

      expect(response.statusCode).toBe(200);
      expect(response.json()).toMatchObject({ fullName: 'Ana Gómez', goal: 'save' });
    });

    it('distingue un token expirado (token_expired) de uno inválido', async () => {
      const { session } = await registerUser(ctx.app);
      ctx.clock.advance(16 * 60 * 1000);

      const expired = await ctx.app.inject({
        method: 'GET',
        url: '/v1/me',
        headers: bearer(session.accessToken),
      });
      const tampered = await ctx.app.inject({
        method: 'GET',
        url: '/v1/me',
        headers: bearer(`${session.accessToken}x`),
      });

      expect(expired.json().error.code).toBe('token_expired');
      expect(tampered.json().error.code).toBe('invalid_token');
    });
  });

  describe('refresh rotativo', () => {
    const refresh = (token: string) =>
      ctx.app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken: token } });

    it('entrega una sesión nueva y un refresh token distinto', async () => {
      const { session } = await registerUser(ctx.app);
      ctx.clock.advance(16 * 60 * 1000);

      const response = await refresh(session.refreshToken);
      const renewed = response.json().session;

      expect(response.statusCode).toBe(200);
      expect(renewed.refreshToken).not.toBe(session.refreshToken);
      const me = await ctx.app.inject({
        method: 'GET',
        url: '/v1/me',
        headers: bearer(renewed.accessToken),
      });
      expect(me.statusCode).toBe(200);
    });

    it('detecta el reuso de un refresh token y revoca toda la familia', async () => {
      const { session } = await registerUser(ctx.app);
      const legit = (await refresh(session.refreshToken)).json().session;

      // Un atacante reutiliza el token viejo que ya fue rotado.
      const attack = await refresh(session.refreshToken);
      expect(attack.statusCode).toBe(401);
      expect(attack.json().error.code).toBe('refresh_token_reused');

      // El token legítimo más reciente también queda revocado.
      const afterAttack = await refresh(legit.refreshToken);
      expect(afterAttack.statusCode).toBe(401);
    });

    it('rechaza un refresh token expirado', async () => {
      const { session } = await registerUser(ctx.app);
      ctx.clock.advance(31 * 24 * 3600 * 1000);

      const response = await refresh(session.refreshToken);

      expect(response.json().error.code).toBe('refresh_token_expired');
    });

    it('logout invalida el refresh token', async () => {
      const { session } = await registerUser(ctx.app);
      const logout = await ctx.app.inject({
        method: 'POST',
        url: '/v1/auth/logout',
        payload: { refreshToken: session.refreshToken },
      });

      expect(logout.statusCode).toBe(204);
      expect((await refresh(session.refreshToken)).statusCode).toBe(401);
    });
  });
});
