import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/accounts_repository.dart';
import '../../domain/models.dart';

/// Cuentas y saldos del cliente. El estado es directamente el `Resource` del
/// stale-while-revalidate: datos (quizá de caché) + si se está actualizando
/// + la falla de la última actualización.
///
/// Al recuperar la conexión se actualiza solo: el usuario no tiene que
/// adivinar que debe tocar "Reintentar".
class AccountsCubit extends Cubit<Resource<AccountsOverview>> {
  AccountsCubit({
    required this._repository,
    required ConnectivityMonitor connectivity,
  }) : super(const Resource(isRefreshing: true)) {
    _connectivitySub = connectivity.onStatusChange.listen((online) {
      if (online && state.failure != null) unawaited(refresh());
    });
  }

  final AccountsRepository _repository;
  late final StreamSubscription<bool> _connectivitySub;
  StreamSubscription<Resource<AccountsOverview>>? _overviewSub;

  Future<void> refresh() async {
    await _overviewSub?.cancel();
    final done = Completer<void>();
    _overviewSub = _repository.watchOverview().listen(
      (resource) {
        // Mientras se actualiza, se conserva lo que ya se mostraba si la
        // caché está vacía (evita parpadear a skeleton en un reintento).
        if (resource.isRefreshing && !resource.hasData && state.hasData) {
          emit(
            Resource(
              data: state.data,
              updatedAt: state.updatedAt,
              isRefreshing: true,
            ),
          );
        } else {
          emit(resource);
        }
      },
      onDone: done.complete,
    );
    return done.future;
  }

  @override
  Future<void> close() async {
    await _connectivitySub.cancel();
    await _overviewSub?.cancel();
    return super.close();
  }
}
