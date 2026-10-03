/**
 * Servicios de dominio que expone el BFF. Cada ruta declara a cuál pertenece
 * (`config.service`) para que el chaos testing y la telemetría puedan actuar
 * por servicio: así se simula una caída parcial (p. ej. solo `experience`).
 */
export const SERVICES = [
  'auth',
  'accounts',
  'transfers',
  'experience',
  'mini_apps',
  'notifications',
] as const;

export type ServiceName = (typeof SERVICES)[number];

declare module 'fastify' {
  interface FastifyContextConfig {
    service?: ServiceName;
  }
}
