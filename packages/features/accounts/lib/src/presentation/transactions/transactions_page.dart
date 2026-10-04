import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../accounts_routes.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../category_style.dart';
import '../widgets/skeleton.dart';
import '../widgets/stale_data_banner.dart';
import '../widgets/transaction_tile.dart';
import 'transactions_cubit.dart';
import 'transactions_state.dart';

/// Movimientos de una cuenta: scroll infinito agrupado por día, filtro por
/// categoría y pull-to-refresh. [account] llega al navegar desde el home;
/// con un deep link puede ser `null`.
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({this.account, super.key});

  final Account? account;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();

    return Scaffold(
      appBar: AppBar(title: Text(account?.name ?? 'Movimientos')),
      body: BlocConsumer<TransactionsCubit, TransactionsState>(
        // Un refresh fallido no tapa la lista: se avisa con un SnackBar.
        listenWhen: (prev, next) =>
            next.status == TransactionsStatus.success &&
            next.failure != null &&
            prev.failure != next.failure,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.failure!.message))),
        builder: (context, state) => RefreshIndicator(
          onRefresh: cubit.refresh,
          child: NotificationListener<ScrollNotification>(
            // Pide la siguiente página antes de llegar al final.
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) {
                cubit.loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverList.list(
                    children: [
                      if (account != null) _BalanceHeader(account: account!),
                      _CategoryFilters(selected: state.category),
                      if (state.isStale) ...[
                        const SizedBox(height: AppSpacing.sm),
                        StaleDataBanner(
                          updatedAt: state.cachedAt,
                          onRetry: cubit.refresh,
                        ),
                      ],
                    ],
                  ),
                ),
                ..._content(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, TransactionsState state) {
    final cubit = context.read<TransactionsCubit>();
    const padding = EdgeInsets.symmetric(horizontal: AppSpacing.md);

    switch (state.status) {
      case TransactionsStatus.initial:
      case TransactionsStatus.loading:
        return const [
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(child: SkeletonList(rows: 8)),
          ),
        ];
      case TransactionsStatus.failure:
        return [
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(
              child: InlineMessage(
                state.failure?.message ?? 'No pudimos cargar los movimientos.',
                action: TextButton(
                  onPressed: cubit.load,
                  child: const Text('Reintentar'),
                ),
              ),
            ),
          ),
        ];
      case TransactionsStatus.success when state.items.isEmpty:
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No hay movimientos para mostrar.')),
          ),
        ];
      case TransactionsStatus.success:
        final groups = groupByDay(
          state.items,
          dateOf: (tx) => tx.bookedAt,
          now: DateTime.now(),
        );
        return [
          for (final (label, items) in groups) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  header: true,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => TransactionTile(
                transaction: items[index],
                onTap: () => context.push(
                  AccountsRoutes.transaction(items[index].id),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: _ListFooter(state: state)),
        ];
    }
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${account.type.label} ${account.maskedNumber}'),
          Text(
            Formatters.money(account.balanceMinor),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in [null, ...CategoryStyle.filters])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(
                  category == null ? 'Todos' : CategoryStyle.label(category),
                ),
                selected: selected == category,
                onSelected: (_) => cubit.categorySelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});

  final TransactionsState state;

  @override
  Widget build(BuildContext context) {
    final child = switch (state) {
      TransactionsState(isLoadingMore: true) => const CircularProgressIndicator(
        semanticsLabel: 'Cargando más movimientos',
      ),
      TransactionsState(:final loadMoreFailure?) => TextButton.icon(
        onPressed: context.read<TransactionsCubit>().loadMore,
        icon: const Icon(Icons.refresh),
        label: Text('${loadMoreFailure.message} Reintentar'),
      ),
      TransactionsState(hasReachedEnd: true) when !state.isStale => const Text(
        'No hay más movimientos',
      ),
      _ => const SizedBox.shrink(),
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(child: child),
    );
  }
}
