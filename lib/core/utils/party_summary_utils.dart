import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';

class PartyAccountsSummary {
  final int partyCount;
  final double totalReceivable;
  final double totalPayable;

  const PartyAccountsSummary({
    required this.partyCount,
    required this.totalReceivable,
    required this.totalPayable,
  });
}

class PartySummaryUtils {
  static const double settledThreshold = 0.01;

  static bool isVisiblePartyAccount(Account account) {
    return account.isActive &&
        account.category.trim().toLowerCase() != 'partner' &&
        !QuickBillConstants.isCashCustomerAccount(account);
  }

  static List<Account> filterPartyAccounts(Iterable<Account> accounts) {
    final byId = <String, Account>{};
    for (final account in accounts) {
      if (!isVisiblePartyAccount(account)) continue;
      final existing = byId[account.id];
      if (existing == null || account.updatedAt.isAfter(existing.updatedAt)) {
        byId[account.id] = account;
      }
    }
    return byId.values.toList();
  }

  static double openingBalanceFor(Account account) {
    final initial = account.initialBalance;
    if (initial == 0) return 0.0;
    return account.balanceType.trim().toLowerCase() == 'payable'
        ? -initial
        : initial;
  }

  static double partyCardBalance(
    Account account,
    Iterable<Transaction> accountTransactions,
  ) {
    final balance = AccountBalanceUtils.currentCycle(
      accountTransactions,
      initialBalance: openingBalanceFor(account),
    ).balance;
    return balance.abs() < settledThreshold ? 0.0 : balance;
  }

  static PartyAccountsSummary calculateSummary({
    required Iterable<Account> accounts,
    required Iterable<Transaction> transactions,
  }) {
    final partyAccounts = filterPartyAccounts(accounts);
    final transactionsByAccount = <String, List<Transaction>>{};
    for (final transaction in transactions) {
      transactionsByAccount
          .putIfAbsent(transaction.accountId, () => <Transaction>[])
          .add(transaction);
    }

    var totalReceivable = 0.0;
    var totalPayable = 0.0;
    for (final account in partyAccounts) {
      final accountTransactions =
          transactionsByAccount[account.id] ?? const <Transaction>[];
      final balance = partyCardBalance(account, accountTransactions);
      if (balance >= settledThreshold) {
        totalReceivable += balance;
      } else if (balance <= -settledThreshold) {
        totalPayable += -balance;
      }
    }

    return PartyAccountsSummary(
      partyCount: partyAccounts.length,
      totalReceivable: totalReceivable,
      totalPayable: totalPayable,
    );
  }
}
