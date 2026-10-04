import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/testing.dart';

void main() {
  late FakeAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(CorrelationIdInterceptor());
    client = ApiClient(dio);
  });

  Future<AppFailure> failureOf(Future<Result<Object?>> call) async =>
      switch (await call) {
        Failure(:final failure) => failure,
        Success() => throw StateError('se esperaba Failure'),
      };

  Future<Result<Object?>> getAccounts() =>
      client.get('/v1/accounts', decode: (json) => json);

  test('decodifica una respuesta exitosa', () async {
    adapter.enqueueJson(200, {'name': 'Ahorros'});

    final result = await client.get(
      '/v1/accounts',
      decode: (json) => (json! as Map<String, Object?>)['name'],
    );

    expect(result, const Success<Object?>('Ahorros'));
  });

  test(
    'un contrato roto se convierte en UnexpectedFailure, no en crash',
    () async {
      adapter.enqueueJson(200, {'inesperado': true});

      final result = await client.get(
        '/v1/accounts',
        decode: (json) => (json! as Map<String, Object?>)['name']! as String,
      );

      expect(result, isA<Failure<String>>());
    },
  );

  group('mapeo de errores del BFF', () {
    test('400 → ValidationFailure con errores por campo', () async {
      adapter.enqueueJson(400, {
        'error': {
          'code': 'validation_error',
          'message': 'Datos inválidos',
          'details': [
            {'path': 'email', 'message': 'Correo inválido'},
          ],
        },
      });

      final failure = await failureOf(getAccounts());

      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors, {
        'email': 'Correo inválido',
      });
    });

    test('401 → UnauthorizedFailure con el código del BFF', () async {
      adapter.enqueueError(401, 'invalid_token');

      final failure = await failureOf(getAccounts());

      expect((failure as UnauthorizedFailure).code, 'invalid_token');
    });

    test('422 → BusinessFailure con código y mensaje del servidor', () async {
      adapter.enqueueJson(422, {
        'error': {
          'code': 'insufficient_funds',
          'message': 'Saldo insuficiente.',
        },
      });

      final failure = await failureOf(getAccounts()) as BusinessFailure;

      expect(failure.code, 'insufficient_funds');
      expect(failure.message, 'Saldo insuficiente.');
    });

    test('503 → ServiceUnavailableFailure (transitoria)', () async {
      adapter.enqueueError(503, 'service_unavailable');

      final failure = await failureOf(getAccounts());

      expect(failure, isA<ServiceUnavailableFailure>());
      expect(failure.isTransient, isTrue);
    });

    test('500 → ServerFailure', () async {
      adapter.enqueueError(500, 'internal_error');

      expect(await failureOf(getAccounts()), isA<ServerFailure>());
    });

    test('timeout → TimeoutFailure; sin red → NoConnectionFailure', () async {
      adapter
        ..enqueueTransportError(DioExceptionType.receiveTimeout)
        ..enqueueTransportError(DioExceptionType.connectionError);

      expect(await failureOf(getAccounts()), isA<TimeoutFailure>());
      expect(await failureOf(getAccounts()), isA<NoConnectionFailure>());
    });

    test('conserva el correlation-id para soporte', () async {
      adapter.enqueueError(500, 'internal_error', {
        'x-correlation-id': ['corr-123'],
      });

      expect((await failureOf(getAccounts())).correlationId, 'corr-123');
    });
  });

  test(
    'CorrelationIdInterceptor agrega un id y conserva uno existente',
    () async {
      adapter
        ..enqueueJson(200)
        ..enqueueJson(200);

      await getAccounts();
      await client.get('/v1/accounts', decode: (json) => json, query: const {});

      final ids = adapter.requests.map(
        (r) => r.headers[CorrelationIdInterceptor.header],
      );
      expect(ids.every((id) => id is String && id.length == 36), isTrue);
      expect(ids.toSet(), hasLength(2));
    },
  );
}
