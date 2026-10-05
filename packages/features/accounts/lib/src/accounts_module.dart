import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:sdui/sdui.dart';

import 'accounts_routes.dart';
import 'data/accounts_api_repository.dart';
import 'domain/accounts_repository.dart';
import 'domain/models.dart';
import 'presentation/movements/movements_page.dart';
import 'presentation/overview/accounts_cubit.dart';
import 'presentation/overview/accounts_overview_section.dart';
import 'presentation/privacy/balance_visibility_cubit.dart';
import 'presentation/transactions/transaction_detail_page.dart';
import 'presentation/transactions/transactions_cubit.dart';
import 'presentation/transactions/transactions_page.dart';
import 'presentation/transfer/transfer_cubit.dart';
import 'presentation/transfer/transfer_page.dart';

class AccountsModule implements FeatureModule, SduiContributor {
  late GetIt _di;

  @override
  String get name => 'accounts';

  @override
  void registerDependencies(GetIt di) {
    _di = di;
    di
      ..registerLazySingleton<AccountsRepository>(
        () => AccountsApiRepository(
          api: di<ApiClient>(),
          fetcher: di<CachedFetcher>(),
          cache: di<CacheStore>(),
        ),
      )
      // Uno solo para toda la app: el ojo del home y el perfil lo comparten.
      ..registerLazySingleton<BalanceVisibilityCubit>(
        () => BalanceVisibilityCubit(store: di<CacheStore>())..load(),
        dispose: (cubit) => cubit.close(),
      );
  }

  /// Aporta el componente `accounts_summary` al catálogo SDUI: el servidor
  /// decide si y dónde aparece el resumen de cuentas en el home.
  @override
  void registerSduiComponents(SduiRegistry registry) => registry.register(
    'accounts_summary',
    (context, component, actions) => overview(_di),
  );

  /// Resumen de cuentas autocontenido (con su propio cubit).
  static Widget overview(GetIt di) => BlocProvider(
    create: (_) => AccountsCubit(
      repository: di<AccountsRepository>(),
      connectivity: di<ConnectivityMonitor>(),
    )..refresh(),
    child: const AccountsOverviewSection(),
  );

  /// Pestaña Movimientos autocontenida (con su propio cubit de cuentas).
  static Widget movements(GetIt di) => BlocProvider(
    create: (_) => AccountsCubit(
      repository: di<AccountsRepository>(),
      connectivity: di<ConnectivityMonitor>(),
    )..refresh(),
    child: MovementsPage(
      transactionsFor: (accountId) => TransactionsCubit(
        repository: di<AccountsRepository>(),
        accountId: accountId,
      )..load(),
    ),
  );

  @override
  List<RouteBase> routes(GetIt di) => [
    GoRoute(
      path: AccountsRoutes.accountPattern,
      builder: (context, state) => BlocProvider(
        create: (_) => TransactionsCubit(
          repository: di<AccountsRepository>(),
          accountId: state.pathParameters['accountId']!,
        )..load(),
        child: TransactionsPage(account: state.extra as Account?),
      ),
    ),
    GoRoute(
      path: AccountsRoutes.transactionPattern,
      builder: (context, state) => TransactionDetailPage(
        transactionId: state.pathParameters['transactionId']!,
        repository: di<AccountsRepository>(),
      ),
    ),
    GoRoute(
      path: AccountsRoutes.transfer,
      builder: (context, state) => BlocProvider(
        create: (_) => TransferCubit(
          repository: di<AccountsRepository>(),
          connectivity: di<ConnectivityMonitor>(),
        )..start(),
        child: const TransferPage(),
      ),
    ),
  ];
}
