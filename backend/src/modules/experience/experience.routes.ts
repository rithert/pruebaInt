import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import { requireAdminKey } from '../../shared/admin-guard.js';
import { buildHomeLayout, SCHEMA_VERSION } from './rules.js';
import { collectSignals } from './signals.js';

const eventsBody = z.object({
  events: z
    .array(
      z.object({
        type: z.enum(['tapped', 'dismissed']),
        componentId: z.string().min(1).max(80),
      }),
    )
    .min(1)
    .max(50),
});

const flagsBody = z
  .object({
    insights: z.boolean(),
    promotions: z.boolean(),
    miniApps: z.boolean(),
  })
  .partial()
  .strict();

/** Experiencia del home dirigida por el servidor (SDUI) + eventos de uso. */
export async function experienceRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  const config = { service: 'experience' as const };

  app.get('/experience/home', { config }, async (request) => {
    const signals = collectSignals(deps.db, request.userId, deps.now());
    return {
      schemaVersion: SCHEMA_VERSION,
      layoutId: `home.${signals.segment}`,
      generatedAt: deps.now().toISOString(),
      components: buildHomeLayout(signals, deps.flags.current()),
    };
  });

  app.post('/events', { config }, async (request, reply) => {
    const { events } = eventsBody.parse(request.body);
    const insert = deps.db.prepare(
      'INSERT INTO user_events (id, user_id, type, component_id, created_at) VALUES (?, ?, ?, ?, ?)',
    );
    const at = deps.now().toISOString();
    for (const event of events) {
      insert.run(crypto.randomUUID(), request.userId, event.type, event.componentId, at);
    }
    return reply.status(202).send({ accepted: events.length });
  });
}

/** Kill switches de la experiencia (protegidos por ADMIN_KEY). */
export async function flagsAdminRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  app.addHook('onRequest', requireAdminKey(deps.config.adminKey));
  app.get('/admin/flags', async () => deps.flags.current());
  app.put('/admin/flags', async (request) => deps.flags.update(flagsBody.parse(request.body)));
}
