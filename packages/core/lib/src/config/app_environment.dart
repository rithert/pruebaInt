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

  /// Lee los valores definidos al compilar. Por defecto apunta al BFF local
  /// a través de `adb reverse tcp:3000 tcp:3000`, que redirige el puerto del
  /// dispositivo (físico o emulador) al PC por USB.
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
  );

  final String name;
  final String apiBaseUrl;

  /// Habilita el panel de diagnóstico y chaos testing. Debe ser `false` en prod.
  final bool enableDebugTools;

  bool get isProduction => name == 'prod';
}
