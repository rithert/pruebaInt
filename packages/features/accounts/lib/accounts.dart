/// Dominio de cuentas: saldos, movimientos y transferencias entre cuentas
/// propias. El shell usa [AccountsModule] y `AccountsModule.overview`.
library;

export 'src/accounts_module.dart';
export 'src/accounts_routes.dart';
export 'src/data/accounts_api_repository.dart';
export 'src/domain/accounts_repository.dart';
export 'src/domain/formatters.dart';
export 'src/domain/models.dart';
export 'src/presentation/movements/movements_page.dart';
export 'src/presentation/overview/accounts_cubit.dart';
export 'src/presentation/privacy/balance_visibility_cubit.dart';
export 'src/presentation/transactions/transactions_cubit.dart';
export 'src/presentation/transactions/transactions_state.dart';
export 'src/presentation/transfer/transfer_cubit.dart';
