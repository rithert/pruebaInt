import { afterAll, describe, expect, it } from 'vitest';

import { buildApp } from '../src/app.js';

describe('GET /health', () => {
  const app = buildApp({ logger: false });

  afterAll(() => app.close());

  it('responde ok', async () => {
    const response = await app.inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ status: 'ok' });
  });

  it('propaga el correlation-id recibido', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
      headers: { 'x-correlation-id': 'abc-123' },
    });

    expect(response.headers['x-correlation-id']).toBe('abc-123');
  });

  it('genera un correlation-id si no viene en la petición', async () => {
    const response = await app.inject({ method: 'GET', url: '/health' });

    expect(response.headers['x-correlation-id']).toMatch(/^[0-9a-f-]{36}$/);
  });
});
