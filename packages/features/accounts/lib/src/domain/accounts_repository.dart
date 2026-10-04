import 'package:core/core.dart';

import 'models.dart';

abstract interface class AccountsRepository {
  /// Cuentas y saldos con *stale-while-revalidate*: emite la caché al
  /// instante y luego lo que responde el BFF.
  Stream<Resource<AccountsOverview>> watchOverview();

  /// Página de movimientos. Si el BFF no responde al pedir la PRIMERA página,
  /// devuelve la última guardada con `cachedAt` (y solo falla si no hay).
  Future<Result<TransactionPage>> transactions(
    String accountId, {
    String? cursor,
    String? category,
  });

  Future<Result<Transaction>> transaction(String transactionId);

  /// Transferencia idempotente: reintentar con la misma [idempotencyKey]
  /// nunca mueve el dinero dos veces.
  Future<Result<TransferReceipt>> transfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required String idempotencyKey,
    String? description,
  });
}
