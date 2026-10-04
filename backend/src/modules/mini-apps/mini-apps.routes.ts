import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import { AppError, Errors } from '../../shared/errors.js';
import type { Segment } from '../../shared/segments.js';
import { MINI_APPS } from './catalog.js';
import { annualRateFor, quoteCredit } from './credit.js';

const appParams = z.object({ appId: z.string().min(1).max(60) });
const creditBody = z.object({
  amountMinor: z.number().int().min(500_00).max(50_000_00),
  termMonths: z.number().int().min(6).max(60),
});

const segmentOf = (deps: Deps, userId: string) =>
  (deps.db.prepare('SELECT segment FROM users WHERE id = ?').get(userId) as { segment: Segment })
    .segment;

function requireMiniAppsEnabled(deps: Deps): void {
  if (!deps.flags.current().miniApps) {
    throw new AppError(
      403,
      'mini_app_disabled',
      'Esta funcionalidad no está disponible por ahora.',
    );
  }
}

/** Rutas que usa la APP (sesión del cliente). */
export async function miniAppsHostRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  const config = { service: 'mini_apps' as const };

  /** Token delegado para que la mini app actúe en nombre del cliente. */
  app.post('/mini-apps/:appId/token', { config }, async (request) => {
    requireMiniAppsEnabled(deps);
    const { appId } = appParams.parse(request.params);
    const miniApp = MINI_APPS[appId];
    if (!miniApp) throw Errors.notFound('Mini app');

    const { token, expiresAt } = await deps.delegatedTokens.issue(
      request.userId,
      miniApp.id,
      miniApp.scopes,
    );
    return { token, expiresAt: expiresAt.toISOString(), scopes: miniApp.scopes };
  });

  /**
   * La SOLICITUD de crédito la hace la app nativa con la sesión del cliente,
   * tras su confirmación explícita: la mini app solo puede cotizar.
   */
  app.post('/credit/applications', { config }, async (request, reply) => {
    requireMiniAppsEnabled(deps);
    const { amountMinor, termMonths } = creditBody.parse(request.body);
    const quote = quoteCredit(
      amountMinor,
      termMonths,
      annualRateFor(segmentOf(deps, request.userId), termMonths),
    );
    const id = crypto.randomUUID();
    deps.db
      .prepare(
        `INSERT INTO credit_applications
           (id, user_id, amount_minor, term_months, annual_rate, monthly_payment_minor, status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, 'in_review', ?)`,
      )
      .run(
        id,
        request.userId,
        amountMinor,
        termMonths,
        quote.annualRate,
        quote.monthlyPaymentMinor,
        deps.now().toISOString(),
      );
    return reply.status(201).send({ applicationId: id, status: 'in_review', quote });
  });
}

/** Rutas que usa la MINI APP con su token delegado (nunca la sesión). */
export async function miniAppsPublicRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  app.addHook('preHandler', async (request: FastifyRequest) => {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw Errors.unauthorized('missing_token');
    const { userId } = await deps.delegatedTokens.verify(
      header.slice('Bearer '.length),
      'credit-simulator',
      'credit:quote',
    );
    request.userId = userId;
  });

  app.post('/credit/quote', { config: { service: 'mini_apps' } }, async (request) => {
    requireMiniAppsEnabled(deps);
    const { amountMinor, termMonths } = creditBody.parse(request.body);
    return quoteCredit(
      amountMinor,
      termMonths,
      annualRateFor(segmentOf(deps, request.userId), termMonths),
    );
  });
}
