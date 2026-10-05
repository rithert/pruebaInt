import 'package:auth/auth.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Raíz de la aplicación (shell). Aplica tema, router y expone la sesión a
/// toda la app; la lógica de cada dominio vive en su módulo.
class SuperApp extends StatelessWidget {
  const SuperApp({
    required this.router,
    required this.session,
    this.messengerKey,
    this.providers = const [],
    super.key,
  });

  final GoRouter router;
  final SessionCubit session;

  /// Estado global de otros dominios (p. ej. la visibilidad de saldos), que
  /// necesitan tanto las pestañas como las pantallas de detalle.
  final List<BlocProvider> providers;

  /// Permite mostrar avisos globales (p. ej. una notificación recibida con
  /// la app abierta) sin depender de la pantalla actual.
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: session),
        ...providers,
      ],
      child: MaterialApp.router(
        title: 'Super App Financiera',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        scaffoldMessengerKey: messengerKey,
        routerConfig: router,
      ),
    );
  }
}
