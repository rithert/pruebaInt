import type { AppConfig } from './config.js';
import { type Db, openDatabase } from './db/database.js';
import { AccountsRepository } from './modules/accounts/accounts.repository.js';
import { ActivityEngine } from './modules/activity/activity-engine.js';
import { PortfolioGenerator } from './modules/activity/portfolio-generator.js';
import { AuthRepository } from './modules/auth/auth.repository.js';
import { AuthService } from './modules/auth/auth.service.js';
import { TokenService } from './modules/auth/tokens.js';
import { FlagStore } from './modules/experience/flags.js';
import { TransfersService } from './modules/transfers/transfers.service.js';
import { DomainEvents } from './shared/events.js';
import type { Random } from './shared/random.js';

/**
 * Composición manual de dependencias (sin framework de DI): explícita, fácil
 * de seguir y de sustituir en tests (reloj, aleatoriedad, base de datos).
 */
export interface Deps {
  config: AppConfig;
  db: Db;
  now: () => Date;
  random: Random;
  events: DomainEvents;
  tokens: TokenService;
  accountsRepository: AccountsRepository;
  authService: AuthService;
  transfersService: TransfersService;
  activityEngine: ActivityEngine;
  flags: FlagStore;
}

export interface DepsOverrides {
  db?: Db;
  now?: () => Date;
  random?: Random;
}

export function createDeps(config: AppConfig, overrides: DepsOverrides = {}): Deps {
  const db = overrides.db ?? openDatabase(config.databasePath);
  const now = overrides.now ?? (() => new Date());
  const random = overrides.random ?? Math.random;
  const events = new DomainEvents();

  const tokens = new TokenService(config.jwtSecret, config.accessTokenTtlSeconds, now);
  const accountsRepository = new AccountsRepository(db);
  const portfolio = new PortfolioGenerator(accountsRepository);

  return {
    config,
    db,
    now,
    random,
    events,
    tokens,
    accountsRepository,
    authService: new AuthService({
      db,
      repository: new AuthRepository(db),
      tokens,
      portfolio,
      refreshTtlSeconds: config.refreshTokenTtlSeconds,
      now,
      random,
    }),
    transfersService: new TransfersService({ db, accounts: accountsRepository, events, now }),
    activityEngine: new ActivityEngine({ db, accounts: accountsRepository, events, now, random }),
    flags: new FlagStore(),
  };
}
