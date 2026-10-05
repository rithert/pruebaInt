import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../accounts_routes.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../privacy/balance_visibility_cubit.dart';
import '../widgets/account_icon.dart';
import '../widgets/stale_data_banner.dart';
import 'accounts_cubit.dart';

/// Resumen de cuentas para el home: saldo total, tarjetas por cuenta y acceso
/// a transferir. Requiere un [AccountsCubit] y un [BalanceVisibilityCubit]
/// en el árbol.
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
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('Mis cuentas'),
            if (overview.accounts.isEmpty)
              const EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'Aún no tienes cuentas',
                message: 'Cuando abras una, aparecerá aquí con su saldo.',
              ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hidden = context.watch<BalanceVisibilityCubit>().state;
    final count = overview.accounts.length;

    return Card(
      color: scheme.primaryContainer,
      // El borde del tema sobra sobre un fondo de color.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius * 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Saldo total',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (refreshing)
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimaryContainer,
                      semanticsLabel: 'Actualizando saldos',
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: hidden ? 'Mostrar saldos' : 'Ocultar saldos',
                  color: scheme.onPrimaryContainer,
                  icon: Icon(
                    hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: context.read<BalanceVisibilityCubit>().toggle,
                ),
              ],
            ),
            AmountText(
              Formatters.money(overview.totalMinor),
              hidden: hidden,
              semanticsLabel: 'Saldo total disponible',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              count == 1 ? 'En 1 cuenta' : 'En $count cuentas',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    final hidden = context.watch<BalanceVisibilityCubit>().state;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.sm,
        ),
        leading: AccountIcon(type: account.type),
        title: Text(account.name),
        subtitle: Text('${account.type.label} ${account.maskedNumber}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountText(
              Formatters.money(account.balanceMinor),
              hidden: hidden,
              semanticsLabel: 'Saldo',
              style: theme.textTheme.titleMedium,
            ),
            ExcludeSemantics(
              child: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        onTap: () =>
            context.push(AccountsRoutes.account(account.id), extra: account),
      ),
    );
  }
}
