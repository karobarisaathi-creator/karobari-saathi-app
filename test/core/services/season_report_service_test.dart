import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/season_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

Profession _season({
  double totalIncome = 0,
  double totalExpense = 0,
  Map<String, double>? budgetLimits,
}) {
  final date = DateTime(2026, 1, 1);
  return Profession(
    id: 'season-1',
    name: 'Season 1',
    categories: const [],
    createdAt: date,
    updatedAt: date,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    budgetLimits: budgetLimits,
  );
}

Transaction _transaction({
  required String id,
  required String type,
  required String category,
  required double amount,
  String professionId = 'season-1',
}) {
  final date = DateTime(2026, 1, 1);
  return Transaction(
    id: id,
    accountId: 'account-1',
    amount: amount,
    type: type,
    category: category,
    description: category,
    date: date,
    createdAt: date,
    updatedAt: date,
    professionId: professionId,
  );
}

void main() {
  test('does not use stale cached income when only expense rows exist', () {
    final report = SeasonReportService.buildReport(
      profession: _season(
        totalIncome: 9000,
        totalExpense: 800,
        budgetLimits: const {'Seeds': 100},
      ),
      transactions: [
        _transaction(
          id: 'expense-1',
          type: 'expense',
          category: 'EXP:Seeds',
          amount: 125,
        ),
      ],
    );

    expect(report.totalIncome, 0);
    expect(report.totalExpense, 125);
    expect(report.netProfit, -125);
    expect(report.budgetOverruns, hasLength(1));
    expect(report.budgetOverruns.single.value.value, 125);
  });

  test('uses saved totals when the season has no financial transactions', () {
    final report = SeasonReportService.buildReport(
      profession: _season(totalIncome: 1500, totalExpense: 600),
      transactions: [
        _transaction(
          id: 'other-season-expense',
          type: 'expense',
          category: 'EXP:Seeds',
          amount: 75,
          professionId: 'another-season',
        ),
      ],
    );

    expect(report.totalIncome, 1500);
    expect(report.totalExpense, 600);
    expect(report.netProfit, 900);
    expect(report.incomeCategories.single.entriesCount, 0);
    expect(report.expenseCategories.single.entriesCount, 0);
  });
}
