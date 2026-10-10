import 'package:account_app/core/models/transaction_model.dart';

class AccountCycleBalance {
  final double income;
  final double expense;

  const AccountCycleBalance({
    required this.income,
    required this.expense,
  });

  double get balance => income - expense;
}

class ReceiptBalanceBreakdown {
  final double openingBalance;
  final double balanceBeforeDiscount;
  final double balanceAfterDiscount;
  final double finalBalance;

  const ReceiptBalanceBreakdown({
    required this.openingBalance,
    required this.balanceBeforeDiscount,
    required this.balanceAfterDiscount,
    required this.finalBalance,
  });
}

class AccountBalanceUtils {
  static AccountCycleBalance currentCycle(Iterable<Transaction> transactions) {
    final sortedTransactions = transactions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double currentCycleIn = 0;
    double currentCycleOut = 0;
    double totalRunningIn = 0;
    double totalRunningOut = 0;

    for (final transaction in sortedTransactions) {
      if (transaction.type == 'income') {
        totalRunningIn += transaction.accountBalanceAmount;
        currentCycleIn += transaction.accountBalanceAmount;
      } else {
        totalRunningOut += transaction.accountBalanceAmount;
        currentCycleOut += transaction.accountBalanceAmount;
      }

      if ((totalRunningIn - totalRunningOut).abs() < 0.01) {
        currentCycleIn = 0;
        currentCycleOut = 0;
      }
    }

    if (currentCycleIn == 0 &&
        currentCycleOut == 0 &&
        sortedTransactions.isNotEmpty) {
      double lastCycleIn = 0;
      double lastCycleOut = 0;
      for (final transaction in sortedTransactions) {
        if (transaction.type == 'income') {
          lastCycleIn += transaction.accountBalanceAmount;
        } else {
          lastCycleOut += transaction.accountBalanceAmount;
        }

        if ((lastCycleIn - lastCycleOut).abs() < 0.01) {
          currentCycleIn = lastCycleIn;
          currentCycleOut = lastCycleOut;
          lastCycleIn = 0;
          lastCycleOut = 0;
        }
      }
    }

    return AccountCycleBalance(
      income: currentCycleIn,
      expense: currentCycleOut,
    );
  }

  static double currentCycleBalance(Iterable<Transaction> transactions) =>
      currentCycle(transactions).balance;

  static ReceiptBalanceBreakdown receiptBreakdown({
    required Iterable<Transaction> transactions,
    required Transaction receipt,
    double initialBalance = 0,
  }) {
    final precedingTransactions = transactions.where((transaction) {
      if (transaction.id == receipt.id ||
          transaction.accountId != receipt.accountId ||
          transaction.partnershipId != null) {
        return false;
      }
      return _compareOrder(transaction, receipt) < 0;
    }).toList()
      ..sort(_compareOrder);

    var openingBalance = initialBalance;
    for (final transaction in precedingTransactions) {
      openingBalance += transaction.type == 'income'
          ? transaction.accountBalanceAmount
          : -transaction.accountBalanceAmount;
      if (openingBalance.abs() < 0.01) openingBalance = 0;
    }

    final direction = receipt.type == 'income' ? 1.0 : -1.0;
    final subtotal = receipt.subtotal > 0 ? receipt.subtotal : receipt.amount;
    final discount = receipt.discountAmount.clamp(0, subtotal).toDouble();
    final received = receipt.receivedAmount.clamp(0, subtotal - discount).toDouble();
    final beforeDiscount = openingBalance + direction * subtotal;
    final afterDiscount = beforeDiscount - direction * discount;
    final finalBalance = afterDiscount - direction * received;

    return ReceiptBalanceBreakdown(
      openingBalance: openingBalance,
      balanceBeforeDiscount: beforeDiscount,
      balanceAfterDiscount: afterDiscount,
      finalBalance: finalBalance,
    );
  }

  static int _compareOrder(Transaction first, Transaction second) {
    final dateOrder = first.date.compareTo(second.date);
    if (dateOrder != 0) return dateOrder;

    final createdOrder = first.createdAt.compareTo(second.createdAt);
    if (createdOrder != 0) return createdOrder;

    return first.id.compareTo(second.id);
  }
}
