import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/transaction_model.dart';

Transaction _transaction({
  required String description,
  required double amount,
  required double receivedAmount,
  required double pendingAmount,
}) {
  final now = DateTime(2026, 10, 6);
  return Transaction(
    id: 'test',
    accountId: 'party',
    amount: amount,
    type: 'income',
    category: 'Sale',
    description: description,
    date: now,
    receivedAmount: receivedAmount,
    pendingAmount: pendingAmount,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Transaction account balance amount', () {
    test('Quick Bill contributes only its pending amount to account balance',
        () {
      final transaction = _transaction(
        description: 'Quick bill',
        amount: 600,
        receivedAmount: 400,
        pendingAmount: 600,
      );

      expect(transaction.accountBalanceAmount, 600);
    });

    test('fully received Quick Bill contributes zero to account balance', () {
      final transaction = _transaction(
        description: 'فوری بل',
        amount: 0,
        receivedAmount: 1000,
        pendingAmount: 0,
      );

      expect(transaction.accountBalanceAmount, 0);
    });

    test('non-Quick-Bill transaction keeps its full amount in account balance',
        () {
      final transaction = _transaction(
        description: 'Sale',
        amount: 1000,
        receivedAmount: 400,
        pendingAmount: 600,
      );

      expect(transaction.accountBalanceAmount, 1000);
    });

    test('legacy Quick Bill without payment values uses its full amount', () {
      final transaction = _transaction(
        description: 'Quick bill',
        amount: 1000,
        receivedAmount: 0,
        pendingAmount: 0,
      );

      expect(transaction.accountBalanceAmount, 1000);
    });

    test('preserves counterparty receipt perspective in serialized data', () {
      final transaction = _transaction(
        description: 'Imported transaction',
        amount: 1000,
        receivedAmount: 0,
        pendingAmount: 1000,
      );
      final imported = Transaction.fromMap({
        ...transaction.toMap(),
        'receiptFromCounterparty': true,
      });
      final restored = Transaction.fromMap(imported.toMap());

      expect(restored.receiptFromCounterparty, isTrue);
    });
  });
}
