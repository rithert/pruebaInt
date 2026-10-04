import 'dart:async';

import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sdui/sdui.dart';

import '../data/event_tracker.dart';
import '../data/home_repository.dart';

class HomeState extends Equatable {
  const HomeState({
    this.resource = const Resource(isRefreshing: true),
    this.dismissed = const {},
  });

  final Resource<SduiLayout> resource;

  /// Descartados en esta sesión: se ocultan al instante, sin esperar a que
  /// el servidor procese el evento.
  final Set<String> dismissed;

  /// El servicio de experiencia no respondió y no hay caché: se usa el
  /// layout embebido.
  bool get isFallback => resource.data == null && !resource.isRefreshing;

  SduiLayout? get layout {
    final base =
        resource.data ?? (resource.isRefreshing ? null : fallbackHomeLayout);
    if (base == null) return null;
    return base.copyWith(
      components: [
        for (final c in base.components)
          if (!dismissed.contains(c.id)) c,
      ],
    );
  }

  HomeState copyWith({
    Resource<SduiLayout>? resource,
    Set<String>? dismissed,
  }) => HomeState(
    resource: resource ?? this.resource,
    dismissed: dismissed ?? this.dismissed,
  );

  @override
  List<Object?> get props => [
    resource.data?.layoutId,
    resource.data?.components.map((c) => c.id).join(','),
    resource.updatedAt,
    resource.isRefreshing,
    resource.failure,
    dismissed,
  ];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this._repository,
    required this._tracker,
    required ConnectivityMonitor connectivity,
  }) : super(const HomeState()) {
    _connectivitySub = connectivity.onStatusChange.listen((online) {
      if (online && state.resource.failure != null) unawaited(refresh());
    });
  }

  final HomeRepository _repository;
  final EventTracker _tracker;
  late final StreamSubscription<bool> _connectivitySub;
  StreamSubscription<Resource<SduiLayout>>? _homeSub;

  Future<void> refresh() async {
    await _homeSub?.cancel();
    final done = Completer<void>();
    _homeSub = _repository.watchHome().listen((resource) {
      // En un reintento se conserva lo que ya se veía (sin parpadeo).
      final keep =
          resource.isRefreshing && !resource.hasData && state.resource.hasData;
      emit(
        state.copyWith(
          resource: keep
              ? Resource(
                  data: state.resource.data,
                  updatedAt: state.resource.updatedAt,
                  isRefreshing: true,
                )
              : resource,
        ),
      );
    }, onDone: done.complete);
    return done.future;
  }

  void tapped(String componentId) => _tracker.track('tapped', componentId);

  void dismiss(String componentId) {
    emit(state.copyWith(dismissed: {...state.dismissed, componentId}));
    _tracker.track('dismissed', componentId);
  }

  @override
  Future<void> close() async {
    await _connectivitySub.cancel();
    await _homeSub?.cancel();
    unawaited(_tracker.flush());
    return super.close();
  }
}
