import Fastify, { type FastifyInstance } from 'fastify';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ChaosController, chaosAdminRoutes, registerChaos } from '../src/chaos/chaos.js';
import { registerErrorHandler } from '../src/shared/errors.js';
import '../src/shared/services.js';

/**
 * Especificación del chaos testing. Permite demostrar en vivo cómo se
 * comporta la app ante latencia alta, errores intermitentes y caídas
 * parciales (un servicio caído mientras los demás funcionan).
 */

const ADMIN = { 'x-admin-key': 'test-key' };

async function buildTestApp(controller: ChaosController, sleep = vi.fn(async (_ms: number) => {})) {
  const app = Fastify({ logger: false });
  registerErrorHandler(app);
  registerChaos(app, controller, { sleep });

  app.get('/accounts', { config: { service: 'accounts' } }, async () => ({ ok: true }));
  app.get('/experience', { config: { service: 'experience' } }, async () => ({ ok: true }));
  app.get('/health', async () => ({ status: 'ok' }));
  await app.register(chaosAdminRoutes, { controller, adminKey: 'test-key' });

  return { app, sleep };
}

describe('ChaosController', () => {
  it('arranca desactivado y sin fallas configuradas', () => {
    const controller = new ChaosController();

    expect(controller.current()).toEqual({ enabled: false, services: {} });
  });

  it('combina actualizaciones parciales sin perder lo configurado', () => {
    const controller = new ChaosController();

    controller.update({ enabled: true, services: { accounts: { latencyMs: 500 } } });
    const config = controller.update({ services: { accounts: { errorRate: 0.5 } } });

    expect(config).toEqual({
      enabled: true,
      services: { accounts: { latencyMs: 500, errorRate: 0.5, down: false } },
    });
  });

  it('reset vuelve a la configuración inicial', () => {
    const controller = new ChaosController();
    controller.update({ enabled: true, services: { auth: { down: true } } });

    expect(controller.reset()).toEqual({ enabled: false, services: {} });
  });

  it('desactivado, deja pasar todo aunque haya fallas configuradas', () => {
    const controller = new ChaosController();
    controller.update({ enabled: false, services: { accounts: { down: true, latencyMs: 900 } } });

    expect(controller.decide('accounts')).toEqual({ action: 'pass', latencyMs: 0 });
  });

  it('las rutas sin servicio (p. ej. /health) nunca se afectan', () => {
    const controller = new ChaosController();
    controller.update({ enabled: true, services: { accounts: { down: true } } });

    expect(controller.decide(undefined)).toEqual({ action: 'pass', latencyMs: 0 });
  });

  it('un servicio caído falla con 503 service_unavailable', () => {
    const controller = new ChaosController();
    controller.update({ enabled: true, services: { accounts: { down: true, latencyMs: 200 } } });

    expect(controller.decide('accounts')).toEqual({
      action: 'fail',
      latencyMs: 200,
      statusCode: 503,
      code: 'service_unavailable',
    });
  });

  it('errorRate falla cuando el número aleatorio es menor que la tasa', () => {
    const unlucky = new ChaosController(() => 0.2);
    const lucky = new ChaosController(() => 0.8);
    for (const c of [unlucky, lucky]) {
      c.update({ enabled: true, services: { accounts: { errorRate: 0.5 } } });
    }

    expect(unlucky.decide('accounts')).toEqual({
      action: 'fail',
      latencyMs: 0,
      statusCode: 502,
      code: 'upstream_error',
    });
    expect(lucky.decide('accounts')).toEqual({ action: 'pass', latencyMs: 0 });
  });
});

