// lib/core/widgets/item_rate_history_card_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/utils/formatters.dart';

class ItemPriceHistory {
  final double price;
  final double quantity;
  final double total;
  final DateTime date;
  final String type;
  final double? changePercentage;
  final int? daysInterval;
  final String? unit;

  const ItemPriceHistory({
    required this.price,
    this.quantity = 1.0,
    double? total,
    required this.date,
    required this.type,
    this.changePercentage,
    this.daysInterval,
    this.unit,
  }) : total = total ?? (price * quantity);
}

class ItemRateHistoryCardWidget extends StatefulWidget {
  final String itemName;
  final String partyName;
  final List<ItemPriceHistory> history;
  final bool isUrdu;
  final String? fontFamily;
  final VoidCallback? onItemUpdated;
  final EdgeInsetsGeometry? margin;

  const ItemRateHistoryCardWidget({
    super.key,
    required this.itemName,
    required this.partyName,
    required this.history,
    this.isUrdu = true,
    this.fontFamily,
    this.onItemUpdated,
    this.margin,
  });

  @override
  State<ItemRateHistoryCardWidget> createState() =>
      _ItemRateHistoryCardWidgetState();
}

class _ItemRateHistoryCardWidgetState extends State<ItemRateHistoryCardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) return const SizedBox.shrink();

    final latest = widget.history.first;
    final isDecrease = latest.changePercentage != null &&
        latest.changePercentage! < 0;
    final isSame = latest.changePercentage != null &&
        latest.changePercentage == 0;

    // ═══ Trend color (sparkline) ═══
    final double? change = latest.changePercentage;
    Color sparkColor;
    if (change == null || change == 0) {
      sparkColor = AppTheme.themeColor;
    } else if (isDecrease) {
      sparkColor = AppTheme.incomeColor;
    } else {
      sparkColor = AppTheme.expenseColor;
    }

    // ═══ Change badge colors ═══
    final Color changeBg;
    final Color changeFg;
    if (isSame) {
      changeBg = Colors.white.withValues(alpha: 0.15);
      changeFg = Colors.white.withValues(alpha: 0.7);
    } else if (isDecrease) {
      changeBg = AppTheme.incomeColor.withValues(alpha: 0.30);
      changeFg = const Color(0xFFB8C74A);
    } else {
      changeBg = AppTheme.expenseColor.withValues(alpha: 0.25);
      changeFg = const Color(0xFFFCA58E);
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.darkColor.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor
                .withValues(alpha: _isExpanded ? 0.12 : 0.06),
            blurRadius: _isExpanded ? 28 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════
            // TOP — Dark gradient header (tap to toggle)
            // ═══════════════════════════════════════════════
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A4560),
                      AppTheme.darkColor,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  children: [
                    // Decorative circle
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    // Content
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ═══ Icon box ═══
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            PhosphorIcons.package(),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ═══ Name + count ═══
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UrduAwareText(
                                widget.itemName,
                                style: TextStyle(
                                  fontFamily: widget.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.3,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              UrduAwareText(
                                '${widget.history.length} ${widget.isUrdu ? "ریٹ تبدیلیاں" : "price changes"}',
                                style: TextStyle(
                                  fontFamily: widget.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // ═══ Latest price + change ═══
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UrduAwareText(
                              'Rs ${latest.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: changeBg,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (change != null) ...[
                                    Text(
                                      isSame
                                          ? '—'
                                          : (isDecrease ? '↓' : '↑'),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: changeFg,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  UrduAwareText(
                                    change == null
                                        ? (widget.isUrdu ? 'پہلی' : 'First')
                                        : isSame
                                        ? (widget.isUrdu ? 'وہی' : 'Same')
                                        : '${latest.changePercentage!.abs().toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: changeFg,
                                      fontFamily: widget.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ═══════════════════════════════════════════════
            // SPARKLINE — Rate trend
            // ═══════════════════════════════════════════════
            if (widget.history.length > 1)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.02),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.darkColor.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.chartLineUp(),
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        UrduAwareText(
                          widget.isUrdu ? 'ریٹ کا رجحان' : 'Rate Trend',
                          style: TextStyle(
                            fontFamily: widget.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        UrduAwareText(
                          '${_formatDate(widget.history.last.date)} → ${_formatDate(widget.history.first.date)}',
                          style: TextStyle(
                            fontFamily: widget.fontFamily,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 55,
                      child: CustomPaint(
                        painter: _CardSparklinePainter(
                          prices: widget.history.reversed
                              .map((h) => h.price)
                              .toList(),
                          color: sparkColor,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),

            // ═══════════════════════════════════════════════
            // EXPAND TOGGLE
            // ═══════════════════════════════════════════════
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.03),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppTheme.themeColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    UrduAwareText(
                      _isExpanded
                          ? (widget.isUrdu ? 'کم کریں' : 'Hide Changes')
                          : (widget.isUrdu
                          ? 'ریٹ تبدیلیاں دیکھیں'
                          : 'Show Rate Changes'),
                      style: TextStyle(
                        fontFamily: widget.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.themeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ═══════════════════════════════════════════════
            // EXPANDED LIST — Rate changes timeline
            // ═══════════════════════════════════════════════
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _buildRateChangesList(),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Rate Changes List — Timeline
  // ═════════════════════════════════════════════════════════════
  Widget _buildRateChangesList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        border: Border(
          top: BorderSide(
            color: AppTheme.darkColor.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: UrduAwareText(
              (widget.isUrdu
                  ? 'ریٹ تبدیلیوں کی ٹائم لائن'
                  : 'RATE CHANGES TIMELINE')
                  .toUpperCase(),
              style: TextStyle(
                fontFamily: widget.fontFamily,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: widget.history.asMap().entries.map((entry) {
                final i = entry.key;
                final curr = entry.value;
                final prev =
                i < widget.history.length - 1 ? widget.history[i + 1] : null;
                return _buildRateRow(curr, prev, i == widget.history.length - 1);
              }).toList(),
            ),
          ),

          // ═══ Bottom action — Item Options (Set Unit / Merge) ═══
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showItemOptionsPopup(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.themeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.sliders(),
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      UrduAwareText(
                        widget.isUrdu
                            ? 'آئٹم آپشنز (اکائی / مرج)'
                            : 'Item Options (Unit / Merge)',
                        style: TextStyle(
                          fontFamily: widget.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Rate Row — ٹائم لائن
  // ═════════════════════════════════════════════════════════════
  Widget _buildRateRow(
      ItemPriceHistory curr,
      ItemPriceHistory? prev,
      bool isLast,
      ) {
    final double? rowChange = (prev != null && prev.price > 0)
        ? ((curr.price - prev.price) / prev.price) * 100
        : null;
    final bool isDecrease = rowChange != null && rowChange < 0;
    final bool isSame = rowChange != null && rowChange == 0;

    // ═══ Colors ═══
    Color dotColor;
    Color badgeBg;
    Color badgeFg;
    String badgeText;
    IconData? badgeIcon;

    if (rowChange == null) {
      dotColor = const Color(0xFFCBD5E1);
      badgeBg = const Color(0xFFCBD5E1).withValues(alpha: 0.15);
      badgeFg = AppTheme.textSecondary;
      badgeText = widget.isUrdu ? 'نئی' : 'New';
      badgeIcon = null;
    } else if (isSame) {
      dotColor = const Color(0xFFCBD5E1);
      badgeBg = AppTheme.textSecondary.withValues(alpha: 0.10);
      badgeFg = AppTheme.textSecondary;
      badgeText = '—';
      badgeIcon = null;
    } else if (isDecrease) {
      dotColor = AppTheme.incomeColor;
      badgeBg = AppTheme.incomeColor.withValues(alpha: 0.12);
      badgeFg = AppTheme.incomeColor;
      badgeText = '${rowChange.abs().toStringAsFixed(1)}%';
      badgeIcon = Icons.arrow_downward_rounded;
    } else {
      dotColor = AppTheme.expenseColor;
      badgeBg = AppTheme.expenseColor.withValues(alpha: 0.10);
      badgeFg = AppTheme.expenseColor;
      badgeText = '${rowChange.abs().toStringAsFixed(1)}%';
      badgeIcon = Icons.arrow_upward_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
          bottom: BorderSide(
            color: AppTheme.darkColor.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ═══ Timeline dot ═══
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ═══ Date + detail ═══
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  _formatDate(curr.date),
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkColor,
                  ),
                ),
                const SizedBox(height: 1),
                UrduAwareText(
                  _buildChangeDetailText(curr, prev, rowChange, isDecrease),
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // ═══ Change badge ═══
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeIcon != null) ...[
                  Icon(badgeIcon, size: 10, color: badgeFg),
                  const SizedBox(width: 1),
                ],
                UrduAwareText(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: badgeFg,
                    fontFamily: widget.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ═══ Price (new + old) ═══
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              UrduAwareText(
                'Rs ${curr.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (prev != null && prev.price != curr.price) ...[
                const SizedBox(height: 1),
                UrduAwareText(
                  'Rs ${prev.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    decoration: TextDecoration.lineThrough,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══ Change detail text ═══
  String _buildChangeDetailText(
      ItemPriceHistory curr,
      ItemPriceHistory? prev,
      double? rowChange,
      bool isDecrease,
      ) {
    if (rowChange == null) {
      return widget.isUrdu ? 'پہلی خریداری' : 'First purchase';
    }
    if (rowChange == 0) {
      return widget.isUrdu ? 'کوئی تبدیلی نہیں' : 'No change';
    }
    final diff = (curr.price - (prev?.price ?? 0)).abs();
    final diffStr = Formatters.formatAmountWithCurrency(diff);
    return widget.isUrdu
        ? '${isDecrease ? "کمی" : "اضافہ"} $diffStr'
        : '${isDecrease ? "Decreased by" : "Increased by"} $diffStr';
  }

  // ═══ Date formatter ═══
  String _formatDate(DateTime date) {
    return DateFormat('d MMM', widget.isUrdu ? 'ur' : 'en').format(date);
  }

  // ═════════════════════════════════════════════════════════════
  // ITEM OPTIONS POPUP — (اکائی سیٹ کریں / مرج کریں)
  // ═════════════════════════════════════════════════════════════
  void _showItemOptionsPopup(BuildContext context) {
    final isUrdu = widget.isUrdu;
    final fontFamily = widget.fontFamily;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (popupCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    PhosphorIcons.package(),
                    color: AppTheme.themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        widget.itemName,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      UrduAwareText(
                        isUrdu ? 'آئٹم کی سیٹنگز و آپشنز' : 'Item Settings & Options',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Option 1: Set Unit (اکائی سیٹ کریں)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIcons.scales(),
                  color: const Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              title: UrduAwareText(
                isUrdu ? 'اکائی سیٹ کریں' : 'Set Unit',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkColor,
                ),
              ),
              subtitle: UrduAwareText(
                isUrdu
                    ? 'اس آئٹم کے لیے اکائی (کلو، ڈبہ، وغیرہ) منتخب کریں'
                    : 'Select unit (Kg, Box, etc.) for this item',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.pop(popupCtx);
                _showSetUnitDialog(context);
              },
            ),

            const SizedBox(height: 10),

            // Option 2: Merge Item (آئٹم مرج کریں)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIcons.gitMerge(),
                  color: const Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              title: UrduAwareText(
                isUrdu ? 'آئٹم مرج (ضم) کریں' : 'Merge Item',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkColor,
                ),
              ),
              subtitle: UrduAwareText(
                isUrdu
                    ? 'اس آئٹم کو کسی دوسرے آئٹم کے ساتھ ملائیں'
                    : 'Combine this item into another existing item',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.pop(popupCtx);
                _showMergeItemDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // 1. SET UNIT DIALOG & ACTION
  // ═════════════════════════════════════════════════════════════
  void _showSetUnitDialog(BuildContext context) {
    final isUrdu = widget.isUrdu;
    final fontFamily = widget.fontFamily;
    final units = ['ڈبہ', 'کلو', 'لیٹر', 'من', 'یونٹ', 'عدد', 'بوری', 'پیکٹ', 'گرام', 'درجن', 'میٹر', 'گز'];

    String? currentUnit;
    for (final h in widget.history) {
      if (h.unit != null && h.unit!.trim().isNotEmpty) {
        currentUnit = h.unit!.trim();
        break;
      }
    }

    String selectedUnit = currentUnit ?? 'کلو';
    final customCtrl = TextEditingController();
    if (!units.contains(selectedUnit)) {
      customCtrl.text = selectedUnit;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isCustom = !units.contains(selectedUnit);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(PhosphorIcons.scales(), color: AppTheme.themeColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: UrduAwareText(
                    isUrdu ? 'اکائی سیٹ کریں' : 'Set Unit',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.themeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: UrduAwareText(
                      '${isUrdu ? "آئٹم:" : "Item:"} ${widget.itemName}',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  UrduAwareText(
                    isUrdu ? 'اکائی منتخب کریں:' : 'Select Unit:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: units.map((u) {
                      final isSelected = u == selectedUnit;
                      return ChoiceChip(
                        label: UrduAwareText(
                          u,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.themeColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        onSelected: (_) {
                          setDialogState(() {
                            selectedUnit = u;
                            customCtrl.clear();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: customCtrl,
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        setDialogState(() {
                          selectedUnit = val.trim();
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'یا اپنی اکائی لکھیں (مثلاً گرام)' : 'Or type custom unit',
                      hintText: isUrdu ? 'اکائی لکھیں...' : 'Enter unit...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: UrduAwareText(
                  isUrdu ? 'منسوخ' : 'Cancel',
                  style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary),
                ),
              ),
              AppButton(
                text: isUrdu ? 'محفوظ کریں' : 'Save',
                onPressed: () {
                  final finalUnit = isCustom
                      ? customCtrl.text.trim()
                      : selectedUnit;
                  Navigator.pop(dialogContext);
                  if (finalUnit.isNotEmpty) {
                    _updateItemUnit(context, finalUnit);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateItemUnit(BuildContext context, String newUnit) async {
    final cleanUnit = newUnit.trim();
    if (cleanUnit.isEmpty) return;

    final db = Provider.of<DatabaseService>(context, listen: false);
    final allTx = db.getAllTransactions().toList();

    for (var tx in allTx) {
      bool modified = false;
      final updatedItems = tx.items.map((item) {
        if (item.description.trim().toLowerCase() == widget.itemName.trim().toLowerCase()) {
          modified = true;
          return TransactionItem(
            description: item.description,
            quantity: item.quantity,
            rate: item.rate,
            total: item.total,
            unit: cleanUnit,
            stockItemId: item.stockItemId,
          );
        }
        return item;
      }).toList();

      if (modified) {
        final map = tx.toMap();
        map['items'] = updatedItems.map((x) => x.toMap()).toList();
        map['updatedAt'] = DateTime.now().toIso8601String();
        final updatedTx = Transaction.fromMap(map);
        await db.updateTransaction(updatedTx);
      }
    }

    if (context.mounted) {
      AppToast.success(
        context,
        widget.isUrdu
            ? 'اکائی "$cleanUnit" کامیابی سے سیٹ ہو گئی'
            : 'Unit "$cleanUnit" updated successfully',
      );
    }
    if (widget.onItemUpdated != null) widget.onItemUpdated!();
  }

  // ═════════════════════════════════════════════════════════════
  // 2. MERGE ITEM DIALOG & ACTION
  // ═════════════════════════════════════════════════════════════
  void _showMergeItemDialog(BuildContext context) {
    final isUrdu = widget.isUrdu;
    final fontFamily = widget.fontFamily;
    final sourceName = widget.itemName.trim();

    final db = Provider.of<DatabaseService>(context, listen: false);
    final allTx = db.getAllTransactions();
    final Set<String> existingItems = {};

    for (var tx in allTx) {
      for (var item in tx.items) {
        final name = item.description.trim();
        if (name.isNotEmpty && name.toLowerCase() != sourceName.toLowerCase()) {
          existingItems.add(name);
        }
      }
    }

    final sortedItems = existingItems.toList()..sort();
    final targetCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(PhosphorIcons.gitMerge(), color: const Color(0xFF8B5CF6), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: UrduAwareText(
                    isUrdu ? 'آئٹم مرج (ضم) کریں' : 'Merge Item',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          isUrdu ? 'مرج کرنے کا مقصد:' : 'Merge description:',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6D28D9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        UrduAwareText(
                          isUrdu
                              ? '"$sourceName" کی تمام اینٹریز کو منتخب کردہ نئے آئٹم کے ساتھ ملا دیا جائے گا۔'
                              : 'All records of "$sourceName" will be merged into the selected target item.',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 11.5,
                            color: AppTheme.darkColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  UrduAwareText(
                    isUrdu ? 'کس آئٹم میں مرج کرنا چاہتے ہیں؟' : 'Target Item Name:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'نئے/ہدف آئٹم کا نام' : 'Target Item Name',
                      hintText: isUrdu ? 'نام منتخب یا درج کریں...' : 'Select or type item name...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (sortedItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    UrduAwareText(
                      isUrdu ? 'موجودہ آئٹمز میں سے منتخب کریں:' : 'Select from existing items:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: fontFamily,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: sortedItems.map((item) {
                            final isSelected = targetCtrl.text.trim().toLowerCase() == item.toLowerCase();
                            return ChoiceChip(
                              label: UrduAwareText(
                                item,
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: 11.5,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF8B5CF6),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                              onSelected: (_) {
                                setDialogState(() {
                                  targetCtrl.text = item;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: UrduAwareText(
                  isUrdu ? 'منسوخ' : 'Cancel',
                  style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary),
                ),
              ),
              AppButton(
                text: isUrdu ? 'مرج کریں' : 'Merge',
                onPressed: targetCtrl.text.trim().isEmpty
                    ? null
                    : () {
                        final targetName = targetCtrl.text.trim();
                        if (targetName.toLowerCase() == sourceName.toLowerCase()) {
                          AppToast.error(
                            dialogContext,
                            isUrdu
                                ? 'اسی نام میں مرج نہیں کیا جا سکتا'
                                : 'Cannot merge item into itself',
                          );
                          return;
                        }
                        Navigator.pop(dialogContext);
                        _confirmAndMergeItem(context, sourceName, targetName);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmAndMergeItem(
    BuildContext context,
    String sourceItem,
    String targetItem,
  ) {
    final isUrdu = widget.isUrdu;
    final fontFamily = widget.fontFamily;

    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: UrduAwareText(
          isUrdu ? 'مرج کی تصدیق' : 'Confirm Merge',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: UrduAwareText(
          isUrdu
              ? 'کیا آپ واقعی "$sourceItem" کو "$targetItem" میں مرج کرنا چاہتے ہیں؟'
              : 'Are you sure you want to merge "$sourceItem" into "$targetItem"?',
          style: TextStyle(fontFamily: fontFamily, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          AppButton(
            text: isUrdu ? 'جی ہاں، مرج کریں' : 'Yes, Merge',
            onPressed: () {
              Navigator.pop(confirmCtx);
              _mergeItemIntoTarget(context, targetItem);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _mergeItemIntoTarget(
    BuildContext context,
    String targetItemName,
  ) async {
    final sourceItem = widget.itemName.trim();
    final targetItem = targetItemName.trim();
    if (targetItem.isEmpty || sourceItem.toLowerCase() == targetItem.toLowerCase()) {
      return;
    }

    final db = Provider.of<DatabaseService>(context, listen: false);
    final allTx = db.getAllTransactions().toList();

    for (var tx in allTx) {
      bool modified = false;
      final updatedItems = tx.items.map((item) {
        if (item.description.trim().toLowerCase() == sourceItem.toLowerCase()) {
          modified = true;
          return TransactionItem(
            description: targetItem,
            quantity: item.quantity,
            rate: item.rate,
            total: item.total,
            unit: item.unit,
            stockItemId: item.stockItemId,
          );
        }
        return item;
      }).toList();

      if (modified) {
        final map = tx.toMap();
        map['items'] = updatedItems.map((x) => x.toMap()).toList();
        map['updatedAt'] = DateTime.now().toIso8601String();
        final updatedTx = Transaction.fromMap(map);
        await db.updateTransaction(updatedTx);
      }
    }

    if (context.mounted) {
      AppToast.success(
        context,
        widget.isUrdu
            ? '"$sourceItem" کو "$targetItem" میں مرج کر دیا گیا'
            : 'Merged "$sourceItem" into "$targetItem"',
      );
    }

    if (widget.onItemUpdated != null) {
      widget.onItemUpdated!();
    }
  }
}

// ═══════════════════════════════════════════════════════
// CARD SPARKLINE PAINTER — gradient + dots
// ═══════════════════════════════════════════════════════
class _CardSparklinePainter extends CustomPainter {
  final List<double> prices;
  final Color color;

  _CardSparklinePainter({required this.prices, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);

    final stepX = size.width / (prices.length - 1);

    // Points
    final points = <Offset>[];
    for (int i = 0; i < prices.length; i++) {
      final x = i * stepX;
      final y = size.height -
          ((prices[i] - minPrice) / range) * (size.height - 15) -
          8;
      points.add(Offset(x, y));
    }

    // ═══ Area gradient fill ═══
    final areaPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      areaPath.lineTo(points[i].dx, points[i].dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.lineTo(points.first.dx, size.height);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    canvas.drawPath(areaPath, areaPaint);

    // ═══ Line ═══
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // ═══ Dots ═══
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CardSparklinePainter oldDelegate) =>
      oldDelegate.prices != prices || oldDelegate.color != color;
}