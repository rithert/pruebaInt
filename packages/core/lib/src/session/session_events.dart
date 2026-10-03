import 'dart:async';

/// Canal de eventos de sesión entre la capa de red y el módulo de auth.
///
/// La red detecta que la sesión terminó (refresh rechazado), pero no sabe
/// navegar al login: publica el evento y el módulo de auth reacciona.
class SessionEvents {
  final StreamController<void> _expired = StreamController<void>.broadcast();

  Stream<void> get onExpired => _expired.stream;

  void notifyExpired() => _expired.add(null);

  Future<void> dispose() => _expired.close();
}
