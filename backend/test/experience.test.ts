import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { DEFAULT_FLAGS } from '../src/modules/experience/flags.js';
import { buildHomeLayout, type SduiComponent } from '../src/modules/experience/rules.js';
import type { HomeSignals } from '../src/modules/experience/signals.js';
import { formatUsd } from '../src/shared/money.js';
import { bearer, createTestContext, registerUser, type TestContext } from './helpers.js';

const baseSignals: HomeSignals = {
  firstName: 'Ana',
  segment: 'saver',
  localHour: 9,
  mainAccountId: 'acc-1',
  mainBalanceMinor: 1_000_00,
  goalBalanceMinor: 250_00,
  spendCurrent: {},
  spendPrevious: {},
  incomeLast7dMinor: 0,
  salesLast7dMinor: 0,
  salesPrev7dMinor: 0,
  dismissed: new Set(),
  taps: {},
};

const ids = (components: SduiComponent[]) => components.map((c) => c.id);
const byId = (components: SduiComponent[], id: string) => components.find((c) => c.id === id);

describe('formatUsd', () => {
  it('formatea en es-EC', () => {
    expect(formatUsd(128430)).toBe('$1.284,30');
    expect(formatUsd(5)).toBe('$0,05');
    expect(formatUsd(-4520)).toBe('-$45,20');
  });
});

describe('buildHomeLayout (motor de reglas)', () => {
  it('saluda según la hora local y el segmento', () => {
    const layout = buildHomeLayout({ ...baseSignals, localHour: 20 }, DEFAULT_FLAGS);

    expect(byId(layout, 'greeting')?.props).toMatchObject({ title: 'Buenas noches, Ana' });
  });

  it('siempre incluye saludo, cuentas y acciones rápidas', () => {
    const layout = buildHomeLayout(baseSignals, DEFAULT_FLAGS);

    expect(ids(layout)).toEqual(expect.arrayContaining(['greeting', 'accounts', 'quick_actions']));
  });

  it('saldo bajo: el aviso tiene la máxima prioridad', () => {
    const layout = buildHomeLayout(
      { ...baseSignals, mainBalanceMinor: 12_50, incomeLast7dMinor: 400_00 },
      DEFAULT_FLAGS,
    );

    expect(ids(layout)[1]).toBe('insight.low_balance');
    expect(byId(layout, 'insight.low_balance')?.props).toMatchObject({
      body: expect.stringContaining('$12,50'),
    });
  });

  it('detecta un aumento relevante de gasto con cifras reales', () => {
    const layout = buildHomeLayout(
      {
        ...baseSignals,
        spendCurrent: { restaurants: 130_00, groceries: 100_00 },
        spendPrevious: { restaurants: 100_00, groceries: 95_00 },
      },
      DEFAULT_FLAGS,
    );

    const insight = byId(layout, 'insight.spending_up.restaurants');
    expect(insight?.props).toMatchObject({ title: 'Gastaste 30% más en restaurantes' });
    // Un aumento chico (5%) no genera ruido.
    expect(byId(layout, 'insight.spending_up.groceries')).toBeUndefined();
  });

  it('emprendedor: muestra la tendencia de ventas', () => {
    const layout = buildHomeLayout(
      {
        ...baseSignals,
        segment: 'entrepreneur',
        salesLast7dMinor: 600_00,
        salesPrev7dMinor: 500_00,
      },
      DEFAULT_FLAGS,
    );

    expect(byId(layout, 'insight.sales_trend')?.props).toMatchObject({
      title: 'Tus ventas subieron 20% esta semana',
    });
  });

  it('COMPORTAMIENTO: lo descartado no vuelve a aparecer', () => {
    const signals = { ...baseSignals, incomeLast7dMinor: 400_00 };
    const before = buildHomeLayout(signals, DEFAULT_FLAGS);
    const after = buildHomeLayout(
      { ...signals, dismissed: new Set(['insight.income_received', 'promo.saver']) },
      DEFAULT_FLAGS,
    );

    expect(ids(before)).toContain('insight.income_received');
    expect(ids(after)).not.toContain('insight.income_received');
    expect(ids(after)).not.toContain('promo.saver');
  });

  it('COMPORTAMIENTO: las acciones rápidas más usadas suben', () => {
    const layout = buildHomeLayout(
      { ...baseSignals, taps: { 'quick_actions.support': 5, 'quick_actions.movements': 2 } },
      DEFAULT_FLAGS,
    );

    const actions = byId(layout, 'quick_actions')?.props?.actions as { id: string }[];
    expect(actions.map((a) => a.id)).toEqual([
      'support',
      'movements',
      'transfer',
      'credit_simulator',
    ]);
  });

  it('FLAGS: apagar promociones e insights los quita sin publicar la app', () => {
    const layout = buildHomeLayout(
      { ...baseSignals, mainBalanceMinor: 10_00 },
      { insights: false, promotions: false, miniApps: false },
    );

    expect(ids(layout).some((id) => id.startsWith('insight.'))).toBe(false);
    expect(ids(layout).some((id) => id.startsWith('promo.'))).toBe(false);
  });

  it('FLAGS: la mini app aparece en acciones solo si está habilitada', () => {
    const off = buildHomeLayout(baseSignals, { ...DEFAULT_FLAGS, miniApps: false });
    const on = buildHomeLayout(baseSignals, { ...DEFAULT_FLAGS, miniApps: true });
    const actionIds = (layout: SduiComponent[]) =>
      (byId(layout, 'quick_actions')?.props?.actions as { id: string }[]).map((a) => a.id);

    expect(actionIds(off)).not.toContain('credit_simulator');
    expect(actionIds(on)).toContain('credit_simulator');
  });
});

