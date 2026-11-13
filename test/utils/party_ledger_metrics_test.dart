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
  String? partnershipId,
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
    partnershipId: partnershipId,
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
        type: 'income',
        amount: 120,
        date: now.subtract(const Duration(days: 5)),
        category: AccountBalanceUtils.partySettlementCategory,
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
      expect(metrics.agingScore, 15);
    });

    test('uses the supplied reference date for aging calculations', () {
      final now = DateTime(2025, 4, 11);
      final bill = _transaction(
        id: 'bill',
        type: 'expense',
        amount: 100,
        date: DateTime(2025, 3, 12),
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [bill],
        now: now,
      );

      expect(metrics.overdueBalance, 100);
      expect(metrics.agingScore, 70);
    });

    test('includes legacy transactions carrying an old partnership id', () {
      final transaction = _transaction(
        id: 'legacy-bill',
        type: 'expense',
        amount: 100,
        date: DateTime(2026, 1, 1),
        partnershipId: 'old-partnership',
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [transaction],
      );

      expect(metrics.totalBilled, 100);
      expect(metrics.outstandingBalance, 100);
    });

    test('includes opening due in clearance rate and applies its payment', () {
      final receipt = _transaction(
        id: 'opening-receipt',
        type: 'income',
        amount: 40,
        received: 40,
        date: DateTime.now(),
        category: AccountBalanceUtils.partySettlementCategory,
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [receipt],
        openingBalance: 100,
      );

      expect(metrics.totalBilled, 100);
      expect(metrics.totalReceived, 40);
      expect(metrics.outstandingBalance, 60);
      expect(metrics.unknownAgeBalance, 60);
      expect(metrics.averagePaymentDays, isNull);
    });

    test('uses supplier debit and credit ledger directions', () {
      final now = DateTime.now();
      final metrics = PartyLedgerMetrics.calculate(
        partyCategory: 'supplier',
        transactions: [
          _transaction(
            id: 'supplier-charge',
            type: 'income',
            amount: 80,
            date: now.subtract(const Duration(days: 2)),
          ),
          _transaction(
            id: 'supplier-payment',
            type: 'expense',
            amount: 30,
            date: now,
          ),
        ],
      );

      expect(metrics.totalBilled, 80);
      expect(metrics.totalReceived, 30);
      expect(metrics.outstandingBalance, 50);
    });

    test('recognizes the Urdu supplier category', () {
      final metrics = PartyLedgerMetrics.calculate(
        partyCategory: 'سپلائر',
        transactions: [
          _transaction(
            id: 'supplier-charge',
            type: 'income',
            amount: 80,
            date: DateTime(2025, 1, 1),
          ),
        ],
      );

      expect(metrics.totalBilled, 80);
      expect(metrics.outstandingBalance, 80);
    });

    test('counts customer ordinary income as credit settlement, not a bill',
        () {
      final metrics = PartyLedgerMetrics.calculate(
        transactions: [
          _transaction(
            id: 'customer-income',
            type: 'income',
            amount: 100,
            date: DateTime.now(),
          ),
        ],
      );

      expect(metrics.totalBilled, 0);
      expect(metrics.totalReceived, 100);
      expect(metrics.outstandingBalance, -100);
    });

    test('uses full supplier Quick Bill total and its recorded receipt', () {
      final bill = _transaction(
        id: 'supplier-bill',
        type: 'expense',
        amount: 700,
        subtotal: 1000,
        received: 300,
        pending: 700,
        date: DateTime.now(),
        referenceNumber: 'QB-P1',
      );

      final metrics = PartyLedgerMetrics.calculate(
        partyCategory: 'supplier',
        transactions: [bill],
      );

      expect(metrics.totalBilled, 1000);
      expect(metrics.totalReceived, 300);
      expect(metrics.outstandingBalance, 700);
      expect(metrics.outstandingQuickBills['supplier-bill'], 700);
    });

    test('uses receivedAmount when a settlement amount is zero', () {
      final settlement = _transaction(
        id: 'settlement',
        type: 'expense',
        amount: 0,
        received: 40,
        date: DateTime.now(),
        category: AccountBalanceUtils.partySettlementCategory,
      );

      final metrics = PartyLedgerMetrics.calculate(
        transactions: [settlement],
      );

      expect(metrics.outstandingBalance, 40);
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
      expect(metrics.totalReceived, 0);
      expect(metrics.averagePaymentDays, isNull);
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

    test('counts full, partial, unpaid entries and weights payment days', () {
      final metrics = PartyLedgerMetrics.calculate(
        transactions: [
          _transaction(
            id: 'ordinary-charge',
            type: 'expense',
            amount: 100,
            date: DateTime(2025, 1, 1),
          ),
          _transaction(
            id: 'quick-bill-charge',
            type: 'income',
            amount: 200,
            subtotal: 200,
            pending: 200,
            date: DateTime(2025, 1, 11),
            referenceNumber: 'QB-2',
          ),
          _transaction(
            id: 'receipt',
            type: 'income',
            amount: 150,
            date: DateTime(2025, 1, 21),
            category: AccountBalanceUtils.partySettlementCategory,
          ),
          _transaction(
            id: 'unpaid-charge',
            type: 'expense',
            amount: 50,
            date: DateTime(2025, 2, 1),
          ),
        ],
        now: DateTime(2025, 3, 20),
      );

      expect(metrics.chargeEntryCount, 3);
      expect(metrics.fullyPaidEntries, 1);
      expect(metrics.partiallyPaidEntries, 1);
      expect(metrics.unpaidEntries, 1);
      expect(metrics.averagePaymentDays, closeTo(50 / 3, 0.001));
      expect(metrics.outstandingBalance, 200);
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

      expect(metrics.totalBilled, 90);
      expect(metrics.totalReceived, 10);
      expect(metrics.outstandingBalance, 80);
    });
  });

  group('PartyTrustMetrics', () {
    test('uses the supplied date and revised component weights', () {
      final now = DateTime(2025, 4, 11);
      final party = Account(
        id: 'party-1',
        name: 'Customer',
        phone: '',
        category: 'customer',
        initialBalance: 0,
        balanceType: 'receivable',
        balance: 100,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = PartyTrustMetrics.calculate(
        party: party,
        transactions: [
          _transaction(
            id: 'bill',
            type: 'expense',
            amount: 100,
            date: DateTime(2025, 1, 1),
          ),
        ],
        isUrdu: false,
        now: now,
      );

      expect(metrics.paymentScore, 0);
      expect(metrics.balanceScore, 0);
      expect(metrics.agingScore, 15);
      expect(metrics.paymentTimingScore, 0);
      expect(metrics.fullPaymentScore, 0);
      expect(metrics.overallScore, closeTo(5.25, 0.01));
    });

    test('counts supplier debit as payment under the party ledger columns', () {
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
      expect(metrics.totalBilled, 0);
      expect(metrics.totalReceived, 100);
      expect(metrics.outstandingBalance, -100);
      expect(metrics.paymentScore, 50);
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
      expect(metrics.fullPaymentScore, 50);
      expect(metrics.hasTransactionHistory, isFalse);
      expect(metrics.ratingTitle, contains('no history'));
    });
  });
}
