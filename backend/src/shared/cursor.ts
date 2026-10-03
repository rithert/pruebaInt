import { Errors } from './errors.js';

/**
 * Paginación por cursor (keyset) en lugar de offset: si llegan movimientos
 * nuevos mientras el usuario hace scroll, no se duplican ni se saltan filas.
 */
export interface Cursor {
  bookedAt: string;
  id: string;
}

export function encodeCursor(cursor: Cursor): string {
  return Buffer.from(`${cursor.bookedAt}|${cursor.id}`).toString('base64url');
}

export function decodeCursor(raw: string): Cursor {
  const [bookedAt, id] = Buffer.from(raw, 'base64url').toString('utf8').split('|');
  if (!bookedAt || !id || Number.isNaN(Date.parse(bookedAt))) {
    throw Errors.unprocessable('invalid_cursor', 'El cursor de paginación no es válido.');
  }
  return { bookedAt, id };
}
