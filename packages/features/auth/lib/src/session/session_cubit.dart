import 'dart:async';

import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import 'biometric_authenticator.dart';

enum SessionStatus {
  /// Arrancando: todavía no se sabe si hay sesión.
  unknown,
  unauthenticated,

  /// Hay sesión guardada, pero se exige biometría para entrar.
  locked,
  authenticated,
}

/// Por qué terminó la última sesión (para informar al usuario).
enum SessionEndReason { none, logout, expired }

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.endReason = SessionEndReason.none,
  });

  final SessionStatus status;
  final UserProfile? user;
  final SessionEndReason endReason;

  @override
  List<Object?> get props => [status, user, endReason];
}

/// Fuente de verdad del estado de la sesión en toda la app. El router
/// redirige según [SessionState.status]; ninguna pantalla navega por su
/// cuenta al login.
///
/// ```
/// unknown ──restore──► unauthenticated ──signedIn──► authenticated
///    │                      ▲                            │
///    └──(sesión + huella)──►locked ──unlock──────────────┘
///                           │  ▲                         │
///                usePassword└──┴──────logout / expired───┘
/// ```
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required this._repository,
    required this._biometrics,
    required this._telemetry,
    required SessionEvents sessionEvents,
  }) : super(const SessionState()) {
    _expiredSub = sessionEvents.onExpired.listen((_) => _onExpired());
  }

  final AuthRepository _repository;
  final BiometricAuthenticator _biometrics;
  final Telemetry _telemetry;
  late final StreamSubscription<void> _expiredSub;

  /// Al abrir la app: decide si hay sesión y si debe bloquearse.
  Future<void> restore() async {
    if (!await _repository.hasStoredSession()) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
      return;
    }
    final user = await _repository.cachedProfile();
    final status = await _biometrics.isAvailable()
        ? SessionStatus.locked
        : SessionStatus.authenticated;
    emit(SessionState(status: status, user: user));
    if (status == SessionStatus.authenticated) unawaited(_refreshProfile());
  }

  Future<void> unlock() async {
    if (state.status != SessionStatus.locked) return;
    final ok = await _biometrics.authenticate(
      reason: 'Confirma tu identidad para entrar',
    );
    _telemetry.logEvent('biometric_unlock', {'success': ok});
    if (!ok) return;
    emit(SessionState(status: SessionStatus.authenticated, user: state.user));
    unawaited(_refreshProfile());
  }

  /// Llamado por login y onboarding cuando el BFF abrió la sesión.
  void signedIn(UserProfile user) {
    _telemetry
      ..setUserId(user.id)
      ..logEvent('session_started', {'segment': user.segment});
    emit(SessionState(status: SessionStatus.authenticated, user: user));
  }

  /// Desde el bloqueo, el usuario prefiere entrar con su contraseña.
  Future<void> usePassword() => _end(SessionEndReason.none);

  Future<void> logout() => _end(SessionEndReason.logout);

  Future<void> _onExpired() async {
    if (state.status == SessionStatus.unauthenticated) return;
    _telemetry.logEvent('session_expired');
    await _end(SessionEndReason.expired);
  }

  Future<void> _end(SessionEndReason reason) async {
    await _repository.logout();
    _telemetry.setUserId(null);
    emit(
      SessionState(status: SessionStatus.unauthenticated, endReason: reason),
    );
  }

  Future<void> _refreshProfile() async {
    final result = await _repository.fetchProfile();
    if (result case Success(:final value) when !isClosed) {
      if (state.status == SessionStatus.authenticated) {
        emit(SessionState(status: SessionStatus.authenticated, user: value));
      }
    }
  }

  @override
  Future<void> close() async {
    await _expiredSub.cancel();
    return super.close();
  }
}
