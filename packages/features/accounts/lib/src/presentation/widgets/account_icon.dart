import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// Icono del tipo de cuenta sobre un fondo tonal.
class AccountIcon extends StatelessWidget {
  const AccountIcon({required this.type, super.key});

  final AccountType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Icon(switch (type) {
          AccountType.savings => Icons.account_balance_wallet_outlined,
          AccountType.investment => Icons.trending_up,
          AccountType.business => Icons.storefront_outlined,
        }, color: scheme.onPrimaryContainer),
      ),
    );
  }
}
