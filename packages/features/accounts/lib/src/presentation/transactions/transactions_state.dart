import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/models.dart';

enum TransactionsStatus {
  /// Aún no se pidió nada.
  initial,

  /// Cargando la primera página (la UI muestra skeleton).
  loading,
  success,

  /// La primera página falló y no hay caché (la UI muestra error + reintentar).
  failure,
}

class TransactionsState extends Equatable {
  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.items = const [],
    this.nextCursor,
    this.category,
    this.isLoadingMore = false,
    this.loadMoreFailure,
    this.cachedAt,
    this.failure,
  });

  final TransactionsStatus status;
  final List<Transaction> items;

  /// Cursor de la siguiente página; `null` = no hay más.
  final String? nextCursor;

  /// Filtro activo; `null` = todas las categorías.
  final String? category;

  /// Cargando la siguiente página (la UI muestra un spinner al final).
  final bool isLoadingMore;

  /// Falló la siguiente página: se conservan los items y se ofrece reintentar.
  final AppFailure? loadMoreFailure;

  /// No es `null` si los items vienen de caché (la UI muestra el banner).
  final DateTime? cachedAt;

  /// Falla de la primera página o de un refresh.
  final AppFailure? failure;

  bool get hasReachedEnd =>
      status == TransactionsStatus.success && nextCursor == null;
  bool get isStale => cachedAt != null;

  /// Los campos anulables reciben una función para poder asignarles `null`
  /// (p. ej. `nextCursor: () => null`).
  TransactionsState copyWith({
    TransactionsStatus? status,
    List<Transaction>? items,
    String? Function()? nextCursor,
    String? Function()? category,
    bool? isLoadingMore,
    AppFailure? Function()? loadMoreFailure,
    DateTime? Function()? cachedAt,
    AppFailure? Function()? failure,
  }) => TransactionsState(
    status: status ?? this.status,
    items: items ?? this.items,
    nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    category: category != null ? category() : this.category,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure != null
        ? loadMoreFailure()
        : this.loadMoreFailure,
    cachedAt: cachedAt != null ? cachedAt() : this.cachedAt,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    nextCursor,
    category,
    isLoadingMore,
    loadMoreFailure,
    cachedAt,
    failure,
  ];
}
