import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El dispositivo de prueba "no tiene huella": la app entra sin bloqueo.
class NoBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Bombea frames hasta que aparezca [finder]. `pumpAndSettle` no sirve aquí:
/// los indicadores de carga animan sin fin y la red real tarda lo que tarda.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció en ${timeout.inSeconds}s: $finder');
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Sigue visible tras ${timeout.inSeconds}s: $finder');
}

/// Escribe en el campo de formulario con esa etiqueta.
Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// Lleva el elemento a pantalla (scroll) y lo toca.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Correo único por ejecución: cada corrida crea su propio cliente.
String uniqueEmail(String prefix) =>
    '$prefix.${DateTime.now().millisecondsSinceEpoch}@example.com';
