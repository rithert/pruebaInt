// TEMPORAL: los campos se usan al implementar onError. Quitar esta línea
// junto con la implementación.
// ignore_for_file: unused_field

import 'dart:math' as math;

import 'package:dio/dio.dart';

/// Parámetros de reintento.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
  });

  /// Intentos TOTALES, incluido el primero (3 = 1 intento + 2 reintentos).
  final int maxAttempts;

  /// Espera base del primer reintento (antes del jitter).
  final Duration baseDelay;

  /// Tope de espera para el backoff y para `Retry-After`.
  final Duration maxDelay;
}

/// Reintenta errores transitorios con backoff exponencial y jitter.
///
/// Especificación completa: test/network/retry_interceptor_test.dart
/// (`fvm flutter test test/network/retry_interceptor_test.dart` en packages/core).
///
/// Mientras no esté implementado, el interceptor deja pasar los errores sin
/// reintentar (la app funciona, pero sin esta capa de resiliencia).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this._dio,
    this.policy = const RetryPolicy(),
    math.Random? random,
    Future<void> Function(Duration delay)? sleep,
  }) : _random = random ?? math.Random(),
       _sleep = sleep ?? Future<void>.delayed;

  /// `extra` donde se guarda el número de reintento (0 = primer intento).
  static const attemptKey = 'retry_attempt';

  /// `extra` para desactivar los reintentos en una petición concreta.
  static const disableKey = 'disable_retry';

  final RetryPolicy policy;
  final Dio _dio;
  final math.Random _random;
  final Future<void> Function(Duration delay) _sleep;

  /// ¿Se debe reintentar este error? Todas deben cumplirse:
  /// 1. No está desactivado con `extra[disableKey] == true`.
  /// 2. Quedan intentos: `intento actual + 1 < policy.maxAttempts`.
  /// 3. Es idempotente: GET, HEAD, PUT, DELETE u OPTIONS, o cualquier método
  ///    con header `Idempotency-Key` (sin importar mayúsculas).
  /// 4. Es transitorio: timeouts (connection/send/receive), `connectionError`
  ///    o respuesta 502/503/504.
  bool shouldRetry(DioException error) {
    throw UnimplementedError('TODO: implementar shouldRetry');
  }

  /// Espera antes del reintento número [retryNumber] (1, 2, 3…).
  ///
  /// - Con [retryAfter] (header del servidor): se usa ese valor, con tope en
  ///   `policy.maxDelay`.
  /// - Sin él, "full jitter": `random() × min(maxDelay, baseDelay × 2^(n-1))`.
  ///
  /// Pista: `Duration` admite `*` por un número y `>` para comparar.
  Duration delayFor(int retryNumber, {Duration? retryAfter}) {
    throw UnimplementedError('TODO: implementar delayFor');
  }

  /// Si [shouldRetry]: espera [delayFor] (leyendo `Retry-After` en segundos
  /// de la respuesta), incrementa `extra[attemptKey]` y repite la petición
  /// con `_dio.fetch(requestOptions)`. Si el reintento responde, se entrega
  /// con `handler.resolve`; si vuelve a fallar, con `handler.next`.
  ///
  /// Pista: cada `_dio.fetch` vuelve a pasar por este interceptor, así que
  /// los reintentos sucesivos ocurren solos mientras queden intentos.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // TODO: implementar. Por ahora deja pasar el error sin reintentar.
    handler.next(err);
  }
}
