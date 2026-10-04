import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../session/session_cubit.dart';
import 'login_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    final endReason = context.select(
      (SessionCubit session) => session.state.endReason,
    );

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<LoginCubit, LoginState>(
          // El cubit borra la contraseña tras un fallo: se refleja en el campo.
          listenWhen: (prev, next) => next.password != _passwordController.text,
          listener: (context, state) => _passwordController.text = state.password,
          builder: (context, state) {
            final submitting = state.status == LoginStatus.submitting;
            return AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Hola de nuevo',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Ingresa para ver tus cuentas y movimientos.'),
                  const SizedBox(height: AppSpacing.lg),
                  if (endReason == SessionEndReason.expired) ...[
                    const InlineMessage(
                      'Tu sesión expiró por seguridad. Ingresa de nuevo.',
                      tone: InlineMessageTone.info,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextFormField(
                    initialValue: state.email,
                    onChanged: cubit.emailChanged,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Correo',
                      errorText: state.emailError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passwordController,
                    onChanged: cubit.passwordChanged,
                    onSubmitted: (_) => cubit.submit(),
                    enabled: !submitting,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      errorText: state.passwordError,
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (state.failure case final failure?) ...[
                    InlineMessage(loginFailureMessage(failure)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  FilledButton(
                    onPressed: submitting ? null : cubit.submit,
                    child: submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Iniciando sesión',
                            ),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => context.go('/onboarding'),
                    child: const Text('¿Eres nuevo? Crea tu cuenta'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
