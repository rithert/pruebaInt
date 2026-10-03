import 'dart:developer' as developer;

/// Puerto de observabilidad. Los módulos registran eventos y errores sin
/// conocer el proveedor (consola en desarrollo, Firebase en producción).
///
/// Regla: nunca enviar datos personales (correo, nombre, montos con
/// identificador del cliente) en `params` ni en mensajes.
abstract interface class Telemetry {
  /// Evento de producto o de UX (p. ej. `transfer_completed`).
  void logEvent(String name, [Map<String, Object?> params = const {}]);

  /// Rastro técnico que acompaña a un error posterior (red, navegación).
  void breadcrumb(String message, {Map<String, Object?> data = const {}});

  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  });

  /// Identificador anónimo del cliente (id interno, nunca el correo).
  void setUserId(String? userId);
}

/// Implementación para desarrollo: escribe en el log de Dart DevTools.
class DebugTelemetry implements Telemetry {
  const DebugTelemetry();

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    developer.log('$name $params', name: 'telemetry.event');
  }

  @override
  void breadcrumb(String message, {Map<String, Object?> data = const {}}) {
    developer.log('$message $data', name: 'telemetry.breadcrumb');
  }

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    developer.log(
      reason ?? 'error',
      name: 'telemetry.error',
      error: error,
      stackTrace: stackTrace,
      level: fatal ? 1200 : 1000,
    );
  }

  @override
  void setUserId(String? userId) {
    developer.log('user=$userId', name: 'telemetry.user');
  }
}
