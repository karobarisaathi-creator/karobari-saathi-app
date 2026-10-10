// lib/core/services/analytics_service.dart

import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/analytics_model.dart';

class AnalyticsService {
  static List<MonthlyStats> buildMonthlyStats(
    List<Transaction> transactions, {
    required int year,
  }) {
    final Map<int, List<Transaction>> monthMap = {};
    for (int i = 1; i <= 12; i++) {
      monthMap[i] = [];
    }

    for (final tx in transactions) {
      if (tx.date.year == year) {
        monthMap[tx.date.month]?.add(tx);
      }
    }

    List<MonthlyStats> result = [];
    for (int month = 1; month <= 12; month++) {
      final txList = monthMap[month] ?? [];
      double sales = 0;
      double investment = 0;
      var salesCount = 0;
      final salesByDay = <DateTime, double>{};

      for (final tx in txList) {
        final side = tx.professionSide;
        if (side == 'income') {
          sales += tx.amount;
          salesCount++;
          final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
          salesByDay.update(
            day,
            (amount) => amount + tx.amount,
            ifAbsent: () => tx.amount,
          );
        } else if (side == 'expense') {
          investment += tx.amount;
        }
      }

      DateTime? bestSalesDay;
      var bestDaySales = 0.0;
      for (final entry in salesByDay.entries) {
        if (bestSalesDay == null || entry.value > bestDaySales) {
          bestSalesDay = entry.key;
          bestDaySales = entry.value;
        }
      }

      result.add(MonthlyStats(
        year: year,
        month: month,
        sales: sales,
        investment: investment,
        transactionCount: txList.length,
        salesTransactionCount: salesCount,
        bestSalesDay: bestSalesDay,
        bestDaySales: bestDaySales,
      ));
    }

    return result;
  }

  static YearlyStats buildYearlyStats(
    List<Transaction> transactions, {
    required int year,
  }) {
    final months = buildMonthlyStats(transactions, year: year);
    return YearlyStats(year: year, months: months);
  }

  static MonthlyStats getMonthStats(
    List<MonthlyStats> months,
    int year,
    int month,
  ) {
    return months.firstWhere(
      (m) => m.year == year && m.month == month,
      orElse: () => MonthlyStats(
        year: year,
        month: month,
        sales: 0,
        investment: 0,
      ),
    );
  }

  static double getChangePercent(double current, double previous) {
    if (previous == 0) {
      return current > 0 ? 100.0 : 0.0;
    }
    return ((current - previous) / previous.abs()) * 100;
  }
}
