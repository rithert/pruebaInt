import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { createTestContext, type TestContext } from './helpers.js';

describe('GET /health', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestContext();
  });
  afterAll(() => ctx.close());

  it('responde ok', async () => {
    const response = await ctx.app.inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ status: 'ok' });
  });

  it('propaga el correlation-id recibido', async () => {
    const response = await ctx.app.inject({
      method: 'GET',
      url: '/health',
      headers: { 'x-correlation-id': 'abc-123' },
    });

    expect(response.headers['x-correlation-id']).toBe('abc-123');
  });

  it('genera un correlation-id si no viene en la petición', async () => {
    const response = await ctx.app.inject({ method: 'GET', url: '/health' });

    expect(response.headers['x-correlation-id']).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('responde 404 con el formato de error estándar', async () => {
    const response = await ctx.app.inject({ method: 'GET', url: '/no-existe' });

    expect(response.statusCode).toBe(404);
    expect(response.json()).toMatchObject({ error: { code: 'route_not_found' } });
  });
});
