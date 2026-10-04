import 'package:core/core.dart';
import 'package:get_it/get_it.dart';

import 'session_refresher.dart';

/// Registra las capacidades transversales y luego las de cada módulo.
///
/// Las dependencias del core son singletons: una sola base de datos, un
/// solo cliente HTTP (con su circuit breaker compartido) por proceso.
GetIt configureDependencies({
  required AppEnvironment environment,
  required List<FeatureModule> modules,
  GetIt? getIt,
}) {
  final di = getIt ?? GetIt.instance;

  const Telemetry telemetry = DebugTelemetry();
  final tokenStore = SecureTokenStore();
  final sessionEvents = SessionEvents();
  final circuitBreaker = CircuitBreaker();
  final database = AppDatabase.open();

  final dio = createHttpClient(
    environment: environment,
    tokenStore: tokenStore,
    refreshSession: SessionRefresher(environment.apiBaseUrl).call,
    circuitBreaker: circuitBreaker,
    telemetry: telemetry,
    onSessionExpired: sessionEvents.notifyExpired,
  );
  final cacheStore = DriftCacheStore(database);
  final connectivity = PlusConnectivityMonitor();

  di
    ..registerSingleton<AppEnvironment>(environment)
    ..registerSingleton<Telemetry>(telemetry)
    ..registerSingleton<TokenStore>(tokenStore)
    ..registerSingleton<SessionEvents>(sessionEvents)
    ..registerSingleton<CircuitBreaker>(circuitBreaker)
    ..registerSingleton<AppDatabase>(database, dispose: (db) => db.close())
    ..registerSingleton<CacheStore>(cacheStore)
    ..registerSingleton<CachedFetcher>(CachedFetcher(cacheStore))
    ..registerSingleton<ConnectivityMonitor>(connectivity)
    ..registerSingleton<ApiClient>(ApiClient(dio, connectivity: connectivity));

  for (final module in modules) {
    module.registerDependencies(di);
  }
  return di;
}
