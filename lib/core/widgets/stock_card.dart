// lib/core/widgets/stock_card.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/theme/app_theme.dart';

class StockCard extends StatelessWidget {
  static const Map<String, String> _categoryNamesUrdu = {
    'General': 'عمومی',
    'Grocery': 'کریانہ',
    'Food': 'خوراک',
    'Beverages': 'مشروبات',
    'Clothing': 'کپڑے',
    'Electronics': 'الیکٹرانکس',
    'Household': 'گھریلو سامان',
    'Personal Care': 'ذاتی استعمال',
    'Medicine': 'ادویات',
    'Other': 'دیگر',
  };

  final StockItem item;
  final VoidCallback onTap;

  const StockCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final computedStock = stockService.calculateCurrentStock(item.id);
    final isOutOfStock = item.trackStock && computedStock <= 0;
    final isLowStock =
        item.trackStock && computedStock <= item.minStockAlert && !isOutOfStock;

    final displayName = item.name;
    final categoryName = isUrdu
        ? _categoryNamesUrdu[item.categoryName] ?? item.categoryName
        : item.categoryName;

    // ═══════════════════════════════════════════
    // Status Configuration
    // ═══════════════════════════════════════════
    Color statusColor;
    Color statusBg;
    Color statusBorder;
    String statusText;
    IconData statusIcon;

    if (!item.trackStock) {
      statusColor = AppTheme.goldColor;
      statusBg = AppTheme.goldColor.withValues(alpha: 0.10);
      statusBorder = AppTheme.goldColor.withValues(alpha: 0.20);
      statusText = isUrdu ? 'ٹریک نہیں' : 'Not Tracked';
      statusIcon = PhosphorIcons.infinity();
    } else if (isOutOfStock) {
      statusColor = AppTheme.expenseColor;
      statusBg = AppTheme.expenseColor.withValues(alpha: 0.10);
      statusBorder = AppTheme.expenseColor.withValues(alpha: 0.25);
      statusText = isUrdu ? 'ختم' : 'Out of Stock';
      statusIcon = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
    } else if (isLowStock) {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFD97706).withValues(alpha: 0.12);
      statusBorder = const Color(0xFFD97706).withValues(alpha: 0.30);
      statusText = isUrdu ? 'کم' : 'Low Stock';
      statusIcon = PhosphorIcons.warning(PhosphorIconsStyle.fill);
    } else {
      statusColor = AppTheme.goldColor;
      statusBg = AppTheme.goldColor.withValues(alpha: 0.10);
      statusBorder = AppTheme.goldColor.withValues(alpha: 0.25);
      statusText = isUrdu ? 'موجود' : 'In Stock';
      statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
    }

    // ═══════════════════════════════════════════════════════════
    // ⭐ Stock progress — درست حساب
    // ═══════════════════════════════════════════════════════════
    final maxRef = item.minStockAlert > 0
        ? (item.minStockAlert * 10.0).clamp(100.0, double.infinity)
        : 100.0;

    final progress = item.trackStock
        ? (computedStock / maxRef).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.lightColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOutOfStock
              ? AppTheme.expenseColor.withValues(alpha: 0.25)
              : (isLowStock
              ? const Color(0xFFD97706).withValues(alpha: 0.30)
              : AppTheme.backgroundColor),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.02),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,  // ← Detail کھلے
          borderRadius: BorderRadius.circular(20),
          splashColor: AppTheme.themeColor.withValues(alpha: 0.05),
          highlightColor: AppTheme.themeColor.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════════════
                // TOP ROW: Image + Name + Status + Alert
                // ═══════════════════════════════════════
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Image with ring ───
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                statusColor.withValues(alpha: 0.12),
                                statusColor.withValues(alpha: 0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.22),
                              width: 1.5,
                            ),
                          ),
                          child: _buildItemImage(item, statusColor),
                        ),
                        // Featured golden badge
                        if (item.featured)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.verifiedGold,
                                    Color(0xFFB8860B),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.verifiedGold
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // ─── Name + Meta ───
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UrduAwareText(
                            displayName,
                            textDirection:
                            isUrdu ? TextDirection.rtl : TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
                              letterSpacing: isUrdu ? 0 : -0.2,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (item.categoryName.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.themeColor
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: UrduAwareText(
                                    categoryName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.themeColor,
                                      fontFamily: fontFamily,
                                      letterSpacing: isUrdu ? 0 : 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (item.sku.isNotEmpty)
                                Flexible(
                                  child: UrduAwareText(
                                    '#${item.sku}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ─── Status Badge ───
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: statusBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 11, color: statusColor),
                          const SizedBox(width: 4),
                          UrduAwareText(
                            statusText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              fontFamily: fontFamily,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ═══════════════════════════════════════
                // PRICE ROW
                // ═══════════════════════════════════════
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: UrduAwareText(
                              'Rs ${Formatters.formatAmount(item.sellingPrice)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkColor,
                                letterSpacing: -0.5,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          UrduAwareText(
                            '/ ${item.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.purchasePrice > 0 && item.sellingPrice > 0) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UrduAwareText(
                            'Cost: Rs ${Formatters.formatAmount(item.purchasePrice)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                              AppTheme.goldColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: UrduAwareText(
                              '${item.profitMarginPercent.toStringAsFixed(0)}% profit',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.goldColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // MRP
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.mrp > 0)
                      _buildMiniInfo(
                        icon: PhosphorIcons.clipboard(),
                        label: 'MRP',
                        value: 'Rs ${Formatters.formatAmount(item.mrp)}',
                      ),
                  ],
                ),

                // ═══════════════════════════════════════
                // STOCK SECTION
                // ═══════════════════════════════════════
                if (item.trackStock) ...[
                  const SizedBox(height: 12),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 6,
                      color: AppTheme.backgroundColor,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor,
                                statusColor.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Stock row: quantity + alert (موٹا، کونے میں)
                  Row(
                    children: [
                      // Stock quantity
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.12),
                              statusColor.withValues(alpha: 0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.stack(),
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            UrduAwareText(
                              '${computedStock.toStringAsFixed(computedStock.truncateToDouble() == computedStock ? 0 : 1)} ${item.unit}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (item.purchasePrice > 0) ...[
                              UrduAwareText(
                                ' (Rs ${Formatters.formatAmount(computedStock * item.purchasePrice)})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor.withValues(alpha: 0.9),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),

                      // ⭐ Alert — موٹا فونٹ، کونے میں
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.bellRinging(
                                  PhosphorIconsStyle.fill),
                              size: 13,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            UrduAwareText(
                              isUrdu
                                  ? 'الرٹ: ${item.minStockAlert.toStringAsFixed(0)}'
                                  : 'Alert: ${item.minStockAlert.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                fontFamily: fontFamily,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Not tracking stock
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.backgroundColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.infinity(),
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: UrduAwareText(
                            isUrdu
                                ? 'یہ آئٹم اسٹاک ٹریک نہیں کرتا'
                                : 'Stock is not tracked for this item',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Mini Info (Cost / MRP)
  // ═════════════════════════════════════════════
  Widget _buildMiniInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 10,
          color: AppTheme.textSecondary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 3),
        UrduAwareText(
          '$label: ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        UrduAwareText(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // Item Image
  // ═════════════════════════════════════════════
  Widget _buildItemImage(StockItem item, Color statusColor) {
    final path = item.imagePath;
    final fallback = Icon(
      PhosphorIcons.package(PhosphorIconsStyle.duotone),
      size: 28,
      color: statusColor,
    );

    if (path == null || path.isEmpty) return fallback;

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: isRemote
          ? Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      )
          : Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}