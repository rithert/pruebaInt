import type { AccountRow, TransactionRow } from './accounts.repository.js';

/**
 * DTOs públicos. Nunca se expone el número completo de cuenta ni columnas
 * internas: la app recibe solo lo que necesita mostrar.
 */
export function toAccountDto(row: AccountRow) {
  return {
    id: row.id,
    type: row.type,
    name: row.name,
    maskedNumber: `•••• ${row.number.slice(-4)}`,
    currency: row.currency,
    balanceMinor: row.balance_minor,
  };
}

export function toTransactionDto(row: TransactionRow, currency: string) {
  return {
    id: row.id,
    accountId: row.account_id,
    amountMinor: row.amount_minor,
    balanceAfterMinor: row.balance_after_minor,
    currency,
    direction: row.amount_minor >= 0 ? 'credit' : 'debit',
    description: row.description,
    category: row.category,
    counterparty: row.counterparty,
    bookedAt: row.booked_at,
    transferId: row.transfer_id,
  };
}
