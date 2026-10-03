/// Capacidades transversales de la plataforma, sin conocimiento de ningún
/// dominio de negocio: configuración, red y resiliencia, almacenamiento,
/// observabilidad y contrato de módulos.
library;

export 'src/cache/app_database.dart' show AppDatabase;
export 'src/cache/cache_store.dart';
export 'src/cache/cached_fetcher.dart';
export 'src/config/app_environment.dart';
export 'src/connectivity/connectivity_monitor.dart';
export 'src/modules/feature_module.dart';
export 'src/network/api_client.dart';
export 'src/network/failure_mapper.dart';
export 'src/network/http_client_factory.dart';
export 'src/network/interceptors/auth_interceptor.dart';
export 'src/network/interceptors/circuit_breaker_interceptor.dart';
export 'src/network/interceptors/correlation_id_interceptor.dart';
export 'src/network/interceptors/retry_interceptor.dart';
export 'src/network/interceptors/telemetry_interceptor.dart';
export 'src/observability/telemetry.dart';
export 'src/result/app_failure.dart';
export 'src/result/result.dart';
export 'src/session/session_events.dart';
export 'src/session/token_store.dart';
