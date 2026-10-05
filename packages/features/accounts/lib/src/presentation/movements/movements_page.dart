import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models.dart';
import '../overview/accounts_cubit.dart';
import '../transactions/transactions_cubit.dart';
import '../transactions/transactions_page.dart';

/// Pestaña Movimientos: elige una cuenta y muestra sus movimientos. El BFF
/// pagina por cuenta, así que no hay una lista "de todas las cuentas".
/// Requiere un [AccountsCubit] en el árbol.
class MovementsPage extends StatefulWidget {
  const MovementsPage({required this.transactionsFor, super.key});

  /// Crea (y arranca) el cubit de movimientos de una cuenta.
  final TransactionsCubit Function(String accountId) transactionsFor;

  @override
  State<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends State<MovementsPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: BlocBuilder<AccountsCubit, Resource<AccountsOverview>>(
        builder: (context, resource) {
          final accounts = resource.data?.accounts;

          if (accounts == null && resource.isRefreshing) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SkeletonList(rows: 8),
            );
          }
          if (accounts == null) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: InlineMessage(
                resource.failure?.message ?? 'No pudimos cargar tus cuentas.',
                action: TextButton(
                  onPressed: context.read<AccountsCubit>().refresh,
                  child: const Text('Reintentar'),
                ),
              ),
            );
          }
          if (accounts.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'Aún no tienes cuentas',
              ),
            );
          }

          // Si la cuenta elegida ya no existe, se vuelve a la primera.
          final selected = accounts.firstWhere(
            (a) => a.id == _selectedId,
            orElse: () => accounts.first,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (accounts.length > 1)
                _AccountSelector(
                  accounts: accounts,
                  selectedId: selected.id,
                  onSelected: (id) => setState(() => _selectedId = id),
                ),
              Expanded(
                // La key recrea el cubit al cambiar de cuenta: cada cuenta
                // tiene su propio cursor y filtro.
                child: BlocProvider(
                  key: ValueKey(selected.id),
                  create: (_) => widget.transactionsFor(selected.id),
                  child: TransactionsView(account: selected),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Account> accounts;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(account.name),
                selected: account.id == selectedId,
                onSelected: (_) => onSelected(account.id),
              ),
            ),
        ],
      ),
    );
  }
}
