/// Un componente que el servidor pide dibujar.
class SduiComponent {
  const SduiComponent({
    required this.id,
    required this.type,
    this.version = 1,
    this.props = const {},
  });

  /// Identificador estable (eventos de uso, descartes).
  final String id;
  final String type;
  final int version;
  final Map<String, Object?> props;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'version': version,
    'props': props,
  };
}

/// Pantalla completa definida por el servidor.
class SduiLayout {
  const SduiLayout({
    required this.schemaVersion,
    required this.layoutId,
    required this.components,
  });

  final int schemaVersion;
  final String layoutId;
  final List<SduiComponent> components;

  SduiLayout copyWith({List<SduiComponent>? components}) => SduiLayout(
    schemaVersion: schemaVersion,
    layoutId: layoutId,
    components: components ?? this.components,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'layoutId': layoutId,
    'components': [for (final c in components) c.toJson()],
  };
}

/// Lectura defensiva de `props`: un dato con el tipo equivocado nunca
/// rompe la pantalla; se usa el valor por defecto.
extension SduiProps on Map<String, Object?> {
  String string(String key, {String fallback = ''}) {
    final value = this[key];
    return value is String ? value : fallback;
  }

  String? stringOrNull(String key) {
    final value = this[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  bool boolean(String key, {bool fallback = false}) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  Map<String, Object?>? mapOrNull(String key) {
    final value = this[key];
    return value is Map<String, Object?> ? value : null;
  }

  List<Map<String, Object?>> listOfMaps(String key) {
    final value = this[key];
    if (value is! List<Object?>) return const [];
    return value.whereType<Map<String, Object?>>().toList();
  }
}
