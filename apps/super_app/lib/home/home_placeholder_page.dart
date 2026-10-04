import 'package:auth/auth.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// Home provisional hasta F4/F5 (cuentas + experiencia personalizada).
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((SessionCubit cubit) => cubit.state.user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Diagnóstico',
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () => context.push(AppRoutes.diagnostics),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: context.read<SessionCubit>().logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Hola, ${user?.firstName ?? ''}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (user != null)
            Text('Tu objetivo: ${user.goal.title} · segmento ${user.segment}'),
        ],
      ),
    );
  }
}
