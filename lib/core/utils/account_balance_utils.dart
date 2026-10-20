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

class AccountTransactionColumns {
  final double firstColumn;
  final double secondColumn;

  const AccountTransactionColumns({
    required this.firstColumn,
    required this.secondColumn,
  });
}

class AccountBalanceUtils {
  static AccountTransactionColumns transactionColumns(Transaction transaction) {
    final isIncome = transaction.type == 'income';
    final subtotal =
        transaction.subtotal > 0 ? transaction.subtotal : transaction.amount;
    final netTotal =
        (subtotal - transaction.discountAmount).clamp(0, subtotal).toDouble();

    if (transaction.receiptFromCounterparty && !transaction.isQuickBill) {
      return AccountTransactionColumns(
        firstColumn: isIncome ? transaction.receivedAmount : netTotal,
        secondColumn: isIncome ? netTotal : transaction.receivedAmount,
      );
    }

    if (transaction.isQuickBill) {
      // ⭐ کھاتہ اور رسید کو ۱۰۰٪ برابر رکھنا:
      // بنام (First Column) = نیٹ آئٹمز ٹوٹل (Sale) یا ادا شدہ رقم (Purchase)
      // جمع (Second Column) = موصول شدہ رقم (Sale) یا نیٹ آئٹمز ٹوٹل (Purchase)
      return AccountTransactionColumns(
        firstColumn: isIncome ? netTotal : transaction.receivedAmount,
        secondColumn: isIncome ? transaction.receivedAmount : netTotal,
      );
    }

    return AccountTransactionColumns(
      firstColumn: isIncome ? 0 : transaction.amount,
      secondColumn: isIncome ? transaction.amount : 0,
    );
  }

  static double ledgerBalance(
    Iterable<Transaction> transactions, {
    double initialBalance = 0,
  }) {
    return transactions.fold(
      initialBalance,
      (balance, transaction) =>
          balance +
          (transaction.type == 'income'
              ? transaction.accountBalanceAmount
              : -transaction.accountBalanceAmount),
    );
  }

  static Map<String, double> runningBalances(
    Iterable<Transaction> transactions, {
    double initialBalance = 0,
  }) {
    final sortedTransactions = transactions.toList()..sort(_compareOrder);
    final balances = <String, double>{};
    var balance = initialBalance;

    for (final transaction in sortedTransactions) {
      final columns = transactionColumns(transaction);
      balance += columns.firstColumn - columns.secondColumn;
      if (balance.abs() < 0.01) balance = 0;
      balances[transaction.id] = balance;
    }

    return balances;
  }

  static AccountCycleBalance currentCycle(Iterable<Transaction> transactions) {
    final sortedTransactions = transactions.toList()..sort(_compareOrder);

    double currentCycleIn = 0;
    double currentCycleOut = 0;
    double totalRunningIn = 0;
    double totalRunningOut = 0;

    for (final transaction in sortedTransactions) {
      final columns = transactionColumns(transaction);
      totalRunningOut += columns.firstColumn;
      currentCycleOut += columns.firstColumn;
      totalRunningIn += columns.secondColumn;
      currentCycleIn += columns.secondColumn;

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
        final columns = transactionColumns(transaction);
        lastCycleOut += columns.firstColumn;
        lastCycleIn += columns.secondColumn;

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
      final columns = transactionColumns(transaction);
      openingBalance += columns.firstColumn - columns.secondColumn;
      if (openingBalance.abs() < 0.01) openingBalance = 0;
    }

    final direction = receipt.type == 'income' ? 1.0 : -1.0;
    final subtotal = receipt.subtotal > 0 ? receipt.subtotal : receipt.amount;
    final discount = receipt.discountAmount.clamp(0, subtotal).toDouble();
    final received =
        receipt.receivedAmount.clamp(0, subtotal - discount).toDouble();
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
