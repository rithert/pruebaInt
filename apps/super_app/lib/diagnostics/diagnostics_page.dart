import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'diagnostics_cubit.dart';

/// Pantalla técnica para la demo y soporte: verifica la cadena completa
/// app → interceptores → BFF y muestra el estado de resiliencia.
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico')),
      body: BlocBuilder<DiagnosticsCubit, DiagnosticsState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Entorno'),
              subtitle: Text('${environment.name} · ${environment.apiBaseUrl}'),
            ),
            _ConnectivityTile(isOnline: state.isOnline),
            _CircuitsTile(circuits: state.circuits),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: state.health == HealthStatus.checking
                  ? null
                  : context.read<DiagnosticsCubit>().checkHealth,
              icon: const Icon(Icons.network_check),
              label: const Text('Probar conexión con el servidor'),
            ),
            const SizedBox(height: AppSpacing.md),
            _HealthResult(state: state),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityTile extends StatelessWidget {
  const _ConnectivityTile({required this.isOnline});

  final bool? isOnline;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (isOnline) {
      true => (Icons.wifi, 'Conectado a una red'),
      false => (Icons.wifi_off, 'Sin red'),
      null => (Icons.help_outline, 'Verificando…'),
    };
    return ListTile(
      leading: Icon(icon),
      title: const Text('Conectividad'),
      subtitle: Text(label),
    );
  }
}

class _CircuitsTile extends StatelessWidget {
  const _CircuitsTile({required this.circuits});

  final Map<String, CircuitState> circuits;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.electrical_services_outlined),
      title: const Text('Circuitos por servicio'),
      subtitle: circuits.isEmpty
          ? const Text('Sin tráfico aún')
          : Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final entry in circuits.entries)
                  Chip(label: Text('${entry.key}: ${_label(entry.value)}')),
              ],
            ),
    );
  }

  static String _label(CircuitState state) => switch (state) {
    CircuitState.closed => 'normal',
    CircuitState.open => 'abierto',
    CircuitState.halfOpen => 'probando',
  };
}

class _HealthResult extends StatelessWidget {
  const _HealthResult({required this.state});

  final DiagnosticsState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state.health) {
      HealthStatus.idle => '',
      HealthStatus.checking => 'Consultando…',
      HealthStatus.healthy => 'Servidor disponible (${state.latencyMs} ms)',
      HealthStatus.failed =>
        '${state.failure?.message} (${state.latencyMs} ms)'
            '${state.failure?.correlationId == null ? '' : '\nCódigo de soporte: ${state.failure!.correlationId}'}',
    };
    // liveRegion: los lectores de pantalla anuncian el resultado al cambiar.
    return Semantics(
      liveRegion: true,
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
