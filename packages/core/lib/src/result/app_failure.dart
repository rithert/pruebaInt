/// Fallas que pueden ocurrir entre capas. Es `sealed`: un `switch` sobre
/// `AppFailure` obliga, en tiempo de compilación, a manejar cada caso.
///
/// `correlationId` permite al cliente reportar un código de soporte que se
/// cruza con los logs del BFF.
sealed class AppFailure implements Exception {
  const AppFailure({this.correlationId});

  final String? correlationId;

  /// Mensaje por defecto para mostrar al usuario.
  String get message;

  /// Si tiene sentido ofrecer "Reintentar" en la UI.
  bool get isTransient => false;

  @override
  String toString() => '$runtimeType($message, correlationId: $correlationId)';
}

/// El dispositivo no tiene conexión o no pudo alcanzar el servidor.
final class NoConnectionFailure extends AppFailure {
  const NoConnectionFailure({super.correlationId});

  @override
  String get message => 'Sin conexión. Revisa tu internet e intenta de nuevo.';

  @override
  bool get isTransient => true;
}

/// La petición superó el tiempo máximo de espera.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.correlationId});

  @override
  String get message => 'El servicio está tardando más de lo normal.';

  @override
  bool get isTransient => true;
}

/// Servicio caído o degradado (502/503/504) o circuito abierto.
final class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure({
    this.service,
    this.circuitOpen = false,
    super.correlationId,
  });

  final String? service;

  /// `true` si la app dejó de llamar al servicio para protegerlo.
  final bool circuitOpen;

  @override
  String get message => 'Este servicio no está disponible por ahora.';

  @override
  bool get isTransient => true;
}

/// La sesión no es válida o expiró y no pudo renovarse.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({required this.code, super.correlationId});

  final String code;

  @override
  String get message => 'Tu sesión terminó. Vuelve a iniciar sesión.';
}

/// Datos enviados inválidos (400). `fieldErrors` mapea campo → mensaje.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.fieldErrors = const {},
    this.serverMessage,
    super.correlationId,
  });

  final Map<String, String> fieldErrors;
  final String? serverMessage;

  @override
  String get message => serverMessage ?? 'Revisa los datos ingresados.';
}

/// Regla de negocio rechazada (409/422/429), con `code` estable del BFF
/// (p. ej. `email_taken`, `insufficient_funds`).
final class BusinessFailure extends AppFailure {
  const BusinessFailure({
    required this.code,
    required this.serverMessage,
    super.correlationId,
  });

  final String code;
  final String serverMessage;

  @override
  String get message => serverMessage;
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.correlationId});

  @override
  String get message => 'No encontramos lo que buscas.';
}

/// Error del servidor no clasificado (500…).
final class ServerFailure extends AppFailure {
  const ServerFailure({required this.statusCode, super.correlationId});

  final int statusCode;

  @override
  String get message => 'Ocurrió un error inesperado. Intenta más tarde.';

  @override
  bool get isTransient => true;
}

/// Errores del cliente: respuesta con formato inesperado, cancelación, bugs.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({this.cause, super.correlationId});

  final Object? cause;

  @override
  String get message => 'Algo salió mal. Intenta de nuevo.';
}
