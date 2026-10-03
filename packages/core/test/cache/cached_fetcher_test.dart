import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryCacheStore cache;
  late CachedFetcher fetcher;
  final now = DateTime(2026, 10, 3, 12);
  final yesterday = now.subtract(const Duration(days: 1));

  setUp(() {
    cache = InMemoryCacheStore();
    fetcher = CachedFetcher(cache, now: () => now);
  });

  Stream<Resource<String>> watch(Result<Object?> serverResult) => fetcher.watch(
    key: 'accounts',
    fetch: () async => serverResult,
    decode: (json) => (json! as Map<String, Object?>)['name']! as String,
  );

  test('sin caché: carga y luego datos frescos que se guardan', () async {
    final states = await watch(const Success({'name': 'fresco'})).toList();

    expect(states.first.hasData, isFalse);
    expect(states.first.isRefreshing, isTrue);
    expect(states.last.data, 'fresco');
    expect(states.last.updatedAt, now);
    expect((await cache.read('accounts'))?.json, {'name': 'fresco'});
  });

  test(
    'con caché: muestra la caché al instante y luego la actualiza',
    () async {
      await cache.write('accounts', {'name': 'viejo'}, updatedAt: yesterday);

      final states = await watch(const Success({'name': 'fresco'})).toList();

      expect(states.first.data, 'viejo');
      expect(states.first.isRefreshing, isTrue);
      expect(states.last.data, 'fresco');
    },
  );

  test('sin red y con caché: conserva los datos y expone la falla', () async {
    await cache.write('accounts', {'name': 'viejo'}, updatedAt: yesterday);

    final last = await watch(const Failure(NoConnectionFailure())).last;

    expect(last.data, 'viejo');
    expect(last.updatedAt, yesterday);
    expect(last.isStale, isTrue);
    expect(last.failure, isA<NoConnectionFailure>());
  });

  test('sin red y sin caché: solo la falla', () async {
    final last = await watch(const Failure(TimeoutFailure())).last;

    expect(last.hasData, isFalse);
    expect(last.failure, isA<TimeoutFailure>());
  });

  test('una caché ilegible se ignora en vez de romper la pantalla', () async {
    await cache.write('accounts', {'formato': 'viejo'});

    final states = await watch(const Success({'name': 'fresco'})).toList();

    expect(states.first.hasData, isFalse);
    expect(states.last.data, 'fresco');
  });
}