describe('Rutas de experiencia', () => {
  let ctx: TestContext;
  let token: string;

  beforeEach(async () => {
    ctx = await createTestContext();
    token = (await registerUser(ctx.app, { goal: 'invest' })).session.accessToken;
  });
  afterEach(() => ctx.close());

  const home = () =>
    ctx.app.inject({ method: 'GET', url: '/v1/experience/home', headers: bearer(token) });

  it('devuelve un layout versionado con datos reales del cliente', async () => {
    const response = await home();
    const body = response.json();

    expect(response.statusCode).toBe(200);
    expect(body).toMatchObject({ schemaVersion: 1, layoutId: 'home.investor' });
    expect(body.components[0]).toMatchObject({ type: 'greeting' });
  });

  it('registra eventos y el siguiente layout los refleja', async () => {
    const promoId = (await home())
      .json()
      .components.find((c: SduiComponent) => c.type === 'promo_banner').id;

    const events = await ctx.app.inject({
      method: 'POST',
      url: '/v1/events',
      headers: bearer(token),
      payload: { events: [{ type: 'dismissed', componentId: promoId }] },
    });
    const after = (await home()).json().components as SduiComponent[];

    expect(events.statusCode).toBe(202);
    expect(after.map((c) => c.id)).not.toContain(promoId);
  });

  it('rechaza eventos inválidos', async () => {
    const response = await ctx.app.inject({
      method: 'POST',
      url: '/v1/events',
      headers: bearer(token),
      payload: { events: [{ type: 'hackeado', componentId: 'x' }] },
    });

    expect(response.statusCode).toBe(400);
  });

  it('los flags se cambian en caliente con la clave de administración', async () => {
    const put = await ctx.app.inject({
      method: 'PUT',
      url: '/admin/flags',
      headers: { 'x-admin-key': 'dev-admin-key' },
      payload: { promotions: false },
    });
    const components = (await home()).json().components as SduiComponent[];

    expect(put.json()).toMatchObject({ promotions: false });
    expect(components.some((c) => c.type === 'promo_banner')).toBe(false);
  });
});
