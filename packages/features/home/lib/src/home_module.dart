import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:sdui/sdui.dart';

import 'data/event_tracker.dart';
import 'data/home_repository.dart';
import 'presentation/components.dart';

/// Experiencia personalizada del home. La ruta `/home` la monta el shell
/// (que aporta las acciones de la barra); este módulo aporta datos,
/// eventos y los componentes genéricos del catálogo SDUI.
class HomeModule implements FeatureModule, SduiContributor {
  @override
  String get name => 'home';

  @override
  void registerDependencies(GetIt di) {
    di
      ..registerLazySingleton<EventTracker>(
        () => EventTracker(di<ApiClient>()),
        dispose: (tracker) => tracker.dispose(),
      )
      ..registerLazySingleton<HomeRepository>(
        // El parser se crea cuando el catálogo ya está completo.
        () => HomeRepository(
          api: di<ApiClient>(),
          fetcher: di<CachedFetcher>(),
          parser: SduiParser(supported: di<SduiRegistry>().supported),
          telemetry: di<Telemetry>(),
        ),
      );
  }

  @override
  void registerSduiComponents(SduiRegistry registry) =>
      registerHomeComponents(registry);

  @override
  List<RouteBase> routes(GetIt di) => const [];
}
