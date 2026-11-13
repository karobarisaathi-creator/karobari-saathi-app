// lib/features/accounts/widgets/party_tools_grid_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/utils/party_ledger_metrics.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/accounts/bulk_party_transaction_screen.dart';
import 'package:account_app/features/accounts/widgets/party_trust_popup.dart';

class PartyToolsGridWidget extends StatelessWidget {
  final Account party;
  final bool isUrdu;
  final String? fontFamily;
  final VoidCallback onRefresh;

  const PartyToolsGridWidget({
    super.key,
    required this.party,
    required this.isUrdu,
    this.fontFamily,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final currentParty = db.getAccount(party.id) ?? party;
    final allTx = db.getTransactions(party.id);
    final trustMetrics = PartyTrustMetrics.calculate(
      party: currentParty,
      transactions: allTx,
      isUrdu: isUrdu,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.gridFour(),
                  size: 14, color: AppTheme.themeColor),
              const SizedBox(width: 6),
              UrduAwareText(
                isUrdu ? 'پارٹی ٹولز اور مینو' : 'Party Tools & Menu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.85,
            children: [
              _buildToolItem(
                icon: PhosphorIcons.listBullets(),
                label: isUrdu ? 'پیج انٹری' : 'Bulk Entry',
                iconColor: AppTheme.themeColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BulkPartyTransactionScreen(party: party),
                    ),
                  ).then((_) => onRefresh());
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.filePdf(),
                label: isUrdu ? 'PDF رپورٹ' : 'PDF Report',
                iconColor: AppTheme.incomeColor,
                onTap: () async {
                  final pdfService =
                      Provider.of<PdfService>(context, listen: false);
                  final txs = db.getTransactions(party.id);
                  await pdfService.generateAccountStatement(
                    account: party,
                    transactions: txs,
                    isUrdu: isUrdu,
                  );
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.shieldCheck(),
                label: isUrdu ? 'بھروسہ پوائنٹ' : 'Trust Point',
                iconColor: trustMetrics.badgeColor,
                onTap: () => PartyTrustPopup.show(
                  context: context,
                  party: currentParty,
                  metrics: trustMetrics,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                ),
              ),
              _buildToolItem(
                icon: PhosphorIcons.pencilLine(),
                label: isUrdu ? 'ایڈٹ' : 'Edit',
                iconColor: AppTheme.darkColor,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPartyScreen(partyToEdit: party),
                    ),
                  );
                  onRefresh();
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.trash(),
                label: isUrdu ? 'ڈیلیٹ' : 'Delete',
                iconColor: AppTheme.expenseColor,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.backgroundColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(height: 4),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Delete confirmation — ویسا ہی
  // ═════════════════════════════════════════════════════════════
  Future<void> _confirmDelete(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final transactions = db.getTransactions(party.id);
    final hasData = transactions.isNotEmpty ||
        party.initialBalance.abs() > 0.01 ||
        party.balance.abs() > 0.01;

    final nameController = TextEditingController();
    bool canDelete = !hasData;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: UrduAwareText(
            isUrdu ? 'پارٹی کو مستقل ختم کریں؟' : 'Permanently Delete Party?',
            style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                color: AppTheme.expenseColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UrduAwareText(
                isUrdu
                    ? 'وارننگ: اس پارٹی کا ${transactions.length} لین دین اور بیلنس موجود ہے۔ ختم کرنے سے تمام ڈیٹا ہمیشہ کے لیے مٹ جائے گا۔'
                    : 'Warning: This party has ${transactions.length} transactions and balance. Deletion is irreversible.',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    color: Colors.red.shade700),
              ),
              if (hasData) ...[
                const SizedBox(height: 14),
                UrduAwareText(
                  isUrdu
                      ? 'تصدیق کے لیے پارٹی کا نام "${party.name}" درج کریں:'
                      : 'Type party name "${party.name}" to confirm:',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: party.name,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {
                      canDelete = val.trim() == party.name.trim();
                    });
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: UrduAwareText(
                isUrdu ? 'منسوخ' : 'Cancel',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontFamily: fontFamily),
              ),
            ),
            TextButton(
              onPressed: canDelete ? () => Navigator.pop(context, true) : null,
              child: UrduAwareText(
                isUrdu ? 'ختم کریں' : 'Delete',
                style: TextStyle(
                  color: canDelete ? AppTheme.expenseColor : Colors.grey,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && context.mounted) {
      await Provider.of<DatabaseService>(context, listen: false)
          .deleteAccount(party.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ═════════════════════════════════════════════════════════════
// PartyTrustMetrics — آپ کی موجودہ + 4 نئی فیلڈز
// ═════════════════════════════════════════════════════════════
class PartyTrustMetrics {
  // ✅ موجودہ فیلڈز — ویسے ہی
  final double overallScore;
  final double paymentScore;
  final double balanceScore;
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

  // 🆕 نئی فیلڈز
  final double? trendPercent;
  final String riskLevel;
  final String paymentHabit;
  final double? lastTxAmount;
  final int? lastTxDaysAgo;
  final String? lastTxType;

  const PartyTrustMetrics({
    required this.overallScore,
    required this.paymentScore,
    required this.balanceScore,
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
    // 🆕 نئی
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
    final balanceScore = currentBal > 0
        ? (billed > 0
                ? (billed - currentBal).clamp(0.0, billed) / billed * 100
                : 0.0)
            .clamp(0.0, 100.0)
            .toDouble()
        : 100.0;

    final averagePaymentDays = ledger.averagePaymentDays;
    final paymentTimingScore = averagePaymentDays == null
        ? (ledger.chargeEntryCount == 0 ? 50.0 : 0.0)
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
        : (paymentScore * 0.30) +
            (balanceScore * 0.10) +
            (ledger.agingScore * 0.35) +
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
      if (clampedOverall >= 88) {
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
      } else if (clampedOverall >= 75) {
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
        color = const Color(0xFF0284C7);
      } else if (clampedOverall >= 55) {
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
        color = const Color(0xFFD97706);
      } else if (clampedOverall >= 35) {
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
        color = const Color(0xFFEA580C);
      } else {
        title = isSupplier
            ? (isUrdu
                ? 'سپلائر کو ہماری ادائیگی: کمزور'
                : 'Our payments to supplier: poor')
            : (isUrdu
                ? '🚨 گاہک کا ادائیگی ریکارڈ کمزور'
                : '🚨 Customer payment record: poor');
        recText = isSupplier
            ? (isUrdu
                ? 'سپلائر کو واجب رقم زیادہ یا پرانی ہے؛ کھاتے اور طے شدہ تاریخوں کی تصدیق کریں۔'
                : 'Amounts payable to the supplier are high or old; verify the ledger and agreed due dates.')
            : (isUrdu
                ? 'گاہک سے بقایا زیادہ یا پرانا ہے؛ نیا ادھار دینے سے پہلے کھاتے کی تصدیق کریں۔'
                : 'The customer’s recorded dues are high or old; verify the ledger before extending more credit.');
        color = const Color(0xFFDC2626);
      }
    }

    // 🆕 Trend
    final trendPercent = _calculateTrend(
      transactions: transactions,
      isSupplier: isSupplier,
      referenceNow: referenceNow,
    );

    // Risk reflects the overdue share of the current positive balance.
    final String riskLevel;
    if (!hasChargeHistory) {
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

    // 🆕 Habit
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

    // 🆕 Last Tx
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
      balanceScore: balanceScore,
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

  // 🆕 Trend helper
  static double? _calculateTrend({
    required List<Transaction> transactions,
    required bool isSupplier,
    required DateTime referenceNow,
  }) {
    final recentStart = referenceNow.subtract(const Duration(days: 30));
    final previousStart = referenceNow.subtract(const Duration(days: 60));

    double recentCharge = 0, recentPayment = 0;
    for (final tx in transactions) {
      if (!tx.date.isAfter(recentStart)) continue;
      final col = AccountBalanceUtils.transactionColumns(tx);
      final charge = isSupplier ? col.credit : col.debit;
      final payment = isSupplier ? col.debit : col.credit;
      recentCharge += charge;
      recentPayment += payment;
    }

    double prevCharge = 0, prevPayment = 0;
    for (final tx in transactions) {
      if (tx.date.isAfter(recentStart)) continue;
      if (!tx.date.isAfter(previousStart)) continue;
      final col = AccountBalanceUtils.transactionColumns(tx);
      final charge = isSupplier ? col.credit : col.debit;
      final payment = isSupplier ? col.debit : col.credit;
      prevCharge += charge;
      prevPayment += payment;
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
