import 'package:auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_app/router/app_routes.dart';
import 'package:super_app/router/session_redirect.dart';

void main() {
  group('sessionRedirect', () {
    test('mientras se restaura la sesión, todo va al splash', () {
      expect(
        sessionRedirect(SessionStatus.unknown, AppRoutes.home),
        AppRoutes.splash,
      );
      expect(sessionRedirect(SessionStatus.unknown, AppRoutes.splash), isNull);
    });

    test('sin sesión: solo rutas públicas; lo privado va al login', () {
      const status = SessionStatus.unauthenticated;
      expect(sessionRedirect(status, AuthRoutes.login), isNull);
      expect(sessionRedirect(status, AuthRoutes.onboarding), isNull);
      expect(sessionRedirect(status, AppRoutes.home), AuthRoutes.login);
      expect(sessionRedirect(status, AppRoutes.splash), AuthRoutes.login);
    });

    test('el diagnóstico es accesible sin sesión (soporte)', () {
      expect(
        sessionRedirect(SessionStatus.unauthenticated, AppRoutes.diagnostics),
        isNull,
      );
    });

    test('bloqueada: cualquier ruta va al desbloqueo', () {
      expect(
        sessionRedirect(SessionStatus.locked, AppRoutes.home),
        AuthRoutes.unlock,
      );
      expect(sessionRedirect(SessionStatus.locked, AuthRoutes.unlock), isNull);
    });

    test('autenticada: login, onboarding, unlock y splash llevan al home', () {
      const status = SessionStatus.authenticated;
      for (final route in [
        AuthRoutes.login,
        AuthRoutes.onboarding,
        AuthRoutes.unlock,
        AppRoutes.splash,
      ]) {
        expect(sessionRedirect(status, route), AppRoutes.home, reason: route);
      }
      expect(sessionRedirect(status, AppRoutes.home), isNull);
      expect(sessionRedirect(status, AppRoutes.diagnostics), isNull);
    });
  });
}
