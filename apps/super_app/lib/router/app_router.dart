import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../diagnostics/diagnostics_cubit.dart';
import '../diagnostics/diagnostics_page.dart';

abstract final class AppRoutes {
  static const diagnostics = '/diagnostics';
}

/// Router de la app: compone las rutas que aporta cada módulo con las del
/// shell. En F3 se agrega la redirección según el estado de la sesión.
GoRouter createRouter({
  required GetIt di,
  required List<FeatureModule> modules,
}) {
  return GoRouter(
    initialLocation: AppRoutes.diagnostics,
    routes: [
      for (final module in modules) ...module.routes(di),
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
