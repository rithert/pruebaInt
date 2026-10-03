export interface AppConfig {
  env: 'development' | 'test' | 'production';
  port: number;
  host: string;
  databasePath: string;
  jwtSecret: string;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  /** Intentos de login/registro por IP y minuto. */
  authRateLimitPerMinute: number;
  /** Cada cuánto genera movimientos el motor de actividad. 0 lo desactiva. */
  activityIntervalMs: number;
  /** Clave para las rutas /admin (chaos, disparo manual de actividad). */
  adminKey: string;
  /** Registra el chaos testing. Por defecto: activo salvo en producción. */
  chaosEnabled: boolean;
}

const DEV_JWT_SECRET = 'dev-only-secret-change-me-0123456789abcdef';

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const nodeEnv = parseEnv(env.NODE_ENV);
  const isProd = nodeEnv === 'production';

  const jwtSecret = env.JWT_SECRET ?? (isProd ? '' : DEV_JWT_SECRET);
  if (jwtSecret.length < 32) {
    throw new Error('JWT_SECRET es obligatorio y debe tener al menos 32 caracteres.');
  }
  const adminKey = env.ADMIN_KEY ?? (isProd ? '' : 'dev-admin-key');
  if (!adminKey) {
    throw new Error('ADMIN_KEY es obligatorio en producción.');
  }

  return {
    env: nodeEnv,
    port: Number(env.PORT ?? 3000),
    host: env.HOST ?? '0.0.0.0',
    databasePath: env.DATABASE_PATH ?? './data/bff.db',
    jwtSecret,
    accessTokenTtlSeconds: Number(env.ACCESS_TOKEN_TTL_SECONDS ?? 15 * 60),
    refreshTokenTtlSeconds: Number(env.REFRESH_TOKEN_TTL_SECONDS ?? 30 * 24 * 3600),
    authRateLimitPerMinute: Number(env.AUTH_RATE_LIMIT_PER_MINUTE ?? 10),
    activityIntervalMs: Number(env.ACTIVITY_INTERVAL_MS ?? 60_000),
    adminKey,
    chaosEnabled: env.CHAOS_ENABLED ? env.CHAOS_ENABLED === 'true' : !isProd,
  };
}

function parseEnv(value: string | undefined): AppConfig['env'] {
  if (value === 'production' || value === 'test') return value;
  return 'development';
}
