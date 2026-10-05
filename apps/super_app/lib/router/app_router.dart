import 'package:accounts/accounts.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:home/home.dart';
import 'package:mini_apps/mini_apps.dart';
import 'package:sdui/sdui.dart';

import '../diagnostics/dev_tools_cubit.dart';
import '../diagnostics/dev_tools_section.dart';
import '../diagnostics/diagnostics_cubit.dart';
import '../diagnostics/diagnostics_page.dart';
import '../profile/profile_page.dart';
import 'app_routes.dart';
import 'main_shell.dart';
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
      // Pestañas principales. Los detalles (cuenta, transferencia, mini app,
      // diagnóstico) son rutas de primer nivel: se abren a pantalla
      // completa, por encima de la barra.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
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
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.movements,
                builder: (context, state) => AccountsModule.movements(di),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.services,
                builder: (context, state) => MiniAppsModule.services(di),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => ProfilePage(
                  onOpenDiagnostics: () => context.push(AppRoutes.diagnostics),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (context, state) {
          final environment = di<AppEnvironment>();
          final devTools = environment.enableDebugTools;
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => DiagnosticsCubit(
                  api: di<ApiClient>(),
                  connectivity: di<ConnectivityMonitor>(),
                  circuitBreaker: di<CircuitBreaker>(),
                )..start(),
              ),
              if (devTools)
                BlocProvider(
                  create: (_) => DevToolsCubit(
                    api: di<ApiClient>(),
                    adminKey: environment.adminKey,
                    customerEmail: () => session.state.user?.email,
                  )..load(),
                ),
            ],
            child: DiagnosticsPage(
              environment: environment,
              devTools: devTools ? const DevToolsSection() : null,
            ),
          );
        },
      ),
    ],
  );
}
