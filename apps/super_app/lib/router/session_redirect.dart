import 'package:auth/auth.dart';

import 'app_routes.dart';

/// Decide a dónde debe ir el usuario según la sesión. Es una función pura
/// (sin BuildContext) para poder probar todas las combinaciones.
///
/// Devuelve `null` si puede quedarse en [location].
String? sessionRedirect(SessionStatus status, String location) {
  final isPublic = AuthRoutes.public.contains(location);
  final isAlwaysAllowed = location == AppRoutes.diagnostics;

  return switch (status) {
    SessionStatus.unknown =>
      location == AppRoutes.splash ? null : AppRoutes.splash,
    SessionStatus.unauthenticated =>
      isPublic || isAlwaysAllowed ? null : AuthRoutes.login,
    SessionStatus.locked =>
      location == AuthRoutes.unlock ? null : AuthRoutes.unlock,
    SessionStatus.authenticated =>
      isPublic || location == AuthRoutes.unlock || location == AppRoutes.splash
          ? AppRoutes.home
          : null,
  };
}
