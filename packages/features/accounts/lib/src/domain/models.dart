import 'package:equatable/equatable.dart';

enum AccountType {
  savings('Ahorros'),
  investment('Inversión'),
  business('Negocio');

  const AccountType(this.label);

  final String label;

  static AccountType fromApi(String value) => values.byName(value);
}

class Account extends Equatable {
  const Account({
    required this.id,
    required this.type,
    required this.name,
    required this.maskedNumber,
    required this.currency,
    required this.balanceMinor,
  });

  factory Account.fromJson(Map<String, Object?> json) => Account(
    id: json['id']! as String,
    type: AccountType.fromApi(json['type']! as String),
    name: json['name']! as String,
    maskedNumber: json['maskedNumber']! as String,
    currency: json['currency']! as String,
    balanceMinor: json['balanceMinor']! as int,
  );

  final String id;
  final AccountType type;
  final String name;
  final String maskedNumber;
  final String currency;

  /// Saldo en unidades menores (centavos): nunca `double` para dinero.
  final int balanceMinor;

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    maskedNumber,
    currency,
    balanceMinor,
  ];
}

class AccountsOverview extends Equatable {
  const AccountsOverview({required this.accounts, required this.totalMinor});

  factory AccountsOverview.fromJson(Object? json) {
    final body = json! as Map<String, Object?>;
    final accounts = (body['accounts']! as List<Object?>)
        .map((a) => Account.fromJson(a! as Map<String, Object?>))
        .toList();
    final totals = body['totals']! as List<Object?>;
    final total = totals.isEmpty
        ? 0
        : (totals.first! as Map<String, Object?>)['balanceMinor']! as int;
    return AccountsOverview(accounts: accounts, totalMinor: total);
  }

  final List<Account> accounts;

  /// Saldo total (todas las cuentas comparten moneda en este alcance).
  final int totalMinor;

  String get currency => accounts.isEmpty ? 'USD' : accounts.first.currency;

  @override
  List<Object?> get props => [accounts, totalMinor];
}

class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.amountMinor,
    required this.balanceAfterMinor,
    required this.currency,
    required this.description,
    required this.category,
    required this.bookedAt,
    this.counterparty,
  });

  factory Transaction.fromJson(Map<String, Object?> json) => Transaction(
    id: json['id']! as String,
    accountId: json['accountId']! as String,
    amountMinor: json['amountMinor']! as int,
    balanceAfterMinor: json['balanceAfterMinor']! as int,
    currency: json['currency']! as String,
    description: json['description']! as String,
    category: json['category']! as String,
    counterparty: json['counterparty'] as String?,
    bookedAt: DateTime.parse(json['bookedAt']! as String),
  );

  final String id;
  final String accountId;

  /// Positivo = abono; negativo = cargo.
  final int amountMinor;
  final int balanceAfterMinor;
  final String currency;
  final String description;
  final String category;
  final String? counterparty;
  final DateTime bookedAt;

  bool get isCredit => amountMinor >= 0;

  /// Texto principal en listas: el comercio o persona, si existe.
  String get title => counterparty ?? description;

  @override
  List<Object?> get props => [
    id,
    accountId,
    amountMinor,
    balanceAfterMinor,
    currency,
    description,
    category,
    counterparty,
    bookedAt,
  ];
}

/// Página de movimientos. [cachedAt] no es `null` cuando la página viene
/// de caché porque el servidor no respondió.
class TransactionPage extends Equatable {
  const TransactionPage({
    required this.items,
    required this.nextCursor,
    this.cachedAt,
  });

  factory TransactionPage.fromJson(Object? json) {
    final body = json! as Map<String, Object?>;
    return TransactionPage(
      items: (body['items']! as List<Object?>)
          .map((t) => Transaction.fromJson(t! as Map<String, Object?>))
          .toList(),
      nextCursor: body['nextCursor'] as String?,
    );
  }

  final List<Transaction> items;

  /// `null` = no hay más páginas.
  final String? nextCursor;
  final DateTime? cachedAt;

  @override
  List<Object?> get props => [items, nextCursor, cachedAt];
}

class TransferReceipt extends Equatable {
  const TransferReceipt({
    required this.transferId,
    required this.amountMinor,
    required this.currency,
    required this.fromBalanceMinor,
    required this.toBalanceMinor,
  });

  factory TransferReceipt.fromJson(Object? json) {
    final body = json! as Map<String, Object?>;
    return TransferReceipt(
      transferId: body['transferId']! as String,
      amountMinor: body['amountMinor']! as int,
      currency: body['currency']! as String,
      fromBalanceMinor:
          (body['from']! as Map<String, Object?>)['balanceMinor']! as int,
      toBalanceMinor:
          (body['to']! as Map<String, Object?>)['balanceMinor']! as int,
    );
  }

  final String transferId;
  final int amountMinor;
  final String currency;
  final int fromBalanceMinor;
  final int toBalanceMinor;

  @override
  List<Object?> get props => [
    transferId,
    amountMinor,
    currency,
    fromBalanceMinor,
    toBalanceMinor,
  ];
}
