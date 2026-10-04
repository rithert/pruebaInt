import 'dart:async';

import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notifications/notifications.dart';

/// Conecta las notificaciones con la sesión y la navegación (el shell es el
/// único que conoce a ambos dominios):
/// - Con sesión activa: registra el dispositivo.
/// - Antes de cerrar sesión: lo da de baja (aún con credenciales válidas).
/// - Tocar una notificación abre su detalle; si la app está bloqueada, la
///   ruta espera hasta el desbloqueo.
class PushCoordinator {
  PushCoordinator({
    required this.push,
    required this.session,
    required this.router,
    required this.messengerKey,
  });

  final PushService push;
  final SessionCubit session;
  final GoRouter router;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  String? _pendingRoute;
  bool _started = false;

  void start() {
    if (!push.enabled) return;
    session.addBeforeEndHook(() async {
      _started = false;
      await push.stop();
    });
    session.stream.listen(_onSession);
    _onSession(session.state);

    push.openedRoutes.listen((route) {
      if (session.state.status == SessionStatus.authenticated) {
        unawaited(router.push(route));
      } else {
        _pendingRoute = route;
      }
    });
    push.foregroundNotifications.listen(_showInApp);
  }

  void _onSession(SessionState state) {
    if (state.status != SessionStatus.authenticated) return;
    if (!_started) {
      _started = true;
      unawaited(push.start());
    }
    final pending = _pendingRoute;
    if (pending != null) {
      _pendingRoute = null;
      unawaited(router.push(pending));
    }
  }

  /// Con la app abierta el sistema no muestra la notificación: se avisa
  /// dentro de la app, con acceso directo al detalle.
  void _showInApp(ForegroundNotification notification) {
    final route = notification.route;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('${notification.title}\n${notification.body}'),
        action: route == null
            ? null
            : SnackBarAction(label: 'Ver', onPressed: () => router.push(route)),
      ),
    );
  }
}
