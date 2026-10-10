import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';

Transaction _transaction({
  required String id,
  required String type,
  required double amount,
  required DateTime date,
  DateTime? createdAt,
  double? subtotal,
  double discountAmount = 0,
  double receivedAmount = 0,
  double pendingAmount = 0,
  String description = 'Transaction',
}) {
  return Transaction(
    id: id,
    accountId: 'party',
    amount: amount,
    type: type,
    category: 'Sale',
    description: description,
    date: date,
    createdAt: createdAt ?? date,
    updatedAt: date,
    subtotal: subtotal,
    discountAmount: discountAmount,
    receivedAmount: receivedAmount,
    pendingAmount: pendingAmount,
  );
}

void main() {
  group('AccountBalanceUtils.currentCycleBalance', () {
    test('returns the outstanding amount after completed cycles', () {
      final transactions = [
        _transaction(
          id: 'sale-1',
          type: 'income',
          amount: 1000,
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'payment-1',
          type: 'expense',
          amount: 1000,
          date: DateTime(2026, 1, 2),
        ),
        _transaction(
          id: 'sale-2',
          type: 'income',
          amount: 400,
          date: DateTime(2026, 1, 3),
        ),
        _transaction(
          id: 'payment-2',
          type: 'expense',
          amount: 100,
          date: DateTime(2026, 1, 4),
        ),
      ];

      expect(AccountBalanceUtils.currentCycleBalance(transactions), 300);
    });

    test('returns zero when the ledger is settled', () {
      final transactions = [
        _transaction(
          id: 'sale',
          type: 'income',
          amount: 750,
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'payment',
          type: 'expense',
          amount: 750,
          date: DateTime(2026, 1, 2),
        ),
      ];

      expect(AccountBalanceUtils.currentCycleBalance(transactions), 0);
    });
  });

  group('AccountBalanceUtils.receiptBreakdown', () {
    test('uses the balance at the receipt date and applies adjustments', () {
      final receipt = _transaction(
        id: 'receipt',
        type: 'income',
        amount: 450,
        subtotal: 500,
        discountAmount: 50,
        receivedAmount: 100,
        pendingAmount: 350,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 3),
      );
      final transactions = [
        _transaction(
          id: 'sale',
          type: 'income',
          amount: 1000,
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'payment',
          type: 'expense',
          amount: 600,
          date: DateTime(2026, 1, 2),
        ),
        receipt,
        _transaction(
          id: 'later-payment',
          type: 'expense',
          amount: 700,
          date: DateTime(2026, 1, 4),
        ),
      ];

      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: transactions,
        receipt: receipt,
      );

      expect(result.openingBalance, 400);
      expect(result.balanceBeforeDiscount, 900);
      expect(result.balanceAfterDiscount, 850);
      expect(result.finalBalance, 750);
    });

    test('orders same-day transactions by creation time', () {
      final sameDay = DateTime(2026, 1, 1);
      final receipt = _transaction(
        id: 'receipt',
        type: 'income',
        amount: 100,
        date: sameDay,
        createdAt: sameDay.add(const Duration(minutes: 2)),
      );
      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [
          _transaction(
            id: 'after',
            type: 'income',
            amount: 500,
            date: sameDay,
            createdAt: sameDay.add(const Duration(minutes: 3)),
          ),
          receipt,
          _transaction(
            id: 'before',
            type: 'expense',
            amount: 40,
            date: sameDay,
            createdAt: sameDay.add(const Duration(minutes: 1)),
          ),
        ],
        receipt: receipt,
      );

      expect(result.openingBalance, -40);
      expect(result.finalBalance, 60);
    });

    test('includes the account opening balance in the receipt snapshot', () {
      final receipt = _transaction(
        id: 'receipt',
        type: 'income',
        amount: 100,
        date: DateTime(2026, 1, 2),
      );
      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [
          _transaction(
            id: 'sale',
            type: 'income',
            amount: 50,
            date: DateTime(2026, 1, 1),
          ),
          receipt,
        ],
        receipt: receipt,
        initialBalance: -250,
      );

      expect(result.openingBalance, -200);
      expect(result.finalBalance, -100);
    });
  });
}
