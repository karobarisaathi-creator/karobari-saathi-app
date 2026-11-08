import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/quick_bill_trust_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _bill({
  required String id,
  required String accountId,
  required double total,
  required double received,
  required double pending,
  String type = 'income',
}) {
  final date = DateTime(2026, 11, 1);
  return Transaction(
    id: id,
    accountId: accountId,
    amount: pending,
    type: type,
    category: 'Sale',
    description: 'Sale',
    date: date,
    referenceNumber: 'QB-$id',
    receivedAmount: received,
    pendingAmount: pending,
    isPending: pending > 0,
    subtotal: total,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('QuickBillTrustMetrics', () {
    test('counts buyers and considers repeat buyers satisfied', () {
      final metrics = QuickBillTrustMetrics.fromTransactions([
        _bill(
          id: 'partial',
          accountId: 'customer-1',
          total: 100,
          received: 80,
          pending: 20,
        ),
        _bill(
          id: 'paid',
          accountId: 'customer-1',
          total: 100,
          received: 100,
          pending: 0,
        ),
        _bill(
          id: 'new-customer',
          accountId: 'customer-2',
          total: 100,
          received: 0,
          pending: 100,
        ),
        _bill(
          id: 'cash',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 100,
          received: 100,
          pending: 0,
        ),
      ]);

      expect(metrics.billCount, 4);
      expect(metrics.customerCount, 2);
      expect(metrics.satisfiedCustomerPercent, 50);
      expect(
        QuickBillTrustMetrics.isFullyPaid(
          _bill(
            id: 'partial-check',
            accountId: 'customer-1',
            total: 100,
            received: 80,
            pending: 20,
          ),
        ),
        isFalse,
      );
    });

    test('does not count cash sales as customers', () {
      final metrics = QuickBillTrustMetrics.fromTransactions([
        _bill(
          id: 'cash',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 100,
          received: 100,
          pending: 0,
        ),
      ]);

      expect(metrics.customerCount, 0);
      expect(metrics.satisfiedCustomerPercent, 0);
    });

    test('ignores expenses and returns zero metrics when there are no sales',
        () {
      final metrics = QuickBillTrustMetrics.fromTransactions([
        _bill(
          id: 'purchase',
          accountId: 'supplier',
          total: 100,
          received: 100,
          pending: 0,
          type: 'expense',
        ),
      ]);

      expect(metrics.billCount, 0);
      expect(metrics.customerCount, 0);
      expect(metrics.satisfiedCustomerPercent, 0);
    });
  });
}
