import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'accounts_routes.dart';
import 'data/accounts_api_repository.dart';
import 'domain/accounts_repository.dart';
import 'domain/models.dart';
import 'presentation/overview/accounts_cubit.dart';
import 'presentation/overview/accounts_overview_section.dart';
import 'presentation/transactions/transaction_detail_page.dart';
import 'presentation/transactions/transactions_cubit.dart';
import 'presentation/transactions/transactions_page.dart';
import 'presentation/transfer/transfer_cubit.dart';
import 'presentation/transfer/transfer_page.dart';

class AccountsModule implements FeatureModule {
  @override
  String get name => 'accounts';

  @override
  void registerDependencies(GetIt di) {
    di.registerLazySingleton<AccountsRepository>(
      () => AccountsApiRepository(
        api: di<ApiClient>(),
        fetcher: di<CachedFetcher>(),
        cache: di<CacheStore>(),
      ),
    );
  }

  /// Resumen de cuentas listo para insertar en el home (o en un componente
  /// de la experiencia dinámica en F5).
  static Widget overview(GetIt di) => BlocProvider(
    create: (_) => AccountsCubit(
      repository: di<AccountsRepository>(),
      connectivity: di<ConnectivityMonitor>(),
    )..refresh(),
    child: const AccountsOverviewSection(),
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
