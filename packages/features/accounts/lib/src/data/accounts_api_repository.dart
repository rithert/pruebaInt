import 'package:core/core.dart';

import '../domain/accounts_repository.dart';
import '../domain/models.dart';

class AccountsApiRepository implements AccountsRepository {
  AccountsApiRepository({
    required this._api,
    required this._fetcher,
    required this._cache,
  });

  static const _pageSize = 20;

  final ApiClient _api;
  final CachedFetcher _fetcher;
  final CacheStore _cache;

  @override
  Stream<Resource<AccountsOverview>> watchOverview() => _fetcher.watch(
    key: 'accounts.overview',
    fetch: () => _api.get('/v1/accounts', decode: (json) => json),
    decode: AccountsOverview.fromJson,
  );

  @override
  Future<Result<TransactionPage>> transactions(
    String accountId, {
    String? cursor,
    String? category,
  }) async {
    final result = await _api.get(
      '/v1/accounts/$accountId/transactions',
      query: {'limit': _pageSize, 'cursor': ?cursor, 'category': ?category},
      decode: (json) => json,
    );

    // Solo la primera página se guarda y se usa como respaldo: es lo que el
    // usuario ve al abrir la cuenta sin conexión.
    final isFirstPage = cursor == null;
    final cacheKey = 'accounts.$accountId.transactions.${category ?? 'all'}';

    switch (result) {
      case Success(:final value):
        if (isFirstPage) await _cache.write(cacheKey, value);
        return Success(TransactionPage.fromJson(value));
      case Failure(:final failure):
        if (!isFirstPage) return Failure(failure);
        final cached = await _cache.read(cacheKey);
        if (cached == null) return Failure(failure);
        final page = TransactionPage.fromJson(cached.json);
        return Success(
          TransactionPage(
            items: page.items,
            nextCursor: null, // Sin red no se puede paginar.
            cachedAt: cached.updatedAt,
          ),
        );
    }
  }

  @override
  Future<Result<Transaction>> transaction(String transactionId) => _api.get(
    '/v1/transactions/$transactionId',
    decode: (json) => Transaction.fromJson(json! as Map<String, Object?>),
  );

  @override
  Future<Result<TransferReceipt>> transfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required String idempotencyKey,
    String? description,
  }) => _api.post(
    '/v1/transfers',
    headers: {'Idempotency-Key': idempotencyKey},
    body: {
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amountMinor': amountMinor,
      'description': ?description,
    },
    decode: TransferReceipt.fromJson,
  );
}
