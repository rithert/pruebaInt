import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/accounts_repository.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../category_style.dart';
import '../widgets/skeleton.dart';

/// Detalle de un movimiento. Es el destino de los deep links de las
/// notificaciones push (`/transactions/:id`).
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    required this.transactionId,
    required this.repository,
    super.key,
  });

  final String transactionId;
  final AccountsRepository repository;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  late Future<Result<Transaction>> _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _request = widget.repository.transaction(widget.transactionId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del movimiento')),
      body: FutureBuilder(
        future: _request,
        builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (snapshot.data) {
            null => const SkeletonList(rows: 4),
            Failure(:final failure) => InlineMessage(
              failure.message,
              action: TextButton(
                onPressed: () => setState(_load),
                child: const Text('Reintentar'),
              ),
            ),
            Success(value: final tx) => _Detail(transaction: tx),
          },
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final date = tx.bookedAt;
    return ListView(
      children: [
        Text(tx.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          Formatters.signedMoney(tx.amountMinor),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: tx.isCredit ? AppColors.creditFor(context) : null,
          ),
        ),
        const Divider(height: AppSpacing.xl),
        _Row('Descripción', tx.description),
        _Row('Categoría', CategoryStyle.label(tx.category)),
        _Row(
          'Fecha',
          '${Formatters.dayLabel(date, now: DateTime.now())} · '
              '${Formatters.time(date)}',
        ),
        _Row('Saldo después', Formatters.money(tx.balanceAfterMinor)),
        _Row('Referencia', tx.id.substring(0, 8).toUpperCase()),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
