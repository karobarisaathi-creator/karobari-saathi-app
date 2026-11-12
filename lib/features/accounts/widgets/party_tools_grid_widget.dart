import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/utils/party_ledger_metrics.dart';
import 'package:account_app/core/utils/quick_bill_trust_metrics.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/accounts/bulk_party_transaction_screen.dart';

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
    final db = Provider.of<DatabaseService>(context, listen: false);
    final currentParty = db.getAccount(party.id) ?? party;
    final allTx = db
        .getAllTransactions()
        .where((t) => t.accountId == party.id && t.partnershipId == null)
        .toList();
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
                  final txs = db
                      .getAllTransactions()
                      .where((t) => t.accountId == party.id)
                      .toList();
                  await pdfService.generateAccountStatement(
                    account: party,
                    transactions: txs,
                    isUrdu: isUrdu,
                  );
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.shieldCheck(),
                label: isUrdu ? 'پھروسہ انڈیکس' : 'Trust Index',
                iconColor: trustMetrics.badgeColor,
                onTap: () => _showPersonalReviewDialog(context),
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

  void _showPersonalReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PersonalReviewCard(
                party: party,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: UrduAwareText(
                    isUrdu ? 'بند کریں' : 'Close',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final transactions =
        db.getAllTransactions().where((t) => t.accountId == party.id).toList();
    final hasData = transactions.isNotEmpty || party.balance != 0;

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

class PartyTrustMetrics {
  final double overallScore;
  final double paymentScore;
  final double balanceScore;
  final double agingScore;
  final double durationScore;
  final double activityScore;
  final String ratingTitle;
  final String recommendation;
  final Color badgeColor;

  final int totalTransactions;
  final int quickBillsCount;
  final int fullyPaidQuickBills;
  final double totalBilled;
  final double totalReceived;
  final double outstandingBalance;
  final double overdueBalance;
  final double unknownAgeBalance;
  final bool hasRepeatProducts;
  final bool isSupplier;

  const PartyTrustMetrics({
    required this.overallScore,
    required this.paymentScore,
    required this.balanceScore,
    required this.agingScore,
    required this.durationScore,
    required this.activityScore,
    required this.ratingTitle,
    required this.recommendation,
    required this.badgeColor,
    required this.totalTransactions,
    required this.quickBillsCount,
    required this.fullyPaidQuickBills,
    required this.totalBilled,
    required this.totalReceived,
    required this.outstandingBalance,
    required this.overdueBalance,
    required this.unknownAgeBalance,
    required this.hasRepeatProducts,
    required this.isSupplier,
  });

  factory PartyTrustMetrics.calculate({
    required Account party,
    required List<Transaction> transactions,
    required bool isUrdu,
  }) {
    final ledger = PartyLedgerMetrics.calculate(
      transactions: transactions,
      openingBalance: party.initialBalance,
      balanceType: party.balanceType,
      partyCategory: party.category,
    );
    final qbMetrics = QuickBillTrustMetrics.fromTransactions(transactions);
    final txCount = transactions.length;
    final quickBills = transactions.where((transaction) {
      final isPartyCharge = isSupplier
          ? transaction.type == 'expense'
          : transaction.type == 'income';
      return transaction.isQuickBill && isPartyCharge;
    }).toList();
    final qbFullyPaidCount = quickBills
        .where((bill) => (ledger.outstandingQuickBills[bill.id] ?? 0) <= 0.01)
        .length;
    DateTime? earliestDate;
    DateTime? latestDate;
    for (final tx in transactions) {
      if (earliestDate == null || tx.date.isBefore(earliestDate)) {
        earliestDate = tx.date;
      }
      if (latestDate == null || tx.date.isAfter(latestDate)) {
        latestDate = tx.date;
      }
    }

    final billed = ledger.totalBilled;
    final received = ledger.totalReceived;
    final currentBal = ledger.outstandingBalance;
    final isSupplier = party.category.trim().toLowerCase() == 'supplier';
    final paymentScore = billed > 0
        ? (received / billed * 100).clamp(0.0, 100.0).toDouble()
        : (currentBal > 0 ? 0.0 : 50.0);
    final balanceScore = currentBal > 0
        ? (billed > 0 ? billed / (billed + currentBal) * 100 : 0.0)
            .clamp(0.0, 100.0)
            .toDouble()
        : 100.0;

    double durationScore = 50.0;
    if (earliestDate != null) {
      final days =
          DateTime.now().difference(earliestDate).inDays.clamp(0, 100000);
      if (days > 365) {
        durationScore = 100.0;
      } else if (days > 90) {
        durationScore = 85.0 + ((days - 90) / 275 * 15);
      } else if (days > 30) {
        durationScore = 70.0 + ((days - 30) / 60 * 15);
      } else {
        durationScore = 50.0 + (days / 30 * 20);
      }
      durationScore = durationScore.clamp(0.0, 100.0);
    }

    double activityScore =
        txCount == 0 ? 0.0 : (txCount * 8.0).clamp(20.0, 65.0);
    if (qbMetrics.repeatProductCustomerCount > 0) {
      activityScore += 10.0;
    }
    if (latestDate != null) {
      final daysSinceLast =
          DateTime.now().difference(latestDate).inDays.clamp(0, 100000);
      if (daysSinceLast <= 30) {
        activityScore += 15.0;
      } else if (daysSinceLast <= 90) {
        activityScore += 8.0;
      }
    }
    activityScore = activityScore.clamp(0.0, 100.0);

    final overall = txCount == 0 && party.initialBalance == 0
        ? 50.0
        : (paymentScore * 0.30) +
            (balanceScore * 0.20) +
            (ledger.agingScore * 0.25) +
            (durationScore * 0.10) +
            (activityScore * 0.15);
    final clampedOverall = overall.clamp(0.0, 100.0).toDouble();
    final String title;
    final String recText;
    final Color color;

    if (txCount == 0) {
      title = party.initialBalance == 0
          ? (isUrdu
              ? 'نیا کھاتہ — ابھی تاریخ نہیں'
              : 'New account — no history yet')
          : (isUrdu
              ? 'ابتدائی بقایا — تاریخ دستیاب نہیں'
              : 'Opening balance — age unknown');
      recText = isUrdu
          ? 'یہ صرف درج شدہ ریکارڈ کا اشارہ ہے، ادھار کی ضمانت نہیں۔'
          : 'This is an estimate from recorded entries, not a credit guarantee.';
      color = const Color(0xFF0284C7);
    } else {
      if (clampedOverall >= 88) {
        title = isSupplier
            ? (isUrdu
                ? 'سپلائر کھاتہ: بہت بہتر'
                : 'Supplier ledger: very healthy')
            : (isUrdu
                ? '🌟 بہت اچھا ادائیگی ریکارڈ'
                : '🌟 Excellent payment history');
        recText = isUrdu
            ? 'درج شدہ ادائیگیوں کا ریکارڈ اچھا ہے؛ نیا ادھار دینے سے پہلے اپنی پالیسی بھی دیکھیں۔'
            : 'Recorded payment history is strong; use your own credit policy before extending credit.';
        color = const Color(0xFF16A34A);
      } else if (clampedOverall >= 75) {
        title = isSupplier
            ? (isUrdu ? 'سپلائر کھاتہ: بہتر' : 'Supplier ledger: healthy')
            : (isUrdu ? '⭐ اچھا ادائیگی ریکارڈ' : '⭐ Good payment history');
        recText = isUrdu
            ? 'کھاتہ مجموعی طور پر بہتر ہے، مگر بقایا کی عمر بھی دیکھیں۔'
            : 'The ledger is generally healthy; also review the age of outstanding dues.';
        color = const Color(0xFF0284C7);
      } else if (clampedOverall >= 55) {
        title = isSupplier
            ? (isUrdu ? 'سپلائر کھاتہ: درمیانہ' : 'Supplier ledger: moderate')
            : (isUrdu ? '⚡ درمیانہ ادائیگی ریکارڈ' : '⚡ Fair payment history');
        recText = isUrdu
            ? 'کچھ رقم بقایا یا پرانی ہو سکتی ہے؛ نیا ادھار محدود رکھیں۔'
            : 'Some dues may be outstanding or aging; consider limiting additional credit.';
        color = const Color(0xFFD97706);
      } else if (clampedOverall >= 35) {
        title = isSupplier
            ? (isUrdu
                ? 'سپلائر کھاتہ: توجہ درکار'
                : 'Supplier ledger: needs attention')
            : (isUrdu ? '⚠️ احتیاط کریں' : '⚠️ Needs caution');
        recText = isUrdu
            ? 'بقایا اور تاخیر کا جائزہ لے کر اگلا لین دین طے کریں۔'
            : 'Review outstanding and overdue amounts before the next transaction.';
        color = const Color(0xFFEA580C);
      } else {
        title = isSupplier
            ? (isUrdu ? 'سپلائر کھاتہ: کمزور' : 'Supplier ledger: poor')
            : (isUrdu ? '🚨 کمزور ادائیگی ریکارڈ' : '🚨 Weak payment history');
        recText = isUrdu
            ? 'ریکارڈ میں بقایا زیادہ یا پرانا ہے؛ اگلا قدم طے کرنے سے پہلے تصدیق کریں۔'
            : 'Recorded dues are high or old; verify the ledger before deciding what to do next.';
        color = const Color(0xFFDC2626);
      }
    }

    return PartyTrustMetrics(
      overallScore: clampedOverall,
      paymentScore: paymentScore,
      balanceScore: balanceScore,
      agingScore: ledger.agingScore,
      durationScore: durationScore,
      activityScore: activityScore,
      ratingTitle: title,
      recommendation: recText,
      badgeColor: color,
      totalTransactions: txCount,
      quickBillsCount: quickBills.length,
      fullyPaidQuickBills: qbFullyPaidCount,
      totalBilled: billed,
      totalReceived: received,
      outstandingBalance: currentBal,
      overdueBalance: ledger.overdueBalance,
      unknownAgeBalance: ledger.unknownAgeBalance,
      hasRepeatProducts: qbMetrics.repeatProductCustomerCount > 0,
      isSupplier: isSupplier,
    );
  }
}

class _PersonalReviewCard extends StatelessWidget {
  final Account party;
  final bool isUrdu;
  final String? fontFamily;

  const _PersonalReviewCard({
    required this.party,
    required this.isUrdu,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final currentParty = db.getAccount(party.id) ?? party;
    final allTx = db
        .getAllTransactions()
        .where((t) => t.accountId == party.id && t.partnershipId == null)
        .toList();

    final metrics = PartyTrustMetrics.calculate(
      party: currentParty,
      transactions: allTx,
      isUrdu: isUrdu,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Icon(PhosphorIcons.shieldCheck(),
                  size: 20, color: metrics.badgeColor),
              const SizedBox(width: 8),
              Expanded(
                child: UrduAwareText(
                  isUrdu ? 'پارٹی کا پھروسہ انڈیکس' : 'Party Trust Index',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.expenseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 11, color: AppTheme.expenseColor),
                    const SizedBox(width: 4),
                    UrduAwareText(
                      isUrdu ? 'صرف آپ' : 'Only you',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overall Score Card Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  metrics.badgeColor.withValues(alpha: 0.12),
                  metrics.badgeColor.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: metrics.badgeColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Score Circle / Badge
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: metrics.badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: metrics.badgeColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${metrics.overallScore.round()}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Rating Title & Party Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        currentParty.name,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      UrduAwareText(
                        metrics.ratingTitle,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: metrics.badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildLedgerSummary(metrics, isUrdu, fontFamily),
          const SizedBox(height: 16),

          // Section Title: Detailed Breakdown
          UrduAwareText(
            isUrdu
                ? 'الگ الگ شعبوں میں پھروسہ فیصد:'
                : 'Trust Breakdown by Category:',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // 1. Payment Clearance Rate
          _buildMetricProgressBar(
            label:
                isUrdu ? 'ریکارڈ میں کل وصولی' : 'Recorded Payment Clearance',
            score: metrics.paymentScore,
            color: const Color(0xFF16A34A),
            icon: PhosphorIcons.checkCircle(),
          ),

          // 2. Balance & Credit Health
          _buildMetricProgressBar(
            label: isUrdu ? 'موجودہ بقایا' : 'Current Outstanding Balance',
            score: metrics.balanceScore,
            color: const Color(0xFF0284C7),
            icon: PhosphorIcons.scales(),
          ),

          _buildMetricProgressBar(
            label: isUrdu ? 'بقایا کی عمر' : 'Outstanding Age',
            score: metrics.agingScore,
            color: const Color(0xFFEA580C),
            icon: PhosphorIcons.clock(),
          ),

          // 4. Relationship Duration & Loyalty
          _buildMetricProgressBar(
            label: isUrdu
                ? 'تعلق اور کاروبار کا دورانیہ'
                : 'Relationship Duration',
            score: metrics.durationScore,
            color: const Color(0xFF8B5CF6),
            icon: PhosphorIcons.handshake(),
          ),

          // 5. Transaction Activity & Repeat Consistency
          _buildMetricProgressBar(
            label: isUrdu
                ? 'لین دین کی باقاعدگی اور تسلسل'
                : 'Transaction Activity & Consistency',
            score: metrics.activityScore,
            color: const Color(0xFFF59E0B),
            icon: PhosphorIcons.chartLineUp(),
          ),

          if (metrics.quickBillsCount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.receipt(),
                      size: 14, color: AppTheme.darkColor),
                  const SizedBox(width: 6),
                  UrduAwareText(
                    isUrdu
                        ? 'فوری بلز: ${metrics.fullyPaidQuickBills}/${metrics.quickBillsCount} مکمل ادا شدہ'
                        : 'Quick Bills: ${metrics.fullyPaidQuickBills}/${metrics.quickBillsCount} fully paid',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  if (metrics.hasRepeatProducts) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: UrduAwareText(
                        isUrdu ? 'مکرر پروڈکٹ ڈیمانڈ' : 'Repeat Buyer',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Smart Recommendation Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.lightbulb(),
                    size: 18, color: metrics.badgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: UrduAwareText(
                    metrics.recommendation,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Footer note
          UrduAwareText(
            isUrdu
                ? 'یہ حساب آپ کے مکمل لین دین اور کھاتہ ریکارڈ کی بنیاد پر ہے؛ پارٹی کو نظر نہیں آتا۔'
                : 'Calculated from full ledger history; private to you.',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 10.5,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerSummary(
    PartyTrustMetrics metrics,
    bool isUrdu,
    String? fontFamily,
  ) {
    final balanceLabel = metrics.outstandingBalance < -0.01
        ? (isUrdu ? 'ایڈوانس/کریڈٹ' : 'Advance / credit')
        : (isUrdu ? 'موجودہ بقایا' : 'Current due');
    final limitation = metrics.isSupplier
        ? (isUrdu
            ? 'یہ سپلائر کے کھاتے اور آپ کی ادائیگیوں کی کیفیت ہے، سپلائر کی ساکھ نہیں۔'
            : 'This reflects your supplier ledger and settlements, not the supplier’s reliability.')
        : (isUrdu
            ? 'کسی بل سے منسلک نہ ہونے والی وصولی پرانی رقم میں پہلے لگائی گئی ہے؛ اسکور صرف درج شدہ ریکارڈ کا اندازہ ہے۔'
            : 'Unlinked payments are applied to the oldest dues first. This is an estimate from recorded entries, not a credit guarantee.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.backgroundColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrduAwareText(
            '$balanceLabel: ${Formatters.formatAmountWithCurrency(metrics.outstandingBalance.abs())}',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 3),
          UrduAwareText(
            isUrdu
                ? '30 دن سے پرانا: ${Formatters.formatAmountWithCurrency(metrics.overdueBalance)}'
                : 'Over 30 days: ${Formatters.formatAmountWithCurrency(metrics.overdueBalance)}',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          if (metrics.unknownAgeBalance > 0.01) ...[
            const SizedBox(height: 3),
            UrduAwareText(
              isUrdu
                  ? 'عمر نامعلوم (ابتدائی بقایا): ${Formatters.formatAmountWithCurrency(metrics.unknownAgeBalance)}'
                  : 'Age unknown (opening balance): ${Formatters.formatAmountWithCurrency(metrics.unknownAgeBalance)}',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          UrduAwareText(
            limitation,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 10.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricProgressBar({
    required String label,
    required double score,
    required Color color,
    required IconData icon,
  }) {
    final roundScore = score.round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: UrduAwareText(
                  label,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkColor,
                  ),
                ),
              ),
              UrduAwareText(
                '$roundScore%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
