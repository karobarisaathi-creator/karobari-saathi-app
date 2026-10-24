// lib/core/models/analytics_model.dart

class MonthlyStats {
  final int year;
  final int month;
  final double sales;
  final double investment;
  final int transactionCount;
  final int salesTransactionCount;
  final DateTime? bestSalesDay;
  final double bestDaySales;

  MonthlyStats({
    required this.year,
    required this.month,
    required this.sales,
    required this.investment,
    this.transactionCount = 0,
    this.salesTransactionCount = 0,
    this.bestSalesDay,
    this.bestDaySales = 0,
  });

  double get profit => sales - investment;
  double get profitMargin => sales > 0 ? (profit / sales) * 100 : 0.0;

  String get monthName {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String get monthNameUrdu {
    const months = [
      'جنوری',
      'فروری',
      'مارچ',
      'اپریل',
      'مئی',
      'جون',
      'جولائی',
      'اگست',
      'ستمبر',
      'اکتوبر',
      'نومبر',
      'دسمبر',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

class YearlyStats {
  final int year;
  final List<MonthlyStats> months;

  YearlyStats({
    required this.year,
    required this.months,
  });

  double get sales => months.fold(0.0, (sum, m) => sum + m.sales);
  double get investment => months.fold(0.0, (sum, m) => sum + m.investment);
  double get profit => sales - investment;
  double get profitMargin => sales > 0 ? (profit / sales) * 100 : 0.0;

  double averageMonthlySales({required int throughMonth}) {
    if (throughMonth < 1) return 0;
    final elapsedMonths = throughMonth.clamp(1, 12);
    final salesToDate = months
        .where((month) => month.month <= elapsedMonths)
        .fold(0.0, (total, month) => total + month.sales);
    return salesToDate / elapsedMonths;
  }

  MonthlyStats? get bestMonth {
    if (months.isEmpty) return null;
    MonthlyStats? best;
    for (final m in months) {
      if (best == null || m.sales > best.sales) {
        best = m;
      }
    }
    return best;
  }
}
