import 'dart:async';

import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum HealthStatus { idle, checking, healthy, failed }

class DiagnosticsState extends Equatable {
  const DiagnosticsState({
    this.isOnline,
    this.circuits = const {},
    this.health = HealthStatus.idle,
    this.latencyMs,
    this.failure,
  });

  /// `null` mientras no se conoce el estado de la red.
  final bool? isOnline;
  final Map<String, CircuitState> circuits;
  final HealthStatus health;
  final int? latencyMs;
  final AppFailure? failure;

  DiagnosticsState copyWith({
    bool? isOnline,
    Map<String, CircuitState>? circuits,
    HealthStatus? health,
    int? latencyMs,
    AppFailure? failure,
  }) => DiagnosticsState(
    isOnline: isOnline ?? this.isOnline,
    circuits: circuits ?? this.circuits,
    health: health ?? this.health,
    latencyMs: latencyMs ?? this.latencyMs,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [isOnline, circuits, health, latencyMs, failure];
}

/// Muestra el estado de la infraestructura del cliente: conectividad,
/// circuitos por servicio y una prueba real contra el BFF a través de toda
/// la cadena de interceptores.
class DiagnosticsCubit extends Cubit<DiagnosticsState> {
  DiagnosticsCubit({
    required this._api,
    required this._connectivity,
    required CircuitBreaker circuitBreaker,
  }) : _breaker = circuitBreaker,
       super(const DiagnosticsState());

  final ApiClient _api;
  final ConnectivityMonitor _connectivity;
  final CircuitBreaker _breaker;
  StreamSubscription<bool>? _connectivitySub;

  Future<void> start() async {
    _breaker.addListener(_onCircuitsChanged);
    _connectivitySub = _connectivity.onStatusChange.listen(
      (online) => emit(state.copyWith(isOnline: online)),
    );
    emit(
      state.copyWith(
        isOnline: await _connectivity.isOnline,
        circuits: _breaker.snapshot,
      ),
    );
  }

  Future<void> checkHealth() async {
    emit(
      DiagnosticsState(
        isOnline: state.isOnline,
        circuits: state.circuits,
        health: HealthStatus.checking,
      ),
    );
    final stopwatch = Stopwatch()..start();
    final result = await _api.get('/health', decode: (json) => json);
    stopwatch.stop();

    emit(switch (result) {
      Success() => DiagnosticsState(
        isOnline: state.isOnline,
        circuits: _breaker.snapshot,
        health: HealthStatus.healthy,
        latencyMs: stopwatch.elapsedMilliseconds,
      ),
      Failure(:final failure) => DiagnosticsState(
        isOnline: state.isOnline,
        circuits: _breaker.snapshot,
        health: HealthStatus.failed,
        latencyMs: stopwatch.elapsedMilliseconds,
        failure: failure,
      ),
    });
  }

  void _onCircuitsChanged() =>
      emit(state.copyWith(circuits: _breaker.snapshot));

  @override
  Future<void> close() async {
    _breaker.removeListener(_onCircuitsChanged);
    await _connectivitySub?.cancel();
    return super.close();
  }
}
