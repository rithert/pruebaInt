import 'package:flutter/widgets.dart';

import 'models.dart';

/// Lo que un componente puede pedirle a la pantalla que lo contiene.
abstract interface class SduiActions {
  /// Navega a una ruta INTERNA de la app (las URLs externas se rechazan).
  void navigate(String route);

  /// Registra un evento de uso (`tapped`, `dismissed`) del componente.
  void track(String type, String componentId);

  /// Oculta el componente de inmediato (y registra el descarte).
  void dismiss(String componentId);
}

typedef SduiBuilder = Widget Function(
  BuildContext context,
  SduiComponent component,
  SduiActions actions,
);

/// Catálogo de componentes que esta versión de la app sabe dibujar. Cada
/// dominio aporta los suyos (ver [SduiContributor]); el servidor solo puede
/// pedir piezas de este catálogo, nunca código arbitrario.
class SduiRegistry {
  final Map<String, ({int maxVersion, SduiBuilder builder})> _entries = {};

  void register(String type, SduiBuilder builder, {int maxVersion = 1}) {
    assert(!_entries.containsKey(type), 'Componente "$type" ya registrado');
    _entries[type] = (maxVersion: maxVersion, builder: builder);
  }

  /// Tipo → versión máxima soportada (lo usa el parser).
  Map<String, int> get supported => {
    for (final entry in _entries.entries) entry.key: entry.value.maxVersion,
  };

  SduiBuilder? builderFor(String type) => _entries[type]?.builder;
}

/// Lo implementa un módulo de dominio que aporta componentes al catálogo.
abstract interface class SduiContributor {
  void registerSduiComponents(SduiRegistry registry);
}
