import 'package:auth/auth.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Raíz de la aplicación (shell). Aplica tema, router y expone la sesión a
/// toda la app; la lógica de cada dominio vive en su módulo.
class SuperApp extends StatelessWidget {
  const SuperApp({required this.router, required this.session, super.key});

  final GoRouter router;
  final SessionCubit session;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: session,
      child: MaterialApp.router(
        title: 'Super App Financiera',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
      ),
    );
  }
}
