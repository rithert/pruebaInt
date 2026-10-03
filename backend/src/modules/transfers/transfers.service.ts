import { createHash } from 'node:crypto';

import { type Db, inTransaction } from '../../db/database.js';
import { Errors } from '../../shared/errors.js';
import type { DomainEvents } from '../../shared/events.js';
import type { AccountsRepository, TransactionRow } from '../accounts/accounts.repository.js';

export interface TransferInput {
  fromAccountId: string;
  toAccountId: string;
  amountMinor: number;
  description?: string;
}

export interface TransferResult {
  transferId: string;
  amountMinor: number;
  currency: string;
  from: { accountId: string; balanceMinor: number };
  to: { accountId: string; balanceMinor: number };
  createdAt: string;
}

interface TransfersDeps {
  db: Db;
  accounts: AccountsRepository;
  events: DomainEvents;
  now: () => Date;
}

/**
 * Transferencias entre cuentas propias con **idempotencia**: la app envía un
 * `Idempotency-Key` por intento de usuario. Si la red falla y la app
 * reintenta (o la operación queda en la cola offline), el dinero se mueve
 * una sola vez y el reintento recibe la misma respuesta original.
 */
export class TransfersService {
  constructor(private readonly deps: TransfersDeps) {}

  execute(
    userId: string,
    idempotencyKey: string,
    input: TransferInput,
  ): { result: TransferResult; replayed: boolean } {
    const { db, accounts, events, now } = this.deps;
    const requestHash = hashRequest(input);
    const posted: { accountId: string; currency: string; tx: TransactionRow }[] = [];

    const outcome = inTransaction(db, () => {
      const previous = db
        .prepare(
          'SELECT request_hash, response_json FROM transfers WHERE user_id = ? AND idempotency_key = ?',
        )
        .get(userId, idempotencyKey) as { request_hash: string; response_json: string } | undefined;

      if (previous) {
        if (previous.request_hash !== requestHash) {
          throw Errors.unprocessable(
            'idempotency_key_reused',
            'Esta clave de idempotencia ya se usó con otros datos.',
          );
        }
        return { result: JSON.parse(previous.response_json) as TransferResult, replayed: true };
      }

      if (input.fromAccountId === input.toAccountId) {
        throw Errors.unprocessable(
          'same_account',
          'La cuenta de origen y destino deben ser distintas.',
        );
      }
      const from = accounts.findForUser(input.fromAccountId, userId);
      const to = accounts.findForUser(input.toAccountId, userId);
      if (!from || !to) throw Errors.notFound('Cuenta');
      if (from.currency !== to.currency) {
        throw Errors.unprocessable('currency_mismatch', 'Las cuentas tienen monedas distintas.');
      }
      if (from.balance_minor < input.amountMinor) {
        throw Errors.unprocessable('insufficient_funds', 'Saldo insuficiente.');
      }

      const transferId = crypto.randomUUID();
      const bookedAt = now().toISOString();
      const description = input.description?.trim() || 'Transferencia entre mis cuentas';

      const debit = accounts.applyTransaction(from.id, {
        amountMinor: -input.amountMinor,
        description,
        category: 'transfer',
        counterparty: to.name,
        bookedAt,
        transferId,
      });
      const credit = accounts.applyTransaction(to.id, {
        amountMinor: input.amountMinor,
        description,
        category: 'transfer',
        counterparty: from.name,
        bookedAt,
        transferId,
      });
      posted.push(
        { accountId: from.id, currency: from.currency, tx: debit },
        { accountId: to.id, currency: to.currency, tx: credit },
      );

      const result: TransferResult = {
        transferId,
        amountMinor: input.amountMinor,
        currency: from.currency,
        from: { accountId: from.id, balanceMinor: debit.balance_after_minor },
        to: { accountId: to.id, balanceMinor: credit.balance_after_minor },
        createdAt: bookedAt,
      };
      db.prepare(
        `INSERT INTO transfers (id, user_id, idempotency_key, request_hash, response_json, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
      ).run(transferId, userId, idempotencyKey, requestHash, JSON.stringify(result), bookedAt);

      return { result, replayed: false };
    });

    // Los eventos se emiten solo después del COMMIT: nunca se notifica algo que se revirtió.
    for (const entry of posted) {
      events.emit('transaction.created', {
        userId,
        accountId: entry.accountId,
        currency: entry.currency,
        transaction: entry.tx,
        origin: 'transfer',
      });
    }
    return outcome;
  }
}

function hashRequest(input: TransferInput): string {
  const canonical = JSON.stringify([
    input.fromAccountId,
    input.toAccountId,
    input.amountMinor,
    input.description ?? '',
  ]);
  return createHash('sha256').update(canonical).digest('hex');
}
