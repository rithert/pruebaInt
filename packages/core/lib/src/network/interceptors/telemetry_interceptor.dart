import 'package:dio/dio.dart';

import '../../observability/telemetry.dart';

/// Deja un breadcrumb por petición (método, ruta, estado, duración, intento
/// y correlation-id). Si luego hay un error, el reporte trae el contexto de
/// red que lo precedió. No registra headers ni bodies: pueden contener
/// tokens o datos personales.
class TelemetryInterceptor extends Interceptor {
  TelemetryInterceptor(this._telemetry);

  final Telemetry _telemetry;
  static const _startKey = 'telemetry_started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _record(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, err.response?.statusCode, error: err.type.name);
    handler.next(err);
  }

  void _record(RequestOptions options, int? status, {String? error}) {
    final started = options.extra[_startKey] as int?;
    _telemetry.breadcrumb(
      'http',
      data: {
        'method': options.method,
        'path': options.uri.path,
        'status': status,
        'error': ?error,
        'durationMs': started == null
            ? null
            : DateTime.now().millisecondsSinceEpoch - started,
        'attempt': options.extra['retry_attempt'] ?? 0,
        'correlationId': options.headers['x-correlation-id'],
      },
    );
  }
}
