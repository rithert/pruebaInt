import 'dart:async';
import 'dart:ui';

import 'package:accounts/accounts.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';
import 'package:mini_apps/mini_apps.dart';
import 'package:notifications/notifications.dart';

import 'app.dart';
import 'bootstrap/dependencies.dart';
import 'bootstrap/firebase_bootstrap.dart';
import 'bootstrap/push_coordinator.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase es opcional: sin google-services.json la app funciona igual.
  final firebaseReady = await initFirebase();
  final Telemetry telemetry = firebaseReady
      ? CompositeTelemetry([const DebugTelemetry(), FirebaseTelemetry()])
      : const DebugTelemetry();

  /// Módulos de dominio que componen la app. Agregar un dominio nuevo es
  /// agregarlo a esta lista.
  final modules = <FeatureModule>[
    AuthModule(),
    AccountsModule(),
    HomeModule(),
    // El shell conecta dominios: la mini app recibe el nombre desde la
    // sesión sin que su módulo dependa del módulo de auth.
    MiniAppsModule(
      firstName: () => GetIt.instance<SessionCubit>().state.user?.firstName,
    ),
    NotificationsModule(firebaseReady: firebaseReady),
  ];

  final di = configureDependencies(
    environment: AppEnvironment.fromDefines(),
    modules: modules,
    telemetry: telemetry,
  );

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
  final router = createRouter(di: di, modules: modules);
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  PushCoordinator(
    push: di<PushService>(),
    session: session,
    router: router,
    messengerKey: messengerKey,
  ).start();
  unawaited(session.restore());

  runApp(
    SuperApp(router: router, session: session, messengerKey: messengerKey),
  );
}
