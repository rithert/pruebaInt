import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeReply = ResponseBody Function(RequestOptions options);

/// Adaptador HTTP falso: responde en orden con las respuestas encoladas y
/// registra cada petición recibida.
class FakeAdapter implements HttpClientAdapter {
  final List<FakeReply> _replies = [];
  final List<RequestOptions> requests = [];

  void enqueueJson(
    int status, [
    Object? body = const <String, Object?>{},
    Map<String, List<String>> headers = const {},
  ]) {
    _replies.add(
      (_) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      ),
    );
  }

  void enqueueError(
    int status,
    String code, [
    Map<String, List<String>> headers = const {},
  ]) {
    enqueueJson(status, {
      'error': {'code': code, 'message': code},
    }, headers);
  }

  /// Simula un fallo de transporte (timeout, sin conexión).
  void enqueueTransportError(DioExceptionType type) {
    _replies.add(
      (options) => throw DioException(requestOptions: options, type: type),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_replies.isEmpty) {
      throw StateError(
        'FakeAdapter: no hay respuesta para ${options.method} ${options.path}',
      );
    }
    return _replies.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}

/// `Random` con valor fijo para que el jitter sea determinista.
class FixedRandom implements math.Random {
  FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  int nextInt(int max) => (value * max).floor();
}
