import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/user_profile.dart';
import 'onboarding_cubit.dart';
import 'onboarding_state.dart';

/// Wizard de registro en 3 pasos. Toda la lógica vive en [OnboardingCubit];
/// esta pantalla solo refleja su estado y le delega los eventos.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) => PopScope(
        // El botón atrás del sistema retrocede un paso antes de salir.
        canPop: !state.canGoBack,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) cubit.back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: state.canGoBack ? 'Paso anterior' : 'Volver al inicio',
              icon: const Icon(Icons.arrow_back),
              onPressed: state.isSubmitting
                  ? null
                  : state.canGoBack
                  ? cubit.back
                  : () => context.go('/login'),
            ),
            title: const Text('Crear cuenta'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: Semantics(
                label:
                    'Paso ${state.stepNumber} de ${OnboardingStep.total}',
                child: LinearProgressIndicator(
                  value: state.stepNumber / OnboardingStep.total,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (state.step) {
                    OnboardingStep.personalData => _PersonalDataStep(
                      key: const ValueKey('personal'),
                      state: state,
                    ),
                    OnboardingStep.goal => _GoalStep(
                      key: const ValueKey('goal'),
                      state: state,
                    ),
                    OnboardingStep.credentials => _CredentialsStep(
                      key: const ValueKey('credentials'),
                      state: state,
                    ),
                  },
                ),
                if (state.failure case final failure?) ...[
                  const SizedBox(height: AppSpacing.md),
                  InlineMessage(failure.message),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: state.isSubmitting
                      ? null
                      : state.step == OnboardingStep.credentials
                      ? cubit.submit
                      : cubit.next,
                  child: state.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Creando tu cuenta',
                          ),
                        )
                      : Text(
                          state.step == OnboardingStep.credentials
                              ? 'Crear cuenta'
                              : 'Continuar',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _PersonalDataStep extends StatelessWidget {
  const _PersonalDataStep({required this.state, super.key});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeader(
            title: 'Cuéntanos de ti',
            subtitle: 'Abrir tu cuenta toma menos de un minuto.',
          ),
          TextFormField(
            initialValue: state.fullName,
            onChanged: cubit.fullNameChanged,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: 'Nombre completo',
              errorText: state.fieldErrors[OnboardingField.fullName],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: state.email,
            onChanged: cubit.emailChanged,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Correo',
              errorText: state.fieldErrors[OnboardingField.email],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.state, super.key});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final error = state.fieldErrors[OnboardingField.goal];
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: '¿Cuál es tu objetivo?',
          subtitle: 'Adaptaremos tu experiencia a lo que quieres lograr.',
        ),
        for (final goal in FinancialGoal.values) ...[
          Semantics(
            inMutuallyExclusiveGroup: true,
            selected: state.goal == goal,
            child: Card(
              color: state.goal == goal ? scheme.primaryContainer : null,
              child: ListTile(
                leading: Icon(_iconFor(goal)),
                title: Text(goal.title),
                subtitle: Text(goal.description),
                trailing: state.goal == goal
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () => cubit.goalSelected(goal),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (error != null) InlineMessage(error),
      ],
    );
  }

  static IconData _iconFor(FinancialGoal goal) => switch (goal) {
    FinancialGoal.save => Icons.savings_outlined,
    FinancialGoal.invest => Icons.trending_up,
    FinancialGoal.growBusiness => Icons.storefront_outlined,
  };
}

class _CredentialsStep extends StatefulWidget {
  const _CredentialsStep({required this.state, super.key});

  final OnboardingState state;

  @override
  State<_CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends State<_CredentialsStep> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = widget.state;
    final termsError = state.fieldErrors[OnboardingField.acceptTerms];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'Crea tu acceso',
          subtitle: 'Usarás tu correo y esta contraseña para ingresar.',
        ),
        TextFormField(
          initialValue: state.password,
          onChanged: cubit.passwordChanged,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Contraseña',
            helperText: 'Mínimo 8 caracteres, con letras y números.',
            errorText: state.fieldErrors[OnboardingField.password],
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          value: state.acceptTerms,
          onChanged: (value) => cubit.acceptTermsChanged(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Acepto los términos y condiciones'),
          subtitle: termsError == null
              ? null
              : Text(
                  termsError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
        ),
      ],
    );
  }
}
