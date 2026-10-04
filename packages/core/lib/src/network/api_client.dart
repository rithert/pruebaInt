import 'package:dio/dio.dart';

import '../connectivity/connectivity_monitor.dart';
import '../result/app_failure.dart';
import '../result/result.dart';
import 'failure_mapper.dart';

/// Convierte el JSON de la respuesta en un modelo de dominio.
typedef JsonDecoder<T> = T Function(Object? json);

/// Fachada HTTP para los repositorios: siempre devuelve `Result`, nunca
/// lanza. La resiliencia (reintentos, circuit breaker, refresh de sesión)
/// vive en los interceptores del `Dio` que recibe.
class ApiClient {
  /// [connectivity] permite distinguir "el teléfono no tiene red" de "hay
  /// red, pero el servidor no responde" (caída del BFF, VPN, portal cautivo).
  ApiClient(this._dio, {this._connectivity});

  final Dio _dio;
  final ConnectivityMonitor? _connectivity;

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

  Future<Result<T>> delete<T>(
    String path, {
    required JsonDecoder<T> decode,
    Map<String, Object?>? extra,
  }) => _send(
    () => _dio.delete<Object?>(path, options: Options(extra: extra)),
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
      return Failure(await _refine(mapDioException(exception)));
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

  /// Sin conexión con el servidor pero CON red en el dispositivo: el
  /// problema es del servicio. Decirle al usuario "revisa tu internet" lo
  /// mandaría a buscar una falla que no existe.
  Future<AppFailure> _refine(AppFailure failure) async {
    if (failure is NoConnectionFailure &&
        await (_connectivity?.isOnline ?? Future.value(false))) {
      return ServiceUnavailableFailure(correlationId: failure.correlationId);
    }
    return failure;
  }
}
