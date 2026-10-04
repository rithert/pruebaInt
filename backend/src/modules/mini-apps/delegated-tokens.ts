import { errors as joseErrors, jwtVerify, SignJWT } from 'jose';

import { Errors } from '../../shared/errors.js';

const ISSUER = 'fintech-bff';

/** Tokens delegados a una mini app: corta duración y alcance mínimo. */
export const DELEGATED_TTL_SECONDS = 5 * 60;

const audienceFor = (appId: string) => `mini-app:${appId}`;

/**
 * La audience `mini-app:<id>` impide usar este token como sesión del cliente
 * (cuya audience es `super-app`) y viceversa; el scope limita qué puede hacer.
 */
export class DelegatedTokenService {
  private readonly key: Uint8Array;

  constructor(
    secret: string,
    private readonly now: () => Date,
  ) {
    this.key = new TextEncoder().encode(secret);
  }

  async issue(
    userId: string,
    appId: string,
    scopes: readonly string[],
  ): Promise<{ token: string; expiresAt: Date }> {
    const issuedAt = Math.floor(this.now().getTime() / 1000);
    const expiresAt = issuedAt + DELEGATED_TTL_SECONDS;
    const token = await new SignJWT({ scope: scopes.join(' ') })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer(ISSUER)
      .setAudience(audienceFor(appId))
      .setIssuedAt(issuedAt)
      .setExpirationTime(expiresAt)
      .sign(this.key);
    return { token, expiresAt: new Date(expiresAt * 1000) };
  }

  async verify(token: string, appId: string, requiredScope: string): Promise<{ userId: string }> {
    let payload;
    try {
      ({ payload } = await jwtVerify(token, this.key, {
        issuer: ISSUER,
        audience: audienceFor(appId),
        algorithms: ['HS256'],
        currentDate: this.now(),
      }));
    } catch (error) {
      if (error instanceof joseErrors.JWTExpired) {
        throw Errors.unauthorized('token_expired', 'El acceso de la mini app expiró.');
      }
      throw Errors.unauthorized('invalid_token', 'Token de mini app inválido.');
    }
    const scopes = typeof payload.scope === 'string' ? payload.scope.split(' ') : [];
    if (!payload.sub || !scopes.includes(requiredScope)) {
      throw Errors.forbidden('La mini app no tiene permiso para esta operación.');
    }
    return { userId: payload.sub };
  }
}
