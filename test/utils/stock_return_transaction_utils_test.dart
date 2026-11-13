import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/stock_return_transaction_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _bill({
  required double amount,
  required double received,
  required double pending,
}) {
  final date = DateTime(2026, 1, 1);
  return Transaction(
    id: 'bill',
    accountId: 'party',
    amount: amount,
    type: 'income',
    category: 'Sale',
    description: 'Quick bill',
    date: date,
    referenceNumber: 'QB-1',
    items: [
      TransactionItem(
        description: 'Item',
        quantity: 10,
        rate: 100,
        total: 1000,
        stockItemId: 'item-1',
      ),
    ],
    subtotal: 1000,
    receivedAmount: received,
    pendingAmount: pending,
    isPending: pending > 0,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('StockReturnTransactionUtils.applyReturn', () {
    test('reduces unpaid due before reducing recorded receipts', () {
      final updated = StockReturnTransactionUtils.applyReturn(
        transaction: _bill(amount: 1000, received: 300, pending: 700),
        stockItemId: 'item-1',
        quantityToReturn: 1,
      );

      expect(updated.amount, 900);
      expect(updated.subtotal, 900);
      expect(updated.receivedAmount, 300);
      expect(updated.pendingAmount, 600);
      expect(updated.isPending, isTrue);
    });

    test('reduces recorded receipts only when return exceeds the bill total',
        () {
      final updated = StockReturnTransactionUtils.applyReturn(
        transaction: _bill(amount: 1000, received: 1000, pending: 0),
        stockItemId: 'item-1',
        quantityToReturn: 1,
      );

      expect(updated.amount, 900);
      expect(updated.receivedAmount, 900);
      expect(updated.pendingAmount, 0);
      expect(updated.isPending, isFalse);
    });

    test('uses the full bill total when the saved amount is only the due', () {
      final updated = StockReturnTransactionUtils.applyReturn(
        transaction: _bill(amount: 700, received: 300, pending: 700),
        stockItemId: 'item-1',
        quantityToReturn: 1,
      );

      expect(updated.amount, 600);
      expect(updated.subtotal, 900);
      expect(updated.receivedAmount, 300);
      expect(updated.pendingAmount, 600);
    });
  });
}
