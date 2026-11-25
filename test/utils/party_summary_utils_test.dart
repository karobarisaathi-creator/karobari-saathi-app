import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/party_summary_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account({
  required String id,
  required String name,
  String category = 'customer',
  bool isActive = true,
  double initialBalance = 0,
  String balanceType = 'receivable',
}) {
  final date = DateTime(2026, 1, 1);
  return Account(
    id: id,
    name: name,
    phone: '',
    category: category,
    initialBalance: initialBalance,
    balanceType: balanceType,
    balance: 0,
    createdAt: date,
    updatedAt: date,
    isActive: isActive,
  );
}

Transaction _tx({
  required String id,
  required String accountId,
  required String type,
  required double amount,
  double? subtotal,
  double receivedAmount = 0,
  double pendingAmount = 0,
  String category = 'Sale',
  String description = 'Transaction',
  DateTime? date,
}) {
  final txDate = date ?? DateTime(2026, 1, 2);
  return Transaction(
    id: id,
    accountId: accountId,
    amount: amount,
    type: type,
    category: category,
    description: description,
    date: txDate,
    createdAt: txDate,
    updatedAt: txDate,
    subtotal: subtotal,
    receivedAmount: receivedAmount,
    pendingAmount: pendingAmount,
  );
}

void main() {
  group('PartySummaryUtils', () {
    test(
        'excludes cash customer, inactive, and partner accounts from party count and totals',
        () {
      final accounts = [
        _account(id: 'p1', name: 'Customer Ali', category: 'customer'),
        _account(id: 'p2', name: 'Supplier Bilal', category: 'supplier'),
        _account(id: 'w1', name: 'Worker Usman', category: 'worker'),
        _account(
          id: QuickBillConstants.cashCustomerAccountId,
          name: QuickBillConstants.cashCustomerName,
          category: 'نقد گاہک',
        ),
        _account(
          id: 'legacy-cash',
          name: 'Cash Customer',
          category: 'customer',
        ),
        _account(
          id: 'inactive-1',
          name: 'Merged Old Party',
          category: 'general',
          isActive: false,
        ),
        _account(id: 'partner-1', name: 'Business Partner', category: 'Partner'),
      ];

      final transactions = [
        // Customer Ali owes 700 (Quick Bill 1000, paid 300)
        _tx(
          id: 't1',
          accountId: 'p1',
          type: 'income',
          amount: 700,
          subtotal: 1000,
          receivedAmount: 300,
          pendingAmount: 700,
          description: 'Quick Bill',
        ),
        // Supplier Bilal is owed 450 (purchase 450)
        _tx(
          id: 't2',
          accountId: 'p2',
          type: 'income',
          amount: 450,
        ),
        // Worker Usman is owed 200 (wage accrual 500, paid 300)
        _tx(
          id: 't3',
          accountId: 'w1',
          type: 'income',
          amount: 500,
          date: DateTime(2026, 1, 2),
        ),
        _tx(
          id: 't4',
          accountId: 'w1',
          type: 'expense',
          amount: 300,
          date: DateTime(2026, 1, 3),
        ),
        // Cash customer, inactive, and partner transactions must not leak into summary
        _tx(
          id: 't5',
          accountId: QuickBillConstants.cashCustomerAccountId,
          type: 'expense',
          amount: 999,
        ),
        _tx(
          id: 't6',
          accountId: 'inactive-1',
          type: 'expense',
          amount: 888,
        ),
        _tx(
          id: 't7',
          accountId: 'partner-1',
          type: 'income',
          amount: 777,
        ),
      ];

      final summary = PartySummaryUtils.calculateSummary(
        accounts: accounts,
        transactions: transactions,
      );

      expect(summary.partyCount, 3);
      expect(summary.totalReceivable, 700);
      expect(summary.totalPayable, 650);
    });

    test('matches the sum of individual PartyCard balances including initialBalance and settled threshold',
        () {
      final accounts = [
        _account(
          id: 'p1',
          name: 'Opening Receivable',
          initialBalance: 500,
          balanceType: 'receivable',
        ),
        _account(
          id: 'p2',
          name: 'Opening Payable Settled',
          initialBalance: 300,
          balanceType: 'payable',
        ),
        _account(
          id: 'p3',
          name: 'Settled With Dust',
        ),
        _account(
          id: 'p4',
          name: 'Named Like Worker',
          category: 'customer',
        ),
      ];

      final transactions = [
        // p1: 500 opening + 200 debit - 100 settlement = 600 receivable
        _tx(id: 't1', accountId: 'p1', type: 'expense', amount: 200),
        _tx(
          id: 't2',
          accountId: 'p1',
          type: 'income',
          amount: 100,
          receivedAmount: 100,
          category: AccountBalanceUtils.partySettlementCategory,
          date: DateTime(2026, 1, 3),
        ),
        // p2: -300 opening + 300 debit = 0 settled
        _tx(id: 't3', accountId: 'p2', type: 'expense', amount: 300),
        // p3: settled within < 0.01 threshold
        _tx(id: 't4', accountId: 'p3', type: 'expense', amount: 100.004),
        _tx(
          id: 't5',
          accountId: 'p3',
          type: 'income',
          amount: 100,
          date: DateTime(2026, 1, 3),
        ),
        // p4: payable 250
        _tx(id: 't6', accountId: 'p4', type: 'income', amount: 250),
      ];

      final summary = PartySummaryUtils.calculateSummary(
        accounts: accounts,
        transactions: transactions,
      );

      final visibleParties = PartySummaryUtils.filterPartyAccounts(accounts);
      var cardReceivableSum = 0.0;
      var cardPayableSum = 0.0;
      for (final party in visibleParties) {
        final partyTxs = transactions.where((t) => t.accountId == party.id);
        final cardBalance = PartySummaryUtils.partyCardBalance(party, partyTxs);
        if (cardBalance > 0) {
          cardReceivableSum += cardBalance;
        } else if (cardBalance < 0) {
          cardPayableSum += -cardBalance;
        }
      }

      expect(summary.partyCount, visibleParties.length);
      expect(summary.totalReceivable, 600);
      expect(summary.totalPayable, 250);
      expect(summary.totalReceivable, cardReceivableSum);
      expect(summary.totalPayable, cardPayableSum);
    });
  });
}
