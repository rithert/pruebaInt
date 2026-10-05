import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'data/mini_apps_repository.dart';
import 'domain/mini_app.dart';
import 'presentation/mini_app_cubit.dart';
import 'presentation/mini_app_page.dart';
import 'presentation/services_page.dart';

class MiniAppsModule implements FeatureModule {
  /// [firstName] lo aporta el shell (sesión) para personalizar la mini app
  /// sin que este módulo dependa del módulo de auth.
  MiniAppsModule({this._firstName});

  final String? Function()? _firstName;

  @override
  String get name => 'mini_apps';

  @override
  void registerDependencies(GetIt di) {
    di.registerLazySingleton<MiniAppsRepository>(
      () => MiniAppsRepository(di<ApiClient>()),
    );
  }

  /// Pestaña Servicios con el catálogo del entorno.
  static Widget services(GetIt di) => ServicesPage(
    catalog: miniAppCatalog(di<AppEnvironment>().miniAppsBaseUrl).values
        .toList(),
  );

  @override
  List<RouteBase> routes(GetIt di) => [
    GoRoute(
      path: '/mini-apps/:appId',
      builder: (context, state) {
        final environment = di<AppEnvironment>();
        final definition = miniAppCatalog(
          environment.miniAppsBaseUrl,
        )[state.pathParameters['appId']];
        if (definition == null) {
          return const Scaffold(
            body: Center(child: Text('Mini app no encontrada.')),
          );
        }
        return BlocProvider(
          create: (_) => MiniAppCubit(
            repository: di<MiniAppsRepository>(),
            appId: definition.id,
            telemetry: di<Telemetry>(),
          )..authorize(),
          child: MiniAppPage(
            definition: definition,
            environment: environment,
            firstName: _firstName?.call(),
          ),
        );
      },
    ),
  ];
}
