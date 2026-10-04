/// Mini app registrada en la app. Solo se cargan las de este catálogo y
/// solo se permite navegar dentro de su [origin].
class MiniAppDefinition {
  const MiniAppDefinition({
    required this.id,
    required this.title,
    required this.entryUrl,
  });

  final String id;
  final String title;
  final Uri entryUrl;

  /// `scheme://host:port` de la mini app.
  String get origin => entryUrl.origin;
}

/// Catálogo de mini apps según el hosting del entorno.
Map<String, MiniAppDefinition> miniAppCatalog(String baseUrl) => {
  'credit-simulator': MiniAppDefinition(
    id: 'credit-simulator',
    title: 'Simulador de crédito',
    entryUrl: Uri.parse('$baseUrl/credit-simulator/'),
  ),
};
