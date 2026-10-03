import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Deps } from '../../container.js';
import { decodeCursor, encodeCursor } from '../../shared/cursor.js';
import { Errors } from '../../shared/errors.js';
import { toAccountDto, toTransactionDto } from './accounts.mapper.js';

const accountParams = z.object({ accountId: z.string().min(1) });
const transactionParams = z.object({ transactionId: z.string().min(1) });
const listQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().optional(),
  category: z.string().optional(),
});

export async function accountsRoutes(app: FastifyInstance, { deps }: { deps: Deps }) {
  const repo = deps.accountsRepository;
  const config = { service: 'accounts' as const };

  app.get('/accounts', { config }, async (request) => {
    const accounts = repo.listByUser(request.userId);

    const totals = new Map<string, number>();
    for (const account of accounts) {
      totals.set(account.currency, (totals.get(account.currency) ?? 0) + account.balance_minor);
    }

    return {
      accounts: accounts.map(toAccountDto),
      totals: [...totals].map(([currency, balanceMinor]) => ({ currency, balanceMinor })),
      asOf: deps.now().toISOString(),
    };
  });

  app.get('/accounts/:accountId', { config }, async (request) => {
    const { accountId } = accountParams.parse(request.params);
    const account = repo.findForUser(accountId, request.userId);
    if (!account) throw Errors.notFound('Cuenta');
    return toAccountDto(account);
  });

  app.get('/accounts/:accountId/transactions', { config }, async (request) => {
    const { accountId } = accountParams.parse(request.params);
    const query = listQuery.parse(request.query);

    // Verifica pertenencia: un usuario no puede listar movimientos ajenos.
    const account = repo.findForUser(accountId, request.userId);
    if (!account) throw Errors.notFound('Cuenta');

    // Se pide un elemento extra para saber si hay otra página sin un COUNT.
    const rows = repo.listTransactions(accountId, {
      limit: query.limit + 1,
      cursor: query.cursor ? decodeCursor(query.cursor) : undefined,
      category: query.category,
    });
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];

    return {
      items: page.map((row) => toTransactionDto(row, account.currency)),
      nextCursor:
        rows.length > query.limit && last
          ? encodeCursor({ bookedAt: last.booked_at, id: last.id })
          : null,
    };
  });

  app.get('/transactions/:transactionId', { config }, async (request) => {
    const { transactionId } = transactionParams.parse(request.params);
    const row = repo.findTransactionForUser(transactionId, request.userId);
    if (!row) throw Errors.notFound('Movimiento');
    return { ...toTransactionDto(row, row.currency), accountName: row.account_name };
  });
}
