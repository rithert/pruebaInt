import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../accounts_routes.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../widgets/skeleton.dart';
import '../widgets/stale_data_banner.dart';
import 'accounts_cubit.dart';

/// Resumen de cuentas para el home: saldo total, tarjetas por cuenta y acceso
/// a transferir. Requiere un [AccountsCubit] en el árbol.
class AccountsOverviewSection extends StatelessWidget {
  const AccountsOverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountsCubit, Resource<AccountsOverview>>(
      builder: (context, resource) {
        final cubit = context.read<AccountsCubit>();
        final overview = resource.data;

        if (overview == null && resource.isRefreshing) {
          return const SkeletonList(rows: 3);
        }
        if (overview == null) {
          return InlineMessage(
            resource.failure?.message ?? 'No pudimos cargar tus cuentas.',
            action: TextButton(
              onPressed: cubit.refresh,
              child: const Text('Reintentar'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (resource.isStale) ...[
              StaleDataBanner(
                updatedAt: resource.updatedAt,
                failure: resource.failure,
                onRetry: cubit.refresh,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _TotalCard(overview: overview, refreshing: resource.isRefreshing),
            const SizedBox(height: AppSpacing.md),
            for (final account in overview.accounts) ...[
              _AccountTile(account: account),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: overview.accounts.length < 2
                  ? null
                  : () async {
                      final moved = await context.push<bool>(
                        AccountsRoutes.transfer,
                      );
                      if (moved ?? false) await cubit.refresh();
                    },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Transferir entre mis cuentas'),
            ),
          ],
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.overview, required this.refreshing});

  final AccountsOverview overview;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = Formatters.money(overview.totalMinor);

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          label: 'Saldo total disponible: $total',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Saldo total',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  const Spacer(),
                  if (refreshing)
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                total,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(switch (account.type) {
          AccountType.savings => Icons.account_balance_wallet_outlined,
          AccountType.investment => Icons.trending_up,
          AccountType.business => Icons.storefront_outlined,
        }),
        title: Text(account.name),
        subtitle: Text('${account.type.label} ${account.maskedNumber}'),
        trailing: Text(
          Formatters.money(account.balanceMinor),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () =>
            context.push(AccountsRoutes.account(account.id), extra: account),
      ),
    );
  }
}
