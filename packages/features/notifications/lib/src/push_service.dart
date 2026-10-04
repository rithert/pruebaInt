import 'dart:async';

import 'package:core/core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Notificación recibida con la app abierta: se muestra como aviso dentro
/// de la app (el sistema solo las dibuja cuando la app está en segundo plano).
class ForegroundNotification {
  const ForegroundNotification({
    required this.title,
    required this.body,
    this.route,
  });

  final String title;
  final String body;
  final String? route;
}

/// Puerto de notificaciones push. El shell solo conoce esta interfaz.
abstract interface class PushService {
  bool get enabled;

  /// Pide permiso, obtiene el token y lo registra en el BFF.
  Future<void> start();

  /// Da de baja el dispositivo (logout): no llegan push de otro cliente.
  Future<void> stop();

  /// Rutas internas a abrir cuando el usuario toca una notificación.
  Stream<String> get openedRoutes;

  Stream<ForegroundNotification> get foregroundNotifications;
}

/// Ruta interna segura desde los datos de una notificación, o `null`.
String? routeFromData(Map<String, Object?> data) {
  final route = data['route'];
  if (route is! String || !route.startsWith('/') || route.startsWith('//')) {
    return null;
  }
  return route;
}

/// Sin Firebase configurado (p. ej. un clon del repo sin credenciales): la
/// app funciona igual, sin notificaciones.
class DisabledPushService implements PushService {
  const DisabledPushService();

  @override
  bool get enabled => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<String> get openedRoutes => const Stream.empty();

  @override
  Stream<ForegroundNotification> get foregroundNotifications =>
      const Stream.empty();
}

class FcmPushService implements PushService {
  FcmPushService({
    required this._messaging,
    required this._api,
    required this._telemetry,
  });

  final FirebaseMessaging _messaging;
  final ApiClient _api;
  final Telemetry _telemetry;

  final _routes = StreamController<String>.broadcast();
  final _foreground = StreamController<ForegroundNotification>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  String? _token;
  bool _listening = false;

  @override
  bool get enabled => true;

  @override
  Stream<String> get openedRoutes => _routes.stream;

  @override
  Stream<ForegroundNotification> get foregroundNotifications =>
      _foreground.stream;

  @override
  Future<void> start() async {
    _listenOnce();

    final settings = await _messaging.requestPermission();
    _telemetry.logEvent('push_permission', {
      'status': settings.authorizationStatus.name,
    });
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) await _register(token);
  }

  @override
  Future<void> stop() async {
    final token = _token;
    _token = null;
    if (token == null) return;
    // Mejor esfuerzo: el BFF también limpia tokens inválidos al enviar.
    await _api.delete<void>(
      '/v1/devices/${Uri.encodeComponent(token)}',
      decode: (_) {},
    );
  }

  void _listenOnce() {
    if (_listening) return;
    _listening = true;

    _subs
      ..add(_messaging.onTokenRefresh.listen(_register))
      ..add(
        FirebaseMessaging.onMessage.listen((message) {
          final notification = message.notification;
          if (notification == null) return;
          _foreground.add(
            ForegroundNotification(
              title: notification.title ?? '',
              body: notification.body ?? '',
              route: routeFromData(message.data),
            ),
          );
        }),
      )
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_opened));

    // La app se abrió en frío tocando una notificación.
    unawaited(
      _messaging.getInitialMessage().then((m) {
        if (m != null) _opened(m);
      }),
    );
  }

  void _opened(RemoteMessage message) {
    final route = routeFromData(message.data);
    _telemetry.logEvent('push_opened', {'hasRoute': route != null});
    if (route != null) _routes.add(route);
  }

  Future<void> _register(String token) async {
    _token = token;
    final result = await _api.post<void>(
      '/v1/devices',
      body: {'token': token, 'platform': 'android'},
      decode: (_) {},
    );
    if (result case Failure(:final failure)) {
      _telemetry.recordError(failure, null, reason: 'push_register_failed');
    }
  }
}
