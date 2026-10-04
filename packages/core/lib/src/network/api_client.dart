import 'package:dio/dio.dart';

import '../result/app_failure.dart';
import '../result/result.dart';
import 'failure_mapper.dart';

/// Convierte el JSON de la respuesta en un modelo de dominio.
typedef JsonDecoder<T> = T Function(Object? json);

/// Fachada HTTP para los repositorios: siempre devuelve `Result`, nunca
/// lanza. La resiliencia (reintentos, circuit breaker, refresh de sesión)
/// vive en los interceptores del `Dio` que recibe.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// [extra] viaja a los interceptores (p. ej. `AuthInterceptor.skipAuthKey`,
  /// `RetryInterceptor.disableKey`).
  Future<Result<T>> get<T>(
    String path, {
    required JsonDecoder<T> decode,
    Map<String, Object?>? query,
    Map<String, Object?>? extra,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: query,
      options: Options(extra: extra),
    ),
    decode,
  );

  Future<Result<T>> post<T>(
    String path, {
    required JsonDecoder<T> decode,
    Object? body,
    Map<String, String>? headers,
    Map<String, Object?>? extra,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: Options(headers: headers, extra: extra),
    ),
    decode,
  );

  Future<Result<T>> _send<T>(
    Future<Response<Object?>> Function() request,
    JsonDecoder<T> decode,
  ) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (exception) {
      return Failure(mapDioException(exception));
    }

    try {
      return Success(decode(response.data));
    } on Object catch (error) {
      // El BFF respondió algo que la app no sabe interpretar (contrato roto).
      return Failure(
        UnexpectedFailure(
          cause: error,
          correlationId: response.headers.value('x-correlation-id'),
        ),
      );
    }
  }
}
