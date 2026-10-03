import { EventEmitter } from 'node:events';

import type { TransactionRow } from '../modules/accounts/accounts.repository.js';

/**
 * Eventos de dominio. Desacoplan a quien produce un hecho (transferencias,
 * motor de actividad) de quien reacciona (push, personalización).
 */
export interface DomainEventMap {
  'transaction.created': {
    userId: string;
    accountId: string;
    currency: string;
    transaction: TransactionRow;
    origin: 'activity' | 'transfer';
  };
}

export class DomainEvents {
  private readonly emitter = new EventEmitter();

  on<K extends keyof DomainEventMap>(event: K, listener: (payload: DomainEventMap[K]) => void): void {
    this.emitter.on(event, listener);
  }

  emit<K extends keyof DomainEventMap>(event: K, payload: DomainEventMap[K]): void {
    this.emitter.emit(event, payload);
  }
}
