import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';

/// Componentes genéricos del home que el servidor puede pedir. Cada builder
/// lee sus props de forma defensiva (`SduiProps`).
void registerHomeComponents(SduiRegistry registry) {
  registry
    ..register('greeting', (context, c, actions) => _Greeting(component: c))
    ..register(
      'insight',
      (context, c, actions) => _InsightCard(component: c, actions: actions),
    )
    ..register(
      'quick_actions',
      (context, c, actions) => _QuickActions(component: c, actions: actions),
    )
    ..register(
      'promo_banner',
      (context, c, actions) => _PromoBanner(component: c, actions: actions),
    );
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.component});

  final SduiComponent component;

  @override
  Widget build(BuildContext context) {
    final subtitle = component.props.stringOrNull('subtitle');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            component.props.string('title', fallback: 'Hola'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle),
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.component, required this.actions});

  final SduiComponent component;
  final SduiActions actions;

  @override
  Widget build(BuildContext context) {
    final props = component.props;
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (props.string('tone')) {
      'warning' => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.warning_amber_rounded,
      ),
      'success' => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.trending_up,
      ),
      _ => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.lightbulb_outline,
      ),
    };
    final action = props.mapOrNull('action');
    final route = action?.stringOrNull('route');

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, color: foreground)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    props.string('title'),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    props.string('body'),
                    style: TextStyle(color: foreground),
                  ),
                  if (route != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        actions
                          ..track('tapped', component.id)
                          ..navigate(route);
                      },
                      child: Text(action!.string('label', fallback: 'Ver')),
                    ),
                ],
              ),
            ),
            if (props.boolean('dismissible'))
              IconButton(
                tooltip: 'Descartar',
                color: foreground,
                icon: const Icon(Icons.close),
                onPressed: () => actions.dismiss(component.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.component, required this.actions});

  final SduiComponent component;
  final SduiActions actions;

  static const _icons = <String, IconData>{
    'transfer': Icons.swap_horiz,
    'receipt': Icons.receipt_long_outlined,
    'calculator': Icons.calculate_outlined,
    'support': Icons.support_agent_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final items = component.props
        .listOfMaps('actions')
        .where((a) => a.stringOrNull('route') != null)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              onTap: () {
                actions
                  ..track('tapped', 'quick_actions.${item.string('id')}')
                  ..navigate(item.string('route'));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        _icons[item.string('icon')] ?? Icons.apps,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.string('label'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.component, required this.actions});

  final SduiComponent component;
  final SduiActions actions;

  @override
  Widget build(BuildContext context) {
    final props = component.props;
    final scheme = Theme.of(context).colorScheme;
    final route = props.stringOrNull('route');

    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    props.string('title'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (props.boolean('dismissible'))
                  IconButton(
                    tooltip: 'Descartar',
                    color: scheme.onPrimary,
                    icon: const Icon(Icons.close),
                    onPressed: () => actions.dismiss(component.id),
                  ),
              ],
            ),
            Text(
              props.string('body'),
              style: TextStyle(color: scheme.onPrimary),
            ),
            if (route != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                onPressed: () {
                  actions
                    ..track('tapped', component.id)
                    ..navigate(route);
                },
                child: Text(props.string('cta', fallback: 'Ver más')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
