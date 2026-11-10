import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/utils/quick_bill_trust_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _bill({
  required String id,
  required String accountId,
  required double total,
  required double received,
  required double pending,
  String type = 'income',
  List<TransactionItem> items = const [],
  String? customerPhone,
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
    items: items,
    customerPhone: customerPhone,
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
      expect(metrics.returningCustomerCount, 1);
      expect(metrics.repeatProductCustomerCount, 0);
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

    test('counts phone-identified cash buyers and merges account aliases', () {
      final metrics = QuickBillTrustMetrics.fromTransactions([
        _bill(
          id: 'named-customer-old',
          accountId: 'customer-1',
          total: 100,
          received: 100,
          pending: 0,
        ),
        _bill(
          id: 'named-customer-with-phone',
          accountId: 'customer-1',
          total: 100,
          received: 100,
          pending: 0,
          customerPhone: '0300 1234567',
        ),
        _bill(
          id: 'cash-phone-first',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 50,
          received: 50,
          pending: 0,
          customerPhone: '+923001234567',
        ),
        _bill(
          id: 'cash-phone-second',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 50,
          received: 50,
          pending: 0,
          customerPhone: '0300-7654321',
        ),
        _bill(
          id: 'cash-phone-second-repeat',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 50,
          received: 50,
          pending: 0,
          customerPhone: '+923007654321',
        ),
        _bill(
          id: 'anonymous-cash',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 50,
          received: 50,
          pending: 0,
        ),
      ]);

      expect(metrics.billCount, 6);
      expect(metrics.customerCount, 2);
      expect(metrics.returningCustomerCount, 2);
      expect(metrics.satisfiedCustomerPercent, 100);
    });

    test('counts customers who bought the same stock item on separate bills',
        () {
      TransactionItem item(String id) => TransactionItem(
            description: 'Item $id',
            quantity: 1,
            rate: 10,
            total: 10,
            stockItemId: id,
          );

      final metrics = QuickBillTrustMetrics.fromTransactions([
        _bill(
          id: 'customer-1-first',
          accountId: 'customer-1',
          total: 10,
          received: 10,
          pending: 0,
          items: [item('item-a'), item('item-a')],
        ),
        _bill(
          id: 'customer-1-second',
          accountId: 'customer-1',
          total: 10,
          received: 10,
          pending: 0,
          items: [item('item-a')],
        ),
        _bill(
          id: 'customer-2',
          accountId: 'customer-2',
          total: 10,
          received: 10,
          pending: 0,
          items: [item('item-a')],
        ),
        _bill(
          id: 'cash-first',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 10,
          received: 10,
          pending: 0,
          items: [item('item-a')],
        ),
        _bill(
          id: 'cash-second',
          accountId: QuickBillTrustMetrics.cashCustomerAccountId,
          total: 10,
          received: 10,
          pending: 0,
          items: [item('item-a')],
        ),
      ]);

      expect(metrics.returningCustomerCount, 1);
      expect(metrics.repeatProductCustomerCount, 1);
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
