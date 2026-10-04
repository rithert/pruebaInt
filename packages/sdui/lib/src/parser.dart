import 'models.dart';

/// El layout completo no se puede usar (formato inválido o versión futura).
class SduiSchemaException implements Exception {
  const SduiSchemaException(this.message);

  final String message;

  @override
  String toString() => 'SduiSchemaException: $message';
}

class SduiParseResult {
  const SduiParseResult(this.layout, this.skipped);

  final SduiLayout layout;

  /// Componentes descartados y por qué (se reportan a telemetría).
  final List<String> skipped;
}

/// Convierte el JSON del servidor en un [SduiLayout] seguro de dibujar.
///
/// Política de compatibilidad (clave para evolucionar sin publicar):
/// - Un `schemaVersion` mayor al soportado invalida el layout completo:
///   la app usa la caché o el layout embebido.
/// - Un componente desconocido, mal formado o de una versión que esta app no
///   sabe dibujar se OMITE; el resto de la pantalla se muestra igual.
/// Así el servidor puede lanzar componentes nuevos sin romper a quienes
/// tienen versiones viejas de la app.
class SduiParser {
  const SduiParser({required this.supported, this.maxSchemaVersion = 1});

  /// Tipo de componente → versión máxima que esta app sabe dibujar.
  final Map<String, int> supported;
  final int maxSchemaVersion;

  SduiParseResult parse(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const SduiSchemaException('la raíz no es un objeto');
    }
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int) {
      throw const SduiSchemaException('falta schemaVersion');
    }
    if (schemaVersion > maxSchemaVersion) {
      throw SduiSchemaException(
        'schemaVersion $schemaVersion no soportada (máx. $maxSchemaVersion)',
      );
    }
    final rawComponents = json['components'];
    if (rawComponents is! List<Object?>) {
      throw const SduiSchemaException('falta la lista de componentes');
    }

    final components = <SduiComponent>[];
    final skipped = <String>[];
    final seenIds = <String>{};

    for (final (index, raw) in rawComponents.indexed) {
      if (raw is! Map<String, Object?>) {
        skipped.add('#$index: no es un objeto');
        continue;
      }
      final id = raw['id'];
      final type = raw['type'];
      final version = raw['version'] ?? 1;
      final props = raw['props'] ?? const <String, Object?>{};

      if (id is! String || id.isEmpty || type is! String) {
        skipped.add('#$index: falta id o type');
      } else if (!seenIds.add(id)) {
        skipped.add('$id: id duplicado');
      } else if (!supported.containsKey(type)) {
        skipped.add('$id: tipo desconocido "$type"');
      } else if (version is! int || version > supported[type]!) {
        skipped.add('$id: versión $version de "$type" no soportada');
      } else if (props is! Map<String, Object?>) {
        skipped.add('$id: props inválidas');
      } else {
        components.add(
          SduiComponent(id: id, type: type, version: version, props: props),
        );
      }
    }

    return SduiParseResult(
      SduiLayout(
        schemaVersion: schemaVersion,
        layoutId: json['layoutId'] is String
            ? json['layoutId']! as String
            : 'unknown',
        components: components,
      ),
      skipped,
    );
  }
}
