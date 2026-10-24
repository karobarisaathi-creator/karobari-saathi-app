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
  bool receiptFromCounterparty = false,
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
    receiptFromCounterparty: receiptFromCounterparty,
  );
}

void main() {
  group('AccountBalanceUtils.transactionColumns', () {
    test('shows imported received income in debit, like incoming receipt', () {
      final transaction = _transaction(
        id: 'imported-income',
        type: 'expense',
        amount: 500,
        subtotal: 500,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );

      final columns = AccountBalanceUtils.transactionColumns(transaction);

      expect(columns.firstColumn, 500);
      expect(columns.secondColumn, 0);
    });

    test('shows imported paid expense in credit, like incoming receipt', () {
      final transaction = _transaction(
        id: 'imported-expense',
        type: 'income',
        amount: 500,
        subtotal: 500,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );

      final columns = AccountBalanceUtils.transactionColumns(transaction);

      expect(columns.firstColumn, 0);
      expect(columns.secondColumn, 500);
    });

    test(
        'keeps imported Quick Bill items and payment in their incoming columns',
        () {
      final transaction = _transaction(
        id: 'imported-sale',
        type: 'expense',
        amount: 600,
        subtotal: 1000,
        discountAmount: 100,
        receivedAmount: 300,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
        description: 'Quick Bill',
      );

      final columns = AccountBalanceUtils.transactionColumns(transaction);

      expect(columns.firstColumn, 300);
      expect(columns.secondColumn, 900);
    });
  });

  group('AccountBalanceUtils.ledgerBalance', () {
    test('includes the opening balance and only each transaction balance', () {
      final transactions = [
        _transaction(
          id: 'sale',
          type: 'income',
          amount: 600,
          date: DateTime(2026, 1, 1),
          description: 'Quick Bill',
          receivedAmount: 400,
        ),
        _transaction(
          id: 'payment',
          type: 'expense',
          amount: 100,
          date: DateTime(2026, 1, 2),
        ),
      ];

      expect(
        AccountBalanceUtils.ledgerBalance(
          transactions,
          initialBalance: 250,
        ),
        750,
      );
    });
  });

  group('AccountBalanceUtils.runningBalances', () {
    test('updates each row balance using its debit and credit columns', () {
      final transactions = [
        _transaction(
          id: 'sale',
          type: 'income',
          amount: 1000,
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'imported-received',
          type: 'expense',
          amount: 300,
          receiptFromCounterparty: true,
          date: DateTime(2026, 1, 2),
        ),
      ];

      final balances = AccountBalanceUtils.runningBalances(
        transactions,
        initialBalance: 200,
      );

      expect(balances['sale'], -800);
      expect(balances['imported-received'], -500);
    });
  });

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

    test('counts a partially paid Quick Bill by its outstanding amount', () {
      final quickBill = _transaction(
        id: 'quick-bill',
        type: 'income',
        amount: 600,
        subtotal: 1000,
        receivedAmount: 400,
        pendingAmount: 600,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );

      expect(AccountBalanceUtils.currentCycleBalance([quickBill]), -600);
    });

    test('uses incoming debit columns for imported transactions', () {
      final importedReceived = _transaction(
        id: 'imported-received',
        type: 'expense',
        amount: 500,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );

      expect(AccountBalanceUtils.currentCycleBalance([importedReceived]), -500);
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

      expect(result.openingBalance, -400);
      expect(result.balanceBeforeDiscount, 100);
      expect(result.balanceAfterDiscount, 50);
      expect(result.finalBalance, -50);
    });

    test('subtracts an expense receipt from the account balance', () {
      final receipt = _transaction(
        id: 'expense-receipt',
        type: 'expense',
        amount: 250,
        date: DateTime(2026, 1, 2),
      );
      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [receipt],
        receipt: receipt,
        initialBalance: 800,
      );

      expect(result.openingBalance, 800);
      expect(result.finalBalance, 550);
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

      expect(result.openingBalance, 40);
      expect(result.finalBalance, 140);
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

      expect(result.openingBalance, -300);
      expect(result.finalBalance, -200);
    });

    test('uses a Quick Bill pending amount in a later receipt snapshot', () {
      final quickBill = _transaction(
        id: 'quick-bill',
        type: 'income',
        amount: 600,
        subtotal: 1000,
        receivedAmount: 400,
        pendingAmount: 600,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );
      final receipt = _transaction(
        id: 'receipt',
        type: 'income',
        amount: 100,
        date: DateTime(2026, 1, 2),
      );

      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [quickBill, receipt],
        receipt: receipt,
      );

      expect(result.openingBalance, 600);
      expect(result.finalBalance, 700);
    });

    test('uses imported transaction columns for the opening balance', () {
      final receipt = _transaction(
        id: 'receipt',
        type: 'income',
        amount: 100,
        date: DateTime(2026, 1, 2),
      );
      final importedReceived = _transaction(
        id: 'imported-received',
        type: 'expense',
        amount: 200,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );

      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [importedReceived, receipt],
        receipt: receipt,
      );

      expect(result.openingBalance, 200);
    });
  });
}
