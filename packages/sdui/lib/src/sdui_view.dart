import 'package:flutter/widgets.dart';

import 'models.dart';
import 'registry.dart';

/// Dibuja un layout del servidor. Cada componente queda aislado: si su
/// builder falla (props inesperadas), se omite y se reporta, y el resto de la
/// pantalla sigue funcionando.
class SduiView extends StatelessWidget {
  const SduiView({
    required this.layout,
    required this.registry,
    required this.actions,
    this.spacing = 16,
    this.onComponentError,
    super.key,
  });

  final SduiLayout layout;
  final SduiRegistry registry;
  final SduiActions actions;
  final double spacing;
  final void Function(SduiComponent component, Object error)? onComponentError;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final component in layout.components) {
      final child = _buildSafely(context, component);
      if (child == null) continue;
      if (children.isNotEmpty) children.add(SizedBox(height: spacing));
      children.add(KeyedSubtree(key: ValueKey(component.id), child: child));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _buildSafely(BuildContext context, SduiComponent component) {
    final builder = registry.builderFor(component.type);
    if (builder == null) return null;
    try {
      return builder(context, component, actions);
    } on Object catch (error) {
      onComponentError?.call(component, error);
      return null;
    }
  }
}
