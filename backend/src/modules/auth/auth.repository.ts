import type { Db } from '../../db/database.js';
import type { Goal, Segment } from '../../shared/segments.js';

export interface UserRow {
  id: string;
  email: string;
  password_hash: string;
  full_name: string;
  goal: Goal;
  segment: Segment;
  terms_accepted_at: string;
  created_at: string;
}

export interface RefreshTokenRow {
  id: string;
  user_id: string;
  family_id: string;
  token_hash: string;
  expires_at: string;
  revoked_at: string | null;
  replaced_by: string | null;
  created_at: string;
}

export class AuthRepository {
  constructor(private readonly db: Db) {}

  findUserByEmail(email: string): UserRow | undefined {
    return this.db.prepare('SELECT * FROM users WHERE email = ?').get(email) as unknown as
      | UserRow
      | undefined;
  }

  findUserById(id: string): UserRow | undefined {
    return this.db.prepare('SELECT * FROM users WHERE id = ?').get(id) as unknown as
      | UserRow
      | undefined;
  }

  insertUser(user: UserRow): void {
    this.db
      .prepare(
        `INSERT INTO users (id, email, password_hash, full_name, goal, segment, terms_accepted_at, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        user.id,
        user.email,
        user.password_hash,
        user.full_name,
        user.goal,
        user.segment,
        user.terms_accepted_at,
        user.created_at,
      );
  }

  insertRefreshToken(token: RefreshTokenRow): void {
    this.db
      .prepare(
        `INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, expires_at, revoked_at, replaced_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        token.id,
        token.user_id,
        token.family_id,
        token.token_hash,
        token.expires_at,
        token.revoked_at,
        token.replaced_by,
        token.created_at,
      );
  }

  findRefreshTokenByHash(hash: string): RefreshTokenRow | undefined {
    return this.db
      .prepare('SELECT * FROM refresh_tokens WHERE token_hash = ?')
      .get(hash) as unknown as RefreshTokenRow | undefined;
  }

  markRefreshTokenRotated(id: string, revokedAt: string, replacedBy: string): void {
    this.db
      .prepare('UPDATE refresh_tokens SET revoked_at = ?, replaced_by = ? WHERE id = ?')
      .run(revokedAt, replacedBy, id);
  }

  revokeFamily(familyId: string, revokedAt: string): void {
    this.db
      .prepare(
        'UPDATE refresh_tokens SET revoked_at = ? WHERE family_id = ? AND revoked_at IS NULL',
      )
      .run(revokedAt, familyId);
  }
}
