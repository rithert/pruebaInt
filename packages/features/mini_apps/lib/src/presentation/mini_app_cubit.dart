import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mini_apps_repository.dart';

enum MiniAppStatus {
  /// Pidiendo el token delegado.
  authorizing,

  /// Token listo: la mini app puede cargarse.
  ready,

  /// Apagada por el servidor (feature flag): no se carga.
  unavailable,

  /// No se pudo autorizar (red, servicio caído).
  failure,
}

class MiniAppState extends Equatable {
  const MiniAppState({
    this.status = MiniAppStatus.authorizing,
    this.token,
    this.failure,
  });

  final MiniAppStatus status;
  final DelegatedToken? token;
  final AppFailure? failure;

  @override
  List<Object?> get props => [status, token?.token, failure];
}

class MiniAppCubit extends Cubit<MiniAppState> {
  MiniAppCubit({
    required this._repository,
    required this.appId,
    required this._telemetry,
  }) : super(const MiniAppState());

  final MiniAppsRepository _repository;
  final Telemetry _telemetry;
  final String appId;

  /// Pide (o renueva) el token delegado.
  Future<void> authorize() async {
    if (state.status != MiniAppStatus.ready) {
      emit(const MiniAppState());
    }
    switch (await _repository.issueToken(appId)) {
      case Success(:final value):
        emit(MiniAppState(status: MiniAppStatus.ready, token: value));
      case Failure(failure: BusinessFailure(code: 'mini_app_disabled')):
        emit(const MiniAppState(status: MiniAppStatus.unavailable));
      case Failure(:final failure):
        emit(MiniAppState(status: MiniAppStatus.failure, failure: failure));
    }
  }

  /// Solicitud confirmada por el usuario en la app nativa.
  Future<Result<String>> requestCredit({
    required int amountMinor,
    required int termMonths,
  }) async {
    final result = await _repository.requestCredit(
      amountMinor: amountMinor,
      termMonths: termMonths,
    );
    _telemetry.logEvent('mini_app_credit_requested', {
      'appId': appId,
      'success': result is Success,
    });
    return result;
  }

  void bridgeMessageRejected() =>
      _telemetry.logEvent('mini_app_message_rejected', {'appId': appId});
}
