// lib/features/order/widgets/shop_item_card_widget.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/shop_model.dart';

class ShopItemCardWidget extends StatelessWidget {
  final ShopItem item;
  final Shop shop;
  final VoidCallback onQuantityIncrement;
  final VoidCallback onQuantityDecrement;
  final Function(double) onQuantitySet;
  final VoidCallback? onQuantityEdit;
  final bool quickBillMode;
  final bool showStockQuantity;

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
  });

  @override
  Widget build(BuildContext context) {
    final selected = item.quantity > 0;
    final out = item.isOutOfStock;
    final low = item.isLowStock;
    final stockPercent = (item.stock / 100 * 100).clamp(0, 100).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.themeColor : AppTheme.backgroundColor,
          width: 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppTheme.themeColor.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: out ? 0.55 : 1.0,
        child: Column(
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Emoji
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: selected
                              ? const LinearGradient(
                                  colors: [
                                    AppTheme.themeColor,
                                    Color(0xFF4A8FE3),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFEEF4FF),
                                    Color(0xFFDCE7F7),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _buildItemImage(item, fontSize: 26, borderRadius: 14),
                      ),
                      if (item.badge != null)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: item.badge == 'hot'
                                    ? [
                                        AppTheme.expenseColor,
                                        const Color(0xFFE54733),
                                      ]
                                    : item.badge == 'new'
                                        ? [
                                            AppTheme.incomeColor,
                                            const Color(0xFF6B7A1F),
                                          ]
                                        : [
                                            const Color(0xFFF59E0B),
                                            const Color(0xFFFBBF24),
                                          ],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: UrduAwareText(
                              item.badge == 'hot'
                                  ? '🔥'
                                  : item.badge == 'new'
                                      ? '✨'
                                      : '%',
                              style: const TextStyle(fontSize: 9),
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
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            UrduAwareText(
                              'Rs ${item.rate.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.themeColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (item.hasDiscount) ...[
                              const SizedBox(width: 5),
                              UrduAwareText(
                                'Rs ${item.oldRate!.toStringAsFixed(0)}',
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
                        if (!quickBillMode) Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 11,
                              color: AppTheme.verifiedGold,
                            ),
                            const SizedBox(width: 2),
                            UrduAwareText(
                              '${item.rating}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Stepper
                  _buildStepper(context),
                ],
              ),
            ),

            // Footer — Tap to see detail
            if (quickBillMode)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      out ? PhosphorIcons.xCircle() : PhosphorIcons.checkCircle(),
                      size: 13,
                      color: out ? AppTheme.expenseColor : AppTheme.incomeColor,
                    ),
                    const SizedBox(width: 5),
                    UrduAwareText(
                      out
                          ? 'اسٹاک ختم'
                          : showStockQuantity
                              ? 'اسٹاک: ${item.stock}'
                              : 'بل میں شامل کریں',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: out ? AppTheme.expenseColor : AppTheme.incomeColor,
                      ),
                    ),
                    const Spacer(),
                    UrduAwareText(
                      'Rs ${item.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.themeColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () => _openDetail(context),
                child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(14),
                    ),
                  ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.info(),
                      size: 13,
                      color: AppTheme.themeColor,
                    ),
                    const SizedBox(width: 5),
                    const UrduAwareText(
                      'تفصیل دیکھیں',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.themeColor,
                      ),
                    ),
                    const Spacer(),
                    // Stock bar
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

  Widget _buildStepper(BuildContext context) {
    final qty = item.quantity;
    final selected = qty > 0;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEEF4FF) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppTheme.themeColor : AppTheme.backgroundColor,
          width: 1.5,
        ),
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
                            color: AppTheme.darkColor.withValues(alpha: 0.06),
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
                      ? AppTheme.themeColor
                      : AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),

          // Value — tap to open detail
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
                  color: selected ? AppTheme.themeColor : AppTheme.darkColor,
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
                            color: AppTheme.darkColor.withValues(alpha: 0.06),
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
                      : AppTheme.themeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    int tempQty = item.quantity.toInt();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final out = item.isOutOfStock;
          final low = item.isLowStock;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.themeColor,
                              Color(0xFF4A8FE3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.themeColor.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _buildItemImage(item, fontSize: 28, borderRadius: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UrduAwareText(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            UrduAwareText(
                              '${shop.name}  •  ${item.category}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF1F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            UrduAwareText(
                              'Rs ${item.rate.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.themeColor,
                                letterSpacing: -0.8,
                              ),
                            ),
                            if (item.hasDiscount) ...[
                              const SizedBox(width: 8),
                              UrduAwareText(
                                'Rs ${item.oldRate!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: UrduAwareText(
                                  '${item.discountPercent}% آف',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.expenseColor,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            UrduAwareText(
                              item.unit,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Description
                        if (item.description != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12),
                              border: const Border(
                                right: BorderSide(
                                  color: AppTheme.themeColor,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: UrduAwareText(
                              item.description!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.9,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Highlights
                        if (item.highlights.isNotEmpty) ...[
                          _DetailSectionTitle(
                            icon: PhosphorIcons.checkCircle(),
                            title: 'خصوصیات',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: item.highlights
                                .map((h) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        border: Border.all(
                                            color: const Color(0xFFBBF7D0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check,
                                            size: 11,
                                            color: AppTheme.incomeColor,
                                          ),
                                          const SizedBox(width: 5),
                                          UrduAwareText(
                                            h,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.incomeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Info grid
                        _DetailSectionTitle(
                          icon: PhosphorIcons.info(),
                          title: 'اضافی معلومات',
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: [
                            _buildInfoTile(
                              'دستیابی',
                              out ? 'ختم' : (low ? 'کم اسٹاک' : 'دستیاب'),
                              color: out || low
                                  ? AppTheme.expenseColor
                                  : AppTheme.incomeColor,
                            ),
                            _buildInfoTile('ریٹنگ', '★ ${item.rating}'),
                            _buildInfoTile('کیٹیگری', item.category),
                            _buildInfoTile('ڈیلیوری', shop.deliveryTime),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEF1F5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Modal stepper
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.backgroundColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: tempQty > 0
                                    ? () => setSheetState(() => tempQty--)
                                    : null,
                                borderRadius: BorderRadius.circular(11),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: tempQty > 0
                                        ? Colors.white
                                        : const Color(0xFFEEF1F5),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    PhosphorIcons.minus(),
                                    size: 16,
                                    color: tempQty > 0
                                        ? AppTheme.themeColor
                                        : AppTheme.textSecondary
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 42),
                              alignment: Alignment.center,
                              child: UrduAwareText(
                                '$tempQty',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkColor,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: (out || tempQty >= item.stock)
                                    ? null
                                    : () => setSheetState(() => tempQty++),
                                borderRadius: BorderRadius.circular(11),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: (out || tempQty >= item.stock)
                                        ? const Color(0xFFEEF1F5)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    PhosphorIcons.plus(),
                                    size: 16,
                                    color: (out || tempQty >= item.stock)
                                        ? AppTheme.textSecondary
                                            .withValues(alpha: 0.5)
                                        : AppTheme.themeColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Add button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tempQty > 0
                                ? AppTheme.incomeColor
                                : AppTheme.themeColor,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            onQuantitySet(tempQty.toDouble());
                            Navigator.pop(ctx);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tempQty > 0
                                    ? PhosphorIcons.checkCircle()
                                    : PhosphorIcons.shoppingCart(),
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              UrduAwareText(
                                tempQty > 0
                                    ? 'کارٹ میں شامل ($tempQty) - Rs ${(item.rate * tempQty).toStringAsFixed(0)}'
                                    : 'کارٹ میں شامل کریں',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.backgroundColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UrduAwareText(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          UrduAwareText(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color ?? AppTheme.darkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(ShopItem item, {double fontSize = 26, double borderRadius = 14}) {
    final path = item.imageUrl?.trim();
    final fallback = Center(
      child: UrduAwareText(
        item.emoji.trim().isEmpty ? '📦' : item.emoji,
        style: TextStyle(fontSize: fontSize),
      ),
    );

    if (path == null || path.isEmpty) return fallback;

    final uri = Uri.tryParse(path);
    final isRemote = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

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

class _DetailSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _DetailSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.themeColor),
        const SizedBox(width: 6),
        UrduAwareText(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkColor,
          ),
        ),
      ],
    );
  }
}
