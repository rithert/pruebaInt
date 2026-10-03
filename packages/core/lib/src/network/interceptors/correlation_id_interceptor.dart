import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Agrega `x-correlation-id` a cada petición para rastrearla de la app al
/// BFF (sus logs lo incluyen). Si ya existe —un reintento de la misma
/// petición— se conserva, así todos los intentos comparten el mismo id.
class CorrelationIdInterceptor extends Interceptor {
  CorrelationIdInterceptor([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  static const header = 'x-correlation-id';
  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(header, _uuid.v4);
    handler.next(options);
  }
}
