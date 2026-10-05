import 'dart:async';
import 'dart:ui';

import 'package:accounts/accounts.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:home/home.dart';
import 'package:mini_apps/mini_apps.dart';
import 'package:notifications/notifications.dart';

import '../app.dart';
import '../router/app_router.dart';
import 'dependencies.dart';
import 'firebase_bootstrap.dart';
import 'push_coordinator.dart';

/// App lista para `runApp` y su contenedor de dependencias.
class BootstrappedApp {
  const BootstrappedApp(this.app, this.di);

  final Widget app;
  final GetIt di;
}

/// Arma la app completa. `main()` la usa con los valores reales; los tests
/// E2E la usan con ajustes para poder automatizar el flujo:
/// - [enableFirebase] `false`: sin diálogo nativo de permisos de push.
/// - [biometrics]: autenticador falso (un test no puede poner la huella).
/// - [resetLocalData]: arranca sin sesión ni caché de una ejecución previa.
Future<BootstrappedApp> bootstrap({
  AppEnvironment? environment,
  bool enableFirebase = true,
  BiometricAuthenticator? biometrics,
  bool resetLocalData = false,
  bool installErrorHandlers = true,
}) async {
  // Firebase es opcional: sin google-services.json la app funciona igual.
  final firebaseReady = enableFirebase && await initFirebase();
  final Telemetry telemetry = firebaseReady
      ? CompositeTelemetry([const DebugTelemetry(), FirebaseTelemetry()])
      : const DebugTelemetry();

  /// Módulos de dominio que componen la app. Agregar un dominio nuevo es
  /// agregarlo a esta lista.
  final modules = <FeatureModule>[
    AuthModule(biometrics: biometrics),
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
    environment: environment ?? AppEnvironment.fromDefines(),
    modules: modules,
    telemetry: telemetry,
  );

  if (resetLocalData) {
    await di<TokenStore>().clear();
    await di<CacheStore>().clear();
  }

  // Captura global de errores: de UI (Flutter) y asíncronos (plataforma).
  // En los tests E2E no se instala: el binding de test usa los suyos para
  // que cualquier error haga fallar la prueba.
  if (installErrorHandlers) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      telemetry.recordError(
        details.exception,
        details.stack,
        reason: 'flutter',
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      telemetry.recordError(error, stack, reason: 'platform', fatal: true);
      return true;
    };
  }

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

  return BootstrappedApp(
    SuperApp(
      router: router,
      session: session,
      messengerKey: messengerKey,
      providers: [
        BlocProvider<BalanceVisibilityCubit>.value(
          value: di<BalanceVisibilityCubit>(),
        ),
      ],
    ),
    di,
  );
}
