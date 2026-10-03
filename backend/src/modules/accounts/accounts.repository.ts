import type { Db } from '../../db/database.js';
import type { Cursor } from '../../shared/cursor.js';

export type AccountType = 'savings' | 'investment' | 'business';

export interface AccountRow {
  id: string;
  user_id: string;
  type: AccountType;
  name: string;
  number: string;
  currency: string;
  balance_minor: number;
  created_at: string;
}

export interface TransactionRow {
  id: string;
  account_id: string;
  /** Positivo = abono, negativo = cargo. En unidades menores (centavos). */
  amount_minor: number;
  balance_after_minor: number;
  description: string;
  category: string;
  counterparty: string | null;
  booked_at: string;
  transfer_id: string | null;
}

export interface NewTransaction {
  amountMinor: number;
  description: string;
  category: string;
  counterparty?: string | null;
  bookedAt: string;
  transferId?: string | null;
}

export class AccountsRepository {
  constructor(private readonly db: Db) {}

  listByUser(userId: string): AccountRow[] {
    return this.db
      .prepare('SELECT * FROM accounts WHERE user_id = ? ORDER BY created_at, name')
      .all(userId) as unknown as AccountRow[];
  }

  findForUser(accountId: string, userId: string): AccountRow | undefined {
    return this.db
      .prepare('SELECT * FROM accounts WHERE id = ? AND user_id = ?')
      .get(accountId, userId) as unknown as AccountRow | undefined;
  }

  insertAccount(account: AccountRow): void {
    this.db
      .prepare(
        `INSERT INTO accounts (id, user_id, type, name, number, currency, balance_minor, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        account.id,
        account.user_id,
        account.type,
        account.name,
        account.number,
        account.currency,
        account.balance_minor,
        account.created_at,
      );
  }

  /**
   * Registra un movimiento y actualiza el saldo de la cuenta. Debe llamarse
   * dentro de `inTransaction` para que saldo y movimiento sean consistentes.
   */
  applyTransaction(accountId: string, tx: NewTransaction): TransactionRow {
    const account = this.db
      .prepare('SELECT balance_minor FROM accounts WHERE id = ?')
      .get(accountId) as { balance_minor: number } | undefined;
    if (!account) throw new Error(`Cuenta inexistente: ${accountId}`);

    const row: TransactionRow = {
      id: crypto.randomUUID(),
      account_id: accountId,
      amount_minor: tx.amountMinor,
      balance_after_minor: account.balance_minor + tx.amountMinor,
      description: tx.description,
      category: tx.category,
      counterparty: tx.counterparty ?? null,
      booked_at: tx.bookedAt,
      transfer_id: tx.transferId ?? null,
    };

    this.db
      .prepare(
        `INSERT INTO transactions
           (id, account_id, amount_minor, balance_after_minor, description, category, counterparty, booked_at, transfer_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        row.id,
        row.account_id,
        row.amount_minor,
        row.balance_after_minor,
        row.description,
        row.category,
        row.counterparty,
        row.booked_at,
        row.transfer_id,
      );
    this.db
      .prepare('UPDATE accounts SET balance_minor = ? WHERE id = ?')
      .run(row.balance_after_minor, accountId);

    return row;
  }

  listTransactions(
    accountId: string,
    options: { limit: number; cursor?: Cursor; category?: string },
  ): TransactionRow[] {
    const conditions = ['account_id = ?'];
    const params: (string | number)[] = [accountId];

    if (options.cursor) {
      conditions.push('(booked_at < ? OR (booked_at = ? AND id < ?))');
      params.push(options.cursor.bookedAt, options.cursor.bookedAt, options.cursor.id);
    }
    if (options.category) {
      conditions.push('category = ?');
      params.push(options.category);
    }
    params.push(options.limit);

    return this.db
      .prepare(
        `SELECT * FROM transactions
         WHERE ${conditions.join(' AND ')}
         ORDER BY booked_at DESC, id DESC
         LIMIT ?`,
      )
      .all(...params) as unknown as TransactionRow[];
  }

  findTransactionForUser(
    transactionId: string,
    userId: string,
  ): (TransactionRow & { currency: string; account_name: string }) | undefined {
    return this.db
      .prepare(
        `SELECT t.*, a.currency, a.name AS account_name
         FROM transactions t JOIN accounts a ON a.id = t.account_id
         WHERE t.id = ? AND a.user_id = ?`,
      )
      .get(transactionId, userId) as unknown as
      | (TransactionRow & { currency: string; account_name: string })
      | undefined;
  }
}
