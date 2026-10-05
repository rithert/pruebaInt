import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_app/bootstrap/bootstrap.dart';

import 'support/e2e_helpers.dart';

/// E2E contra el BFF REAL (sin mocks). Requisitos:
///   - BFF corriendo (`cd backend; npm run dev`).
///   - Teléfono conectado + `adb reverse tcp:3000 tcp:3000`.
/// Ejecutar: `fvm flutter test integration_test` (en apps/super_app).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final environment = AppEnvironment.fromDefines();
  final admin = Dio(
    BaseOptions(
      baseUrl: environment.apiBaseUrl,
      headers: {'x-admin-key': environment.adminKey},
    ),
  );

  late BootstrappedApp bootstrapped;

  Future<void> launchApp(WidgetTester tester) async {
    bootstrapped = await bootstrap(
      environment: environment,
      enableFirebase: false,
      biometrics: NoBiometrics(),
      resetLocalData: true,
      installErrorHandlers: false,
    );
    await tester.pumpWidget(bootstrapped.app);
  }

  tearDown(() async {
    await bootstrapped.di.reset();
  });

  testWidgets('FLUJO CRÍTICO: onboarding → home personalizado → movimientos → '
      'transferencia → logout', (tester) async {
    await launchApp(tester);
    final email = uniqueEmail('e2e');

    // 1. Sin sesión, la app abre el login.
    await pumpUntilFound(tester, find.text('Hola de nuevo'));
    await tapVisible(tester, find.text('¿Eres nuevo? Crea tu cuenta'));

    // 2. Onboarding en 3 pasos (contra el BFF real).
    await pumpUntilFound(tester, find.text('Cuéntanos de ti'));
    await enterField(tester, 'Nombre completo', 'Erika Tester');
    await enterField(tester, 'Correo', email);
    await tapVisible(tester, find.text('Continuar'));

    await pumpUntilFound(tester, find.text('¿Cuál es tu objetivo?'));
    await tapVisible(tester, find.text('Ahorrar para una meta'));
    await tapVisible(tester, find.text('Continuar'));

    await pumpUntilFound(tester, find.text('Crea tu acceso'));
    await enterField(tester, 'Contraseña', 'Segura123');
    await tapVisible(tester, find.text('Acepto los términos y condiciones'));
    await tapVisible(tester, find.text('Crear cuenta'));

    // 3. Home personalizado por el servidor: saludo con el nombre y
    //    resumen de cuentas con datos reales.
    await pumpUntilFound(tester, find.textContaining(', Erika'));
    await pumpUntilFound(tester, find.text('Saldo total'));
    expect(find.text('Cuenta de ahorros'), findsWidgets);
    expect(find.text('Bolsillo de metas'), findsOneWidget);

    // 4. Movimientos de la cuenta y su detalle.
    await tapVisible(tester, find.text('Cuenta de ahorros'));
    await pumpUntilFound(tester, find.text('Todos'));
    await pumpUntilFound(tester, find.byType(ListTile));
    await tapVisible(tester, find.byType(ListTile));
    await pumpUntilFound(tester, find.text('Saldo después'));
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pageBack();
    await pumpUntilFound(tester, find.text('Saldo total'));

    // 5. Transferencia entre cuentas propias.
    await tapVisible(tester, find.text('Transferir entre mis cuentas'));
    await pumpUntilFound(tester, find.text('Monto (USD)'));
    await enterField(tester, 'Monto (USD)', '10');
    await tapVisible(tester, find.text(r'Transferir $10,00'));
    await pumpUntilFound(tester, find.text(r'Transferiste $10,00'));
    await tapVisible(tester, find.text('Listo'));

    // 6. Ocultar saldos desde el home y cerrar sesión desde Perfil.
    await pumpUntilFound(tester, find.byTooltip('Ocultar saldos'));
    await tapVisible(tester, find.byTooltip('Ocultar saldos'));
    await pumpUntilFound(tester, find.byTooltip('Mostrar saldos'));
    await tapVisible(tester, find.text('Perfil'));
    await pumpUntilFound(tester, find.text('Cerrar sesión'));
    await tapVisible(tester, find.text('Cerrar sesión'));
    await pumpUntilFound(tester, find.text('Hola de nuevo'));
  });

  testWidgets(
    'DEGRADADO: con el servicio de experiencia caído, el home usa el layout '
    'de respaldo y las cuentas siguen disponibles; al restaurarlo, se recupera',
    (tester) async {
      final email = uniqueEmail('e2e.chaos');
      await admin.post<Object?>(
        '/v1/auth/register',
        data: {
          'email': email,
          'password': 'Segura123',
          'fullName': 'Carla Caos',
          'goal': 'invest',
          'acceptTerms': true,
        },
      );
      await admin.put<Object?>(
        '/admin/chaos',
        data: {
          'enabled': true,
          'services': {
            'experience': {'down': true},
          },
        },
      );
      // Pase lo que pase, el BFF queda sano para los demás.
      addTearDown(() => admin.delete<Object?>('/admin/chaos'));

      await launchApp(tester);
      await pumpUntilFound(tester, find.text('Hola de nuevo'));
      await enterField(tester, 'Correo', email);
      await tester.enterText(find.byType(TextField).last, 'Segura123');
      await tapVisible(tester, find.text('Iniciar sesión'));

      // La personalización falla (503, con reintentos) → layout embebido,
      // pero el cliente sigue viendo sus cuentas.
      await pumpUntilFound(
        tester,
        find.textContaining('versión básica'),
        timeout: const Duration(seconds: 45),
      );
      await pumpUntilFound(tester, find.text('Saldo total'));
      expect(find.textContaining(', Carla'), findsNothing);

      // Se restaura el servicio y el usuario reintenta: vuelve la
      // experiencia personalizada.
      await admin.delete<Object?>('/admin/chaos');
      await tapVisible(tester, find.text('Reintentar'));
      await pumpUntilFound(tester, find.textContaining(', Carla'));
      await pumpUntilGone(tester, find.textContaining('versión básica'));
    },
  );
}
