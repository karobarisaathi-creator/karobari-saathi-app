// lib/core/models/season_report_model.dart

class CategoryBreakdown {
  final String name;
  final double amount;
  final bool isIncome;
  final int entriesCount;

  CategoryBreakdown({
    required this.name,
    required this.amount,
    required this.isIncome,
    this.entriesCount = 0,
  });

  double percentOf(double total) {
    if (total <= 0) return 0.0;
    return (amount / total) * 100;
  }
}

class SeasonReportData {
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final double profitMargin;
  final double areaAcres;
  final double productionMun;
  final String healthLabel;
  final List<CategoryBreakdown> incomeCategories;
  final List<CategoryBreakdown> expenseCategories;
  final List<MapEntry<String, MapEntry<double, double>>> budgetOverruns;
  final double rentPerAcre;
  final double totalLease;
  final double yieldPerAcre;
  final double costPerAcre;
  final double profitPerAcre;
  final double avgRatePerMun;
  final double costPerMun;
  final double targetProduction;
  final double benchmarkCostPerUnit;

  SeasonReportData({
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.profitMargin,
    required this.areaAcres,
    required this.productionMun,
    required this.healthLabel,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.budgetOverruns,
    required this.rentPerAcre,
    required this.totalLease,
    required this.yieldPerAcre,
    required this.costPerAcre,
    required this.profitPerAcre,
    required this.avgRatePerMun,
    required this.costPerMun,
    required this.targetProduction,
    required this.benchmarkCostPerUnit,
  });
}
