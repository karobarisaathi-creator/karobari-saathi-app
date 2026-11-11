import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/party_ledger_metrics.dart';
import 'package:account_app/features/accounts/widgets/party_tools_grid_widget.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _transaction({
  required String id,
  required String type,
  required double amount,
  required DateTime date,
  double subtotal = 0,
  double received = 0,
  double pending = 0,
  String? referenceNumber,
  bool receiptFromCounterparty = false,
  String? category,
}) {
  return Transaction(
    id: id,
    accountId: 'party-1',
    amount: amount,
    type: type,
    category: category ?? type,
    description: referenceNumber == null ? type : 'Quick bill',
    date: date,
    subtotal: subtotal,
    receivedAmount: received,
    pendingAmount: pending,
    referenceNumber: referenceNumber,
    receiptFromCounterparty: receiptFromCounterparty,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('PartyLedgerMetrics', () {
    test('allocates account-level receipts to the oldest quick bills first',
        () {
      final now = DateTime.now();
      final olderBill = _transaction(
        id: 'older',
        type: 'income',
        amount: 100,
        subtotal: 100,
        pending: 100,
        date: now.subtract(const Duration(days: 70)),
        referenceNumber: 'QB-1',
      );
      final newerBill = _transaction(
        id: 'newer',
        type: 'income',
        amount: 100,
        subtotal: 100,
        pending: 100,
        date: now.subtract(const Duration(days: 10)),
        referenceNumber: 'QB-2',
      );
      final receipt = _transaction(
        id: 'receipt',
        type: 'expense',
        amount: 120,
        date: now.subtract(const Duration(days: 5)),
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [newerBill, receipt, olderBill],
      );

      expect(metrics.outstandingQuickBills.containsKey('older'), isFalse);
      expect(metrics.outstandingQuickBills['newer'], 80);
      expect(metrics.outstandingBalance, 80);
      expect(metrics.totalBilled, 200);
      expect(metrics.totalReceived, 120);
      expect(metrics.overdueBalance, 0);
    });

    test('reports aging and unknown-age opening balances separately', () {
      final now = DateTime.now();
      final oldBill = _transaction(
        id: 'old-bill',
        type: 'income',
        amount: 100,
        subtotal: 100,
        pending: 100,
        date: now.subtract(const Duration(days: 100)),
        referenceNumber: 'QB-1',
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [oldBill],
        openingBalance: 40,
      );

      expect(metrics.outstandingBalance, 140);
      expect(metrics.overdueBalance, 100);
      expect(metrics.unknownAgeBalance, 40);
      expect(metrics.agingScore, closeTo(25, 0.01));
    });

    test('uses supplier purchase and payment directions', () {
      final now = DateTime.now();
      final metrics = PartyLedgerMetrics.calculate(
        partyCategory: 'supplier',
        transactions: [
          _transaction(
            id: 'purchase',
            type: 'expense',
            amount: 80,
            date: now.subtract(const Duration(days: 2)),
          ),
          _transaction(
            id: 'payment',
            type: 'income',
            amount: 30,
            date: now,
          ),
        ],
      );

      expect(metrics.totalBilled, 80);
      expect(metrics.totalReceived, 30);
      expect(metrics.outstandingBalance, 50);
    });

    test('applies opening advances to future customer bills', () {
      final bill = _transaction(
        id: 'bill',
        type: 'income',
        amount: 75,
        subtotal: 75,
        pending: 75,
        date: DateTime.now(),
        referenceNumber: 'QB-1',
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [bill],
        openingBalance: 100,
        balanceType: 'payable',
      );

      expect(metrics.outstandingBalance, -25);
      expect(metrics.outstandingQuickBills, isEmpty);
      expect(metrics.totalReceived, 75);
    });

    test('applies a newly recorded customer receipt to open bills', () {
      final now = DateTime.now();
      final bill = _transaction(
        id: 'bill',
        type: 'income',
        amount: 100,
        subtotal: 100,
        pending: 100,
        date: now.subtract(const Duration(days: 40)),
        referenceNumber: 'QB-1',
      );
      final receipt = _transaction(
        id: 'receipt',
        type: 'income',
        amount: 40,
        received: 40,
        date: now,
        category: AccountBalanceUtils.partySettlementCategory,
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [bill, receipt],
      );

      expect(metrics.outstandingBalance, 60);
      expect(metrics.outstandingQuickBills['bill'], 60);
      expect(metrics.totalReceived, 40);
      expect(metrics.overdueBalance, 60);
    });

    test('respects counterparty receipts as a reversed ledger entry', () {
      final now = DateTime.now();
      final metrics = PartyLedgerMetrics.calculate(
        partyCategory: 'supplier',
        transactions: [
          _transaction(
            id: 'counterparty-bill',
            type: 'income',
            amount: 90,
            received: 10,
            date: now,
            receiptFromCounterparty: true,
          ),
        ],
      );

      expect(metrics.totalBilled, 80);
      expect(metrics.outstandingBalance, 80);
    });
  });

  group('PartyTrustMetrics', () {
    test('does not count supplier purchases as payments received', () {
      final now = DateTime.now();
      final party = Account(
        id: 'party-1',
        name: 'Supplier',
        phone: '',
        category: 'supplier',
        initialBalance: 0,
        balanceType: 'receivable',
        balance: -100,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = PartyTrustMetrics.calculate(
        party: party,
        transactions: [
          _transaction(
            id: 'purchase',
            type: 'expense',
            amount: 100,
            date: now,
          ),
        ],
        isUrdu: false,
      );

      expect(metrics.isSupplier, isTrue);
      expect(metrics.totalBilled, 100);
      expect(metrics.totalReceived, 0);
      expect(metrics.outstandingBalance, 100);
      expect(metrics.paymentScore, 0);
    });

    test('shows an empty history as insufficient instead of perfect', () {
      final now = DateTime.now();
      final party = Account(
        id: 'party-1',
        name: 'New customer',
        phone: '',
        category: 'customer',
        initialBalance: 0,
        balanceType: 'receivable',
        balance: 0,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = PartyTrustMetrics.calculate(
        party: party,
        transactions: const [],
        isUrdu: false,
      );

      expect(metrics.overallScore, 50);
      expect(metrics.paymentScore, 50);
      expect(metrics.ratingTitle, contains('no history'));
    });
  });
}
