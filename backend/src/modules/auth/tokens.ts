import { createHash, randomBytes } from 'node:crypto';

import { errors as joseErrors, jwtVerify, SignJWT } from 'jose';

import { AppError, Errors } from '../../shared/errors.js';

const ISSUER = 'fintech-bff';
const AUDIENCE = 'super-app';

/**
 * Access tokens: JWT firmados (HS256) de vida corta. No guardan estado en el
 * servidor, así que no se pueden revocar; por eso duran solo 15 minutos.
 */
export class TokenService {
  private readonly key: Uint8Array;

  constructor(
    secret: string,
    private readonly accessTtlSeconds: number,
    private readonly now: () => Date,
  ) {
    this.key = new TextEncoder().encode(secret);
  }

  async issueAccessToken(userId: string): Promise<{ token: string; expiresAt: Date }> {
    const issuedAt = Math.floor(this.now().getTime() / 1000);
    const expiresAt = issuedAt + this.accessTtlSeconds;

    const token = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer(ISSUER)
      .setAudience(AUDIENCE)
      .setIssuedAt(issuedAt)
      .setExpirationTime(expiresAt)
      .setJti(crypto.randomUUID())
      .sign(this.key);

    return { token, expiresAt: new Date(expiresAt * 1000) };
  }

  /**
   * Distingue `token_expired` de `invalid_token`: con el primero la app
   * intenta refrescar la sesión; con el segundo la cierra.
   */
  async verifyAccessToken(token: string): Promise<{ userId: string }> {
    try {
      const { payload } = await jwtVerify(token, this.key, {
        issuer: ISSUER,
        audience: AUDIENCE,
        algorithms: ['HS256'],
        currentDate: this.now(),
      });
      if (!payload.sub) throw Errors.unauthorized('invalid_token', 'Token inválido.');
      return { userId: payload.sub };
    } catch (error) {
      if (error instanceof AppError) throw error;
      if (error instanceof joseErrors.JWTExpired) {
        throw Errors.unauthorized('token_expired', 'La sesión expiró.');
      }
      throw Errors.unauthorized('invalid_token', 'Token inválido.');
    }
  }
}

/** Refresh token opaco de 256 bits. En BD solo se guarda su hash. */
export function generateRefreshToken(): string {
  return randomBytes(32).toString('base64url');
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
