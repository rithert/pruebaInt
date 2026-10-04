import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../category_style.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, this.onTap, super.key});

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final amount = Formatters.signedMoney(tx.amountMinor);
    final category = CategoryStyle.label(tx.category);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      // Una sola frase para TalkBack en lugar de 4 fragmentos sueltos.
      label:
          '${tx.title}, ${tx.isCredit ? 'abono' : 'cargo'} de '
          '${Formatters.money(tx.amountMinor.abs())}, $category, '
          '${Formatters.time(tx.bookedAt)}',
      button: onTap != null,
      excludeSemantics: true,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Icon(
            CategoryStyle.icon(tx.category),
            color: scheme.onSecondaryContainer,
          ),
        ),
        title: Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$category · ${Formatters.time(tx.bookedAt)}'),
        trailing: Text(
          amount,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: tx.isCredit
                ? AppColors.creditFor(context)
                : scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
