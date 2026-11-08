import 'package:account_app/core/models/transaction_model.dart';

class QuickBillTrustMetrics {
  static const String cashCustomerAccountId = 'quick_bill_cash_customer';

  final int billCount;
  final int customerCount;
  final int satisfiedCustomerPercent;

  const QuickBillTrustMetrics({
    required this.billCount,
    required this.customerCount,
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

    for (final bill in bills) {
      if (bill.accountId != cashCustomerAccountId) {
        billCountByCustomer.update(
          bill.accountId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final customerCount = billCountByCustomer.length;
    final returningCustomerCount =
        billCountByCustomer.values.where((count) => count > 1).length;

    return QuickBillTrustMetrics(
      billCount: bills.length,
      customerCount: customerCount,
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
