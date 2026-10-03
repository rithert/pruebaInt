import { type Db, inTransaction } from '../../db/database.js';
import { Errors } from '../../shared/errors.js';
import type { Random } from '../../shared/random.js';
import { type Goal, initialSegmentFor } from '../../shared/segments.js';
import type { PortfolioGenerator } from '../activity/portfolio-generator.js';
import type { AuthRepository, UserRow } from './auth.repository.js';
import { hashPassword, verifyPassword } from './password.js';
import { generateRefreshToken, hashToken, type TokenService } from './tokens.js';

export interface RegisterInput {
  email: string;
  password: string;
  fullName: string;
  goal: Goal;
}

export interface Session {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
}

export interface UserProfile {
  id: string;
  email: string;
  fullName: string;
  goal: Goal;
  segment: UserRow['segment'];
  createdAt: string;
}

interface AuthServiceDeps {
  db: Db;
  repository: AuthRepository;
  tokens: TokenService;
  portfolio: PortfolioGenerator;
  refreshTtlSeconds: number;
  now: () => Date;
  random: Random;
}

// Hash de referencia para igualar el tiempo de respuesta cuando el email no
// existe y no revelar qué correos están registrados (enumeración de usuarios).
const DUMMY_HASH = await hashPassword('timing-equalizer');

export class AuthService {
  constructor(private readonly deps: AuthServiceDeps) {}

  async register(input: RegisterInput): Promise<{ user: UserProfile; session: Session }> {
    const { db, repository, portfolio, now, random } = this.deps;
    const email = normalizeEmail(input.email);

    if (repository.findUserByEmail(email)) {
      throw Errors.conflict('email_taken', 'Ya existe una cuenta con este correo.');
    }

    const passwordHash = await hashPassword(input.password);
    const timestamp = now().toISOString();
    const user: UserRow = {
      id: crypto.randomUUID(),
      email,
      password_hash: passwordHash,
      full_name: input.fullName.trim(),
      goal: input.goal,
      segment: initialSegmentFor(input.goal),
      terms_accepted_at: timestamp,
      created_at: timestamp,
    };

    // Usuario y productos se crean juntos: no puede quedar un cliente sin cuentas.
    inTransaction(db, () => {
      repository.insertUser(user);
      portfolio.generate(user, now(), random);
    });

    return { user: toProfile(user), session: await this.openSession(user.id) };
  }

  async login(emailInput: string, password: string): Promise<{ user: UserProfile; session: Session }> {
    const user = this.deps.repository.findUserByEmail(normalizeEmail(emailInput));
    const valid = await verifyPassword(password, user?.password_hash ?? DUMMY_HASH);

    if (!user || !valid) {
      throw Errors.unauthorized('invalid_credentials', 'Correo o contraseña incorrectos.');
    }
    return { user: toProfile(user), session: await this.openSession(user.id) };
  }

  /**
   * Rotación de refresh tokens: cada uso entrega uno nuevo e invalida el
   * anterior. Si llega un token ya rotado, alguien lo copió (robo o ataque de
   * repetición): se revoca toda la familia y ambos actores deben volver a
   * iniciar sesión.
   */
  async refresh(refreshToken: string): Promise<Session> {
    const { repository, now } = this.deps;
    const stored = repository.findRefreshTokenByHash(hashToken(refreshToken));
    const timestamp = now().toISOString();

    if (!stored) {
      throw Errors.unauthorized('invalid_refresh_token', 'La sesión no es válida.');
    }
    if (stored.revoked_at) {
      repository.revokeFamily(stored.family_id, timestamp);
      throw Errors.unauthorized('refresh_token_reused', 'La sesión fue cerrada por seguridad.');
    }
    if (stored.expires_at <= timestamp) {
      throw Errors.unauthorized('refresh_token_expired', 'La sesión expiró.');
    }

    const session = await this.openSession(stored.user_id, stored.family_id, (newId) =>
      repository.markRefreshTokenRotated(stored.id, timestamp, newId),
    );
    return session;
  }

  logout(refreshToken: string): void {
    const { repository, now } = this.deps;
    const stored = repository.findRefreshTokenByHash(hashToken(refreshToken));
    if (stored) repository.revokeFamily(stored.family_id, now().toISOString());
  }

  getProfile(userId: string): UserProfile {
    const user = this.deps.repository.findUserById(userId);
    if (!user) throw Errors.unauthorized('invalid_token', 'La sesión no es válida.');
    return toProfile(user);
  }

  private async openSession(
    userId: string,
    familyId: string = crypto.randomUUID(),
    beforeInsert?: (newTokenId: string) => void,
  ): Promise<Session> {
    const { db, repository, tokens, refreshTtlSeconds, now } = this.deps;
    const access = await tokens.issueAccessToken(userId);
    const refreshToken = generateRefreshToken();
    const issuedAt = now();
    const refreshExpiresAt = new Date(issuedAt.getTime() + refreshTtlSeconds * 1000);
    const id = crypto.randomUUID();

    inTransaction(db, () => {
      beforeInsert?.(id);
      repository.insertRefreshToken({
        id,
        user_id: userId,
        family_id: familyId,
        token_hash: hashToken(refreshToken),
        expires_at: refreshExpiresAt.toISOString(),
        revoked_at: null,
        replaced_by: null,
        created_at: issuedAt.toISOString(),
      });
    });

    return {
      accessToken: access.token,
      accessTokenExpiresAt: access.expiresAt.toISOString(),
      refreshToken,
      refreshTokenExpiresAt: refreshExpiresAt.toISOString(),
    };
  }
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function toProfile(user: UserRow): UserProfile {
  return {
    id: user.id,
    email: user.email,
    fullName: user.full_name,
    goal: user.goal,
    segment: user.segment,
    createdAt: user.created_at,
  };
}
