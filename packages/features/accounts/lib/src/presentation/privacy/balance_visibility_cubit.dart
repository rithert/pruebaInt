import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Modo privacidad: si los saldos se muestran u ocultan en toda la app.
/// Estado: `true` = saldos ocultos.
///
/// Es un singleton (lo registra `AccountsModule`): el ojo del home y el
/// interruptor del perfil cambian el MISMO estado.
///
/// Especificación completa: test/balance_visibility_cubit_test.dart
/// (`fvm flutter test test/balance_visibility_cubit_test.dart` en
/// packages/features/accounts).
///
/// API del almacenamiento (`CacheStore`):
/// - `_store.read(storageKey)` devuelve `Future<CacheEntry?>`; el valor
///   guardado está en `entry.json` (aquí, un `bool`).
/// - `_store.write(storageKey, valor)` persiste un valor JSON.
/// Ambas pueden lanzar (disco lleno, base corrupta): una preferencia nunca
/// debe romper la app.
class BalanceVisibilityCubit extends Cubit<bool> {
  BalanceVisibilityCubit({required this._store}) : super(false);

  static const storageKey = 'prefs.balance_hidden';

  final CacheStore _store;

  /// Si el usuario ya tocó el ojo, una lectura lenta del disco no debe
  /// deshacer su elección.
  bool _userChose = false;

  /// Lee la preferencia guardada. Se llama una vez al arrancar.
  Future<void> load() async {
    try {
      final entry = await _store.read(storageKey);
      if (_userChose) return;

      if (entry?.json case final bool hidden) {
        emit(hidden);
      }
    } on Object {
      // Una preferencia ilegible no debe romper la app: queda visible.
    }
  }

  /// Muestra u oculta los saldos y recuerda la elección.
  Future<void> toggle() async {
    _userChose = true;
    final nextState = !state;

    // Cambiamos el estado en UI inmediatamente para mantener fluidez
    emit(nextState);

    try {
      await _store.write(storageKey, nextState);
    } on Object {
      // Si falla la escritura en disco, prevenimos romper la app.
    }
  }
}
