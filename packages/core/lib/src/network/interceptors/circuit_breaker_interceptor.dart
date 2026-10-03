import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../result/app_failure.dart';

enum CircuitState { closed, open, halfOpen }

/// Circuit breaker por servicio.
///
/// - `closed`: las peticiones pasan; se cuentan fallas consecutivas.
/// - `open`: tras [failureThreshold] fallas, se rechaza localmente durante
///   [openDuration] sin tocar la red. La UI responde al instante y el
///   servicio degradado no recibe más carga.
/// - `halfOpen`: vencido el plazo, se deja pasar UNA petición de prueba. Si
///   funciona, se cierra; si falla, vuelve a abrirse.
class CircuitBreaker extends ChangeNotifier {
  CircuitBreaker({
    this.failureThreshold = 5,
    this.openDuration = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int failureThreshold;
  final Duration openDuration;
  final DateTime Function() _now;

  final Map<String, _Circuit> _circuits = {};

  CircuitState stateOf(String service) =>
      _circuits[service]?.state ?? CircuitState.closed;

  /// Estado de todos los servicios observados (para el panel de diagnóstico).
  Map<String, CircuitState> get snapshot => {
    for (final entry in _circuits.entries) entry.key: entry.value.state,
  };

  bool allowRequest(String service) {
    final circuit = _circuits.putIfAbsent(service, _Circuit.new);
    switch (circuit.state) {
      case CircuitState.closed:
        return true;
      case CircuitState.halfOpen:
        return false; // Ya hay una petición de prueba en curso.
      case CircuitState.open:
        if (_now().isBefore(circuit.openedAt!.add(openDuration))) return false;
        _transition(service, circuit, CircuitState.halfOpen);
        return true;
    }
  }

  void recordSuccess(String service) {
    final circuit = _circuits.putIfAbsent(service, _Circuit.new);
    circuit.consecutiveFailures = 0;
    if (circuit.state != CircuitState.closed) {
      _transition(service, circuit, CircuitState.closed);
    }
  }

  void recordFailure(String service) {
    final circuit = _circuits.putIfAbsent(service, _Circuit.new);
    circuit.consecutiveFailures++;
    final shouldOpen =
        circuit.state == CircuitState.halfOpen ||
        circuit.consecutiveFailures >= failureThreshold;
    if (shouldOpen) {
      circuit.openedAt = _now();
      _transition(service, circuit, CircuitState.open);
    }
  }

  void _transition(String service, _Circuit circuit, CircuitState next) {
    circuit.state = next;
    notifyListeners();
  }
}

class _Circuit {
  CircuitState state = CircuitState.closed;
  int consecutiveFailures = 0;
  DateTime? openedAt;
}

class CircuitBreakerInterceptor extends Interceptor {
  CircuitBreakerInterceptor(this._breaker);

  final CircuitBreaker _breaker;

  /// Servicio de una petición: `extra['service']` o el primer segmento de la
  /// ruta tras la versión (`/v1/accounts/123` → `accounts`).
  static String serviceOf(RequestOptions options) {
    final explicit = options.extra['service'];
    if (explicit is String) return explicit;
    final segments = options.uri.pathSegments.where((s) => s.isNotEmpty);
    return segments.firstWhere(
      (s) => !RegExp(r'^v\d+$').hasMatch(s),
      orElse: () => 'root',
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final service = serviceOf(options);
    options.extra['service'] = service;
    if (_breaker.allowRequest(service)) return handler.next(options);

    handler.reject(
      DioException(
        requestOptions: options,
        error: ServiceUnavailableFailure(service: service, circuitOpen: true),
        message: 'Circuito abierto para $service',
      ),
    );
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _breaker.recordSuccess(serviceOf(response.requestOptions));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Un rechazo del propio circuito no cuenta como falla nueva.
    if (err.error is! ServiceUnavailableFailure) {
      final service = serviceOf(err.requestOptions);
      if (_isServiceFailure(err)) {
        _breaker.recordFailure(service);
      } else if (err.response != null) {
        // Un 4xx significa que el servicio respondió: está sano.
        _breaker.recordSuccess(service);
      }
    }
    handler.next(err);
  }

  /// Solo cuentan las fallas atribuibles al servicio. Sin conexión es un
  /// problema del dispositivo: no debe abrir el circuito.
  static bool _isServiceFailure(DioException err) => switch (err.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.badResponse => (err.response?.statusCode ?? 0) >= 500,
    _ => false,
  };
}
