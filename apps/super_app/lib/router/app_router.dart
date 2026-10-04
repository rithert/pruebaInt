import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:home/home.dart';
import 'package:sdui/sdui.dart';

import '../diagnostics/diagnostics_cubit.dart';
import '../diagnostics/diagnostics_page.dart';
import 'app_routes.dart';
import 'session_redirect.dart';
import 'stream_listenable.dart';

/// Router de la app: compone las rutas de cada módulo con las del shell y
/// protege la navegación según el estado de la sesión.
GoRouter createRouter({
  required GetIt di,
  required List<FeatureModule> modules,
}) {
  final session = di<SessionCubit>();

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: StreamListenable(session.stream),
    redirect: (context, state) =>
        sessionRedirect(session.state.status, state.matchedLocation),
    routes: [
      for (final module in modules) ...module.routes(di),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => BlocProvider(
          create: (_) => HomeCubit(
            repository: di<HomeRepository>(),
            tracker: di<EventTracker>(),
            connectivity: di<ConnectivityMonitor>(),
          )..refresh(),
          child: HomePage(
            registry: di<SduiRegistry>(),
            telemetry: di<Telemetry>(),
            appBarActions: [
              IconButton(
                tooltip: 'Diagnóstico',
                icon: const Icon(Icons.monitor_heart_outlined),
                onPressed: () => context.push(AppRoutes.diagnostics),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: session.logout,
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (context, state) => BlocProvider(
          create: (_) => DiagnosticsCubit(
            api: di<ApiClient>(),
            connectivity: di<ConnectivityMonitor>(),
            circuitBreaker: di<CircuitBreaker>(),
          )..start(),
          child: DiagnosticsPage(environment: di<AppEnvironment>()),
        ),
      ),
    ],
  );
}
