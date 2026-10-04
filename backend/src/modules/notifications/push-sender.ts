import { existsSync, readFileSync } from 'node:fs';

import type { FastifyBaseLogger } from 'fastify';
import { cert, initializeApp, type App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

export interface PushMessage {
  title: string;
  body: string;
  /** Datos para la app (p. ej. `route` para el deep link). */
  data: Record<string, string>;
}

export interface PushResult {
  /** Tokens que FCM reporta como inválidos: se eliminan de la BD. */
  invalidTokens: string[];
}

/** Puerto de envío de notificaciones: FCM en real, en memoria en tests. */
export interface PushSender {
  readonly enabled: boolean;
  send(tokens: string[], message: PushMessage): Promise<PushResult>;
}

/** Sin credenciales de Firebase: no envía, solo deja rastro en el log. */
export class LogPushSender implements PushSender {
  readonly enabled = false;

  constructor(private readonly log?: FastifyBaseLogger) {}

  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    this.log?.info({ tokens: tokens.length, title: message.title }, 'push omitido (sin FCM)');
    return { invalidTokens: [] };
  }
}

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export class FcmPushSender implements PushSender {
  readonly enabled = true;

  constructor(private readonly app: App) {}

  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    if (tokens.length === 0) return { invalidTokens: [] };
    const response = await getMessaging(this.app).sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
      android: { priority: 'high' },
    });
    const invalidTokens = response.responses.flatMap((r, i) =>
      r.error && INVALID_TOKEN_CODES.has(r.error.code) ? [tokens[i]!] : [],
    );
    return { invalidTokens };
  }
}

/** FCM si hay credenciales; si no, el emisor que solo registra en log. */
export function createPushSender(
  serviceAccountPath: string | undefined,
  log?: FastifyBaseLogger,
): PushSender {
  if (!serviceAccountPath || !existsSync(serviceAccountPath)) {
    return new LogPushSender(log);
  }
  const credentials = JSON.parse(readFileSync(serviceAccountPath, 'utf8')) as object;
  return new FcmPushSender(initializeApp({ credential: cert(credentials) }, 'push'));
}
