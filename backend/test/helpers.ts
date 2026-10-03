import type { FastifyInstance } from 'fastify';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { createDeps, type Deps } from '../src/container.js';
import { openDatabase } from '../src/db/database.js';
import { seededRandom } from '../src/shared/random.js';

export interface TestContext {
  app: FastifyInstance;
  deps: Deps;
  clock: { now: () => Date; advance: (ms: number) => void };
  close: () => Promise<void>;
}

/** App completa con BD en memoria, reloj controlable y aleatoriedad fija. */
export async function createTestContext(start = new Date('2026-10-03T12:00:00.000Z')): Promise<TestContext> {
  let current = start;
  const clock = {
    now: () => current,
    advance: (ms: number) => {
      current = new Date(current.getTime() + ms);
    },
  };

  const config = loadConfig({
    NODE_ENV: 'test',
    DATABASE_PATH: ':memory:',
    ACTIVITY_INTERVAL_MS: '0',
    AUTH_RATE_LIMIT_PER_MINUTE: '1000',
  });
  const deps = createDeps(config, {
    db: openDatabase(':memory:'),
    now: clock.now,
    random: seededRandom(42),
  });
  const app = await buildApp(deps, { logger: false });

  return {
    app,
    deps,
    clock,
    close: async () => {
      await app.close();
      deps.db.close();
    },
  };
}

export const validRegistration = {
  email: 'ana@example.com',
  password: 'Segura123',
  fullName: 'Ana Gómez',
  goal: 'save',
  acceptTerms: true,
} as const;

export interface AuthResponse {
  user: { id: string; email: string; segment: string };
  session: { accessToken: string; refreshToken: string };
}

export async function registerUser(
  app: FastifyInstance,
  overrides: Partial<Record<keyof typeof validRegistration, unknown>> = {},
): Promise<AuthResponse> {
  const response = await app.inject({
    method: 'POST',
    url: '/v1/auth/register',
    payload: { ...validRegistration, ...overrides },
  });
  if (response.statusCode !== 201) {
    throw new Error(`registro falló: ${response.statusCode} ${response.body}`);
  }
  return response.json<AuthResponse>();
}

export const bearer = (token: string) => ({ authorization: `Bearer ${token}` });
