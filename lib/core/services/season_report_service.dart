// lib/core/services/season_report_service.dart

import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/season_report_model.dart';

class SeasonReportService {
  static SeasonReportData buildReport({
    required Profession profession,
    required List<Transaction> transactions,
  }) {
    final seasonTx = transactions.where((tx) => tx.professionId == profession.id).toList();

    double totalIncome = profession.totalIncome;
    double totalExpense = profession.totalExpense;

    Map<String, double> incomeMap = {};
    Map<String, int> incomeCountMap = {};
    Map<String, double> expenseMap = {};
    Map<String, int> expenseCountMap = {};

    for (final tx in seasonTx) {
      final side = tx.professionSide;
      if (side == 'income' || tx.type == 'income') {
        final cat = tx.category.isNotEmpty ? tx.category : 'General';
        incomeMap[cat] = (incomeMap[cat] ?? 0) + tx.amount;
        incomeCountMap[cat] = (incomeCountMap[cat] ?? 0) + 1;
      } else if (side == 'expense' || tx.type == 'expense') {
        final cat = tx.category.isNotEmpty ? tx.category : 'General';
        expenseMap[cat] = (expenseMap[cat] ?? 0) + tx.amount;
        expenseCountMap[cat] = (expenseCountMap[cat] ?? 0) + 1;
      }
    }

    if (incomeMap.isEmpty && totalIncome > 0) {
      incomeMap['Income'] = totalIncome;
      incomeCountMap['Income'] = 1;
    }
    if (expenseMap.isEmpty && totalExpense > 0) {
      expenseMap['Expense'] = totalExpense;
      expenseCountMap['Expense'] = 1;
    }

    final incomeCategories = incomeMap.entries.map((e) => CategoryBreakdown(
      name: e.key,
      amount: e.value,
      isIncome: true,
      entriesCount: incomeCountMap[e.key] ?? 1,
    )).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final expenseCategories = expenseMap.entries.map((e) => CategoryBreakdown(
      name: e.key,
      amount: e.value,
      isIncome: false,
      entriesCount: expenseCountMap[e.key] ?? 1,
    )).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final netProfit = totalIncome - totalExpense;
    final profitMargin = totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0.0;

    final area = profession.areaAcres > 0 ? profession.areaAcres : 1.0;
    final totalLease = profession.rentPerAcre * profession.areaAcres;
    final yieldPerAcre = profession.areaAcres > 0 ? profession.productionMun / profession.areaAcres : 0.0;
    final costPerAcre = totalExpense / area;
    final profitPerAcre = netProfit / area;
    final avgRatePerMun = profession.productionMun > 0 ? totalIncome / profession.productionMun : 0.0;
    final costPerMun = profession.productionMun > 0 ? totalExpense / profession.productionMun : 0.0;

    String healthLabel = 'good';
    final score = profession.performanceScore;
    if (score >= 80) healthLabel = 'excellent';
    else if (score >= 60) healthLabel = 'good';
    else if (score >= 40) healthLabel = 'fair';
    else healthLabel = 'poor';

    List<MapEntry<String, MapEntry<double, double>>> budgetOverruns = [];
    if (profession.budgetLimits != null) {
      profession.budgetLimits!.forEach((cat, limit) {
        final actual = expenseMap[cat] ?? 0.0;
        if (actual > limit) {
          budgetOverruns.add(MapEntry(cat, MapEntry(limit, actual)));
        }
      });
    }

    return SeasonReportData(
      totalIncome: totalIncome > 0 ? totalIncome : profession.totalIncome,
      totalExpense: totalExpense > 0 ? totalExpense : profession.totalExpense,
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
}
