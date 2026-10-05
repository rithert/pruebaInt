import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// Título de una sección dentro de una pantalla, con una acción opcional
/// ("Ver todo"). Se anuncia como encabezado para navegar por secciones con
/// el lector de pantalla.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.action, super.key});

  final String title;

  /// Normalmente un `TextButton`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
