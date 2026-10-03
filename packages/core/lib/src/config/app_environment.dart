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
  });

  /// Lee los valores definidos al compilar. Por defecto apunta al backend
  /// local visto desde el emulador Android (10.0.2.2 = localhost del host).
  factory AppEnvironment.fromDefines() => const AppEnvironment(
    name: String.fromEnvironment('ENV', defaultValue: 'dev'),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000',
    ),
    enableDebugTools: bool.fromEnvironment(
      'ENABLE_DEBUG_TOOLS',
      defaultValue: true,
    ),
  );

  final String name;
  final String apiBaseUrl;

  /// Habilita el panel de diagnóstico y chaos testing. Debe ser `false` en prod.
  final bool enableDebugTools;

  bool get isProduction => name == 'prod';
}
