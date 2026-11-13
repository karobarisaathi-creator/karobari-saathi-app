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
  String? partnershipId,
  String category = 'Sale',
  String description = 'Transaction',
}) {
  return Transaction(
    id: id,
    accountId: 'party',
    amount: amount,
    type: type,
    category: category,
    description: description,
    date: date,
    createdAt: createdAt ?? date,
    updatedAt: date,
    subtotal: subtotal,
    discountAmount: discountAmount,
    receivedAmount: receivedAmount,
    pendingAmount: pendingAmount,
    receiptFromCounterparty: receiptFromCounterparty,
    partnershipId: partnershipId,
  );
}

void main() {
  group('AccountBalanceUtils.partySettlementDescription', () {
    test('describes local receipt and its mirrored payment in Urdu', () {
      expect(
        AccountBalanceUtils.partySettlementDescription(
          type: 'income',
          paymentMethod: 'cash',
          isUrdu: true,
        ),
        'پارٹی سے وصولی - نقد',
      );
      expect(
        AccountBalanceUtils.partySettlementDescription(
          type: 'expense',
          paymentMethod: 'bank_transfer',
          isUrdu: true,
        ),
        'پارٹی کو ادائیگی - بینک',
      );
    });

    test('labels supported settlement methods in English', () {
      expect(
        AccountBalanceUtils.partySettlementDescription(
          type: 'expense',
          paymentMethod: 'mobile_wallet',
          isUrdu: false,
        ),
        'Payment to party - Mobile wallet',
      );
      expect(
        AccountBalanceUtils.partySettlementDescription(
          type: 'income',
          paymentMethod: 'cheque',
          isUrdu: false,
        ),
        'Receipt from party - Cheque',
      );
    });
  });

  group('AccountBalanceUtils.transactionColumns', () {
    test('mirrors both directions of ordinary transactions', () {
      final localIncome = _transaction(
        id: 'local-income',
        type: 'income',
        amount: 100,
        date: DateTime(2026, 1, 1),
      );
      final incomingExpense = _transaction(
        id: 'incoming-expense',
        type: 'expense',
        amount: 100,
        subtotal: 100,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );
      final localExpense = _transaction(
        id: 'local-expense',
        type: 'expense',
        amount: 100,
        date: DateTime(2026, 1, 1),
      );
      final incomingIncome = _transaction(
        id: 'incoming-income',
        type: 'income',
        amount: 100,
        subtotal: 100,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );

      final localIncomeColumns =
          AccountBalanceUtils.transactionColumns(localIncome);
      final incomingExpenseColumns =
          AccountBalanceUtils.transactionColumns(incomingExpense);
      final localExpenseColumns =
          AccountBalanceUtils.transactionColumns(localExpense);
      final incomingIncomeColumns =
          AccountBalanceUtils.transactionColumns(incomingIncome);

      expect(localIncomeColumns.debit, incomingExpenseColumns.credit);
      expect(localIncomeColumns.credit, incomingExpenseColumns.debit);
      expect(localExpenseColumns.debit, incomingIncomeColumns.credit);
      expect(localExpenseColumns.credit, incomingIncomeColumns.debit);
    });

    test('mirrors Quick Bill columns, including partial payment', () {
      final localBill = _transaction(
        id: 'local-bill',
        type: 'income',
        amount: 700,
        subtotal: 1000,
        receivedAmount: 300,
        pendingAmount: 700,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );
      final incomingBill = _transaction(
        id: 'incoming-bill',
        type: 'expense',
        amount: 700,
        subtotal: 1000,
        receivedAmount: 300,
        pendingAmount: 700,
        receiptFromCounterparty: true,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );

      final localColumns = AccountBalanceUtils.transactionColumns(localBill);
      final incomingColumns =
          AccountBalanceUtils.transactionColumns(incomingBill);

      expect(localColumns.debit, incomingColumns.credit);
      expect(localColumns.credit, incomingColumns.debit);
      expect(AccountBalanceUtils.currentCycleBalance([localBill]), 700);
      expect(AccountBalanceUtils.currentCycleBalance([incomingBill]), -700);
    });

    test('places a local settlement in exactly one ledger column', () {
      final settlement = _transaction(
        id: 'local-receipt',
        type: 'income',
        amount: 100,
        receivedAmount: 100,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 1),
      );

      final columns = AccountBalanceUtils.transactionColumns(settlement);

      expect(columns.debit, 0);
      expect(columns.credit, 100);
      expect(AccountBalanceUtils.currentCycleBalance([settlement]), -100);
    });

    test('places an incoming payment settlement in the debit column', () {
      final settlement = _transaction(
        id: 'incoming-receipt',
        type: 'expense',
        amount: 100,
        receivedAmount: 100,
        receiptFromCounterparty: true,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 1),
      );

      final columns = AccountBalanceUtils.transactionColumns(settlement);

      expect(columns.debit, 100);
      expect(columns.credit, 0);
      expect(AccountBalanceUtils.currentCycleBalance([settlement]), 100);
    });

    test('mirrors payment settlements into opposite ledger columns', () {
      final localPayment = _transaction(
        id: 'local-payment',
        type: 'expense',
        amount: 100,
        receivedAmount: 100,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 1),
      );
      final incomingPayment = _transaction(
        id: 'incoming-payment',
        type: 'income',
        amount: 100,
        receivedAmount: 100,
        receiptFromCounterparty: true,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 1),
      );

      final localColumns = AccountBalanceUtils.transactionColumns(localPayment);
      final incomingColumns =
          AccountBalanceUtils.transactionColumns(incomingPayment);

      expect(localColumns.debit, incomingColumns.credit);
      expect(localColumns.credit, incomingColumns.debit);
    });

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

      expect(columns.debit, 500);
      expect(columns.credit, 0);
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

      expect(columns.debit, 0);
      expect(columns.credit, 500);
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

      expect(columns.debit, 300);
      expect(columns.credit, 900);
    });

    test('keeps both sides for an incoming ordinary partial transaction', () {
      final transaction = _transaction(
        id: 'imported-partial',
        type: 'expense',
        amount: 400,
        subtotal: 500,
        receivedAmount: 100,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );

      final columns = AccountBalanceUtils.transactionColumns(transaction);
      final receiptBalance = AccountBalanceUtils.receiptBreakdown(
        transactions: [transaction],
        receipt: transaction,
      );

      expect(columns.debit, 500);
      expect(columns.credit, 100);
      expect(
        receiptBalance.finalBalance,
        columns.debit - columns.credit,
      );
    });
  });

  group('AccountBalanceUtils.receiptSubtotalIsDebit', () {
    test(
        'outgoing settlement receipts put collection in credit and payment in debit',
        () {
      final receipt = _transaction(
        id: 'outgoing-receipt',
        type: 'income',
        amount: 100,
        receivedAmount: 100,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 1),
      );
      final payment = _transaction(
        id: 'outgoing-payment',
        type: 'expense',
        amount: 100,
        receivedAmount: 100,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 1),
      );

      expect(
        AccountBalanceUtils.receiptSubtotalIsDebit(receipt),
        isFalse,
      );
      expect(
        AccountBalanceUtils.receiptSubtotalIsDebit(payment),
        isTrue,
      );
    });

    test('matches the saved side for both incoming Quick Bill directions', () {
      final counterpartyIncome = _transaction(
        id: 'counterparty-income',
        type: 'expense',
        amount: 70,
        subtotal: 100,
        receivedAmount: 30,
        receiptFromCounterparty: true,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );
      final counterpartyExpense = _transaction(
        id: 'counterparty-expense',
        type: 'income',
        amount: 70,
        subtotal: 100,
        receivedAmount: 30,
        receiptFromCounterparty: true,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );

      expect(
        AccountBalanceUtils.receiptSubtotalIsDebit(counterpartyIncome),
        isFalse,
      );
      expect(
        AccountBalanceUtils.receiptSubtotalIsDebit(counterpartyExpense),
        isTrue,
      );
    });

    test('preserves the existing outgoing receipt sides', () {
      final sale = _transaction(
        id: 'sale',
        type: 'income',
        amount: 100,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );
      final expense = _transaction(
        id: 'expense',
        type: 'expense',
        amount: 100,
        date: DateTime(2026, 1, 1),
      );

      expect(
        AccountBalanceUtils.receiptSubtotalIsDebit(sale),
        isTrue,
      );
      expect(
        AccountBalanceUtils.receiptSubtotalIsDebit(expense),
        isTrue,
      );
    });

    test('places Quick Bill purchase subtotals on the saved Credit side', () {
      final localPurchase = _transaction(
        id: 'local-purchase',
        type: 'expense',
        amount: 700,
        subtotal: 1000,
        receivedAmount: 300,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );
      final incomingPurchase = _transaction(
        id: 'incoming-purchase',
        type: 'income',
        amount: 700,
        subtotal: 1000,
        receivedAmount: 300,
        receiptFromCounterparty: true,
        description: 'Quick Bill',
        date: DateTime(2026, 1, 1),
      );

      final localColumns =
          AccountBalanceUtils.transactionColumns(localPurchase);
      final incomingColumns =
          AccountBalanceUtils.transactionColumns(incomingPurchase);

      expect(localColumns.debit, 300);
      expect(localColumns.credit, 1000);
      expect(incomingColumns.debit, 1000);
      expect(incomingColumns.credit, 300);
      expect(
          AccountBalanceUtils.receiptSubtotalIsDebit(localPurchase), isFalse);
      expect(
        AccountBalanceUtils.receiptSubtotalIsDebit(incomingPurchase),
        isTrue,
      );
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
        550,
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
    test('keeps Debit and Credit totals on their matching cycle fields', () {
      final debitTransaction = _transaction(
        id: 'debit',
        type: 'expense',
        amount: 100,
        date: DateTime(2026, 1, 1),
      );
      final creditTransaction = _transaction(
        id: 'credit',
        type: 'income',
        amount: 40,
        date: DateTime(2026, 1, 2),
      );

      final cycle = AccountBalanceUtils.currentCycle(
          [debitTransaction, creditTransaction]);

      expect(cycle.debit, 100);
      expect(cycle.credit, 40);
      expect(cycle.balance, 60);
    });

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

      expect(AccountBalanceUtils.currentCycleBalance(transactions), -300);
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

      expect(AccountBalanceUtils.currentCycleBalance([quickBill]), 600);
    });

    test('uses incoming debit columns for imported transactions', () {
      final importedReceived = _transaction(
        id: 'imported-received',
        type: 'expense',
        amount: 500,
        receiptFromCounterparty: true,
        date: DateTime(2026, 1, 1),
      );

      expect(AccountBalanceUtils.currentCycleBalance([importedReceived]), 500);
    });
  });

  group('AccountBalanceUtils.receiptBreakdown', () {
    test('includes older transactions with a legacy partnership id', () {
      final previousBill = _transaction(
        id: 'legacy-bill',
        type: 'expense',
        amount: 100,
        date: DateTime(2026, 1, 1),
        partnershipId: 'old-partnership',
      );
      final receipt = _transaction(
        id: 'receipt',
        type: 'income',
        amount: 30,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 2),
      );

      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [previousBill, receipt],
        receipt: receipt,
      );

      expect(result.openingBalance, 100);
      expect(result.finalBalance, 70);
    });

    test('uses the Party Details Debit minus Credit sign for every receipt',
        () {
      final receipts = [
        _transaction(
          id: 'income',
          type: 'income',
          amount: 100,
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'expense',
          type: 'expense',
          amount: 100,
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'quick-sale',
          type: 'income',
          amount: 70,
          subtotal: 100,
          receivedAmount: 30,
          description: 'Quick Bill',
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'quick-purchase',
          type: 'expense',
          amount: 70,
          subtotal: 100,
          receivedAmount: 30,
          description: 'Quick Bill',
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'incoming-sale',
          type: 'expense',
          amount: 70,
          subtotal: 100,
          receivedAmount: 30,
          receiptFromCounterparty: true,
          description: 'Quick Bill',
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'settlement',
          type: 'expense',
          amount: 100,
          category: AccountBalanceUtils.partySettlementCategory,
          date: DateTime(2026, 1, 1),
        ),
      ];

      for (final receipt in receipts) {
        final columns = AccountBalanceUtils.transactionColumns(receipt);
        final result = AccountBalanceUtils.receiptBreakdown(
          transactions: [receipt],
          receipt: receipt,
          initialBalance: 250,
        );

        expect(result.finalBalance, 250 + columns.debit - columns.credit);
      }
    });

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
      expect(result.finalBalance, 1050);
    });

    test('reduces supplier payable once for a settlement', () {
      final receipt = _transaction(
        id: 'supplier-payment',
        type: 'expense',
        amount: 100,
        receivedAmount: 100,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 2),
      );
      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [receipt],
        receipt: receipt,
        initialBalance: -500,
      );

      expect(result.openingBalance, -500);
      expect(result.finalBalance, -400);
    });

    test('reduces customer receivable once for a settlement', () {
      final receipt = _transaction(
        id: 'customer-receipt',
        type: 'income',
        amount: 100,
        receivedAmount: 100,
        category: AccountBalanceUtils.partySettlementCategory,
        date: DateTime(2026, 1, 2),
      );
      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [receipt],
        receipt: receipt,
        initialBalance: 500,
      );

      expect(result.openingBalance, 500);
      expect(result.finalBalance, 400);
    });

    test('matches the party-ledger balance for a new supplier transaction', () {
      final purchase = _transaction(
        id: 'supplier-purchase',
        type: 'expense',
        amount: 10000,
        date: DateTime(2026, 1, 2),
      );
      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [purchase],
        receipt: purchase,
        initialBalance: -7000,
      );

      expect(result.openingBalance, -7000);
      expect(result.finalBalance, 3000);
    });

    test('applies preceding transactions using Party Details columns', () {
      final previousPurchase = _transaction(
        id: 'previous-purchase',
        type: 'expense',
        amount: 10000,
        date: DateTime(2026, 1, 1),
      );
      final purchase = _transaction(
        id: 'supplier-purchase',
        type: 'expense',
        amount: 0,
        date: DateTime(2026, 1, 2),
      );
      final result = AccountBalanceUtils.receiptBreakdown(
        transactions: [previousPurchase, purchase],
        receipt: purchase,
        initialBalance: -7000,
      );

      expect(result.openingBalance, 3000);
      expect(result.finalBalance, 3000);
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
      expect(result.finalBalance, -60);
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
      expect(result.finalBalance, -400);
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
      expect(result.finalBalance, 500);
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
