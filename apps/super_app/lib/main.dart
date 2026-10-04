import 'dart:async';
import 'dart:ui';

import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap/dependencies.dart';
import 'router/app_router.dart';

/// Módulos de dominio que componen la app. Agregar un dominio nuevo es
/// agregarlo a esta lista (y en el futuro, habilitarlo por feature flag).
final List<FeatureModule> _modules = [AuthModule()];

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final di = configureDependencies(
    environment: AppEnvironment.fromDefines(),
    modules: _modules,
  );
  final telemetry = di<Telemetry>();

  // Captura global de errores: de UI (Flutter) y asíncronos (plataforma).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    telemetry.recordError(details.exception, details.stack, reason: 'flutter');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    telemetry.recordError(error, stack, reason: 'platform', fatal: true);
    return true;
  };

  final session = di<SessionCubit>();
  unawaited(session.restore());

  runApp(
    SuperApp(
      router: createRouter(di: di, modules: _modules),
      session: session,
    ),
  );
}
