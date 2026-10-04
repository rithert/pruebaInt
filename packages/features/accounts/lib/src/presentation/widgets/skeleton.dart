import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Bloque gris de carga. Se excluye de la semántica: el lector de pantalla
/// anuncia "Cargando" una sola vez desde el contenedor.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.height = 16, this.width, super.key});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 5, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SkeletonBox(height: 40, width: 40),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: SkeletonBox()),
                  SizedBox(width: AppSpacing.md),
                  SkeletonBox(width: 72),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
