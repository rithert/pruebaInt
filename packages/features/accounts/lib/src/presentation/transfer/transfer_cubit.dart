import 'dart:async';

import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/accounts_repository.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';

enum TransferField { from, to, amount }

enum TransferStatus { loadingAccounts, editing, submitting, success, failure }

class TransferState extends Equatable {
  const TransferState({
    required this.idempotencyKey,
    this.status = TransferStatus.loadingAccounts,
    this.accounts = const [],
    this.fromId,
    this.toId,
    this.amountMinor = 0,
    this.fieldErrors = const {},
    this.failure,
    this.receipt,
    this.connectionRestored = false,
  });

  /// Identifica ESTE intento de transferencia. Se conserva entre reintentos
  /// (el BFF no duplica) y se renueva si el usuario cambia algún dato.
  final String idempotencyKey;
  final TransferStatus status;
  final List<Account> accounts;
  final String? fromId;
  final String? toId;

  /// Monto en centavos.
  final int amountMinor;
  final Map<TransferField, String> fieldErrors;
  final AppFailure? failure;
  final TransferReceipt? receipt;

  /// La red volvió después de un fallo: la UI invita a reintentar en lugar
  /// de seguir mostrando "sin conexión".
  final bool connectionRestored;

  Account? get from => accounts.where((a) => a.id == fromId).firstOrNull;

  TransferState copyWith({
    String? idempotencyKey,
    TransferStatus? status,
    List<Account>? accounts,
    String? fromId,
    String? toId,
    int? amountMinor,
    Map<TransferField, String>? fieldErrors,
    AppFailure? Function()? failure,
    TransferReceipt? receipt,
    bool? connectionRestored,
  }) => TransferState(
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    status: status ?? this.status,
    accounts: accounts ?? this.accounts,
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    amountMinor: amountMinor ?? this.amountMinor,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    failure: failure != null ? failure() : this.failure,
    receipt: receipt ?? this.receipt,
    connectionRestored: connectionRestored ?? this.connectionRestored,
  );

  @override
  List<Object?> get props => [
    idempotencyKey,
    status,
    accounts,
    fromId,
    toId,
    amountMinor,
    fieldErrors,
    failure,
    receipt,
    connectionRestored,
  ];
}

/// Transferencia entre cuentas propias.
///
/// La clave de idempotencia es lo que hace segura la resiliencia: si la
/// respuesta se pierde (timeout) y el usuario —o el RetryInterceptor—
/// reintenta, el BFF reconoce la clave y devuelve el resultado original sin
/// mover el dinero otra vez.
class TransferCubit extends Cubit<TransferState> {
  TransferCubit({
    required this._repository,
    ConnectivityMonitor? connectivity,
    String Function()? newKey,
  }) : _newKey = newKey ?? const Uuid().v4,
       super(TransferState(idempotencyKey: (newKey ?? const Uuid().v4)())) {
    _connectivitySub = connectivity?.onStatusChange.listen(_onConnectivity);
  }

  final AccountsRepository _repository;
  final String Function() _newKey;
  StreamSubscription<bool>? _connectivitySub;

  /// NO se reintenta solo: mover dinero exige una acción explícita del
  /// usuario. Solo se actualiza el mensaje para invitarlo a reintentar.
  void _onConnectivity(bool online) {
    final transient = state.failure?.isTransient ?? false;
    if (online && state.status == TransferStatus.failure && transient) {
      emit(state.copyWith(connectionRestored: true));
    }
  }

  @override
  Future<void> close() async {
    await _connectivitySub?.cancel();
    return super.close();
  }

  /// Carga las cuentas (caché primero) y preselecciona origen y destino.
  Future<void> start() async {
    await for (final resource in _repository.watchOverview()) {
      final accounts = resource.data?.accounts;
      if (accounts == null || accounts.isEmpty || isClosed) continue;
      emit(
        state.copyWith(
          status: state.status == TransferStatus.loadingAccounts
              ? TransferStatus.editing
              : state.status,
          accounts: accounts,
          fromId: state.fromId ?? accounts.first.id,
          toId: state.toId ?? accounts.skip(1).firstOrNull?.id,
        ),
      );
    }
    if (state.accounts.isEmpty && !isClosed) {
      emit(
        state.copyWith(
          status: TransferStatus.failure,
          failure: () => const NoConnectionFailure(),
        ),
      );
    }
  }

  void fromSelected(String id) => _edit(state.copyWith(fromId: id));

  void toSelected(String id) => _edit(state.copyWith(toId: id));

  /// Monto en dólares tal como lo escribe el usuario (`12`, `12,50`).
  void amountChanged(String text) =>
      _edit(state.copyWith(amountMinor: Formatters.parseAmount(text) ?? 0));

  /// Cualquier cambio de datos es un intento NUEVO: nueva clave.
  void _edit(TransferState next) => emit(
    next.copyWith(
      idempotencyKey: _newKey(),
      status: TransferStatus.editing,
      fieldErrors: const {},
      failure: () => null,
      connectionRestored: false,
    ),
  );

  Future<void> submit() async {
    if (state.status == TransferStatus.submitting) return;

    final errors = _validate();
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors));
      return;
    }

    emit(
      state.copyWith(
        status: TransferStatus.submitting,
        failure: () => null,
        connectionRestored: false,
      ),
    );
    final result = await _repository.transfer(
      fromAccountId: state.fromId!,
      toAccountId: state.toId!,
      amountMinor: state.amountMinor,
      idempotencyKey: state.idempotencyKey,
    );

    switch (result) {
      case Success(:final value):
        emit(state.copyWith(status: TransferStatus.success, receipt: value));
      case Failure(failure: BusinessFailure(code: 'insufficient_funds')):
        emit(
          state.copyWith(
            status: TransferStatus.editing,
            fieldErrors: {TransferField.amount: 'Saldo insuficiente.'},
          ),
        );
      case Failure(:final failure):
        // Se conserva la MISMA clave: "Reintentar" es seguro.
        emit(
          state.copyWith(
            status: TransferStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }

  Map<TransferField, String> _validate() {
    final from = state.from;
    return {
      if (state.fromId == null)
        TransferField.from: 'Elige la cuenta de origen.',
      if (state.toId == null) TransferField.to: 'Elige la cuenta de destino.',
      if (state.toId != null && state.toId == state.fromId)
        TransferField.to: 'Debe ser distinta a la de origen.',
      if (state.amountMinor <= 0)
        TransferField.amount: 'Ingresa un monto mayor a cero.'
      else if (from != null && state.amountMinor > from.balanceMinor)
        TransferField.amount:
            'Supera tu saldo disponible (${Formatters.money(from.balanceMinor)}).',
    };
  }
}
