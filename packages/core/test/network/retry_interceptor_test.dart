import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/testing.dart';

/// Especificación del RetryInterceptor.
///
/// Reintenta solo errores TRANSITORIOS en peticiones IDEMPOTENTES, con
/// espera exponencial + jitter ("full jitter") para no sincronizar a miles
/// de clientes reintentando a la vez contra un servicio que se recupera.
void main() {
  late FakeAdapter adapter;
  late List<Duration> sleeps;

  Dio buildDio({
    RetryPolicy policy = const RetryPolicy(),
    double jitter = 0.5,
  }) {
    adapter = FakeAdapter();
    sleeps = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        policy: policy,
        random: FixedRandom(jitter),
        sleep: (delay) async => sleeps.add(delay),
      ),
    );
    return dio;
  }

  group('qué se reintenta', () {
    for (final status in [502, 503, 504]) {
      test(
        'reintenta un GET que responde $status y devuelve el éxito',
        () async {
          final dio = buildDio();
          adapter
            ..enqueueError(status, 'upstream_error')
            ..enqueueJson(200, {'ok': true});

          final response = await dio.get<Object?>('/v1/accounts');

          expect(response.statusCode, 200);
          expect(adapter.requests, hasLength(2));
        },
      );
    }

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('reintenta errores de transporte: ${type.name}', () async {
        final dio = buildDio();
        adapter
          ..enqueueTransportError(type)
          ..enqueueJson(200);

        await dio.get<Object?>('/v1/accounts');

        expect(adapter.requests, hasLength(2));
      });
    }

    for (final status in [400, 401, 404, 409, 422, 500]) {
      test('NO reintenta un $status (no es transitorio)', () async {
        final dio = buildDio();
        adapter.enqueueError(status, 'x');

        await expectLater(
          dio.get<Object?>('/v1/accounts'),
          throwsA(isA<DioException>()),
        );
        expect(adapter.requests, hasLength(1));
      });
    }
  });

  group('idempotencia', () {
    test(
      'NO reintenta un POST sin Idempotency-Key (podría duplicar la operación)',
      () async {
        final dio = buildDio();
        adapter.enqueueError(503, 'service_unavailable');

        await expectLater(
          dio.post<Object?>('/v1/transfers'),
          throwsA(isA<DioException>()),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test('SÍ reintenta un POST con Idempotency-Key', () async {
      final dio = buildDio();
      adapter
        ..enqueueError(503, 'service_unavailable')
        ..enqueueJson(201);

      final response = await dio.post<Object?>(
        '/v1/transfers',
        options: Options(headers: {'Idempotency-Key': 'abc-12345'}),
      );

      expect(response.statusCode, 201);
      expect(adapter.requests, hasLength(2));
    });

    test('reintenta PUT y DELETE (idempotentes por definición)', () async {
      final dio = buildDio();
      adapter
        ..enqueueError(503, 'x')
        ..enqueueJson(200)
        ..enqueueError(503, 'x')
        ..enqueueJson(200);

      await dio.put<Object?>('/v1/x');
      await dio.delete<Object?>('/v1/x');

      expect(adapter.requests, hasLength(4));
    });
  });

  group('límites', () {
    test(
      'se rinde tras maxAttempts intentos en total y propaga el último error',
      () async {
        final dio = buildDio(policy: const RetryPolicy(maxAttempts: 3));
        adapter
          ..enqueueError(503, 'x')
          ..enqueueError(503, 'x')
          ..enqueueError(503, 'x');

        final error = await dio
            .get<Object?>('/v1/accounts')
            .then<DioException?>(
              (_) => null,
              onError: (Object e) => e as DioException,
            );

        expect(error?.response?.statusCode, 503);
        expect(adapter.requests, hasLength(3));
      },
    );

    test('se puede desactivar por petición con extra[disable_retry]', () async {
      final dio = buildDio();
      adapter.enqueueError(503, 'x');

      await expectLater(
        dio.get<Object?>(
          '/v1/accounts',
          options: Options(extra: {RetryInterceptor.disableKey: true}),
        ),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('registra el número de intento en extra[retry_attempt]', () async {
      final dio = buildDio();
      adapter
        ..enqueueError(503, 'x')
        ..enqueueError(503, 'x')
        ..enqueueJson(200);

      await dio.get<Object?>('/v1/accounts');

      expect(adapter.requests.last.extra[RetryInterceptor.attemptKey], 2);
    });
  });

  group('espera entre intentos', () {
    test('backoff exponencial con jitter: random × base × 2^(n-1)', () async {
      final dio = buildDio(
        policy: const RetryPolicy(
          maxAttempts: 4,
          baseDelay: Duration(milliseconds: 300),
        ),
        jitter: 0.5,
      );
      adapter
        ..enqueueError(503, 'x')
        ..enqueueError(503, 'x')
        ..enqueueError(503, 'x')
        ..enqueueJson(200);

      await dio.get<Object?>('/v1/accounts');

      expect(sleeps, const [
        Duration(milliseconds: 150), // 0.5 × 300
        Duration(milliseconds: 300), // 0.5 × 600
        Duration(milliseconds: 600), // 0.5 × 1200
      ]);
    });

    test('delayFor nunca supera maxDelay antes del jitter', () {
      final interceptor = RetryInterceptor(
        dio: Dio(),
        policy: const RetryPolicy(
          baseDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 5),
        ),
        random: FixedRandom(0.5),
      );

      expect(
        interceptor.delayFor(10),
        const Duration(milliseconds: 2500),
      ); // 0.5 × 5 s
    });

    test('respeta Retry-After (segundos) en lugar del backoff', () async {
      final dio = buildDio();
      adapter
        ..enqueueError(503, 'service_unavailable', {
          'retry-after': ['2'],
        })
        ..enqueueJson(200);

      await dio.get<Object?>('/v1/accounts');

      expect(sleeps, const [Duration(seconds: 2)]);
    });

    test('limita un Retry-After exagerado a maxDelay', () async {
      final dio = buildDio(
        policy: const RetryPolicy(maxDelay: Duration(seconds: 5)),
      );
      adapter
        ..enqueueError(503, 'service_unavailable', {
          'retry-after': ['120'],
        })
        ..enqueueJson(200);

      await dio.get<Object?>('/v1/accounts');

      expect(sleeps, const [Duration(seconds: 5)]);
    });
  });
}
