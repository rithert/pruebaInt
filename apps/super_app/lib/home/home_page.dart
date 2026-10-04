import 'package:accounts/accounts.dart';
import 'package:auth/auth.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// Home del cliente. En F5 su contenido pasa a definirlo el servidor
/// (experiencia personalizada); por ahora compone las secciones fijas.
class HomePage extends StatelessWidget {
  const HomePage({required this.di, super.key});

  final GetIt di;

  @override
  Widget build(BuildContext context) {
    final user = context.select((SessionCubit cubit) => cubit.state.user);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${user?.firstName ?? ''}'),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [AccountsModule.overview(di)],
      ),
    );
  }
}