describe('Hook de chaos', () => {
  let app: FastifyInstance;
  afterEach(() => app.close());

  it('no altera las respuestas cuando está desactivado', async () => {
    ({ app } = await buildTestApp(new ChaosController()));

    const response = await app.inject({ method: 'GET', url: '/accounts' });

    expect(response.statusCode).toBe(200);
  });

  it('simula una caída parcial: accounts cae y experience sigue funcionando', async () => {
    const controller = new ChaosController();
    controller.update({ enabled: true, services: { accounts: { down: true } } });
    ({ app } = await buildTestApp(controller));

    const accounts = await app.inject({ method: 'GET', url: '/accounts' });
    const experience = await app.inject({ method: 'GET', url: '/experience' });

    expect(accounts.statusCode).toBe(503);
    expect(accounts.json()).toMatchObject({ error: { code: 'service_unavailable' } });
    expect(accounts.headers['retry-after']).toBe('5');
    expect(experience.statusCode).toBe(200);
  });

  it('responde 502 upstream_error ante errores intermitentes', async () => {
    const controller = new ChaosController(() => 0);
    controller.update({ enabled: true, services: { accounts: { errorRate: 1 } } });
    ({ app } = await buildTestApp(controller));

    const response = await app.inject({ method: 'GET', url: '/accounts' });

    expect(response.statusCode).toBe(502);
    expect(response.json()).toMatchObject({ error: { code: 'upstream_error' } });
  });

  it('agrega la latencia configurada antes de responder', async () => {
    const controller = new ChaosController();
    controller.update({ enabled: true, services: { accounts: { latencyMs: 3000 } } });
    let sleep;
    ({ app, sleep } = await buildTestApp(controller));

    const response = await app.inject({ method: 'GET', url: '/accounts' });

    expect(sleep).toHaveBeenCalledWith(3000);
    expect(response.statusCode).toBe(200);
  });

  it('no duerme cuando no hay latencia configurada', async () => {
    const controller = new ChaosController();
    controller.update({ enabled: true, services: { accounts: { down: true } } });
    let sleep;
    ({ app, sleep } = await buildTestApp(controller));

    await app.inject({ method: 'GET', url: '/accounts' });

    expect(sleep).not.toHaveBeenCalled();
  });
});

describe('Rutas /admin/chaos', () => {
  let app: FastifyInstance;
  afterEach(() => app.close());

  it('exigen la clave de administración', async () => {
    ({ app } = await buildTestApp(new ChaosController()));

    const response = await app.inject({ method: 'GET', url: '/admin/chaos' });

    expect(response.statusCode).toBe(403);
  });

  it('PUT actualiza y GET devuelve la configuración vigente', async () => {
    ({ app } = await buildTestApp(new ChaosController()));

    const put = await app.inject({
      method: 'PUT',
      url: '/admin/chaos',
      headers: ADMIN,
      payload: { enabled: true, services: { experience: { down: true } } },
    });
    const get = await app.inject({ method: 'GET', url: '/admin/chaos', headers: ADMIN });

    expect(put.statusCode).toBe(200);
    expect(get.json()).toEqual({
      enabled: true,
      services: { experience: { latencyMs: 0, errorRate: 0, down: true } },
    });
  });

  it.each([
    ['errorRate fuera de rango', { services: { accounts: { errorRate: 2 } } }],
    ['latencia negativa', { services: { accounts: { latencyMs: -1 } } }],
    ['latencia mayor a 30 s', { services: { accounts: { latencyMs: 30_001 } } }],
    ['servicio desconocido', { services: { pagos: { down: true } } }],
    ['campo con error de tipeo', { services: { accounts: { latency: 500 } } }],
  ])('PUT rechaza %s con 400 validation_error', async (_, payload) => {
    ({ app } = await buildTestApp(new ChaosController()));

    const response = await app.inject({
      method: 'PUT',
      url: '/admin/chaos',
      headers: ADMIN,
      payload,
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ error: { code: 'validation_error' } });
  });

  it('DELETE restablece la configuración', async () => {
    const controller = new ChaosController();
    controller.update({ enabled: true, services: { auth: { down: true } } });
    ({ app } = await buildTestApp(controller));

    const response = await app.inject({ method: 'DELETE', url: '/admin/chaos', headers: ADMIN });

    expect(response.json()).toEqual({ enabled: false, services: {} });
  });
});
