// lib/features/accounts/widgets/party_trust_popup.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/accounts/widgets/party_tools_grid_widget.dart';

class PartyTrustPopup extends StatelessWidget {
  final Account party;
  final PartyTrustMetrics metrics;
  final bool isUrdu;
  final String? fontFamily;

  const PartyTrustPopup({
    super.key,
    required this.party,
    required this.metrics,
    required this.isUrdu,
    this.fontFamily,
  });

  static Future<void> show({
    required BuildContext context,
    required Account party,
    required PartyTrustMetrics metrics,
    required bool isUrdu,
    String? fontFamily,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.darkColor.withValues(alpha: 0.55),
      builder: (_) => PartyTrustPopup(
        party: party,
        metrics: metrics,
        isUrdu: isUrdu,
        fontFamily: fontFamily,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Color helpers
  // ═══════════════════════════════════════════════════════════
  String _getColorClass() {
    if (!metrics.hasTransactionHistory) return 'grey';
    if (metrics.overallScore >= 75) return 'green';
    if (metrics.overallScore >= 55) return 'amber';
    if (metrics.overallScore >= 35) return 'orange';
    return 'red';
  }

  Color _getBadgeColor() {
    switch (_getColorClass()) {
      case 'green':
        return const Color(0xFF16A34A);
      case 'amber':
        return const Color(0xFFD97706);
      case 'orange':
        return const Color(0xFFEA580C);
      case 'red':
        return const Color(0xFFDC2626);
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getBadgeBgColor() {
    switch (_getColorClass()) {
      case 'green':
        return const Color(0xFFECFDF5);
      case 'amber':
        return const Color(0xFFFFFBEB);
      case 'orange':
        return const Color(0xFFFFF7ED);
      case 'red':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF9FAFB);
    }
  }

  String _getCategoryLabel() {
    switch (_getColorClass()) {
      case 'green':
        return isUrdu ? 'اچھا' : 'Good';
      case 'amber':
        return isUrdu ? 'درمیانہ' : 'Fair';
      case 'orange':
        return isUrdu ? 'احتیاط' : 'Caution';
      case 'red':
        return isUrdu ? 'کمزور' : 'Poor';
      default:
        return isUrdu ? 'نیا' : 'New';
    }
  }

  String _getRiskLabel() {
    switch (metrics.riskLevel) {
      case 'low':
        return isUrdu ? 'کم' : 'Low';
      case 'medium':
        return isUrdu ? 'درمیانہ' : 'Medium';
      case 'high':
        return isUrdu ? 'زیادہ' : 'High';
      default:
        return isUrdu ? 'نامعلوم' : 'Unknown';
    }
  }

  Color _getRiskColor() {
    switch (metrics.riskLevel) {
      case 'low':
        return const Color(0xFF16A34A);
      case 'medium':
        return const Color(0xFFD97706);
      case 'high':
        return const Color(0xFFDC2626);
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getHabitLabel() {
    switch (metrics.paymentHabit) {
      case 'onTime':
        return isUrdu ? 'وقت پر ادائیگی' : 'Pays on time';
      case 'slightDelay':
        return isUrdu ? 'تھوڑی تاخیر' : 'Slight delay';
      case 'late':
        return isUrdu ? 'بہت تاخیر' : 'Very late';
      default:
        return isUrdu ? 'کوئی ریکارڈ نہیں' : 'No record';
    }
  }

  Color _getHabitColor() {
    switch (metrics.paymentHabit) {
      case 'onTime':
        return const Color(0xFF16A34A);
      case 'slightDelay':
        return const Color(0xFFD97706);
      case 'late':
        return const Color(0xFFDC2626);
      default:
        return AppTheme.textSecondary;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Dots builder — 10 گھنے
  // ═══════════════════════════════════════════════════════════
  List<Widget> _buildDots() {
    final dots = <Widget>[];
    final score = metrics.overallScore;
    final hasScore = metrics.hasTransactionHistory;
    final color = _getBadgeColor();

    for (int i = 0; i < 10; i++) {
      final dotStart = i * 10;
      final dotEnd = dotStart + 10;

      Widget dot;
      if (!hasScore) {
        dot = _dot(
          Colors.black.withValues(alpha: 0.08),
          null,
        );
      } else if (score >= dotEnd) {
        // مکمل بھرا
        dot = _dot(
          color,
          color.withValues(alpha: 0.4),
        );
      } else if (score >= dotStart + 5) {
        // آدھا بھرا
        dot = _dot(
          color,
          null,
          halfFilled: true,
        );
      } else {
        // خالی
        dot = _dot(
          Colors.black.withValues(alpha: 0.08),
          null,
        );
      }

      dots.add(dot);
      if (i < 9) {
        dots.add(const SizedBox(width: 4));
      }
    }
    return dots;
  }

  Widget _dot(Color fill, Color? shadow, {bool halfFilled = false}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: halfFilled
            ? LinearGradient(
                stops: const [0.5, 0.5],
                colors: [fill, Colors.black.withValues(alpha: 0.08)],
              )
            : null,
        color: halfFilled ? null : fill,
        boxShadow: shadow != null
            ? [
                BoxShadow(
                  color: shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final partyName = party.name;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkColor.withValues(alpha: 0.4),
              blurRadius: 60,
              offset: const Offset(0, 25),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══ HEADER ═══
            _buildHeader(context, partyName),

            // ═══ BODY ═══
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 14, bottom: 14),
                child: Column(
                  children: [
                    // Trust Point Box
                    _buildTrustBox(),
                    // Extra Info (3 cells)
                    _buildExtraInfo(),
                    // Payment Habit
                    if (metrics.paymentHabit != 'none') _buildHabit(),
                    // Last Transaction
                    if (metrics.lastTxType != null) _buildLastTx(),
                    // Recorded settlement history
                    if (metrics.chargeEntryCount > 0) _buildSettlementSummary(),
                    // Opinion
                    _buildOpinion(),
                  ],
                ),
              ),
            ),

            // ═══ FOOTER ═══
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, String partyName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.darkColor.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
              size: 16,
              color: AppTheme.themeColor,
            ),
          ),
          const SizedBox(width: 10),

          // Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  metrics.isSupplier
                      ? (isUrdu
                          ? 'سپلائر کو ہماری ادائیگی'
                          : 'Our Payment Record with Supplier')
                      : (isUrdu
                          ? 'گاہک کی ادائیگی کا ریکارڈ'
                          : 'Customer Payment Record'),
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 9,
                      color: AppTheme.expenseColor,
                    ),
                    const SizedBox(width: 3),
                    UrduAwareText(
                      isUrdu ? 'صرف آپ دیکھ سکتے ہیں' : 'Only you can see this',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (metrics.trendPercent != null &&
              metrics.trendPercent!.abs() >= 1) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: (metrics.trendPercent! >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: UrduAwareText(
                '${metrics.trendPercent! >= 0 ? '↑' : '↓'} ${metrics.trendPercent!.abs().round()}%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: metrics.trendPercent! >= 0
                      ? const Color(0xFF047857)
                      : const Color(0xFFB91C1C),
                ),
              ),
            ),
          ],

          // Close button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.darkColor.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppTheme.darkColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TRUST BOX
  // ═══════════════════════════════════════════════════════════
  Widget _buildTrustBox() {
    final hasScore = metrics.hasTransactionHistory;
    final badgeColor = _getBadgeColor();
    final badgeBg = _getBadgeBgColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badgeColor.withValues(alpha: 0.12),
            badgeColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Big number
          UrduAwareText(
            hasScore ? '${metrics.overallScore.round()}' : '—',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: badgeColor,
              height: 1,
              letterSpacing: -2,
              fontFamily: null,
            ),
          ),
          const SizedBox(height: 2),

          // Label
          UrduAwareText(
            isUrdu ? 'بھروسہ پوائنٹ' : 'TRUST POINT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              letterSpacing: 0.5,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 12),

          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildDots(),
          ),
          const SizedBox(height: 10),

          // Category
          UrduAwareText(
            _getCategoryLabel(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EXTRA INFO — 3 cells
  // ═══════════════════════════════════════════════════════════
  Widget _buildExtraInfo() {
    final riskLabel = _getRiskLabel();
    final riskColor = _getRiskColor();
    final avgDays = metrics.averagePaymentDays;
    final balance = metrics.outstandingBalance.abs();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCell(
              value: riskLabel,
              label: isUrdu ? 'خطرہ' : 'Risk',
              icon: '🎯',
              color: riskColor,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildInfoCell(
              value: avgDays != null ? '${avgDays.round()}d' : '—',
              label: isUrdu ? 'اوسط دن' : 'Avg Days',
              icon: '⏱️',
              color: avgDays == null
                  ? AppTheme.themeColor
                  : avgDays < 30
                      ? const Color(0xFF16A34A)
                      : avgDays < 60
                          ? const Color(0xFFD97706)
                          : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildInfoCell(
              value: Formatters.formatAmountWithCurrency(balance),
              label: metrics.isSupplier
                  ? (isUrdu ? 'واجب' : 'Payable')
                  : (isUrdu ? 'وصول' : 'Due'),
              icon: '💰',
              color: balance > 0
                  ? const Color(0xFFEA580C)
                  : const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCell({
    required String value,
    required String label,
    required String icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.darkColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UrduAwareText(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
              letterSpacing: -0.3,
              fontFamily: null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          UrduAwareText(
            '$icon $label',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.2,
              fontFamily: fontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PAYMENT HABIT
  // ═══════════════════════════════════════════════════════════
  Widget _buildHabit() {
    final habitLabel = _getHabitLabel();
    final habitColor = _getHabitColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.darkColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  isUrdu ? 'ادائیگی کی عادت' : 'PAYMENT HABIT',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                UrduAwareText(
                  habitLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: habitColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LAST TRANSACTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildLastTx() {
    final isPayment = metrics.lastTxType == 'payment';
    final amount = metrics.lastTxAmount ?? 0;
    final daysAgo = metrics.lastTxDaysAgo ?? 0;

    final daysAgoText = daysAgo == 0
        ? (isUrdu ? 'آج' : 'Today')
        : daysAgo == 1
            ? (isUrdu ? 'کل' : 'Yesterday')
            : '$daysAgo ${isUrdu ? "دن پہلے" : "days ago"}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.darkColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isPayment ? '💵' : '🛒',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  isPayment
                      ? (isUrdu ? 'آخری ادائیگی' : 'Last payment')
                      : (isUrdu ? 'آخری خریداری' : 'Last purchase'),
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                UrduAwareText(
                  Formatters.formatAmountWithCurrency(amount),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkColor,
                    fontFamily: null,
                  ),
                ),
                const SizedBox(height: 1),
                UrduAwareText(
                  daysAgoText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RECORDED SETTLEMENT HISTORY
  // ═══════════════════════════════════════════════════════════
  Widget _buildSettlementSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrduAwareText(
            isUrdu ? 'کھاتے کی ادائیگی کا خلاصہ' : 'ACCOUNT SETTLEMENT SUMMARY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _buildSettlementCount(
                  isUrdu ? 'کل' : 'Entries',
                  metrics.chargeEntryCount,
                  AppTheme.darkColor,
                ),
              ),
              Expanded(
                child: _buildSettlementCount(
                  isUrdu ? 'مکمل' : 'Settled',
                  metrics.fullyPaidEntries,
                  const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _buildSettlementCount(
                  isUrdu ? 'جزوی' : 'Partial',
                  metrics.partiallyPaidEntries,
                  const Color(0xFFD97706),
                ),
              ),
              Expanded(
                child: _buildSettlementCount(
                  isUrdu ? 'باقی' : 'Open',
                  metrics.unpaidEntries,
                  const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementCount(String label, int count, Color color) {
    return Column(
      children: [
        UrduAwareText(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // OPINION
  // ═══════════════════════════════════════════════════════════
  Widget _buildOpinion() {
    final badgeColor = _getBadgeColor();
    final op = _getOpinion();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(op['icon']!, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  op['action']!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    fontFamily: fontFamily,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                UrduAwareText(
                  op['text']!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getOpinion() {
    final score = metrics.overallScore;
    final isSupplier = metrics.isSupplier;

    if (!metrics.hasTransactionHistory) {
      return {
        'icon': '🆕',
        'action': isUrdu ? 'ابھی کوئی رائے نہیں' : 'No opinion yet',
        'text': isUrdu
            ? 'لین دین شروع کریں تو رائے بنے گی'
            : 'Opinion will form after transactions',
      };
    }

    if (score >= 75) {
      return {
        'icon': '✅',
        'action': isSupplier
            ? (isUrdu ? 'ادائیگی جاری رکھیں' : 'Continue payments')
            : (isUrdu ? 'مزید لین دین کریں' : 'Continue more transactions'),
        'text': isSupplier
            ? (isUrdu
                ? 'سپلائر کو ادائیگی کا ریکارڈ مضبوط ہے، اعتماد بڑھا سکتے ہیں'
                : 'Payment record with supplier is strong, can build more trust')
            : (isUrdu
                ? 'گاہک کا ریکارڈ اچھا ہے، اعتماد بڑھا سکتے ہیں'
                : 'Customer record is good, can build more trust'),
      };
    } else if (score >= 55) {
      return {
        'icon': '⚖️',
        'action': isUrdu ? 'محدود لین دین کریں' : 'Limit transactions',
        'text': isSupplier
            ? (isUrdu
                ? 'کچھ ادائیگیاں واجب ہیں، پہلے پرانی رقم دیکھیں'
                : 'Some payments due, check old amount first')
            : (isUrdu
                ? 'کچھ بقایا ہے، پہلے پرانی رقم وصول کریں'
                : 'Some dues pending, recover old amount first'),
      };
    } else if (score >= 35) {
      return {
        'icon': '⚠️',
        'action': isUrdu ? 'احتیاط سے لین دین کریں' : 'Transact with caution',
        'text': isSupplier
            ? (isUrdu
                ? 'ادائیگی میں تاخیر ہے، شرائط دوبارہ طے کریں'
                : 'Payment is delayed, re-negotiate terms')
            : (isUrdu
                ? 'بقایا بڑھ رہا ہے، نقد لین دین کریں'
                : 'Dues increasing, do cash transactions'),
      };
    } else {
      return {
        'icon': '🚫',
        'action': isUrdu ? 'لین دین نہ کریں' : 'Do not transact',
        'text': isSupplier
            ? (isUrdu
                ? 'سپلائر کے واجب بقایا اور ادائیگی کی تاریخ کا جائزہ لیں۔'
                : 'Review payable balances and your payment history with this supplier.')
            : (isUrdu ? 'پہلے پرانا حساب صاف کریں' : 'Clear old account first'),
      };
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════════
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            backgroundColor: AppTheme.darkColor.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: UrduAwareText(
            isUrdu ? 'بند کریں' : 'Close',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkColor,
            ),
          ),
        ),
      ),
    );
  }
}
