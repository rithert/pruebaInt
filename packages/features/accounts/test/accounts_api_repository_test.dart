import 'package:accounts/accounts.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _txJson(String id) => {
  'id': id,
  'accountId': 'acc-1',
  'amountMinor': -4520000,
  'balanceAfterMinor': 100000000,
  'currency': 'USD',
  'direction': 'debit',
  'description': 'Compra con tarjeta débito',
  'category': 'groceries',
  'counterparty': 'Mercado Fresco',
  'bookedAt': '2026-10-03T12:00:00.000Z',
  'transferId': null,
};

void main() {
  late FakeAdapter adapter;
  late InMemoryCacheStore cache;
  late AccountsApiRepository repository;

  setUp(() {
    adapter = FakeAdapter();
    cache = InMemoryCacheStore();
    final api = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );
    repository = AccountsApiRepository(
      api: api,
      fetcher: CachedFetcher(cache),
      cache: cache,
    );
  });

  test('watchOverview decodifica cuentas y total del BFF', () async {
    adapter.enqueueJson(200, {
      'accounts': [
        {
          'id': 'acc-1',
          'type': 'savings',
          'name': 'Cuenta de ahorros',
          'maskedNumber': '•••• 1234',
          'currency': 'USD',
          'balanceMinor': 150000000,
        },
      ],
      'totals': [
        {'currency': 'USD', 'balanceMinor': 150000000},
      ],
      'asOf': '2026-10-03T12:00:00.000Z',
    });

    final last = await repository.watchOverview().last;

    expect(last.data?.accounts.single.type, AccountType.savings);
    expect(last.data?.totalMinor, 150000000);
  });

  test('transactions envía cursor y categoría al BFF', () async {
    adapter.enqueueJson(200, {'items': <Object>[], 'nextCursor': null});

    await repository.transactions('acc-1', cursor: 'c2', category: 'income');

    final query = adapter.requests.single.queryParameters;
    expect(adapter.requests.single.path, '/v1/accounts/acc-1/transactions');
    expect(query, {'limit': 20, 'cursor': 'c2', 'category': 'income'});
  });

  test(
    'sin red, la primera página se sirve desde caché con cachedAt',
    () async {
      adapter
        ..enqueueJson(200, {
          'items': [_txJson('t1')],
          'nextCursor': 'c2',
        })
        ..enqueueTransportError(DioExceptionType.connectionError);

      await repository.transactions('acc-1');
      final offline = await repository.transactions('acc-1');

      final page = offline.valueOrNull!;
      expect(page.items.single.title, 'Mercado Fresco');
      expect(page.cachedAt, isNotNull);
      expect(page.nextCursor, isNull, reason: 'sin red no se puede paginar');
    },
  );

  test('sin red y sin caché, la falla se propaga', () async {
    adapter.enqueueTransportError(DioExceptionType.connectionError);

    final result = await repository.transactions('acc-1');

    expect(result, isA<Failure<TransactionPage>>());
  });

  test('las páginas siguientes no usan caché como respaldo', () async {
    adapter.enqueueTransportError(DioExceptionType.receiveTimeout);

    final result = await repository.transactions('acc-1', cursor: 'c2');

    expect(result, isA<Failure<TransactionPage>>());
  });

  test('transfer envía la Idempotency-Key en el header', () async {
    adapter.enqueueJson(201, {
      'transferId': 'tr-1',
      'amountMinor': 5000000,
      'currency': 'USD',
      'from': {'accountId': 'a', 'balanceMinor': 1},
      'to': {'accountId': 'b', 'balanceMinor': 2},
      'createdAt': '2026-10-03T12:00:00.000Z',
    });

    final result = await repository.transfer(
      fromAccountId: 'a',
      toAccountId: 'b',
      amountMinor: 5000000,
      idempotencyKey: 'key-123',
    );

    expect(adapter.requests.single.headers['Idempotency-Key'], 'key-123');
    expect(result.valueOrNull?.transferId, 'tr-1');
  });
}
