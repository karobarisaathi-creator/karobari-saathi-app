import 'package:account_app/core/models/transaction_model.dart';

class QuickBillTrustMetrics {
  static const String cashCustomerAccountId = 'quick_bill_cash_customer';

  final int billCount;
  final int customerCount;
  final int returningCustomerCount;
  final int repeatProductCustomerCount;
  final int satisfiedCustomerPercent;

  const QuickBillTrustMetrics({
    required this.billCount,
    required this.customerCount,
    this.returningCustomerCount = 0,
    this.repeatProductCustomerCount = 0,
    required this.satisfiedCustomerPercent,
  });

  factory QuickBillTrustMetrics.fromTransactions(
    Iterable<Transaction> transactions,
  ) {
    final bills = transactions
        .where((transaction) =>
            transaction.isQuickBill && transaction.type == 'income')
        .toList();
    final billCountByCustomer = <String, int>{};
    final billsByCustomerAndItem = <String, Map<String, Set<String>>>{};

    for (final bill in bills) {
      final customerId = bill.accountId.trim();
      if (customerId.isEmpty || customerId == cashCustomerAccountId) continue;

      billCountByCustomer.update(
        customerId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );

      final itemBills = billsByCustomerAndItem.putIfAbsent(
        customerId,
        () => <String, Set<String>>{},
      );
      for (final item in bill.items) {
        final stockItemId = item.stockItemId?.trim();
        if (stockItemId == null || stockItemId.isEmpty) continue;
        itemBills.putIfAbsent(stockItemId, () => <String>{}).add(bill.id);
      }
    }

    final customerCount = billCountByCustomer.length;
    final returningCustomerCount =
        billCountByCustomer.values.where((count) => count > 1).length;
    final repeatProductCustomerCount = billsByCustomerAndItem.values
        .where((items) => items.values.any((billIds) => billIds.length > 1))
        .length;

    return QuickBillTrustMetrics(
      billCount: bills.length,
      customerCount: customerCount,
      returningCustomerCount: returningCustomerCount,
      repeatProductCustomerCount: repeatProductCustomerCount,
      satisfiedCustomerPercent: customerCount == 0
          ? 0
          : (returningCustomerCount * 100 / customerCount).round(),
    );
  }

  static double billTotal(Transaction bill) {
    final subtotal = bill.subtotal > 0 ? bill.subtotal : bill.amount;
    return (subtotal - bill.discountAmount).clamp(0, subtotal).toDouble();
  }

  static double amountReceived(Transaction bill) =>
      bill.receivedAmount.clamp(0, billTotal(bill)).toDouble();

  static double outstandingAmount(Transaction bill) =>
      (billTotal(bill) - amountReceived(bill))
          .clamp(0, double.infinity)
          .toDouble();

  static bool isFullyPaid(Transaction bill) => outstandingAmount(bill) <= 0.01;
}
