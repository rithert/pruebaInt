import 'package:dio/dio.dart';

import '../result/app_failure.dart';

/// Traduce errores de transporte (Dio) a fallas de dominio. Es el único
/// lugar de la app que conoce el formato de error del BFF:
/// `{ error: { code, message, details, correlationId } }`.
AppFailure mapDioException(DioException exception) {
  // Un interceptor (p. ej. el circuit breaker) ya decidió la falla.
  final cause = exception.error;
  if (cause is AppFailure) return cause;

  final correlationId = _correlationId(exception);

  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return TimeoutFailure(correlationId: correlationId);
    case DioExceptionType.connectionError:
      return NoConnectionFailure(correlationId: correlationId);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnexpectedFailure(cause: exception, correlationId: correlationId);
    case DioExceptionType.badResponse:
      return _fromResponse(exception.response!, correlationId);
  }
}

AppFailure _fromResponse(Response<Object?> response, String? correlationId) {
  final status = response.statusCode ?? 0;
  final error = _errorBody(response.data);
  final code = error?['code'] as String? ?? 'unknown';
  final message = error?['message'] as String?;

  return switch (status) {
    400 => ValidationFailure(
      fieldErrors: _fieldErrors(error?['details']),
      serverMessage: message,
      correlationId: correlationId,
    ),
    401 => UnauthorizedFailure(code: code, correlationId: correlationId),
    404 => NotFoundFailure(correlationId: correlationId),
    403 || 409 || 422 || 429 => BusinessFailure(
      code: code,
      serverMessage: message ?? 'No fue posible completar la operación.',
      correlationId: correlationId,
    ),
    502 || 503 || 504 => ServiceUnavailableFailure(
      service: response.requestOptions.extra['service'] as String?,
      correlationId: correlationId,
    ),
    _ => ServerFailure(statusCode: status, correlationId: correlationId),
  };
}

Map<String, Object?>? _errorBody(Object? data) {
  if (data is Map<String, Object?> && data['error'] is Map<String, Object?>) {
    return data['error']! as Map<String, Object?>;
  }
  return null;
}

/// `details` del BFF: `[{ path: 'email', message: '...' }]`.
Map<String, String> _fieldErrors(Object? details) {
  if (details is! List<Object?>) return const {};
  return {
    for (final item in details.whereType<Map<String, Object?>>())
      if (item['path'] is String && item['message'] is String)
        item['path']! as String: item['message']! as String,
  };
}

String? _correlationId(DioException exception) =>
    exception.response?.headers.value('x-correlation-id') ??
    exception.requestOptions.headers['x-correlation-id'] as String?;
