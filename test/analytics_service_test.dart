import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/analytics_service.dart';

Transaction _transaction({
  required String id,
  required String type,
  required String category,
  required double amount,
  required DateTime date,
}) {
  return Transaction(
    id: id,
    accountId: 'account',
    amount: amount,
    type: type,
    category: category,
    description: 'test',
    date: date,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('AnalyticsService', () {
    test('builds sales, expenses, counts, and the true best sales day', () {
      final transactions = [
        _transaction(
          id: 'sale-1',
          type: 'income',
          category: 'Sale',
          amount: 100,
          date: DateTime(2026, 4, 3, 9),
        ),
        _transaction(
          id: 'sale-2',
          type: 'income',
          category: 'Sale',
          amount: 50,
          date: DateTime(2026, 4, 3, 15),
        ),
        _transaction(
          id: 'sale-3',
          type: 'income',
          category: 'Sale',
          amount: 120,
          date: DateTime(2026, 4, 7),
        ),
        _transaction(
          id: 'expense-1',
          type: 'expense',
          category: 'Purchase',
          amount: 40,
          date: DateTime(2026, 4, 7),
        ),
        _transaction(
          id: 'other-year',
          type: 'income',
          category: 'Sale',
          amount: 900,
          date: DateTime(2025, 4, 3),
        ),
      ];

      final stats = AnalyticsService.buildYearlyStats(transactions, year: 2026);
      final april = AnalyticsService.getMonthStats(stats.months, 2026, 4);

      expect(april.sales, 270);
      expect(april.investment, 40);
      expect(april.transactionCount, 4);
      expect(april.salesTransactionCount, 3);
      expect(april.bestSalesDay, DateTime(2026, 4, 3));
      expect(april.bestDaySales, 150);
    });

    test('profession category determines side ahead of ledger type', () {
      final transaction = _transaction(
        id: 'profession-expense',
        type: 'income',
        category: 'EXP:Materials',
        amount: 75,
        date: DateTime(2026, 2, 10),
      );

      final stats =
          AnalyticsService.buildYearlyStats([transaction], year: 2026);
      final february = AnalyticsService.getMonthStats(stats.months, 2026, 2);

      expect(february.sales, 0);
      expect(february.investment, 75);
      expect(february.salesTransactionCount, 0);
      expect(february.bestSalesDay, isNull);
    });

    test('change percentage handles zero baseline without NaN', () {
      expect(AnalyticsService.getChangePercent(0, 0), 0);
      expect(AnalyticsService.getChangePercent(100, 0), 100);
      expect(AnalyticsService.getChangePercent(50, 100), -50);
    });

    test('yearly monthly average includes elapsed months with no sales', () {
      final stats = AnalyticsService.buildYearlyStats([
        _transaction(
          id: 'january-sale',
          type: 'income',
          category: 'Sale',
          amount: 900,
          date: DateTime(2026, 1, 10),
        ),
        _transaction(
          id: 'march-sale',
          type: 'income',
          category: 'Sale',
          amount: 300,
          date: DateTime(2026, 3, 10),
        ),
      ], year: 2026);

      expect(stats.averageMonthlySales(throughMonth: 3), 400);
      expect(stats.averageMonthlySales(throughMonth: 0), 0);
    });
  });
}
