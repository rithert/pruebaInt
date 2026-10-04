import 'dart:async';

import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications/notifications.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockSettings extends Mock implements NotificationSettings {}

void main() {
  group('routeFromData', () {
    test('acepta solo rutas internas', () {
      expect(routeFromData({'route': '/transactions/t1'}), '/transactions/t1');
      expect(routeFromData({'route': 'https://phishing.example'}), isNull);
      expect(routeFromData({'route': '//evil.example/x'}), isNull);
      expect(routeFromData({'route': 42}), isNull);
      expect(routeFromData({}), isNull);
    });
  });

  test('DisabledPushService no hace nada y no falla', () async {
    const service = DisabledPushService();

    await service.start();
    await service.stop();

    expect(service.enabled, isFalse);
  });

  group('FcmPushService', () {
    late _MockMessaging messaging;
    late FakeAdapter adapter;
    late FcmPushService service;
    late StreamController<String> tokenRefresh;

    setUp(() {
      messaging = _MockMessaging();
      adapter = FakeAdapter();
      tokenRefresh = StreamController<String>.broadcast();
      final settings = _MockSettings();
      when(() => settings.authorizationStatus)
          .thenReturn(AuthorizationStatus.authorized);
      when(() => messaging.requestPermission())
          .thenAnswer((_) async => settings);
      when(() => messaging.onTokenRefresh)
          .thenAnswer((_) => tokenRefresh.stream);
      when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);

      service = FcmPushService(
        messaging: messaging,
        api: ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
        telemetry: const DebugTelemetry(),
      );
    });
    tearDown(() => tokenRefresh.close());

    test('registra el token del dispositivo en el BFF', () async {
      when(() => messaging.getToken()).thenAnswer((_) async => 'token-1');
      adapter.enqueueJson(204, null);

      await service.start();

      expect(adapter.requests.single.path, '/v1/devices');
      expect(adapter.requests.single.data, {
        'token': 'token-1',
        'platform': 'android',
      });
    });

    test('al rotar el token lo vuelve a registrar', () async {
      when(() => messaging.getToken()).thenAnswer((_) async => 'token-1');
      adapter
        ..enqueueJson(204, null)
        ..enqueueJson(204, null);
      await service.start();

      tokenRefresh.add('token-2');
      await pumpEventQueue();

      expect(adapter.requests.last.data, containsPair('token', 'token-2'));
    });

    test(
      'al cerrar sesión da de baja el token (codificado en la URL)',
      () async {
        when(() => messaging.getToken()).thenAnswer((_) async => 'abc:def');
        adapter
          ..enqueueJson(204, null)
          ..enqueueJson(204, null);
        await service.start();

        await service.stop();

        expect(adapter.requests.last.method, 'DELETE');
        expect(adapter.requests.last.path, '/v1/devices/abc%3Adef');
      },
    );

    test('si el usuario niega el permiso no registra nada', () async {
      final denied = _MockSettings();
      when(() => denied.authorizationStatus)
          .thenReturn(AuthorizationStatus.denied);
      when(() => messaging.requestPermission()).thenAnswer((_) async => denied);

      await service.start();

      expect(adapter.requests, isEmpty);
      verifyNever(() => messaging.getToken());
    });
  });
}
