import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/quick_bill_trust_metrics.dart';

class PartyLedgerMetrics {
  final double totalBilled;
  final double totalReceived;
  final double outstandingBalance;
  final double overdueBalance;
  final double unknownAgeBalance;
  final double agingScore;
  final Map<String, double> outstandingQuickBills;

  const PartyLedgerMetrics({
    required this.totalBilled,
    required this.totalReceived,
    required this.outstandingBalance,
    required this.overdueBalance,
    required this.unknownAgeBalance,
    required this.agingScore,
    required this.outstandingQuickBills,
  });

  factory PartyLedgerMetrics.calculate({
    required Iterable<Transaction> transactions,
    double openingBalance = 0,
    String balanceType = 'receivable',
    String partyCategory = 'customer',
  }) {
    final isSupplier = partyCategory.trim().toLowerCase() == 'supplier';
    final partyDirection = isSupplier ? -1.0 : 1.0;
    final openingDirection =
        balanceType.trim().toLowerCase() == 'payable' ? -1.0 : 1.0;
    final openingDue = openingBalance * openingDirection * partyDirection;

    final sortedTransactions = transactions
        .where((transaction) => transaction.partnershipId == null)
        .toList()
      ..sort(_compareOrder);
    final openEntries = <_OpenLedgerEntry>[];
    var availableCredit = 0.0;
    var totalBilled = 0.0;

    if (openingDue > 0) {
      openEntries.add(_OpenLedgerEntry(
        amount: openingDue,
        date: null,
      ));
    } else if (openingDue < 0) {
      availableCredit = -openingDue;
    }

    void applyCredit(double amount) {
      var remaining = amount;
      // Receipts aren't linked to invoice IDs, so allocate them oldest-first.
      for (final entry in openEntries) {
        if (remaining <= 0.01) break;
        final applied = remaining < entry.amount ? remaining : entry.amount;
        entry.amount -= applied;
        remaining -= applied;
      }
      openEntries.removeWhere((entry) => entry.amount <= 0.01);
      if (remaining > 0.01) availableCredit += remaining;
    }

    for (final transaction in sortedTransactions) {
      if (transaction.category == AccountBalanceUtils.partySettlementCategory) {
        applyCredit(transaction.amount.clamp(0, double.infinity).toDouble());
        continue;
      }

      if (transaction.receiptFromCounterparty && !transaction.isQuickBill) {
        final columns = AccountBalanceUtils.transactionColumns(transaction);
        final dueChange = (columns.debit - columns.credit) * partyDirection;
        if (dueChange > 0) {
          totalBilled += dueChange;
          var due = dueChange;
          if (availableCredit > 0) {
            final applied = availableCredit < due ? availableCredit : due;
            due -= applied;
            availableCredit -= applied;
          }
          if (due > 0.01) {
            openEntries.add(_OpenLedgerEntry(
              amount: due,
              date: transaction.date,
            ));
          }
        } else if (dueChange < 0) {
          applyCredit(-dueChange);
        }
        continue;
      }

      final isCharge = isSupplier
          ? transaction.type == 'expense'
          : transaction.type == 'income';
      final isPayment = isSupplier
          ? transaction.type == 'income'
          : transaction.type == 'expense';

      if (isCharge) {
        final billAmount = transaction.isQuickBill && !isSupplier
            ? QuickBillTrustMetrics.billTotal(transaction)
            : transaction.amount;
        final received = transaction.isQuickBill && !isSupplier
            ? QuickBillTrustMetrics.amountReceived(transaction)
            : transaction.receivedAmount.clamp(0, billAmount).toDouble();
        totalBilled += billAmount;
        var due = (billAmount - received).clamp(0, billAmount).toDouble();
        if (availableCredit > 0 && due > 0) {
          final applied = availableCredit < due ? availableCredit : due;
          due -= applied;
          availableCredit -= applied;
        }
        if (due > 0.01) {
          openEntries.add(_OpenLedgerEntry(
            amount: due,
            date: transaction.date,
            quickBillId: transaction.isQuickBill ? transaction.id : null,
          ));
        }
      } else if (isPayment) {
        applyCredit(transaction.amount.clamp(0, double.infinity).toDouble());
      }
    }

    final now = DateTime.now();
    var outstandingBalance = 0.0;
    var overdueBalance = 0.0;
    var unknownAgeBalance = 0.0;
    var ageWeightedBalance = 0.0;
    final outstandingQuickBills = <String, double>{};

    for (final entry in openEntries) {
      outstandingBalance += entry.amount;
      if (entry.quickBillId != null) {
        outstandingQuickBills[entry.quickBillId!] = entry.amount;
      }

      if (entry.date == null) {
        unknownAgeBalance += entry.amount;
        ageWeightedBalance += entry.amount * 0.5;
        continue;
      }

      final daysOpen = now.difference(entry.date!).inDays.clamp(0, 100000);
      if (daysOpen >= 30) overdueBalance += entry.amount;
      final ageWeight = daysOpen >= 90
          ? 0.15
          : daysOpen >= 60
              ? 0.4
              : daysOpen >= 30
                  ? 0.7
                  : 1.0;
      ageWeightedBalance += entry.amount * ageWeight;
    }

    final agingScore = outstandingBalance <= 0
        ? 100.0
        : (ageWeightedBalance / outstandingBalance * 100)
            .clamp(0.0, 100.0)
            .toDouble();
    final unpaidBilled = openEntries
        .where((entry) => entry.quickBillId != null || entry.date != null)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final totalReceived =
        (totalBilled - unpaidBilled).clamp(0, totalBilled).toDouble();

    return PartyLedgerMetrics(
      totalBilled: totalBilled,
      totalReceived: totalReceived,
      outstandingBalance: outstandingBalance - availableCredit,
      overdueBalance: overdueBalance,
      unknownAgeBalance: unknownAgeBalance,
      agingScore: agingScore,
      outstandingQuickBills:
          Map<String, double>.unmodifiable(outstandingQuickBills),
    );
  }

  static int _compareOrder(Transaction first, Transaction second) {
    final dateOrder = first.date.compareTo(second.date);
    if (dateOrder != 0) return dateOrder;

    final createdOrder = first.createdAt.compareTo(second.createdAt);
    if (createdOrder != 0) return createdOrder;

    return first.id.compareTo(second.id);
  }
}

class _OpenLedgerEntry {
  double amount;
  final DateTime? date;
  final String? quickBillId;

  _OpenLedgerEntry({
    required this.amount,
    required this.date,
    this.quickBillId,
  });
}
