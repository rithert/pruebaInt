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
    final extra = error.requestOptions.extra;

    // 1. Verificar si está desactivado
    if (extra[disableKey] == true) {
      return false;
    }

    // 2. Verificar intentos restantes
    if (_attemptOf(error.requestOptions) + 1 >= policy.maxAttempts) {
      return false;
    }

    // 3. Verificar idempotencia
    if (!_isIdempotent(error.requestOptions)) {
      return false;
    }

    // 4. Verificar si es error transitorio
    return _isTransient(error);
  }

  /// Número de reintento ya realizado (0 = primer intento).
  static int _attemptOf(RequestOptions options) =>
      (options.extra[attemptKey] as int?) ?? 0;

  bool _isIdempotent(RequestOptions options) {
    const idempotentMethods = {'GET', 'HEAD', 'PUT', 'DELETE', 'OPTIONS'};
    final method = options.method.toUpperCase();

    if (idempotentMethods.contains(method)) {
      return true;
    }

    // Comprobar si existe el header 'Idempotency-Key' ignorando mayúsculas/minúsculas
    return options.headers.keys.any(
      (key) => key.toLowerCase() == 'idempotency-key',
    );
  }

  bool _isTransient(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return statusCode == 502 || statusCode == 503 || statusCode == 504;
      default:
        return false;
    }
  }

  /// Espera antes del reintento número [retryNumber] (1, 2, 3…).
  ///
  /// - Con [retryAfter] (header del servidor): se usa ese valor, con tope en
  ///   `policy.maxDelay`.
  /// - Sin él, "full jitter": `random() × min(maxDelay, baseDelay × 2^(n-1))`.
  Duration delayFor(int retryNumber, {Duration? retryAfter}) {
    if (retryAfter != null) {
      return retryAfter > policy.maxDelay ? policy.maxDelay : retryAfter;
    }

    // Backoff exponencial: baseDelay * 2^(retryNumber - 1)
    final exponentialFactor = math.pow(2, retryNumber - 1).toDouble();
    final calculatedMs = policy.baseDelay.inMilliseconds * exponentialFactor;

    final cappedMs = math.min(
      policy.maxDelay.inMilliseconds.toDouble(),
      calculatedMs,
    );

    // Full jitter: random() * cappedDelay
    final jitteredMs = (_random.nextDouble() * cappedMs).round();
    return Duration(milliseconds: jitteredMs);
  }

  /// Si [shouldRetry]: espera [delayFor] (leyendo `Retry-After` en segundos
  /// de la respuesta), incrementa `extra[attemptKey]` y repite la petición
  /// con `_dio.fetch(requestOptions)`. Si el reintento responde, se entrega
  /// con `handler.resolve`; si vuelve a fallar, con `handler.next`.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final nextAttempt = _attemptOf(err.requestOptions) + 1;

    // Extraer header Retry-After si viene en la respuesta
    Duration? retryAfter;
    final retryAfterHeader = err.response?.headers.value('retry-after');
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader);
      if (seconds != null) {
        retryAfter = Duration(seconds: seconds);
      }
    }

    final delay = delayFor(nextAttempt, retryAfter: retryAfter);
    await _sleep(delay);

    // Actualizar el número de intento en los extras
    err.requestOptions.extra[attemptKey] = nextAttempt;

    // `fetch` envuelve cualquier falla en DioException, por eso basta con
    // capturar ese tipo: el error que se propaga es el del último intento.
    try {
      final response = await _dio.fetch<Object?>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
