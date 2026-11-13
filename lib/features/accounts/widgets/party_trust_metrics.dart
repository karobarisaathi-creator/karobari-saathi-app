import 'package:flutter/material.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/party_ledger_metrics.dart';
import 'package:account_app/core/theme/app_theme.dart';

class PartyTrustMetrics {
  final double overallScore;
  final double paymentScore;
  final double agingScore;
  final double paymentTimingScore;
  final double fullPaymentScore;
  final String ratingTitle;
  final String recommendation;
  final Color badgeColor;

  final int chargeEntryCount;
  final int fullyPaidEntries;
  final int partiallyPaidEntries;
  final int unpaidEntries;
  final double? averagePaymentDays;
  final double totalBilled;
  final double totalReceived;
  final double outstandingBalance;
  final double overdueBalance;
  final double unknownAgeBalance;
  final bool hasTransactionHistory;
  final bool isSupplier;

  final double? trendPercent;
  final String riskLevel;
  final String paymentHabit;
  final double? lastTxAmount;
  final int? lastTxDaysAgo;
  final String? lastTxType;

  const PartyTrustMetrics({
    required this.overallScore,
    required this.paymentScore,
    required this.agingScore,
    required this.paymentTimingScore,
    required this.fullPaymentScore,
    required this.ratingTitle,
    required this.recommendation,
    required this.badgeColor,
    required this.chargeEntryCount,
    required this.fullyPaidEntries,
    required this.partiallyPaidEntries,
    required this.unpaidEntries,
    required this.averagePaymentDays,
    required this.totalBilled,
    required this.totalReceived,
    required this.outstandingBalance,
    required this.overdueBalance,
    required this.unknownAgeBalance,
    required this.hasTransactionHistory,
    required this.isSupplier,
    required this.trendPercent,
    required this.riskLevel,
    required this.paymentHabit,
    required this.lastTxAmount,
    required this.lastTxDaysAgo,
    required this.lastTxType,
  });

