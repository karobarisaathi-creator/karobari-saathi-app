// lib/core/services/season_report_service.dart

import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/season_report_model.dart';

class SeasonReportService {
  static SeasonReportData buildReport({
    required Profession profession,
    required List<Transaction> transactions,
  }) {
    final seasonTx =
        transactions.where((tx) => tx.professionId == profession.id).toList();

    double calculatedIncome = 0.0;
    double calculatedExpense = 0.0;
    var hasFinancialTransactions = false;

    final incomeMap = <String, double>{};
    final incomeCountMap = <String, int>{};
    final expenseMap = <String, double>{};
    final expenseCountMap = <String, int>{};

    for (final tx in seasonTx) {
      final side = tx.professionSide;
      if (side == 'income') {
        hasFinancialTransactions = true;
        final cat = tx.category.isNotEmpty ? tx.category : 'General';
        incomeMap[cat] = (incomeMap[cat] ?? 0) + tx.amount;
        incomeCountMap[cat] = (incomeCountMap[cat] ?? 0) + 1;
        calculatedIncome += tx.amount;
      } else if (side == 'expense') {
        hasFinancialTransactions = true;
        final cat = tx.category.isNotEmpty ? tx.category : 'General';
        expenseMap[cat] = (expenseMap[cat] ?? 0) + tx.amount;
        expenseCountMap[cat] = (expenseCountMap[cat] ?? 0) + 1;
        calculatedExpense += tx.amount;
      }
    }

    final totalIncome =
        hasFinancialTransactions ? calculatedIncome : profession.totalIncome;
    final totalExpense =
        hasFinancialTransactions ? calculatedExpense : profession.totalExpense;

    if (incomeMap.isEmpty && totalIncome > 0) {
      incomeMap['Income'] = totalIncome;
      incomeCountMap['Income'] = 0;
    }
    if (expenseMap.isEmpty && totalExpense > 0) {
      expenseMap['Expense'] = totalExpense;
      expenseCountMap['Expense'] = 0;
    }

    final incomeCategories = incomeMap.entries.map((e) {
      String cleanName = e.key;
      if (cleanName.startsWith('INC:')) cleanName = cleanName.substring(4);
      if (cleanName.startsWith('EXP:')) cleanName = cleanName.substring(4);
      return CategoryBreakdown(
        name: cleanName,
        amount: e.value,
        isIncome: true,
        entriesCount: incomeCountMap[e.key] ?? 1,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final expenseCategories = expenseMap.entries.map((e) {
      String cleanName = e.key;
      if (cleanName.startsWith('INC:')) cleanName = cleanName.substring(4);
      if (cleanName.startsWith('EXP:')) cleanName = cleanName.substring(4);
      return CategoryBreakdown(
        name: cleanName,
        amount: e.value,
        isIncome: false,
        entriesCount: expenseCountMap[e.key] ?? 1,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final netProfit = totalIncome - totalExpense;
    final profitMargin =
        totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0.0;

    final totalLease = profession.rentPerAcre * profession.areaAcres;
    final yieldPerAcre = profession.areaAcres > 0
        ? profession.productionMun / profession.areaAcres
        : 0.0;
    final costPerAcre =
        profession.areaAcres > 0 ? totalExpense / profession.areaAcres : 0.0;
    final profitPerAcre =
        profession.areaAcres > 0 ? netProfit / profession.areaAcres : 0.0;
    final avgRatePerMun = profession.productionMun > 0
        ? totalIncome / profession.productionMun
        : 0.0;
    final costPerMun = profession.productionMun > 0
        ? totalExpense / profession.productionMun
        : 0.0;

    String healthLabel = 'good';
    final score = profession.performanceScore;
    if (score >= 80) {
      healthLabel = 'excellent';
    } else if (score >= 60) {
      healthLabel = 'good';
    } else if (score >= 40) {
      healthLabel = 'fair';
    } else {
      healthLabel = 'poor';
    }

    List<MapEntry<String, MapEntry<double, double>>> budgetOverruns = [];
    if (profession.budgetLimits != null) {
      profession.budgetLimits!.forEach((cat, limit) {
        final normalizedBudgetCategory = _normalizeCategory(cat).toLowerCase();
        final actual = expenseMap.entries
            .where((entry) =>
                _normalizeCategory(entry.key).toLowerCase() ==
                normalizedBudgetCategory)
            .fold(0.0, (sum, entry) => sum + entry.value);
        if (actual > limit) {
          budgetOverruns.add(MapEntry(cat, MapEntry(limit, actual)));
        }
      });
    }

    return SeasonReportData(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netProfit: netProfit,
      profitMargin: profitMargin,
      areaAcres: profession.areaAcres,
      productionMun: profession.productionMun,
      healthLabel: healthLabel,
      incomeCategories: incomeCategories,
      expenseCategories: expenseCategories,
      budgetOverruns: budgetOverruns,
      rentPerAcre: profession.rentPerAcre,
      totalLease: totalLease,
      yieldPerAcre: yieldPerAcre,
      costPerAcre: costPerAcre,
      profitPerAcre: profitPerAcre,
      avgRatePerMun: avgRatePerMun,
      costPerMun: costPerMun,
      targetProduction: profession.targetProduction,
      benchmarkCostPerUnit: profession.benchmarkCostPerUnit,
    );
  }

  static String _normalizeCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.startsWith('INC:') || trimmed.startsWith('EXP:')) {
      return trimmed.substring(4).trim();
    }
    return trimmed;
  }
}
