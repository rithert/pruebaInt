import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Raíz de la aplicación (shell). Compone los módulos de dominio; en F2 se
/// incorporan router, inyección de dependencias y observabilidad.
class SuperApp extends StatelessWidget {
  const SuperApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super App Financiera',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(body: Center(child: Text('Entorno: ${environment.name}'))),
    );
  }
}
