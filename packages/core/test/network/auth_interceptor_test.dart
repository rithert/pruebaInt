import 'dart:async';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  late InMemoryTokenStore store;
  late Dio dio;
  late int refreshCalls;
  late int sessionExpiredCalls;
  late Completer<SessionTokens?> refreshResult;

  const oldTokens = SessionTokens(accessToken: 'old', refreshToken: 'r-old');
  const newTokens = SessionTokens(accessToken: 'new', refreshToken: 'r-new');

  setUp(() {
    adapter = FakeAdapter();
    store = InMemoryTokenStore(oldTokens);
    refreshCalls = 0;
    sessionExpiredCalls = 0;
    refreshResult = Completer();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        tokenStore: store,
        refresh: (refreshToken) {
          refreshCalls++;
          expect(refreshToken, 'r-old');
          return refreshResult.future;
        },
        onSessionExpired: () => sessionExpiredCalls++,
      ),
    );
  });

  String? authOf(RequestOptions r) => r.headers['Authorization'] as String?;

  test('adjunta el access token guardado', () async {
    adapter.enqueueJson(200);

    await dio.get<Object?>('/v1/me');

    expect(authOf(adapter.requests.single), 'Bearer old');
  });

  test('no adjunta token en peticiones marcadas como públicas', () async {
    adapter.enqueueJson(200);

    await dio.post<Object?>(
      '/v1/auth/login',
      options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
    );

    expect(authOf(adapter.requests.single), isNull);
  });

  test('ante token_expired renueva la sesión y repite la petición', () async {
    adapter
      ..enqueueError(401, 'token_expired')
      ..enqueueJson(200, {'ok': true});
    refreshResult.complete(newTokens);

    final response = await dio.get<Object?>('/v1/me');

    expect(response.statusCode, 200);
    expect(authOf(adapter.requests.last), 'Bearer new');
    expect((await store.read())?.refreshToken, 'r-new');
  });

  test(
    'SINGLE-FLIGHT: 3 peticiones expiradas a la vez → 1 solo refresh',
    () async {
      for (var i = 0; i < 3; i++) {
        adapter.enqueueError(401, 'token_expired');
      }
      for (var i = 0; i < 3; i++) {
        adapter.enqueueJson(200);
      }

      final calls = Future.wait([
        dio.get<Object?>('/v1/me'),
        dio.get<Object?>('/v1/accounts'),
        dio.get<Object?>('/v1/transactions/1'),
      ]);
      // El refresh tarda: las tres peticiones fallan antes de que termine.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      refreshResult.complete(newTokens);
      final responses = await calls;

      expect(refreshCalls, 1);
      expect(responses.every((r) => r.statusCode == 200), isTrue);
      expect(adapter.requests.skip(3).map(authOf), everyElement('Bearer new'));
    },
  );

  test(
    'si el refresh es rechazado, cierra la sesión y propaga el 401',
    () async {
      adapter.enqueueError(401, 'token_expired');
      refreshResult.complete(null);

      await expectLater(
        dio.get<Object?>('/v1/me'),
        throwsA(isA<DioException>()),
      );

      expect(await store.read(), isNull);
      expect(sessionExpiredCalls, 1);
    },
  );

  test(
    'un token inválido (no expirado) cierra la sesión sin intentar refresh',
    () async {
      adapter.enqueueError(401, 'invalid_token');

      await expectLater(
        dio.get<Object?>('/v1/me'),
        throwsA(isA<DioException>()),
      );

      expect(refreshCalls, 0);
      expect(sessionExpiredCalls, 1);
    },
  );

  test(
    'si el refresh falla por red, NO cierra la sesión (se reintenta luego)',
    () async {
      adapter.enqueueError(401, 'token_expired');
      refreshResult.completeError(
        DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'sin red',
        ),
      );

      await expectLater(
        dio.get<Object?>('/v1/me'),
        throwsA(isA<DioException>()),
      );

      expect(await store.read(), isNotNull);
      expect(sessionExpiredCalls, 0);
    },
  );

  test('no entra en bucle si la petición repetida vuelve a dar 401', () async {
    adapter
      ..enqueueError(401, 'token_expired')
      ..enqueueError(401, 'token_expired');
    refreshResult.complete(newTokens);

    await expectLater(dio.get<Object?>('/v1/me'), throwsA(isA<DioException>()));

    expect(refreshCalls, 1);
    expect(adapter.requests, hasLength(2));
  });
}
