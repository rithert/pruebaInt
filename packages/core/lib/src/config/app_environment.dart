/// Configuración de entorno inyectada en tiempo de compilación con
/// `--dart-define` (o `--dart-define-from-file=config/<env>.json`).
///
/// Así el mismo código se construye para dev, staging y prod sin
/// secretos versionados.
class AppEnvironment {
  const AppEnvironment({
    required this.name,
    required this.apiBaseUrl,
    required this.enableDebugTools,
    this.miniAppsBaseUrl = 'http://localhost:3100',
  });

  /// Lee los valores definidos al compilar. Por defecto apunta a los
  /// servicios locales a través de `adb reverse` (puertos 3000 y 3100), que
  /// redirige el puerto del dispositivo (físico o emulador) al PC por USB.
  factory AppEnvironment.fromDefines() => const AppEnvironment(
    name: String.fromEnvironment('ENV', defaultValue: 'dev'),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    ),
    enableDebugTools: bool.fromEnvironment(
      'ENABLE_DEBUG_TOOLS',
      defaultValue: true,
    ),
    miniAppsBaseUrl: String.fromEnvironment(
      'MINI_APPS_BASE_URL',
      defaultValue: 'http://localhost:3100',
    ),
  );

  final String name;
  final String apiBaseUrl;

  /// Habilita el panel de diagnóstico y chaos testing. Debe ser `false` en prod.
  final bool enableDebugTools;

  /// Hosting de las mini apps (otro origen, desplegado de forma independiente).
  final String miniAppsBaseUrl;

  bool get isProduction => name == 'prod';
}
