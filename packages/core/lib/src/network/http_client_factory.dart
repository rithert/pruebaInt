import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import '../observability/telemetry.dart';
import '../session/token_store.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/circuit_breaker_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/telemetry_interceptor.dart';

/// Arma el cliente HTTP con la cadena de resiliencia. El ORDEN importa:
///
/// 1. CorrelationId: el id se fija antes que nada y se conserva en reintentos.
/// 2. Telemetry: registra cada intento, incluidos los reintentos.
/// 3. Auth: adjunta el token; ante `token_expired` renueva y repite.
/// 4. CircuitBreaker: corta localmente si el servicio está caído y cuenta
///    las fallas ANTES de que Retry las resuelva.
/// 5. Retry: reintenta lo transitorio; cada reintento recorre de nuevo la
///    cadena completa, así que el circuito puede cortar un reintento.
Dio createHttpClient({
  required AppEnvironment environment,
  required TokenStore tokenStore,
  required RefreshSession refreshSession,
  required CircuitBreaker circuitBreaker,
  required Telemetry telemetry,
  void Function()? onSessionExpired,
  RetryPolicy retryPolicy = const RetryPolicy(),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: environment.apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.addAll([
    CorrelationIdInterceptor(),
    TelemetryInterceptor(telemetry),
    AuthInterceptor(
      dio: dio,
      tokenStore: tokenStore,
      refresh: refreshSession,
      onSessionExpired: onSessionExpired,
    ),
    CircuitBreakerInterceptor(circuitBreaker),
    RetryInterceptor(dio: dio, policy: retryPolicy),
  ]);
  return dio;
}
