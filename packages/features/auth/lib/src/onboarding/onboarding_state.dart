import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../domain/user_profile.dart';

enum OnboardingStep {
  personalData([OnboardingField.fullName, OnboardingField.email]),
  goal([OnboardingField.goal]),
  credentials([OnboardingField.password, OnboardingField.acceptTerms]);

  const OnboardingStep(this.fields);

  /// Campos que se validan en este paso.
  final List<OnboardingField> fields;

  static const total = 3;

  /// Paso donde vive un campo (para volver a él si el servidor lo rechaza).
  static OnboardingStep of(OnboardingField field) =>
      values.firstWhere((step) => step.fields.contains(field));
}

enum OnboardingField { fullName, email, goal, password, acceptTerms }

enum OnboardingStatus { editing, submitting, failure }

/// Mensajes que no vienen de `Validators` (los usan cubit, UI y tests).
abstract final class OnboardingMessages {
  static const goalRequired = 'Elige un objetivo para continuar.';
  static const termsRequired = 'Debes aceptar los términos y condiciones.';
  static const emailTaken =
      'Ya existe una cuenta con este correo. Inicia sesión o usa otro.';
}

class OnboardingState extends Equatable {
  const OnboardingState({
    this.step = OnboardingStep.personalData,
    this.fullName = '',
    this.email = '',
    this.goal,
    this.password = '',
    this.acceptTerms = false,
    this.fieldErrors = const {},
    this.status = OnboardingStatus.editing,
    this.failure,
  });

  final OnboardingStep step;
  final String fullName;
  final String email;
  final FinancialGoal? goal;
  final String password;
  final bool acceptTerms;

  /// Error a mostrar bajo cada campo; un campo sin entrada es válido.
  final Map<OnboardingField, String> fieldErrors;
  final OnboardingStatus status;

  /// Falla general (sin campo asociado), p. ej. sin conexión.
  final AppFailure? failure;

  int get stepNumber => step.index + 1;
  bool get canGoBack => step != OnboardingStep.personalData;
  bool get isSubmitting => status == OnboardingStatus.submitting;

  /// `goal` y `failure` aceptan una función para poder asignarles `null`.
  OnboardingState copyWith({
    OnboardingStep? step,
    String? fullName,
    String? email,
    FinancialGoal? Function()? goal,
    String? password,
    bool? acceptTerms,
    Map<OnboardingField, String>? fieldErrors,
    OnboardingStatus? status,
    AppFailure? Function()? failure,
  }) => OnboardingState(
    step: step ?? this.step,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    goal: goal != null ? goal() : this.goal,
    password: password ?? this.password,
    acceptTerms: acceptTerms ?? this.acceptTerms,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    status: status ?? this.status,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    step,
    fullName,
    email,
    goal,
    password,
    acceptTerms,
    fieldErrors,
    status,
    failure,
  ];
}
