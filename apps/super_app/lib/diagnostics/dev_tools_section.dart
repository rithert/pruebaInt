import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dev_tools_cubit.dart';

/// Controles de la demo de resiliencia: degradar servicios del BFF, apagar
/// funcionalidades en caliente y generar movimientos (push).
class DevToolsSection extends StatelessWidget {
  const DevToolsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DevToolsCubit>();

    return BlocBuilder<DevToolsCubit, DevToolsState>(
      builder: (context, state) {
        if (state.loading) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header('Fallas por servicio (chaos)'),
            const Text(
              'Simula caídas parciales, latencia o errores en un servicio '
              'del servidor. El resto de la app debe seguir funcionando.',
            ),
            for (final entry in demoServices.entries)
              _ServiceFaults(service: entry.key, label: entry.value),
            OutlinedButton.icon(
              onPressed: cubit.resetChaos,
              icon: const Icon(Icons.healing),
              label: const Text('Restaurar todos los servicios'),
            ),
            const _Header('Funcionalidades (kill switches)'),
            for (final entry in demoFlags.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: state.flags[entry.key] ?? false,
                onChanged: (value) => cubit.setFlag(entry.key, value),
              ),
            const _Header('Notificaciones'),
            FilledButton.tonalIcon(
              onPressed: cubit.generateMovement,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Generar movimiento (push)'),
            ),
            if (state.message case final message?) ...[
              const SizedBox(height: AppSpacing.md),
              InlineMessage(message, tone: InlineMessageTone.info),
            ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _ServiceFaults extends StatelessWidget {
  const _ServiceFaults({required this.service, required this.label});

  final String service;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DevToolsCubit>();
    final state = context.watch<DevToolsCubit>().state;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final kind in FaultKind.values)
                FilterChip(
                  label: Text(kind.label),
                  selected: state.isOn(service, kind),
                  onSelected: (on) => cubit.toggleFault(service, kind, on),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
