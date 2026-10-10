class StockMonthlyStats {
  final int year;
  final int month;
  final double salesRevenue;
  final double purchaseValue;
  final double purchaseQuantity;
  final double salesQuantity;
  final double grossProfit;
  final int salesCount;
  final int purchaseCount;
  final double endingStockQuantity;
  final double uncostedSalesQuantity;
  final DateTime? bestSalesDay;
  final double bestDaySales;

  const StockMonthlyStats({
    required this.year,
    required this.month,
    this.salesRevenue = 0,
    this.purchaseValue = 0,
    this.purchaseQuantity = 0,
    this.salesQuantity = 0,
    this.grossProfit = 0,
    this.salesCount = 0,
    this.purchaseCount = 0,
    this.endingStockQuantity = 0,
    this.uncostedSalesQuantity = 0,
    this.bestSalesDay,
    this.bestDaySales = 0,
  });

  double get profitMargin =>
      salesRevenue > 0 ? (grossProfit / salesRevenue) * 100 : 0;

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

class StockYearlyStats {
  final int year;
  final List<StockMonthlyStats> months;

  const StockYearlyStats({required this.year, required this.months});

  double get salesRevenue =>
      months.fold(0, (total, month) => total + month.salesRevenue);
  double get purchaseValue =>
      months.fold(0, (total, month) => total + month.purchaseValue);
  double get purchaseQuantity =>
      months.fold(0, (total, month) => total + month.purchaseQuantity);
  double get salesQuantity =>
      months.fold(0, (total, month) => total + month.salesQuantity);
  double get grossProfit =>
      months.fold(0, (total, month) => total + month.grossProfit);
  int get salesCount =>
      months.fold(0, (total, month) => total + month.salesCount);
  int get purchaseCount =>
      months.fold(0, (total, month) => total + month.purchaseCount);
  double get endingStockQuantity =>
      months.isEmpty ? 0 : months.last.endingStockQuantity;
  double get uncostedSalesQuantity =>
      months.fold(0, (total, month) => total + month.uncostedSalesQuantity);
  double get profitMargin =>
      salesRevenue > 0 ? (grossProfit / salesRevenue) * 100 : 0;

  double averageMonthlySales({required int throughMonth}) {
    if (throughMonth < 1) return 0;
    final elapsedMonths = throughMonth.clamp(1, 12);
    final revenue = months
        .where((month) => month.month <= elapsedMonths)
        .fold(0.0, (total, month) => total + month.salesRevenue);
    return revenue / elapsedMonths;
  }

  StockMonthlyStats? get bestMonth {
    if (months.isEmpty) return null;
    var best = months.first;
    for (final month in months.skip(1)) {
      if (month.salesRevenue > best.salesRevenue) best = month;
    }
    return best;
  }
}

class StockItemStats {
  final String itemId;
  final String name;
  final String nameUrdu;
  final String unit;
  final double purchaseQuantity;
  final double salesQuantity;
  final double purchaseValue;
  final double salesRevenue;
  final double grossProfit;
  final double endingStockQuantity;
  final double uncostedSalesQuantity;

  const StockItemStats({
    required this.itemId,
    required this.name,
    this.nameUrdu = '',
    required this.unit,
    this.purchaseQuantity = 0,
    this.salesQuantity = 0,
    this.purchaseValue = 0,
    this.salesRevenue = 0,
    this.grossProfit = 0,
    this.endingStockQuantity = 0,
    this.uncostedSalesQuantity = 0,
  });

  double get profitMargin =>
      salesRevenue > 0 ? (grossProfit / salesRevenue) * 100 : 0;
}

class StockPartyStats {
  final String partyId;
  final String partyName;
  final bool isSale;
  final double totalValue;
  final List<StockPartyItemStats> items;

  const StockPartyStats({
    required this.partyId,
    required this.partyName,
    required this.isSale,
    required this.totalValue,
    required this.items,
  });
}

class StockPartyItemStats {
  final String itemId;
  final String itemName;
  final String itemNameUrdu;
  final String unit;
  final double quantity;
  final double value;

  const StockPartyItemStats({
    required this.itemId,
    required this.itemName,
    this.itemNameUrdu = '',
    required this.unit,
    required this.quantity,
    required this.value,
  });
}
