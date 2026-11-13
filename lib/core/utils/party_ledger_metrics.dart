import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';

class PartyLedgerMetrics {
  final double totalBilled;
  final double totalReceived;
  final double outstandingBalance;
  final double overdueBalance;
  final double unknownAgeBalance;
  final double agingScore;
  final double? averagePaymentDays;
  final int chargeEntryCount;
  final int fullyPaidEntries;
  final int partiallyPaidEntries;
  final int unpaidEntries;
  final Map<String, double> outstandingQuickBills;

  const PartyLedgerMetrics({
    required this.totalBilled,
    required this.totalReceived,
    required this.outstandingBalance,
    required this.overdueBalance,
    required this.unknownAgeBalance,
    required this.agingScore,
    required this.averagePaymentDays,
    required this.chargeEntryCount,
    required this.fullyPaidEntries,
    required this.partiallyPaidEntries,
    required this.unpaidEntries,
    required this.outstandingQuickBills,
  });

  factory PartyLedgerMetrics.calculate({
    required Iterable<Transaction> transactions,
    double openingBalance = 0,
    String balanceType = 'receivable',
    String partyCategory = 'customer',
    DateTime? now,
  }) {
    final isSupplier = AccountBalanceUtils.isSupplierCategory(partyCategory);
    final partyDirection = isSupplier ? -1.0 : 1.0;
    final openingDirection =
        balanceType.trim().toLowerCase() == 'payable' ? -1.0 : 1.0;
    final openingDue = openingBalance * openingDirection * partyDirection;

    final sortedTransactions = transactions.toList()..sort(_compareOrder);
    final openEntries = <_OpenLedgerEntry>[];
    var availableRecordedCredit = 0.0;
    var availableOpeningCredit = 0.0;
    var totalBilled = 0.0;
    var totalReceived = 0.0;

    if (openingDue > 0) {
      openEntries.add(_OpenLedgerEntry(
        amount: openingDue,
        date: null,
        isOpeningBalance: true,
      ));
      totalBilled = openingDue;
    } else if (openingDue < 0) {
      availableOpeningCredit = -openingDue;
    }

    double applyToOpenEntries(
      double amount, {
      DateTime? paymentDate,
    }) {
      var remaining = amount;
      for (final entry in openEntries) {
        if (remaining <= 0.01) break;
        if (entry.remainingAmount <= 0.01) continue;

        final applied = remaining < entry.remainingAmount
            ? remaining
            : entry.remainingAmount;
        entry.remainingAmount -= applied;
        entry.paidAmount += applied;
        remaining -= applied;

        if (entry.date != null && paymentDate != null) {
          final daysToPay =
              paymentDate.difference(entry.date!).inDays.clamp(0, 100000);
          entry.timedPaidAmount += applied;
          entry.weightedPaymentDays += applied * daysToPay;
        }
      }
      return amount - remaining;
    }

    for (final transaction in sortedTransactions) {
      final columns = AccountBalanceUtils.transactionColumns(transaction);
      final charge = isSupplier ? columns.credit : columns.debit;
      final payment = isSupplier ? columns.debit : columns.credit;

      if (charge > 0.01) {
        totalBilled += charge;
        openEntries.add(_OpenLedgerEntry(
          amount: charge,
          date: transaction.date,
          quickBillId: transaction.isQuickBill ? transaction.id : null,
        ));

        if (availableOpeningCredit > 0) {
          final applied = applyToOpenEntries(
            availableOpeningCredit,
          );
          availableOpeningCredit -= applied;
        }
        if (availableRecordedCredit > 0) {
          final applied = applyToOpenEntries(
            availableRecordedCredit,
          );
          availableRecordedCredit -= applied;
        }
      }

      if (payment > 0.01) {
        totalReceived += payment;
        final applied = applyToOpenEntries(
          payment,
          paymentDate: transaction.date,
        );
        final excess = payment - applied;
        if (excess > 0.01) availableRecordedCredit += excess;
      }
    }

    final referenceNow = now ?? DateTime.now();
    var openBalance = 0.0;
    var overdueBalance = 0.0;
    var unknownAgeBalance = 0.0;
    var knownAgeBalance = 0.0;
    var ageWeightedBalance = 0.0;
    var totalTimedPaid = 0.0;
    var weightedPaymentDays = 0.0;
    final outstandingQuickBills = <String, double>{};

    for (final entry in openEntries) {
      openBalance += entry.remainingAmount;
      totalTimedPaid += entry.timedPaidAmount;
      weightedPaymentDays += entry.weightedPaymentDays;
      if (entry.quickBillId != null && entry.remainingAmount > 0.01) {
        outstandingQuickBills[entry.quickBillId!] = entry.remainingAmount;
      }

      if (entry.remainingAmount <= 0.01) continue;
      if (entry.date == null) {
        unknownAgeBalance += entry.remainingAmount;
        continue;
      }

      knownAgeBalance += entry.remainingAmount;
      final daysOpen =
          referenceNow.difference(entry.date!).inDays.clamp(0, 100000);
      if (daysOpen >= 30) overdueBalance += entry.remainingAmount;
      final ageWeight = daysOpen >= 90
          ? 0.15
          : daysOpen >= 60
              ? 0.4
              : daysOpen >= 30
                  ? 0.7
                  : 1.0;
      ageWeightedBalance += entry.remainingAmount * ageWeight;
    }

    final chargeEntries =
        openEntries.where((entry) => !entry.isOpeningBalance).toList();
    final fullyPaidEntries =
        chargeEntries.where((entry) => entry.remainingAmount <= 0.01).length;
    final partiallyPaidEntries = chargeEntries
        .where(
            (entry) => entry.paidAmount > 0.01 && entry.remainingAmount > 0.01)
        .length;
    final unpaidEntries = chargeEntries
        .where(
            (entry) => entry.paidAmount <= 0.01 && entry.remainingAmount > 0.01)
        .length;
    final agingScore = openBalance <= 0
        ? 100.0
        : knownAgeBalance <= 0
            ? 50.0
            : (ageWeightedBalance / knownAgeBalance * 100)
                .clamp(0.0, 100.0)
                .toDouble();

    return PartyLedgerMetrics(
      totalBilled: totalBilled,
      totalReceived: totalReceived,
      outstandingBalance:
          openBalance - availableRecordedCredit - availableOpeningCredit,
      overdueBalance: overdueBalance,
      unknownAgeBalance: unknownAgeBalance,
      agingScore: agingScore,
      averagePaymentDays:
          totalTimedPaid > 0 ? weightedPaymentDays / totalTimedPaid : null,
      chargeEntryCount: chargeEntries.length,
      fullyPaidEntries: fullyPaidEntries,
      partiallyPaidEntries: partiallyPaidEntries,
      unpaidEntries: unpaidEntries,
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
  double remainingAmount;
  double paidAmount = 0;
  double timedPaidAmount = 0;
  double weightedPaymentDays = 0;
  final DateTime? date;
  final String? quickBillId;
  final bool isOpeningBalance;

  _OpenLedgerEntry({
    required double amount,
    required this.date,
    this.quickBillId,
    this.isOpeningBalance = false,
  }) : remainingAmount = amount;
}
