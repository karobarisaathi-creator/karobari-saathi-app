import 'package:account_app/core/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction map conversion preserves its contract name', () {
    final date = DateTime(2026, 11, 27);
    final transaction = Transaction(
      id: 'contract-payment',
      accountId: 'party',
      amount: 500,
      type: 'income',
      category: 'ٹھیکہ وصولی',
      description: 'Installment',
      date: date,
      createdAt: date,
      updatedAt: date,
      contractId: 'contract-1',
      contractName: 'Shop renovation',
    );

    final restored = Transaction.fromMap(transaction.toMap());

    expect(restored.contractId, 'contract-1');
    expect(restored.contractName, 'Shop renovation');
  });

  test('legacy transaction without a contract name remains readable', () {
    final date = DateTime(2026, 11, 27);
    final restored = Transaction.fromMap({
      'id': 'legacy',
      'accountId': 'party',
      'amount': 100,
      'type': 'income',
      'category': 'other',
      'description': 'Old transaction',
      'date': date.toIso8601String(),
      'createdAt': date.toIso8601String(),
      'updatedAt': date.toIso8601String(),
    });

    expect(restored.contractName, isNull);
  });
}
