// TEMPORAL: los campos se usan al implementar submit(). Quitar esta línea
// junto con la implementación.
// ignore_for_file: unused_field

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import 'onboarding_state.dart';

/// Lógica del wizard de registro.
///
/// Especificación completa: test/onboarding_cubit_test.dart
/// (`fvm flutter test test/onboarding_cubit_test.dart` en packages/features/auth).
///
/// Piezas disponibles:
/// - `Validators` (domain/validators.dart): fullName, email, password.
/// - `OnboardingMessages` (onboarding_state.dart): goalRequired,
///   termsRequired, emailTaken.
/// - `OnboardingStep.fields` y `OnboardingStep.of(campo)`.
/// - `state.copyWith(...)`: `goal` y `failure` reciben una función para
///   poder asignar `null` (p. ej. `failure: () => null`).
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
    throw UnimplementedError('TODO: fullNameChanged');
  }

  void emailChanged(String value) {
    throw UnimplementedError('TODO: emailChanged');
  }

  void goalSelected(FinancialGoal goal) {
    throw UnimplementedError('TODO: goalSelected');
  }

  void passwordChanged(String value) {
    throw UnimplementedError('TODO: passwordChanged');
  }

  void acceptTermsChanged(bool value) {
    throw UnimplementedError('TODO: acceptTermsChanged');
  }

  // ---------------------------------------------------------------------
  // Navegación
  // ---------------------------------------------------------------------

  /// Valida los campos del paso actual (`state.step.fields`).
  /// - Con errores: los emite en `fieldErrors` y NO avanza.
  /// - Sin errores: avanza al siguiente paso con `fieldErrors` vacío.
  /// - En el último paso no hace nada (ahí se usa [submit]).
  void next() {
    throw UnimplementedError('TODO: next');
  }

  /// Retrocede un paso conservando los datos (limpia `fieldErrors`).
  /// En el primer paso no hace nada.
  void back() {
    throw UnimplementedError('TODO: back');
  }

  // ---------------------------------------------------------------------
  // Envío
  // ---------------------------------------------------------------------

  /// Solo en el paso `credentials` y si no se está enviando ya:
  /// 1. Valida contraseña y términos; con errores los emite y no llama al BFF.
  /// 2. Emite `submitting` (y limpia una `failure` anterior).
  /// 3. Llama a `_repository.register(RegistrationData(...))`.
  /// 4. Según el resultado:
  ///    - `Success` → `_onRegistered(user)` (el estado queda en submitting;
  ///      el router navega al home).
  ///    - `BusinessFailure` con code `email_taken` → vuelve a `personalData`,
  ///      status `editing`, error `OnboardingMessages.emailTaken` en email.
  ///    - `ValidationFailure` cuyas claves coinciden con nombres de
  ///      `OnboardingField` (p. ej. 'password') → esos errores, status
  ///      `editing` y salta al paso del primer campo con error.
  ///    - Cualquier otra → status `failure` con la `failure` (se conservan
  ///      paso y datos).
  Future<void> submit() async {
    throw UnimplementedError('TODO: submit');
  }
}