  factory PartyTrustMetrics.calculate({
    required Account party,
    required List<Transaction> transactions,
    required bool isUrdu,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final ledger = PartyLedgerMetrics.calculate(
      transactions: transactions,
      openingBalance: party.initialBalance,
      balanceType: party.balanceType,
      partyCategory: party.category,
      now: referenceNow,
    );
    final txCount = transactions.length;
    final isSupplier = AccountBalanceUtils.isSupplierCategory(party.category);
    final billed = ledger.totalBilled;
    final received = ledger.totalReceived;
    final currentBal = ledger.outstandingBalance;
    final hasChargeHistory = ledger.chargeEntryCount > 0;
    final paymentScore = billed > 0
        ? (received / billed * 100).clamp(0.0, 100.0).toDouble()
        : (currentBal > 0 ? 0.0 : 50.0);

    final averagePaymentDays = ledger.averagePaymentDays;
    final paymentTimingScore = averagePaymentDays == null
        ? 50.0
        : averagePaymentDays <= 7
            ? 100.0
            : averagePaymentDays <= 15
                ? 85.0
                : averagePaymentDays <= 30
                    ? 70.0
                    : averagePaymentDays <= 60
                        ? 50.0
                        : averagePaymentDays <= 90
                            ? 30.0
                            : 10.0;
    final fullPaymentScore = ledger.chargeEntryCount == 0
        ? 50.0
        : ledger.fullyPaidEntries / ledger.chargeEntryCount * 100;

    final overall = !hasChargeHistory
        ? 50.0
        : (paymentScore * 0.35) +
            (ledger.agingScore * 0.40) +
            (paymentTimingScore * 0.10) +
            (fullPaymentScore * 0.15);
    final clampedOverall = overall.clamp(0.0, 100.0).toDouble();
    final String title;
    final String recText;
    final Color color;

    if (!hasChargeHistory) {
      title = txCount == 0 && party.initialBalance != 0
          ? (isUrdu
              ? 'ابتدائی بقایا — تاریخ دستیاب نہیں'
              : 'Opening balance — age unknown')
          : txCount == 0
              ? (isUrdu
                  ? 'نیا کھاتہ — ابھی تاریخ نہیں'
                  : 'New account — no history yet')
              : (isUrdu
                  ? 'ابھی واجب انٹری کا ریکارڈ نہیں'
                  : 'No charge history to assess yet');
      recText = isUrdu
          ? 'کھاتے میں واجب انٹری درج ہونے کے بعد ادائیگی کا ریکارڈ بنے گا۔'
          : 'A payment record can be assessed after charge entries are recorded.';
      color = AppTheme.textSecondary;
    } else {
      if (clampedOverall >= 80) {
        title = isSupplier
            ? (isUrdu
                ? 'سپلائر کو ہماری ادائیگی: بہت بہتر'
                : 'Our payments to supplier: very healthy')
            : (isUrdu
                ? '🌟 گاہک کی ادائیگی کا ریکارڈ بہت اچھا'
                : '🌟 Customer payment record: excellent');
        recText = isSupplier
            ? (isUrdu
                ? 'اس سپلائر کو آپ کی درج شدہ ادائیگیاں اچھی ہیں؛ ادائیگی کی طے شدہ شرائط بھی دیکھیں۔'
                : 'Your recorded payments to this supplier are strong; also check the agreed payment terms.')
            : (isUrdu
                ? 'گاہک سے درج شدہ وصولی اچھی ہے؛ نیا ادھار دینے سے پہلے اپنی پالیسی بھی دیکھیں۔'
                : 'The customer’s recorded payment history is strong; use your credit policy before extending more credit.');
        color = const Color(0xFF16A34A);
      } else if (clampedOverall >= 60) {
        title = isSupplier
            ? (isUrdu
                ? 'سپلائر کو ہماری ادائیگی: بہتر'
                : 'Our payments to supplier: healthy')
            : (isUrdu
                ? '⭐ گاہک کا ادائیگی ریکارڈ اچھا'
                : '⭐ Customer payment record: good');
        recText = isSupplier
            ? (isUrdu
                ? 'سپلائر کو ادائیگی کا ریکارڈ بہتر ہے، مگر واجب رقم کی عمر بھی دیکھیں۔'
                : 'Your supplier payments are generally on track; also review the age of amounts payable.')
            : (isUrdu
                ? 'گاہک کی درج شدہ ادائیگی بہتر ہے، مگر بقایا کی عمر بھی دیکھیں۔'
                : 'The customer’s recorded payments are generally on track; also review the age of outstanding dues.');
        color = const Color(0xFFD97706);
      } else if (clampedOverall >= 40) {
        title = isSupplier
            ? (isUrdu
                ? 'سپلائر کو ہماری ادائیگی: درمیانہ'
                : 'Our payments to supplier: fair')
            : (isUrdu
                ? '⚡ گاہک کا ادائیگی ریکارڈ درمیانہ'
                : '⚡ Customer payment record: fair');
        recText = isSupplier
            ? (isUrdu
                ? 'سپلائر کو کچھ رقم واجب یا پرانی ہو سکتی ہے؛ ادائیگی کی شرائط کا جائزہ لیں۔'
                : 'Some supplier amounts may be due or aging; review your payment terms.')
            : (isUrdu
                ? 'گاہک سے کچھ رقم بقایا یا پرانی ہو سکتی ہے؛ نیا ادھار محدود رکھنے پر غور کریں۔'
                : 'Some customer dues may be outstanding or aging; consider limiting additional credit.');
        color = const Color(0xFFEA580C);
      } else {
        title = isSupplier
            ? (isUrdu
                ? 'سپلائر کو ہماری ادائیگی: توجہ درکار'
                : 'Our payments to supplier: needs attention')
            : (isUrdu
                ? '⚠️ گاہک کی ادائیگی: احتیاط درکار'
                : '⚠️ Customer payments: needs caution');
        recText = isSupplier
            ? (isUrdu
                ? 'سپلائر کو واجب اور تاخیر شدہ ادائیگیوں کا جائزہ لیں۔'
                : 'Review amounts payable to the supplier and any overdue payments.')
            : (isUrdu
                ? 'گاہک کے بقایا اور تاخیر کا جائزہ لے کر اگلا لین دین طے کریں۔'
                : 'Review the customer’s outstanding and overdue dues before the next transaction.');
        color = const Color(0xFFDC2626);
      }
    }

    final trendPercent = _calculateTrend(
      transactions: transactions,
      isSupplier: isSupplier,
      referenceNow: referenceNow,
    );

    final String riskLevel;
    if (!hasChargeHistory || ledger.unknownAgeBalance > 0.01) {
      riskLevel = 'unknown';
    } else if (currentBal <= 0.01) {
      riskLevel = 'low';
    } else {
      final overdueShare =
          (ledger.overdueBalance / currentBal).clamp(0.0, 1.0).toDouble();
      riskLevel = overdueShare >= 0.5
          ? 'high'
          : overdueShare > 0
              ? 'medium'
              : 'low';
    }

    final String paymentHabit;
    if (averagePaymentDays == null) {
      paymentHabit = 'none';
    } else if (averagePaymentDays <= 30) {
      paymentHabit = 'onTime';
    } else if (averagePaymentDays <= 60) {
      paymentHabit = 'slightDelay';
    } else {
      paymentHabit = 'late';
    }

    double? lastTxAmount;
    int? lastTxDaysAgo;
    String? lastTxType;
    if (transactions.isNotEmpty) {
      final sorted = transactions.toList()
        ..sort((a, b) {
          final dateOrder = b.date.compareTo(a.date);
          if (dateOrder != 0) return dateOrder;
          final createdOrder = b.createdAt.compareTo(a.createdAt);
          if (createdOrder != 0) return createdOrder;
          return b.id.compareTo(a.id);
        });
      final last = sorted.first;
      final columns = AccountBalanceUtils.transactionColumns(last);
      final charge = isSupplier ? columns.credit : columns.debit;
      final payment = isSupplier ? columns.debit : columns.credit;

      if (charge > payment + 0.01) {
        lastTxAmount = charge - payment;
        lastTxType = 'purchase';
      } else if (payment > charge + 0.01) {
        lastTxAmount = payment - charge;
        lastTxType = 'payment';
      }
      lastTxDaysAgo = referenceNow.difference(last.date).inDays.clamp(0, 99999);
    }

    return PartyTrustMetrics(
      overallScore: clampedOverall,
      paymentScore: paymentScore,
      agingScore: ledger.agingScore,
      paymentTimingScore: paymentTimingScore,
      fullPaymentScore: fullPaymentScore,
      ratingTitle: title,
      recommendation: recText,
      badgeColor: color,
      chargeEntryCount: ledger.chargeEntryCount,
      fullyPaidEntries: ledger.fullyPaidEntries,
      partiallyPaidEntries: ledger.partiallyPaidEntries,
      unpaidEntries: ledger.unpaidEntries,
      averagePaymentDays: averagePaymentDays,
      totalBilled: billed,
      totalReceived: received,
      outstandingBalance: currentBal,
      overdueBalance: ledger.overdueBalance,
      unknownAgeBalance: ledger.unknownAgeBalance,
      hasTransactionHistory: hasChargeHistory,
      isSupplier: isSupplier,
      trendPercent: trendPercent,
      riskLevel: riskLevel,
      paymentHabit: paymentHabit,
      lastTxAmount: lastTxAmount,
      lastTxDaysAgo: lastTxDaysAgo,
      lastTxType: lastTxType,
    );
  }

  static double? _calculateTrend({
    required List<Transaction> transactions,
    required bool isSupplier,
    required DateTime referenceNow,
  }) {
    final recentStart = referenceNow.subtract(const Duration(days: 30));
    final previousStart = referenceNow.subtract(const Duration(days: 60));

    double recentCharge = 0, recentPayment = 0;
    double prevCharge = 0, prevPayment = 0;
    for (final tx in transactions) {
      final isRecent = tx.date.isAfter(recentStart);
      final isPrevious = !isRecent && tx.date.isAfter(previousStart);
      if (!isRecent && !isPrevious) continue;

      final col = AccountBalanceUtils.transactionColumns(tx);
      final charge = isSupplier ? col.credit : col.debit;
      final payment = isSupplier ? col.debit : col.credit;
      if (isRecent) {
        recentCharge += charge;
        recentPayment += payment;
      } else {
        prevCharge += charge;
        prevPayment += payment;
      }
    }

    if (recentCharge <= 0.01 || prevCharge <= 0.01) return null;

    final recentRatio =
        (recentPayment / recentCharge).clamp(0.0, 1.0).toDouble();
    final prevRatio = (prevPayment / prevCharge).clamp(0.0, 1.0).toDouble();
    if (prevRatio == 0) return recentRatio > 0 ? 100.0 : 0.0;
    return (((recentRatio - prevRatio) / prevRatio) * 100)
        .clamp(-100.0, 100.0)
        .toDouble();
  }
}
