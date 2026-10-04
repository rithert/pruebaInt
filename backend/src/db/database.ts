import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

export type Db = DatabaseSync;

/**
 * Migraciones versionadas con `PRAGMA user_version`. Solo se agregan al
 * final; nunca se edita una migración ya aplicada.
 */
const MIGRATIONS: readonly string[] = [
  `
  CREATE TABLE users (
    id                TEXT PRIMARY KEY,
    email             TEXT NOT NULL UNIQUE,
    password_hash     TEXT NOT NULL,
    full_name         TEXT NOT NULL,
    goal              TEXT NOT NULL,
    segment           TEXT NOT NULL,
    terms_accepted_at TEXT NOT NULL,
    created_at        TEXT NOT NULL
  );

  CREATE TABLE refresh_tokens (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    family_id   TEXT NOT NULL,
    token_hash  TEXT NOT NULL UNIQUE,
    expires_at  TEXT NOT NULL,
    revoked_at  TEXT,
    replaced_by TEXT,
    created_at  TEXT NOT NULL
  );
  CREATE INDEX idx_refresh_tokens_family ON refresh_tokens(family_id);

  CREATE TABLE accounts (
    id            TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type          TEXT NOT NULL,
    name          TEXT NOT NULL,
    number        TEXT NOT NULL,
    currency      TEXT NOT NULL,
    balance_minor INTEGER NOT NULL,
    created_at    TEXT NOT NULL
  );
  CREATE INDEX idx_accounts_user ON accounts(user_id);

  CREATE TABLE transactions (
    id                  TEXT PRIMARY KEY,
    account_id          TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    amount_minor        INTEGER NOT NULL,
    balance_after_minor INTEGER NOT NULL,
    description         TEXT NOT NULL,
    category            TEXT NOT NULL,
    counterparty        TEXT,
    booked_at           TEXT NOT NULL,
    transfer_id         TEXT
  );
  CREATE INDEX idx_transactions_account_booked
    ON transactions(account_id, booked_at DESC, id DESC);

  CREATE TABLE transfers (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key TEXT NOT NULL,
    request_hash    TEXT NOT NULL,
    response_json   TEXT NOT NULL,
    created_at      TEXT NOT NULL,
    UNIQUE (user_id, idempotency_key)
  );
  `,
  // v2: eventos de uso para personalizar la experiencia.
  `
  CREATE TABLE user_events (
    id           TEXT PRIMARY KEY,
    user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type         TEXT NOT NULL,
    component_id TEXT NOT NULL,
    created_at   TEXT NOT NULL
  );
  CREATE INDEX idx_user_events_user ON user_events(user_id, created_at);
  `,
  // v3: solicitudes de crédito creadas desde la mini app (vía la app nativa).
  `
  CREATE TABLE credit_applications (
    id                    TEXT PRIMARY KEY,
    user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount_minor          INTEGER NOT NULL,
    term_months           INTEGER NOT NULL,
    annual_rate           REAL NOT NULL,
    monthly_payment_minor INTEGER NOT NULL,
    status                TEXT NOT NULL,
    created_at            TEXT NOT NULL
  );
  `,
  // v4: dispositivos registrados para notificaciones push.
  `
  CREATE TABLE device_tokens (
    token      TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform   TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  CREATE INDEX idx_device_tokens_user ON device_tokens(user_id);
  `,
];

export function openDatabase(path: string): Db {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });

  const db = new DatabaseSync(path);
  db.exec('PRAGMA foreign_keys = ON;');
  if (path !== ':memory:') db.exec('PRAGMA journal_mode = WAL;');
  migrate(db);
  return db;
}

export function migrate(db: Db): void {
  const { user_version: current } = db.prepare('PRAGMA user_version').get() as {
    user_version: number;
  };
  for (let version = current; version < MIGRATIONS.length; version++) {
    inTransaction(db, () => {
      db.exec(MIGRATIONS[version]!);
      db.exec(`PRAGMA user_version = ${version + 1}`);
    });
  }
}

/** Ejecuta `work` de forma atómica: o se aplica todo o nada. */
export function inTransaction<T>(db: Db, work: () => T): T {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = work();
    db.exec('COMMIT');
    return result;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}
