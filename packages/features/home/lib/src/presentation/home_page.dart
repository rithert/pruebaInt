import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sdui/sdui.dart';

import 'home_cubit.dart';

/// Home dirigido por el servidor. La página no sabe qué va a mostrar: dibuja
/// el layout del BFF con el catálogo de componentes registrado.
class HomePage extends StatelessWidget {
  const HomePage({
    required this.registry,
    required this.telemetry,
    this.appBarActions = const [],
    super.key,
  });

  final SduiRegistry registry;
  final Telemetry telemetry;

  /// Acciones de la barra que aporta el shell (diagnóstico, cerrar sesión).
  final List<Widget> appBarActions;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio'), actions: appBarActions),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final layout = state.layout;
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (state.isFallback) ...[
                  InlineMessage(
                    'Te mostramos una versión básica del inicio mientras '
                    'recuperamos tu experiencia personalizada.',
                    tone: InlineMessageTone.info,
                    action: TextButton(
                      onPressed: cubit.refresh,
                      child: const Text('Reintentar'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (layout == null)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Cargando tu inicio',
                      ),
                    ),
                  )
                else
                  SduiView(
                    layout: layout,
                    registry: registry,
                    actions: _PageActions(context, cubit),
                    onComponentError: (component, error) =>
                        telemetry.recordError(
                          error,
                          null,
                          reason: 'sdui_component_${component.type}',
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PageActions implements SduiActions {
  _PageActions(this._context, this._cubit);

  final BuildContext _context;
  final HomeCubit _cubit;

  /// Solo rutas internas: el servidor no puede abrir URLs arbitrarias.
  @override
  void navigate(String route) {
    if (!route.startsWith('/') || route.startsWith('//')) return;
    _context.push(route);
  }

  @override
  void track(String type, String componentId) {
    if (type == 'tapped') _cubit.tapped(componentId);
  }

  @override
  void dismiss(String componentId) => _cubit.dismiss(componentId);
}
