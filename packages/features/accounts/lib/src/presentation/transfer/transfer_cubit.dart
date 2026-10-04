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
    this.amountPesos = 0,
    this.fieldErrors = const {},
    this.failure,
    this.receipt,
  });

  /// Identifica ESTE intento de transferencia. Se conserva entre reintentos
  /// (el BFF no duplica) y se renueva si el usuario cambia algún dato.
  final String idempotencyKey;
  final TransferStatus status;
  final List<Account> accounts;
  final String? fromId;
  final String? toId;
  final int amountPesos;
  final Map<TransferField, String> fieldErrors;
  final AppFailure? failure;
  final TransferReceipt? receipt;

  Account? get from => accounts.where((a) => a.id == fromId).firstOrNull;

  TransferState copyWith({
    String? idempotencyKey,
    TransferStatus? status,
    List<Account>? accounts,
    String? fromId,
    String? toId,
    int? amountPesos,
    Map<TransferField, String>? fieldErrors,
    AppFailure? Function()? failure,
    TransferReceipt? receipt,
  }) => TransferState(
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    status: status ?? this.status,
    accounts: accounts ?? this.accounts,
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    amountPesos: amountPesos ?? this.amountPesos,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    failure: failure != null ? failure() : this.failure,
    receipt: receipt ?? this.receipt,
  );

  @override
  List<Object?> get props => [
    idempotencyKey,
    status,
    accounts,
    fromId,
    toId,
    amountPesos,
    fieldErrors,
    failure,
    receipt,
  ];
}

/// Transferencia entre cuentas propias.
///
/// La clave de idempotencia es lo que hace segura la resiliencia: si la
/// respuesta se pierde (timeout) y el usuario —o el RetryInterceptor—
/// reintenta, el BFF reconoce la clave y devuelve el resultado original sin
/// mover el dinero otra vez.
class TransferCubit extends Cubit<TransferState> {
  TransferCubit({required this._repository, String Function()? newKey})
    : _newKey = newKey ?? const Uuid().v4,
      super(TransferState(idempotencyKey: (newKey ?? const Uuid().v4)()));

  final AccountsRepository _repository;
  final String Function() _newKey;

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

  /// Monto en pesos enteros (el campo solo admite dígitos).
  void amountChanged(String digits) =>
      _edit(state.copyWith(amountPesos: int.tryParse(digits) ?? 0));

  /// Cualquier cambio de datos es un intento NUEVO: nueva clave.
  void _edit(TransferState next) => emit(
    next.copyWith(
      idempotencyKey: _newKey(),
      status: TransferStatus.editing,
      fieldErrors: const {},
      failure: () => null,
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
      state.copyWith(status: TransferStatus.submitting, failure: () => null),
    );
    final result = await _repository.transfer(
      fromAccountId: state.fromId!,
      toAccountId: state.toId!,
      amountMinor: state.amountPesos * 100,
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
      if (state.amountPesos <= 0)
        TransferField.amount: 'Ingresa un monto mayor a cero.'
      else if (from != null && state.amountPesos * 100 > from.balanceMinor)
        TransferField.amount:
            'Supera tu saldo disponible (${Formatters.money(from.balanceMinor)}).',
    };
  }
}
