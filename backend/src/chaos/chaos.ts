import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Random } from '../shared/random.js';
import { SERVICES, type ServiceName } from '../shared/services.js';
import { requireAdminKey } from '../shared/admin-guard.js';

/** Falla configurada para un servicio. */
export interface ServiceFault {
  /** Latencia extra (ms) antes de procesar la petición. */
  latencyMs: number;
  /** Probabilidad (0..1) de responder 502 `upstream_error`. */
  errorRate: number;
  /** Si es `true`, el servicio responde siempre 503 `service_unavailable`. */
  down: boolean;
}

export interface ChaosConfig {
  enabled: boolean;
  services: Partial<Record<ServiceName, ServiceFault>>;
}

/** Actualización parcial: solo se modifica lo que viene en el patch. */
export interface ChaosPatch {
  enabled?: boolean;
  services?: Partial<Record<ServiceName, Partial<ServiceFault>>>;
}

/** Qué hacer con una petición concreta. */
export type ChaosDecision =
  | { action: 'pass'; latencyMs: number }
  | {
      action: 'fail';
      latencyMs: number;
      statusCode: 502 | 503;
      code: 'upstream_error' | 'service_unavailable';
    };

const DEFAULT_FAULT: ServiceFault = {
  latencyMs: 0,
  errorRate: 0,
  down: false,
};

export class ChaosController {
  private config: ChaosConfig = {
    enabled: false,
    services: {},
  };

  /** `random` se inyecta para que los tests sean deterministas. */
  constructor(private readonly random: Random = Math.random) {}

  /** Configuración vigente (devolver una copia, no la referencia interna). */
  current(): ChaosConfig {
    return structuredClone(this.config);
  }

  /**
   * Combina el patch con la configuración actual. Los campos que no vienen
   * en el patch se conservan; un servicio nuevo parte de
   * `{ latencyMs: 0, errorRate: 0, down: false }`.
   */
  update(patch: ChaosPatch): ChaosConfig {
    if (patch.enabled !== undefined) {
      this.config.enabled = patch.enabled;
    }

    if (patch.services) {
      for (const [service, faultPatch] of Object.entries(patch.services) as Array<
        [ServiceName, Partial<ServiceFault>]
      >) {
        if (!faultPatch) continue;

        const currentFault = this.config.services[service] ?? { ...DEFAULT_FAULT };

        this.config.services[service] = {
          latencyMs: faultPatch.latencyMs ?? currentFault.latencyMs,
          errorRate: faultPatch.errorRate ?? currentFault.errorRate,
          down: faultPatch.down ?? currentFault.down,
        };
      }
    }

    return this.current();
  }

  /** Vuelve a `{ enabled: false, services: {} }`. */
  reset(): ChaosConfig {
    this.config = {
      enabled: false,
      services: {},
    };
    return this.current();
  }

  /**
   * Reglas, en orden:
   * 1. Desactivado o ruta sin servicio → pass sin latencia.
   * 2. `down` → fail 503 service_unavailable.
   * 3. `random() < errorRate` → fail 502 upstream_error.
   * 4. Si no → pass con la latencia configurada.
   */
  decide(service: ServiceName | undefined): ChaosDecision {
    if (!this.config.enabled || !service) {
      return { action: 'pass', latencyMs: 0 };
    }

    const fault = this.config.services[service];
    if (!fault) {
      return { action: 'pass', latencyMs: 0 };
    }

    if (fault.down) {
      return {
        action: 'fail',
        latencyMs: fault.latencyMs,
        statusCode: 503,
        code: 'service_unavailable',
      };
    }

    if (this.random() < fault.errorRate) {
      return {
        action: 'fail',
        latencyMs: fault.latencyMs,
        statusCode: 502,
        code: 'upstream_error',
      };
    }

    return {
      action: 'pass',
      latencyMs: fault.latencyMs,
    };
  }
}

export interface ChaosHookOptions {
  /** Se inyecta en tests para no esperar de verdad. */
  sleep?: (ms: number) => Promise<void>;
}

const defaultSleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * Registra un hook `onRequest` que consulta `controller.decide()` con el
 * servicio de la ruta (`request.routeOptions.config.service`), espera la
 * latencia y, si la decisión es `fail`, responde con el formato de error
 * estándar `{ error: { code, message, correlationId } }`. En 503 agrega el
 * header `Retry-After: 5`.
 *
 * Debe registrarse en la instancia raíz ANTES que las rutas.
 */
export function registerChaos(
  app: FastifyInstance,
  controller: ChaosController,
  options: ChaosHookOptions = {},
): void {
  const sleepFn = options.sleep ?? defaultSleep;

  app.addHook('onRequest', async (request, reply) => {
    const decision = controller.decide(request.routeOptions.config.service);

    if (decision.latencyMs > 0) {
      await sleepFn(decision.latencyMs);
    }

    if (decision.action === 'fail') {
      if (decision.statusCode === 503) {
        reply.header('Retry-After', '5');
      }

      const correlationId = request.id;
      const message =
        decision.code === 'service_unavailable'
          ? 'El servicio no está disponible en este momento.'
          : 'Un servicio interno respondió con error.';

      return reply.status(decision.statusCode).send({
        error: {
          code: decision.code,
          message,
          correlationId,
        },
      });
    }
  });
}

/**
 * Schema de validación Zod para ChaosPatch. `.strict()` rechaza campos
 * desconocidos (p. ej. `latency` en vez de `latencyMs`) en lugar de ignorarlos.
 */
const faultSchema = z
  .object({
    latencyMs: z.number().int().min(0).max(30000).optional(),
    errorRate: z.number().min(0).max(1).optional(),
    down: z.boolean().optional(),
  })
  .strict();

const chaosPatchSchema = z
  .object({
    enabled: z.boolean().optional(),
    // partialRecord: en Zod 4, z.record con un enum exige TODAS las claves.
    services: z.partialRecord(z.enum(SERVICES), faultSchema).optional(),
  })
  .strict();

/**
 * Rutas protegidas con `requireAdminKey` (src/shared/admin-guard.ts):
 * - GET    /admin/chaos → configuración vigente
 * - PUT    /admin/chaos → aplica un ChaosPatch validado con zod (400 si es inválido)
 * - DELETE /admin/chaos → reset
 */
export async function chaosAdminRoutes(
  app: FastifyInstance,
  options: { controller: ChaosController; adminKey: string },
): Promise<void> {
  const { controller, adminKey } = options;

  app.addHook('onRequest', requireAdminKey(adminKey));

  app.get('/admin/chaos', async () => {
    return controller.current();
  });

  // Si el body es inválido, el ZodError llega al manejador global, que
  // responde 400 `validation_error` con el formato estándar de la API.
  app.put('/admin/chaos', async (request) => {
    return controller.update(chaosPatchSchema.parse(request.body));
  });

  app.delete('/admin/chaos', async () => {
    return controller.reset();
  });
}

