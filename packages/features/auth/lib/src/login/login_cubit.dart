import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import '../domain/validators.dart';

enum LoginStatus { idle, submitting, failure }

class LoginState extends Equatable {
  const LoginState({
    this.email = '',
    this.password = '',
    this.emailError,
    this.passwordError,
    this.status = LoginStatus.idle,
    this.failure,
  });

  final String email;
  final String password;
  final String? emailError;
  final String? passwordError;
  final LoginStatus status;
  final AppFailure? failure;

  LoginState copyWith({
    String? email,
    String? password,
    String? Function()? emailError,
    String? Function()? passwordError,
    LoginStatus? status,
    AppFailure? Function()? failure,
  }) => LoginState(
    email: email ?? this.email,
    password: password ?? this.password,
    emailError: emailError != null ? emailError() : this.emailError,
    passwordError: passwordError != null ? passwordError() : this.passwordError,
    status: status ?? this.status,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    email,
    password,
    emailError,
    passwordError,
    status,
    failure,
  ];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required this._repository, required this._onSignedIn})
    : super(const LoginState());

  final AuthRepository _repository;
  final void Function(UserProfile user) _onSignedIn;

  void emailChanged(String value) =>
      emit(state.copyWith(email: value, emailError: () => null));

  void passwordChanged(String value) =>
      emit(state.copyWith(password: value, passwordError: () => null));

  Future<void> submit() async {
    if (state.status == LoginStatus.submitting) return;

    final emailError = Validators.email(state.email);
    final passwordError = Validators.requiredField(state.password);
    if (emailError != null || passwordError != null) {
      emit(
        state.copyWith(
          emailError: () => emailError,
          passwordError: () => passwordError,
        ),
      );
      return;
    }

    emit(state.copyWith(status: LoginStatus.submitting, failure: () => null));
    final result = await _repository.login(
      email: state.email,
      password: state.password,
    );
    switch (result) {
      case Success(:final value):
        _onSignedIn(value);
      case Failure(:final failure):
        // Por seguridad la contraseña se borra tras un intento fallido.
        emit(
          state.copyWith(
            status: LoginStatus.failure,
            failure: () => failure,
            password: '',
          ),
        );
    }
  }
}

/// Mensaje para el usuario según la falla del login.
String loginFailureMessage(AppFailure failure) => switch (failure) {
  UnauthorizedFailure(code: 'invalid_credentials') =>
    'Correo o contraseña incorrectos.',
  BusinessFailure(code: 'rate_limited') =>
    'Demasiados intentos. Espera un minuto e intenta de nuevo.',
  _ => failure.message,
};
