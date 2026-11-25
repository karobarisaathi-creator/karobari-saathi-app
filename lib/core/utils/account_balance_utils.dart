import 'package:account_app/core/models/transaction_model.dart';

class AccountCycleBalance {
  final double credit;
  final double debit;

  const AccountCycleBalance({
    required this.credit,
    required this.debit,
  });

  double get balance => debit - credit;
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
  final double debit;
  final double credit;

  const AccountTransactionColumns({
    required this.debit,
    required this.credit,
  });
}

class AccountBalanceUtils {
  static const String partySettlementCategory = 'party_settlement';

  static bool isSupplierCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized == 'supplier' || normalized == 'سپلائر';
  }

  static bool isPartyAccountCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized == 'customer' ||
        normalized == 'supplier' ||
        normalized == 'worker' ||
        normalized == 'employee' ||
        normalized == 'technician' ||
        normalized == 'سپلائر' ||
        normalized == 'گاہک' ||
        normalized == 'مزدور';
  }

  static String partySettlementDescription({
    required String type,
    required String paymentMethod,
    required bool isUrdu,
  }) {
    final normalizedMethod = paymentMethod.trim().toLowerCase();
    final methodLabel = switch (normalizedMethod) {
      'cash' || 'نقد' => isUrdu ? 'نقد' : 'Cash',
      'bank_transfer' || 'bank' || 'بینک' => isUrdu ? 'بینک' : 'Bank',
      'mobile_wallet' ||
      'wallet' ||
      'موبائل والٹ' =>
        isUrdu ? 'موبائل والٹ' : 'Mobile wallet',
      'cheque' || 'check' || 'چیک' => isUrdu ? 'چیک' : 'Cheque',
      '' => isUrdu ? 'دیگر' : 'Other',
      _ => paymentMethod.trim(),
    };
    final isReceipt = type == 'income';

    if (isUrdu) {
      return '${isReceipt ? 'پارٹی سے وصولی' : 'پارٹی کو ادائیگی'} - $methodLabel';
    }
    return '${isReceipt ? 'Receipt from party' : 'Payment to party'} - $methodLabel';
  }

  static bool receiptSubtotalIsDebit(Transaction transaction) {
    if (transaction.isQuickBill) {
      return transaction.type == 'income';
    }
    return transaction.type == 'expense';
  }

  static AccountTransactionColumns transactionColumns(Transaction transaction) {
    final isIncome = transaction.type == 'income';
    final subtotal =
        transaction.subtotal > 0 ? transaction.subtotal : transaction.amount;
    final netTotal =
        (subtotal - transaction.discountAmount).clamp(0, subtotal).toDouble();

    if (transaction.category == partySettlementCategory) {
      final settlementAmount = transaction.amount > 0
          ? transaction.amount
          : transaction.receivedAmount;
      final isDebit = !isIncome;
      return AccountTransactionColumns(
        debit: isDebit ? settlementAmount : 0,
        credit: isDebit ? 0 : settlementAmount,
      );
    }

    if (transaction.receiptFromCounterparty && !transaction.isQuickBill) {
      return AccountTransactionColumns(
        debit: isIncome ? transaction.receivedAmount : netTotal,
        credit: isIncome ? netTotal : transaction.receivedAmount,
      );
    }

    if (transaction.isQuickBill) {
      // Sales debit the net bill; purchases credit it. Payments go on the
      // opposite side in both cases.
      return AccountTransactionColumns(
        debit: isIncome ? netTotal : transaction.receivedAmount,
        credit: isIncome ? transaction.receivedAmount : netTotal,
      );
    }

    return AccountTransactionColumns(
      debit: isIncome ? 0 : transaction.amount,
      credit: isIncome ? transaction.amount : 0,
    );
  }

  static double ledgerBalance(
    Iterable<Transaction> transactions, {
    double initialBalance = 0,
  }) {
    return transactions.fold(
      initialBalance,
      (balance, transaction) {
        final columns = transactionColumns(transaction);
        return balance + columns.debit - columns.credit;
      },
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
      balance += columns.debit - columns.credit;
      if (balance.abs() < 0.01) balance = 0;
      balances[transaction.id] = balance;
    }

    return balances;
  }

  static AccountCycleBalance currentCycle(
    Iterable<Transaction> transactions, {
    double initialBalance = 0,
  }) {
    final sortedTransactions = transactions.toList()..sort(_compareOrder);

    double currentCycleCredit = initialBalance < 0 ? -initialBalance : 0;
    double currentCycleDebit = initialBalance > 0 ? initialBalance : 0;
    double totalRunningCredit = currentCycleCredit;
    double totalRunningDebit = currentCycleDebit;

    for (final transaction in sortedTransactions) {
      final columns = transactionColumns(transaction);
      totalRunningDebit += columns.debit;
      currentCycleDebit += columns.debit;
      totalRunningCredit += columns.credit;
      currentCycleCredit += columns.credit;

      if ((totalRunningCredit - totalRunningDebit).abs() < 0.01) {
        currentCycleCredit = 0;
        currentCycleDebit = 0;
      }
    }

    if (currentCycleCredit == 0 &&
        currentCycleDebit == 0 &&
        (sortedTransactions.isNotEmpty || initialBalance != 0)) {
      double lastCycleCredit = initialBalance < 0 ? -initialBalance : 0;
      double lastCycleDebit = initialBalance > 0 ? initialBalance : 0;
      for (final transaction in sortedTransactions) {
        final columns = transactionColumns(transaction);
        lastCycleDebit += columns.debit;
        lastCycleCredit += columns.credit;

        if ((lastCycleCredit - lastCycleDebit).abs() < 0.01) {
          currentCycleCredit = lastCycleCredit;
          currentCycleDebit = lastCycleDebit;
          lastCycleCredit = 0;
          lastCycleDebit = 0;
        }
      }
    }

    return AccountCycleBalance(
      credit: currentCycleCredit,
      debit: currentCycleDebit,
    );
  }

  static double currentCycleBalance(
    Iterable<Transaction> transactions, {
    double initialBalance = 0,
  }) =>
      currentCycle(transactions, initialBalance: initialBalance).balance;

  static ReceiptBalanceBreakdown receiptBreakdown({
    required Iterable<Transaction> transactions,
    required Transaction receipt,
    double initialBalance = 0,
  }) {
    final precedingTransactions = transactions.where((transaction) {
      if (transaction.id == receipt.id ||
          transaction.accountId != receipt.accountId) {
        return false;
      }
      return _compareOrder(transaction, receipt) < 0;
    }).toList()
      ..sort(_compareOrder);

    var openingBalance = initialBalance;
    for (final transaction in precedingTransactions) {
      final columns = transactionColumns(transaction);
      openingBalance += columns.debit - columns.credit;
      if (openingBalance.abs() < 0.01) openingBalance = 0;
    }

    final columns = transactionColumns(receipt);
    final finalBalance = openingBalance + columns.debit - columns.credit;
    if (receipt.category == partySettlementCategory) {
      return ReceiptBalanceBreakdown(
        openingBalance: openingBalance,
        balanceBeforeDiscount: openingBalance,
        balanceAfterDiscount: openingBalance,
        finalBalance: finalBalance,
      );
    }

    final direction = receiptSubtotalIsDebit(receipt) ? 1.0 : -1.0;
    final subtotal = receipt.subtotal > 0 ? receipt.subtotal : receipt.amount;
    final discount = receipt.discountAmount.clamp(0, subtotal).toDouble();
    final beforeDiscount = openingBalance + direction * subtotal;
    final afterDiscount = beforeDiscount - direction * discount;

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
