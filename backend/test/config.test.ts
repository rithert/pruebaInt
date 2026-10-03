import { describe, expect, it } from 'vitest';

import { loadConfig } from '../src/config.js';
import { createTestContext } from './helpers.js';

const PROD_SECRETS = { JWT_SECRET: 'x'.repeat(32), ADMIN_KEY: 'prod-admin-key' };

describe('loadConfig', () => {
  it('exige JWT_SECRET y ADMIN_KEY en producción', () => {
    expect(() => loadConfig({ NODE_ENV: 'production' })).toThrow(/JWT_SECRET/);
    expect(() => loadConfig({ NODE_ENV: 'production', JWT_SECRET: 'x'.repeat(32) })).toThrow(
      /ADMIN_KEY/,
    );
  });

  it('desactiva el chaos en producción por defecto', () => {
    expect(loadConfig({ NODE_ENV: 'production', ...PROD_SECRETS }).chaosEnabled).toBe(false);
    expect(loadConfig({ NODE_ENV: 'development' }).chaosEnabled).toBe(true);
  });

  it('CHAOS_ENABLED permite forzar el valor (p. ej. en staging)', () => {
    const config = loadConfig({ NODE_ENV: 'production', ...PROD_SECRETS, CHAOS_ENABLED: 'true' });
    expect(config.chaosEnabled).toBe(true);
  });
});

describe('Chaos deshabilitado', () => {
  it('no expone /admin/chaos aunque se envíe la clave correcta', async () => {
    const ctx = await createTestContext(undefined, { CHAOS_ENABLED: 'false' });

    const response = await ctx.app.inject({
      method: 'GET',
      url: '/admin/chaos',
      headers: { 'x-admin-key': 'dev-admin-key' },
    });

    expect(response.statusCode).toBe(404);
    await ctx.close();
  });
});
