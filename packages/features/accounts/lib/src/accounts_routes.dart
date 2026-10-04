abstract final class AccountsRoutes {
  static const accountPattern = '/accounts/:accountId';
  static const transactionPattern = '/transactions/:transactionId';
  static const transfer = '/transfer';

  static String account(String id) => '/accounts/$id';
  static String transaction(String id) => '/transactions/$id';
}
