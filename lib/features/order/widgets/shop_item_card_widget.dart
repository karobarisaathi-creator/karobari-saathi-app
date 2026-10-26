// lib/features/order/widgets/shop_item_card_widget.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/features/order/widgets/item_detail_dialog.dart';

class ShopItemCardWidget extends StatelessWidget {
  final ShopItem item;
  final Shop shop;
  final VoidCallback onQuantityIncrement;
  final VoidCallback onQuantityDecrement;
  final Function(double) onQuantitySet;
  final VoidCallback? onQuantityEdit;
  final bool quickBillMode;
  final bool showStockQuantity;
  final bool showStepper;

  const ShopItemCardWidget({
    super.key,
    required this.item,
    required this.shop,
    required this.onQuantityIncrement,
    required this.onQuantityDecrement,
    required this.onQuantitySet,
    this.onQuantityEdit,
    this.quickBillMode = false,
    this.showStockQuantity = true,
    this.showStepper = false,
  });

  @override
  Widget build(BuildContext context) {
    final selected = item.quantity > 0;
    final out = item.isOutOfStock;
    final low = item.isLowStock;
    final stockPercent = (item.stock / 100 * 100).clamp(0, 100).toDouble();

    // ═══════════════════════════════════════════════════════════
    // ⭐ goldColor (#607D8B) — AppTheme سے
    // ═══════════════════════════════════════════════════════════
    final goldColor = AppTheme.goldColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF5F7F8) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? goldColor.withValues(alpha: 0.55)
              : AppTheme.backgroundColor,
          width: selected ? 2 : 1.2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: goldColor.withValues(alpha: 0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Opacity(
        opacity: out ? 0.55 : 1.0,
        child: Column(
          children: [
            // ═══ Main row ═══
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Emoji/Image
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: selected
                              ? LinearGradient(
                                  colors: [
                                    goldColor,
                                    const Color(0xFF78909C),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFECF0F2),
                                    Color(0xFFD5DFE4),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: goldColor.withValues(alpha: 0.30),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: _buildItemImage(item,
                            fontSize: 26, borderRadius: 14),
                      ),
                      if (item.badge != null)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.verifiedGold,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: UrduAwareText(
                              item.badge == 'hot'
                                  ? '🔥'
                                  : item.badge == 'new'
                                      ? '✨'
                                      : (item.badge == '%' ||
                                              item.badge == 'discount'
                                          ? '%'
                                          : item.badge!),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          item.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: selected ? goldColor : AppTheme.darkColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            UrduAwareText(
                              Formatters.formatAmountWithCurrency(item.rate),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color:
                                    selected ? goldColor : AppTheme.darkColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (item.hasDiscount) ...[
                              const SizedBox(width: 5),
                              UrduAwareText(
                                Formatters.formatAmountWithCurrency(
                                    item.oldRate!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                            const SizedBox(width: 5),
                            UrduAwareText(
                              item.unit,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                    ),
                  ),

                  // Stepper
                  if (showStepper || quickBillMode)
                    _buildStepper(context, goldColor),
                ],
              ),
            ),

            // ═══ Footer — شفاف ═══
            if (quickBillMode)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: selected
                      ? goldColor.withValues(alpha: 0.14)
                      : goldColor.withValues(alpha: 0.06),
                  border: Border(
                    top: BorderSide(
                      color: selected
                          ? goldColor.withValues(alpha: 0.20)
                          : goldColor.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      out
                          ? PhosphorIcons.xCircle()
                          : PhosphorIcons.checkCircle(),
                      size: 13,
                      color: selected ? goldColor : AppTheme.incomeColor,
                    ),
                    const SizedBox(width: 5),
                    UrduAwareText(
                      out
                          ? 'اسٹاک ختم'
                          : showStockQuantity
                              ? 'بقیہ اسٹاک: ${((item.stock - item.quantity) < 0 ? 0 : (item.stock - item.quantity)).toStringAsFixed(item.stock % 1 == 0 ? 0 : 1)}'
                              : 'بل میں شامل کریں',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w800,
                        color: selected ? goldColor : AppTheme.incomeColor,
                      ),
                    ),
                    const Spacer(),
                    UrduAwareText(
                      Formatters.formatAmountWithCurrency(item.total),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: selected ? goldColor : AppTheme.goldColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () => _openDetail(context),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? goldColor.withValues(alpha: 0.14)
                        : goldColor.withValues(alpha: 0.06),
                    border: Border(
                      top: BorderSide(
                        color: selected
                            ? goldColor.withValues(alpha: 0.20)
                            : goldColor.withValues(alpha: 0.10),
                        width: 1,
                      ),
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.info(),
                        size: 13,
                        color: goldColor,
                      ),
                      const SizedBox(width: 5),
                      UrduAwareText(
                        'تفصیل دیکھیں',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? goldColor : AppTheme.darkColor,
                        ),
                      ),
                      const Spacer(),
                      // Stock progress bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerRight,
                          widthFactor: out ? 0 : stockPercent / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: out
                                  ? AppTheme.expenseColor
                                  : (low
                                      ? AppTheme.expenseColor
                                      : AppTheme.incomeColor),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: out
                              ? AppTheme.expenseColor
                              : (low
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFF0FDF4)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: UrduAwareText(
                          out ? 'ختم' : (low ? 'کم' : 'دستیاب'),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: out
                                ? Colors.white
                                : (low
                                    ? AppTheme.expenseColor
                                    : AppTheme.incomeColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Stepper — goldColor
  // ═══════════════════════════════════════════════════════════
  Widget _buildStepper(BuildContext context, Color goldColor) {
    final qty = item.quantity;
    final selected = qty > 0;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: selected ? goldColor : const Color(0xFFECF0F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? goldColor : const Color(0xFFD5DFE4),
          width: 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: goldColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: qty > 0 ? onQuantityDecrement : null,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: qty > 0 ? Colors.white : const Color(0xFFEEF1F5),
                  shape: BoxShape.circle,
                  boxShadow: qty > 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  PhosphorIcons.minus(),
                  size: 14,
                  color: qty > 0
                      ? goldColor
                      : AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),

          // Value — tap to edit
          InkWell(
            onTap: onQuantityEdit ?? () => _openDetail(context),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              constraints: const BoxConstraints(minWidth: 34),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              child: UrduAwareText(
                qty == qty.roundToDouble()
                    ? qty.toInt().toString()
                    : qty.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AppTheme.darkColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),

          // Plus
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (item.isOutOfStock || qty >= item.stock)
                  ? null
                  : onQuantityIncrement,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (item.isOutOfStock || qty >= item.stock)
                      ? const Color(0xFFEEF1F5)
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: (item.isOutOfStock || qty >= item.stock)
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Icon(
                  PhosphorIcons.plus(),
                  size: 14,
                  color: (item.isOutOfStock || qty >= item.stock)
                      ? AppTheme.textSecondary.withValues(alpha: 0.5)
                      : goldColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Detail Dialog Popup
  // ═══════════════════════════════════════════════════════════
  void _openDetail(BuildContext context) {
    showItemDetailDialog(context, item);
  }

  Widget _buildItemImage(ShopItem item,
      {double fontSize = 26, double borderRadius = 14}) {
    final path = item.imageUrl?.trim();

    // ═══════════════════════════════════════════════════════════
    // ⭐ ہمیشہ پیکج آئیکن — کوئی emoji نہیں
    // ═══════════════════════════════════════════════════════════
    final fallback = Center(
      child: Icon(
        PhosphorIcons.package(),
        size: fontSize + 2,
        color: Colors.white,
      ),
    );

    // اگر imageUrl خالی ہے → پیکج آئیکن
    if (path == null ||
        path.isEmpty ||
        path == '?' ||
        path == '؟' ||
        path.length < 5) {
      return fallback;
    }

    // اگر imageUrl ہے → تصویر دکھائیں
    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isRemote
          ? Image.network(
              path,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          : Image.file(
              File(path),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
