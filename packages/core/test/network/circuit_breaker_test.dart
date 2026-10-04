import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/testing.dart';

void main() {
  late DateTime now;
  late CircuitBreaker breaker;

  setUp(() {
    now = DateTime(2026, 10, 3, 12);
    breaker = CircuitBreaker(
      failureThreshold: 3,
      openDuration: const Duration(seconds: 30),
      now: () => now,
    );
  });

  group('CircuitBreaker', () {
    test('se abre tras N fallas consecutivas y rechaza localmente', () {
      for (var i = 0; i < 3; i++) {
        expect(breaker.allowRequest('accounts'), isTrue);
        breaker.recordFailure('accounts');
      }

      expect(breaker.stateOf('accounts'), CircuitState.open);
      expect(breaker.allowRequest('accounts'), isFalse);
    });

    test('un éxito reinicia el conteo de fallas', () {
      breaker
        ..recordFailure('accounts')
        ..recordFailure('accounts')
        ..recordSuccess('accounts')
        ..recordFailure('accounts');

      expect(breaker.stateOf('accounts'), CircuitState.closed);
    });

    test('aísla servicios: si cae accounts, experience sigue cerrado', () {
      for (var i = 0; i < 3; i++) {
        breaker.recordFailure('accounts');
      }

      expect(breaker.allowRequest('experience'), isTrue);
    });

    test('vencido el plazo, deja pasar UNA petición de prueba (half-open)', () {
      for (var i = 0; i < 3; i++) {
        breaker.recordFailure('accounts');
      }
      now = now.add(const Duration(seconds: 31));

      expect(breaker.allowRequest('accounts'), isTrue);
      expect(breaker.stateOf('accounts'), CircuitState.halfOpen);
      expect(breaker.allowRequest('accounts'), isFalse);
    });

    test('half-open: éxito cierra el circuito; falla lo reabre', () {
      for (var i = 0; i < 3; i++) {
        breaker.recordFailure('a');
        breaker.recordFailure('b');
      }
      now = now.add(const Duration(seconds: 31));
      breaker
        ..allowRequest('a')
        ..allowRequest('b')
        ..recordSuccess('a')
        ..recordFailure('b');

      expect(breaker.stateOf('a'), CircuitState.closed);
      expect(breaker.stateOf('b'), CircuitState.open);
    });

    test('notifica cambios de estado (para el panel de diagnóstico)', () {
      var notifications = 0;
      breaker.addListener(() => notifications++);

      for (var i = 0; i < 3; i++) {
        breaker.recordFailure('accounts');
      }

      expect(notifications, 1);
      expect(breaker.snapshot, {'accounts': CircuitState.open});
    });
  });

  group('CircuitBreakerInterceptor', () {
    late FakeAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = FakeAdapter();
      dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(CircuitBreakerInterceptor(breaker));
    });

    test('deduce el servicio de la ruta', () {
      RequestOptions at(String path) =>
          RequestOptions(baseUrl: 'https://api.test', path: path);

      expect(
        CircuitBreakerInterceptor.serviceOf(at('/v1/accounts/1')),
        'accounts',
      );
      expect(CircuitBreakerInterceptor.serviceOf(at('/health')), 'health');
    });

    test('con el circuito abierto falla sin tocar la red', () async {
      for (var i = 0; i < 3; i++) {
        adapter.enqueueError(503, 'service_unavailable');
        await dio
            .get<Object?>('/v1/accounts')
            .catchError(
              (_) => Response<Object?>(requestOptions: RequestOptions()),
            );
      }

      final error = await dio
          .get<Object?>('/v1/accounts')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(adapter.requests, hasLength(3));
      expect(
        mapDioException(error! as DioException),
        isA<ServiceUnavailableFailure>().having(
          (f) => f.circuitOpen,
          'circuitOpen',
          isTrue,
        ),
      );
    });

    test('los 4xx y la falta de red no abren el circuito', () async {
      for (var i = 0; i < 3; i++) {
        adapter.enqueueError(404, 'not_found');
        adapter.enqueueTransportError(DioExceptionType.connectionError);
      }
      for (var i = 0; i < 6; i++) {
        await dio
            .get<Object?>('/v1/accounts')
            .catchError(
              (_) => Response<Object?>(requestOptions: RequestOptions()),
            );
      }

      expect(breaker.stateOf('accounts'), CircuitState.closed);
    });
  });
}
