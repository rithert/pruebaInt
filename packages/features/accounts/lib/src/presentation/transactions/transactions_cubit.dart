// TEMPORAL: los campos se usan al implementar los métodos. Quitar esta línea
// junto con la implementación.
// ignore_for_file: unused_field

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/accounts_repository.dart';
import 'transactions_state.dart';

/// Movimientos de una cuenta con paginación por cursor.
///
/// Especificación completa: test/transactions_cubit_test.dart
/// (`fvm flutter test test/transactions_cubit_test.dart` en
/// packages/features/accounts).
///
/// API del repositorio:
/// `_repository.transactions(_accountId, cursor: ..., category: ...)`
/// devuelve `Result<TransactionPage>` con `items`, `nextCursor` y `cachedAt`.
class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({required this._repository, required this._accountId})
    : super(const TransactionsState());

  final AccountsRepository _repository;
  final String _accountId;

  /// Primera página con el filtro actual (`state.category`).
  /// 1. Emite `loading` (sin items, conservando la categoría).
  /// 2. `Success` → `success` con items, `nextCursor` y `cachedAt` de la página.
  ///    `Failure` → `failure` con la falla.
  /// En ambos casos, los errores y marcas anteriores quedan limpios.
  Future<void> load() async {
    throw UnimplementedError('TODO: load');
  }

  /// Pull-to-refresh: pide la primera página SIN emitir `loading` (la lista
  /// sigue visible mientras tanto).
  /// - `Success` → reemplaza items, cursor y `cachedAt`.
  /// - `Failure` → conserva todo y solo asigna `failure`.
  Future<void> refresh() async {
    throw UnimplementedError('TODO: refresh');
  }

  /// Siguiente página. Solo si `status == success`, hay `nextCursor` y no hay
  /// otra carga en curso (`isLoadingMore`).
  /// 1. Emite `isLoadingMore: true` y limpia `loadMoreFailure`.
  /// 2. `Success` → agrega los items al final y actualiza `nextCursor`.
  ///    `Failure` → conserva los items y asigna `loadMoreFailure`.
  Future<void> loadMore() async {
    throw UnimplementedError('TODO: loadMore');
  }

  /// Cambia el filtro (`null` = todas). Si es el mismo, no hace nada.
  /// Si no: emite `loading` con la nueva categoría y sin items, y carga.
  ///
  /// Ojo con las carreras: si el filtro cambia mientras una petición está en
  /// curso, al llegar su respuesta `state.category` ya es otra y esa
  /// respuesta debe descartarse (aplica a load, refresh y loadMore).
  Future<void> categorySelected(String? category) async {
    throw UnimplementedError('TODO: categorySelected');
  }
}
