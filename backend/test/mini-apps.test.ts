import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { quoteCredit } from '../src/modules/mini-apps/credit.js';
import { bearer, createTestContext, registerUser, type TestContext } from './helpers.js';

describe('quoteCredit (sistema francés)', () => {
  it('calcula cuota fija, total e intereses', () => {
    const quote = quoteCredit(10_000_00, 12, 0.12);

    // 10.000 al 12% anual en 12 meses → cuota de $888,49.
    expect(quote.monthlyPaymentMinor).toBe(888_49);
    expect(quote.totalPaymentMinor).toBe(888_49 * 12);
    expect(quote.totalInterestMinor).toBe(888_49 * 12 - 10_000_00);
  });
});

describe('Mini apps', () => {
  let ctx: TestContext;
  let session: string;

  beforeEach(async () => {
    ctx = await createTestContext();
    session = (await registerUser(ctx.app, { goal: 'grow_business' })).session.accessToken;
  });
  afterEach(() => ctx.close());

  const delegatedToken = async () =>
    (
      await ctx.app.inject({
        method: 'POST',
        url: '/v1/mini-apps/credit-simulator/token',
        headers: bearer(session),
      })
    ).json();

  const quote = (token: string, payload: object = { amountMinor: 5_000_00, termMonths: 24 }) =>
    ctx.app.inject({
      method: 'POST',
      url: '/v1/mini-api/credit/quote',
      headers: bearer(token),
      payload,
    });

  it('emite un token delegado con alcance mínimo', async () => {
    const body = await delegatedToken();

    expect(body.scopes).toEqual(['credit:quote']);
    expect(body.token).toBeTruthy();
  });

  it('la mini app cotiza con su token y la tasa depende del perfil', async () => {
    const { token } = await delegatedToken();
    const response = await quote(token);

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ termMonths: 24, annualRate: 0.165 });
  });

  it('el token de SESIÓN no sirve en la API de mini apps', async () => {
    expect((await quote(session)).statusCode).toBe(401);
  });

  it('el token DELEGADO no sirve como sesión del cliente', async () => {
    const { token } = await delegatedToken();
    const response = await ctx.app.inject({
      method: 'GET',
      url: '/v1/accounts',
      headers: bearer(token),
    });

    expect(response.statusCode).toBe(401);
  });

  it('el token delegado expira a los 5 minutos', async () => {
    const { token } = await delegatedToken();
    ctx.clock.advance(6 * 60 * 1000);

    const response = await quote(token);

    expect(response.json().error.code).toBe('token_expired');
  });

  it('valida montos y plazos', async () => {
    const { token } = await delegatedToken();

    expect((await quote(token, { amountMinor: 100, termMonths: 24 })).statusCode).toBe(400);
    expect((await quote(token, { amountMinor: 5_000_00, termMonths: 120 })).statusCode).toBe(400);
  });

  it('la solicitud la crea la app nativa con la sesión del cliente', async () => {
    const response = await ctx.app.inject({
      method: 'POST',
      url: '/v1/credit/applications',
      headers: bearer(session),
      payload: { amountMinor: 5_000_00, termMonths: 24 },
    });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({ status: 'in_review' });
  });

  it('KILL SWITCH: con el flag apagado no se emiten tokens', async () => {
    ctx.deps.flags.update({ miniApps: false });

    const response = await ctx.app.inject({
      method: 'POST',
      url: '/v1/mini-apps/credit-simulator/token',
      headers: bearer(session),
    });

    expect(response.statusCode).toBe(403);
    expect(response.json().error.code).toBe('mini_app_disabled');
  });

  it('CORS: solo el origen registrado de la mini app', async () => {
    const preflight = (origin: string) =>
      ctx.app.inject({
        method: 'OPTIONS',
        url: '/v1/mini-api/credit/quote',
        headers: {
          origin,
          'access-control-request-method': 'POST',
          'access-control-request-headers': 'authorization,content-type',
        },
      });

    const allowed = await preflight('http://localhost:3100');
    const denied = await preflight('https://sitio-malicioso.example');

    expect(allowed.headers['access-control-allow-origin']).toBe('http://localhost:3100');
    expect(denied.headers['access-control-allow-origin']).toBeUndefined();
  });
});
