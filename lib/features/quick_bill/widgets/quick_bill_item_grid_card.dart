// lib/features/quick_bill/widgets/quick_bill_item_grid_card.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// QuickBillItemGridCard
// (Verified Gold Color Accent)
// ═══════════════════════════════════════════════════════════════
class QuickBillItemGridCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double rate;
  final String unit;
  final double stock;        // کل دستیاب اسٹاک (0 = لامحدود)
  final double quantity;     // موجودہ منتخب مقدار
  final bool stopWhenOut;    // اسٹاک ختم ہونے پر روکیں
  final bool hasImageOnly;   // صرف تصویر دکھانی ہے؟

  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onQuantityTap;
  final Color accentColor;

  const QuickBillItemGridCard({
    super.key,
    required this.name,
    this.imageUrl,
    required this.rate,
    required this.unit,
    required this.stock,
    required this.quantity,
    this.stopWhenOut = true,
    this.hasImageOnly = false,
    this.accentColor = AppTheme.slateColor,
    required this.onIncrement,
    required this.onDecrement,
    this.onQuantityTap,
  });

  // ── ایپ تھیم رنگ ──
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = AppTheme.darkColor;
  static const Color _textSecondary = AppTheme.textSecondary;
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _success = AppTheme.incomeColor;
  static const Color _danger = AppTheme.expenseColor;

  // لامحدود اسٹاک کی نمائندگی
  static const double _unlimitedStock = 1000000000;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    final isUnlimited = stock >= _unlimitedStock;
    final remaining = isUnlimited ? _unlimitedStock : (stock - quantity).clamp(0.0, stock);
    final out = !isUnlimited && remaining <= 0;
    final low = !isUnlimited && remaining <= 3 && remaining > 0;

    final stockPercent = isUnlimited
        ? 100.0
        : (stock <= 0 ? 0.0 : (remaining / stock * 100).clamp(0.0, 100.0));

    final stockLimitReached = stopWhenOut && !isUnlimited && quantity >= stock;

    final cardSelected = accentColor == AppTheme.verifiedGold
        ? const Color(0xFFFFFBEB)
        : accentColor.withValues(alpha: 0.06);
    final accentSoft = accentColor.withValues(alpha: 0.12);

    return Opacity(
      opacity: out ? 0.5 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: selected ? cardSelected : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accentColor.withValues(alpha: 0.8) : _border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── اوپر کا حصہ (تصویر، نام، ریٹ، اسٹاک بار) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // تصویر / آئیکن (Expanded تاکہ اوور فلو نہ ہو)
                    Expanded(child: _buildImageBox(selected, accentSoft)),

                    const SizedBox(height: 5),

                    // نام (بڑا فونٹ)
                    UrduAwareText(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: selected ? accentColor : _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // ریٹ + یونٹ
                    Row(
                      children: [
                        Flexible(
                          child: UrduAwareText(
                            Formatters.formatAmountWithCurrency(rate),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: selected ? accentColor : _textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unit.trim().isNotEmpty) ...[
                          const SizedBox(width: 4),
                          UrduAwareText(
                            unit,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // اسٹاک بار
                    if (!isUnlimited) _buildStockBar(out, low, stockPercent),
                  ],
                ),
              ),
            ),

            // ── باٹم اسٹیپر بار ──
            const Divider(height: 1, thickness: 1, color: _border),
            _buildBottomStepperBar(selected, stockLimitReached),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // تصویر باکس (کل رقم بیج کے ساتھ)
  // ═══════════════════════════════════════════════════════════
  Widget _buildImageBox(bool selected, Color accentSoft) {
    final totalAmount = quantity * rate;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [accentColor.withValues(alpha: 0.18), accentSoft]
              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? accentColor.withValues(alpha: 0.4)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Stack(
        children: [
          // تصویر / آئیکن
          Positioned.fill(
            child: _buildItemImage(selected),
          ),

          // تصویر کے اوپر کل رقم کا بیج (اوپر بائیں)
          if (quantity > 0)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: UrduAwareText(
                  Formatters.formatAmountWithCurrency(totalAmount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // اسٹاک بار
  // ═══════════════════════════════════════════════════════════
  Widget _buildStockBar(bool out, bool low, double stockPercent) {
    final remaining = (stock - quantity).clamp(0.0, stock);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2.5,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: stockPercent / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: out ? _danger : (low ? _danger : _success),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        UrduAwareText(
          'اسٹاک: ${remaining.toStringAsFixed(stock % 1 == 0 ? 0 : 1)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: out ? _danger : (low ? _danger : _textSecondary),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // باٹم اسٹیپر بار
  // ═══════════════════════════════════════════════════════════
  Widget _buildBottomStepperBar(bool selected, bool stockLimitReached) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          // مائنس (-) بٹن
          Expanded(
            flex: 1,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: quantity > 0 ? onDecrement : null,
                child: Center(
                  child: Icon(
                    PhosphorIcons.minus(PhosphorIconsStyle.bold),
                    size: 16,
                    color: quantity > 0
                        ? accentColor
                        : _textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
          // کھڑی لائن (Vertical Divider)
          Container(width: 1, color: _border),

          // سینٹر میں مقدار (Quantity)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: onQuantityTap,
              child: Container(
                alignment: Alignment.center,
                child: UrduAwareText(
                  quantity == quantity.roundToDouble()
                      ? quantity.toInt().toString()
                      : quantity.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: selected ? accentColor : _textPrimary,
                  ),
                ),
              ),
            ),
          ),
          // کھڑی لائن (Vertical Divider)
          Container(width: 1, color: _border),

          // پلس (+) بٹن
          Expanded(
            flex: 1,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: !stockLimitReached ? onIncrement : null,
                child: Center(
                  child: Icon(
                    PhosphorIcons.plus(PhosphorIconsStyle.bold),
                    size: 16,
                    color: !stockLimitReached
                        ? accentColor
                        : _textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // تصویر / آئیکن
  // ═══════════════════════════════════════════════════════════
  Widget _buildItemImage(bool selected) {
    final path = imageUrl?.trim();

    Widget buildFallback(BoxConstraints constraints) {
      final iconSize =
          (constraints.biggest.shortestSide * 0.35).clamp(28.0, 72.0);
      return Center(
        child: Icon(
          PhosphorIcons.package(),
          size: iconSize,
          color: selected ? accentColor : _textSecondary,
        ),
      );
    }

    if (path == null ||
        path.isEmpty ||
        path == '?' ||
        path == '؟' ||
        path.length < 5) {
      return LayoutBuilder(
        builder: (ctx, constraints) => buildFallback(constraints),
      );
    }

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: isRemote
          ? Image.network(
              path,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => LayoutBuilder(
                builder: (ctx, constraints) => buildFallback(constraints),
              ),
            )
          : Image.file(
              File(path),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => LayoutBuilder(
                builder: (ctx, constraints) => buildFallback(constraints),
              ),
            ),
    );
  }
}
