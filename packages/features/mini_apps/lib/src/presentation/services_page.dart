import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/mini_app.dart';

/// Pestaña Servicios: catálogo de mini apps disponibles. Si el kill switch
/// del BFF las apaga, la mini app lo informa al abrirse.
class ServicesPage extends StatelessWidget {
  const ServicesPage({required this.catalog, super.key});

  final List<MiniAppDefinition> catalog;

  static const _icons = <String, IconData>{
    'credit-simulator': Icons.calculate_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: catalog.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.apps_outlined,
                title: 'Pronto habrá servicios aquí',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: catalog.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final app = catalog[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radius,
                          ),
                        ),
                        child: Icon(
                          _icons[app.id] ?? Icons.apps_outlined,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    title: Text(app.title),
                    subtitle: app.description.isEmpty
                        ? null
                        : Text(app.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/mini-apps/${app.id}'),
                  ),
                );
              },
            ),
    );
  }
}
