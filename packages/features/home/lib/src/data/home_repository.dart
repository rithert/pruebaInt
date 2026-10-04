import 'package:core/core.dart';
import 'package:sdui/sdui.dart';

/// Layout embebido en la app: se muestra si el servicio de experiencia no
/// responde y no hay un layout en caché. Garantiza que el cliente siempre
/// pueda ver sus cuentas y transferir, aunque la personalización falle.
const fallbackHomeLayout = SduiLayout(
  schemaVersion: 1,
  layoutId: 'home.fallback',
  components: [
    SduiComponent(
      id: 'greeting',
      type: 'greeting',
      props: {'title': 'Hola', 'subtitle': 'Estas son tus cuentas.'},
    ),
    SduiComponent(id: 'accounts', type: 'accounts_summary'),
    SduiComponent(
      id: 'quick_actions',
      type: 'quick_actions',
      props: {
        'actions': [
          {
            'id': 'transfer',
            'label': 'Transferir',
            'icon': 'transfer',
            'route': '/transfer',
          },
          {
            'id': 'support',
            'label': 'Ayuda',
            'icon': 'support',
            'route': '/diagnostics',
          },
        ],
      },
    ),
  ],
);

class HomeRepository {
  HomeRepository({
    required this._api,
    required this._fetcher,
    required this._parser,
    required this._telemetry,
  });

  final ApiClient _api;
  final CachedFetcher _fetcher;
  final SduiParser _parser;
  final Telemetry _telemetry;

  /// Layout personalizado con stale-while-revalidate: el último layout
  /// guardado aparece al instante, también sin red.
  Stream<Resource<SduiLayout>> watchHome() => _fetcher.watch(
    key: 'home.layout',
    fetch: () => _api.get('/v1/experience/home', decode: (json) => json),
    decode: _decode,
  );

  SduiLayout _decode(Object? json) {
    final result = _parser.parse(json);
    if (result.skipped.isNotEmpty) {
      // Señal temprana de que el servidor envía componentes que esta versión
      // de la app no conoce (p. ej. tras lanzar uno nuevo).
      _telemetry.logEvent('sdui_components_skipped', {
        'layoutId': result.layout.layoutId,
        'count': result.skipped.length,
        'reasons': result.skipped.take(5).join(' | '),
      });
    }
    return result.layout;
  }
}
