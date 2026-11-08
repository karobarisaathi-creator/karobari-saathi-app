import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/transaction_model.dart';

Transaction _transaction({
  required String description,
  required double amount,
  required double receivedAmount,
  required double pendingAmount,
  String type = 'income',
  String category = 'Sale',
}) {
  final now = DateTime(2026, 10, 6);
  return Transaction(
    id: 'test',
    accountId: 'party',
    amount: amount,
    type: type,
    category: category,
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

  test('profession side remains independent from account transaction type', () {
    final transaction = _transaction(
      description: 'Seed purchase',
      amount: 500,
      receivedAmount: 0,
      pendingAmount: 500,
      type: 'income',
      category: 'EXP:Seed',
    );

    expect(transaction.type, 'income');
    expect(transaction.professionSide, 'expense');
  });

  test('identifies quick bills separately from add-transaction entries', () {
    final quickBill = Transaction(
      id: 'quick-bill',
      accountId: 'party',
      amount: 500,
      type: 'income',
      category: 'Sale',
      description: 'Sale',
      date: DateTime(2026, 10, 30),
      referenceNumber: 'QB-12',
      createdAt: DateTime(2026, 10, 30),
      updatedAt: DateTime(2026, 10, 30),
    );
    final addTransaction = _transaction(
      description: 'Sale',
      amount: 500,
      receivedAmount: 0,
      pendingAmount: 500,
    );

    expect(quickBill.isQuickBill, isTrue);
    expect(addTransaction.isQuickBill, isFalse);
  });
}
