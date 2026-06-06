import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';

class BalanceService with ChangeNotifier {
  late Box<Account> _accountsBox;
  late Box<Transaction> _transactionsBox;

  BalanceService() {
    _init();
  }

  Future<void> _init() async {
    _accountsBox = await Hive.openBox<Account>('accounts');
    _transactionsBox = await Hive.openBox<Transaction>('transactions');
    notifyListeners();
  }

  // Getters for direct access
  double get totalBalance => calculateTotalBalance();
  double get totalIncome => calculateTotalIncome();
  double get totalExpense => calculateTotalExpense();
  double get totalPending => calculateTotalPending();

  // Calculate total balance across all accounts
  double calculateTotalBalance() {
    if (!_accountsBox.isOpen) return 0.0;
    final accounts = _accountsBox.values.toList();
    return accounts.fold(0.0, (sum, account) => sum + account.balance);
  }

  // Calculate total income
  double calculateTotalIncome() {
    if (!_transactionsBox.isOpen) return 0.0;
    final transactions = _transactionsBox.values.toList();
    return transactions
        .where((transaction) => transaction.type == 'income')
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  // Calculate total expense
  double calculateTotalExpense() {
    if (!_transactionsBox.isOpen) return 0.0;
    final transactions = _transactionsBox.values.toList();
    return transactions
        .where((transaction) => transaction.type == 'expense')
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  // Calculate pending amount across all accounts
  double calculateTotalPending() {
    if (!_transactionsBox.isOpen) return 0.0;
    final transactions = _transactionsBox.values.toList();
    return transactions.fold(
      0.0,
      (sum, transaction) => sum + transaction.pendingAmount,
    );
  }

  // Calculate account-specific balance
  double calculateAccountBalance(String accountId) {
    final account = _accountsBox.get(accountId);
    return account?.balance ?? 0.0;
  }

  // Calculate account income
  double calculateAccountIncome(String accountId) {
    final transactions = _transactionsBox.values
        .where((t) => t.accountId == accountId && t.type == 'income')
        .toList();

    return transactions.fold(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );
  }

  // Calculate account expense
  double calculateAccountExpense(String accountId) {
    final transactions = _transactionsBox.values
        .where((t) => t.accountId == accountId && t.type == 'expense')
        .toList();

    return transactions.fold(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );
  }

  // Calculate account pending amount
  double calculateAccountPending(String accountId) {
    final transactions = _transactionsBox.values
        .where((t) => t.accountId == accountId)
        .toList();

    return transactions.fold(
      0.0,
      (sum, transaction) => sum + transaction.pendingAmount,
    );
  }

  // Calculate monthly summary
  Map<String, double> calculateMonthlySummary(int year, int month) {
    final transactions = _transactionsBox.values
        .where((t) => t.date.year == year && t.date.month == month)
        .toList();

    final income = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);

    final expense = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    final pending = transactions.fold(0.0, (sum, t) => sum + t.pendingAmount);

    return {
      'income': income,
      'expense': expense,
      'pending': pending,
      'net': income - expense,
    };
  }

  // Calculate category-wise summary
  Map<String, double> calculateCategorySummary(
    String type,
    int year,
    int month,
  ) {
    final transactions = _transactionsBox.values
        .where(
          (t) => t.type == type && t.date.year == year && t.date.month == month,
        )
        .toList();

    final Map<String, double> categoryTotals = {};

    for (var transaction in transactions) {
      categoryTotals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    return categoryTotals;
  }

  // Calculate profession-wise summary
  Map<String, Map<String, double>> calculateProfessionSummary(
    int year,
    int month,
  ) {
    final transactions = _transactionsBox.values
        .where(
          (t) =>
              t.professionId != null &&
              t.date.year == year &&
              t.date.month == month,
        )
        .toList();

    final Map<String, Map<String, double>> professionTotals = {};

    for (var transaction in transactions) {
      final professionId = transaction.professionId!;

      if (!professionTotals.containsKey(professionId)) {
        professionTotals[professionId] = {'income': 0.0, 'expense': 0.0};
      }

      professionTotals[professionId]![transaction.type] =
          professionTotals[professionId]![transaction.type]! +
          transaction.amount;
    }

    return professionTotals;
  }

  // Calculate profit/loss percentage
  double calculateProfitPercentage(double income, double expense) {
    if (income == 0) return 0.0;
    return ((income - expense) / income) * 100;
  }

  // Get accounts with negative balance (debt)
  List<Account> getAccountsWithDebt() {
    return _accountsBox.values.where((account) => account.balance < 0).toList();
  }

  // Get accounts with positive balance (credit)
  List<Account> getAccountsWithCredit() {
    return _accountsBox.values.where((account) => account.balance > 0).toList();
  }

  // Calculate average transaction amount
  double calculateAverageTransactionAmount() {
    final transactions = _transactionsBox.values.toList();
    if (transactions.isEmpty) return 0.0;

    final total = transactions.fold(0.0, (sum, t) => sum + t.amount);
    return total / transactions.length;
  }

  // Get financial health score (0-100)
  double calculateFinancialHealthScore() {
    final totalBalance = calculateTotalBalance();
    final totalPending = calculateTotalPending();
    final accountsWithDebt = getAccountsWithDebt().length;
    final totalAccounts = _accountsBox.values.length;

    double score = 100.0;

    // Deduct for negative balance
    if (totalBalance < 0) {
      score -= 30;
    }

    // Deduct for high pending amount
    if (totalPending > totalBalance * 0.5) {
      score -= 20;
    }

    // Deduct for too many debt accounts
    final debtRatio = accountsWithDebt / totalAccounts;
    if (debtRatio > 0.3) {
      score -= (debtRatio * 50);
    }

    return score.clamp(0.0, 100.0);
  }

  // Predict next month balance
  double predictNextMonthBalance() {
    final now = DateTime.now();
    final currentMonthSummary = calculateMonthlySummary(now.year, now.month);
    final lastMonthSummary = calculateMonthlySummary(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
    );

    final currentNet = currentMonthSummary['net']!;
    final lastNet = lastMonthSummary['net']!;

    // Simple prediction: average of last two months
    return (currentNet + lastNet) / 2;
  }

  // Get balance trend (last 6 months)
  Map<String, double> getBalanceTrend() {
    final now = DateTime.now();
    final Map<String, double> trend = {};

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i);
      final summary = calculateMonthlySummary(date.year, date.month);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      trend[monthKey] = summary['net']!;
    }

    return trend;
  }
}
