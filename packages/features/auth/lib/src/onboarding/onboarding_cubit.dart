import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import '../domain/validators.dart';
import 'onboarding_state.dart';

/// Lógica del wizard de registro.
///
/// Especificación completa: test/onboarding_cubit_test.dart
/// (`fvm flutter test test/onboarding_cubit_test.dart` en packages/features/auth).
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required this._repository, required this._onRegistered})
    : super(const OnboardingState());

  final AuthRepository _repository;

  /// Se invoca con el perfil cuando el registro fue exitoso (abre la sesión).
  final void Function(UserProfile user) _onRegistered;

  // ---------------------------------------------------------------------
  // Edición de campos: actualizan el valor y borran SOLO el error de ese
  // campo (los demás errores se conservan).
  // ---------------------------------------------------------------------

  void fullNameChanged(String value) {
    final updatedErrors = Map<OnboardingField, String>.from(state.fieldErrors)
      ..remove(OnboardingField.fullName);

    emit(state.copyWith(fullName: value, fieldErrors: updatedErrors));
  }

  void emailChanged(String value) {
    final updatedErrors = Map<OnboardingField, String>.from(state.fieldErrors)
      ..remove(OnboardingField.email);

    emit(state.copyWith(email: value, fieldErrors: updatedErrors));
  }

  void goalSelected(FinancialGoal goal) {
    final updatedErrors = Map<OnboardingField, String>.from(state.fieldErrors)
      ..remove(OnboardingField.goal);

    emit(state.copyWith(goal: () => goal, fieldErrors: updatedErrors));
  }

  void passwordChanged(String value) {
    final updatedErrors = Map<OnboardingField, String>.from(state.fieldErrors)
      ..remove(OnboardingField.password);

    emit(state.copyWith(password: value, fieldErrors: updatedErrors));
  }

  void acceptTermsChanged(bool value) {
    final updatedErrors = Map<OnboardingField, String>.from(state.fieldErrors)
      ..remove(OnboardingField.acceptTerms);

    emit(state.copyWith(acceptTerms: value, fieldErrors: updatedErrors));
  }

  // ---------------------------------------------------------------------
  // Navegación
  // ---------------------------------------------------------------------

  /// Valida un campo individual de onboarding.
  String? _validateField(OnboardingField field) {
    switch (field) {
      case OnboardingField.fullName:
        return Validators.fullName(state.fullName);
      case OnboardingField.email:
        return Validators.email(state.email);
      case OnboardingField.goal:
        return state.goal == null ? OnboardingMessages.goalRequired : null;
      case OnboardingField.password:
        return Validators.password(state.password);
      case OnboardingField.acceptTerms:
        return !state.acceptTerms ? OnboardingMessages.termsRequired : null;
    }
  }

  /// Valida una lista de campos y devuelve un mapa con los errores encontrados.
  Map<OnboardingField, String> _validateFields(List<OnboardingField> fields) {
    final errors = <OnboardingField, String>{};
    for (final field in fields) {
      final error = _validateField(field);
      if (error != null) {
        errors[field] = error;
      }
    }
    return errors;
  }

  /// Valida los campos del paso actual (`state.step.fields`).
  /// - Con errores: los emite en `fieldErrors` y NO avanza.
  /// - Sin errores: avanza al siguiente paso con `fieldErrors` vacío.
  /// - En el último paso no hace nada (ahí se usa [submit]).
  void next() {
    if (state.step == OnboardingStep.credentials) {
      return;
    }

    final errors = _validateFields(state.step.fields);

    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors));
      return;
    }

    emit(
      state.copyWith(
        step: OnboardingStep.values[state.step.index + 1],
        fieldErrors: const {},
      ),
    );
  }

  /// Retrocede un paso conservando los datos (limpia `fieldErrors`).
  /// En el primer paso no hace nada.
  void back() {
    if (state.step == OnboardingStep.personalData) {
      return;
    }

    emit(
      state.copyWith(
        step: OnboardingStep.values[state.step.index - 1],
        fieldErrors: const {},
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Envío
  // ---------------------------------------------------------------------

  /// Solo en el paso `credentials` y si no se está enviando ya:
  /// 1. Valida contraseña y términos; con errores los emite y no llama al BFF.
  /// 2. Emite `submitting` (y limpia una `failure` anterior).
  /// 3. Llama a `_repository.register(RegistrationData(...))`.
  /// 4. Según el resultado:
  ///    - `Success` → `_onRegistered(user)`
  ///    - `BusinessFailure` con code `email_taken` → vuelve a `personalData`,
  ///      status `editing`, error `OnboardingMessages.emailTaken` en email.
  ///    - `ValidationFailure` cuyas claves coinciden con nombres de
  ///      `OnboardingField` → esos errores, status `editing` y salta al paso
  ///      del primer campo con error.
  ///    - Cualquier otra → status `failure` con la `failure`.
  Future<void> submit() async {
    if (state.step != OnboardingStep.credentials || state.isSubmitting) {
      return;
    }

    final errors = _validateFields(state.step.fields);
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors));
      return;
    }

    emit(
      state.copyWith(status: OnboardingStatus.submitting, failure: () => null),
    );

    final registrationData = RegistrationData(
      fullName: state.fullName,
      email: state.email,
      goal: state.goal!,
      password: state.password,
    );

    final result = await _repository.register(registrationData);

    switch (result) {
      case Success(:final value):
        _onRegistered(value);

      case Failure(failure: BusinessFailure(code: 'email_taken')):
        emit(
          state.copyWith(
            step: OnboardingStep.personalData,
            status: OnboardingStatus.editing,
            fieldErrors: {OnboardingField.email: OnboardingMessages.emailTaken},
          ),
        );

      case Failure(failure: final ValidationFailure validationFailure):
        final parsedErrors = <OnboardingField, String>{};
        OnboardingStep? firstStepWithError;

        for (final entry in validationFailure.fieldErrors.entries) {
          final matchedField = OnboardingField.values
              .where((f) => f.name == entry.key)
              .firstOrNull;

          if (matchedField != null) {
            parsedErrors[matchedField] = entry.value;
            firstStepWithError ??= OnboardingStep.of(matchedField);
          }
        }

        if (parsedErrors.isNotEmpty) {
          emit(
            state.copyWith(
              step: firstStepWithError ?? state.step,
              status: OnboardingStatus.editing,
              fieldErrors: parsedErrors,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: OnboardingStatus.failure,
              failure: () => validationFailure,
            ),
          );
        }

      case Failure(:final failure):
        emit(
          state.copyWith(
            status: OnboardingStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }
}
