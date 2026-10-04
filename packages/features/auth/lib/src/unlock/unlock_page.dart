import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../session/session_cubit.dart';

/// Pantalla de bloqueo cuando hay una sesión guardada. Pide la huella al
/// abrirse y ofrece entrar con contraseña como alternativa.
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SessionCubit>().unlock(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionCubit>();
    final name = context.select(
      (SessionCubit cubit) => cubit.state.user?.firstName,
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: AppSpacing.lg),
              Text(
                name == null ? 'Hola' : 'Hola, $name',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Tu sesión está protegida. Confirma tu identidad para continuar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: session.unlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Desbloquear con huella'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: session.usePassword,
                child: const Text('Ingresar con mi contraseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
