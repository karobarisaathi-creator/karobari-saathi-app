// lib/core/widgets/stock_card.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';

class StockCard extends StatelessWidget {
  final StockItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;
  final VoidCallback onQuickRemove;

  const StockCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickAdd,
    required this.onQuickRemove,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final computedStock = stockService.calculateCurrentStock(item.id);
    final isOutOfStock = item.trackStock && computedStock <= 0;
    final isLowStock = item.trackStock &&
        computedStock <= item.minStockAlert &&
        !isOutOfStock;

    final displayName =
    isUrdu && item.nameUrdu.isNotEmpty ? item.nameUrdu : item.name;

    // ═══════════════════════════════════════════
    // Status Configuration
    // ═══════════════════════════════════════════
    Color statusColor;
    Color statusBg;
    Color statusBorder;
    String statusText;
    IconData statusIcon;

    if (!item.trackStock) {
      statusColor = AppTheme.goldColor; // #607D8B
      statusBg = AppTheme.goldColor.withValues(alpha: 0.10);
      statusBorder = AppTheme.goldColor.withValues(alpha: 0.20);
      statusText = isUrdu ? 'ٹریک نہیں' : 'Not Tracked';
      statusIcon = PhosphorIcons.infinity();
    } else if (isOutOfStock) {
      statusColor = AppTheme.expenseColor; // #C83120
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
      statusColor = AppTheme.incomeColor; // #515D11
      statusBg = AppTheme.incomeColor.withValues(alpha: 0.10);
      statusBorder = AppTheme.incomeColor.withValues(alpha: 0.25);
      statusText = isUrdu ? 'موجود' : 'In Stock';
      statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
    }

    // Stock progress (0.0 to 1.0)
    final maxRef = item.minStockAlert > 0
        ? (item.minStockAlert * 3).clamp(1.0, double.infinity)
        : 30.0;
    final progress = item.trackStock
        ? (computedStock / maxRef).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppTheme.themeColor.withValues(alpha: 0.05),
          highlightColor: AppTheme.themeColor.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════════════
                // TOP ROW: Image + Name + Status
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
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
                              letterSpacing: -0.2,
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
                                  child: Text(
                                    item.categoryName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.themeColor,
                                      fontFamily: fontFamily,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (item.sku.isNotEmpty)
                                Flexible(
                                  child: Text(
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
                          Text(
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
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Rs ${item.sellingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkColor,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '/ ${item.unit}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Cost / MRP / Profit
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.purchasePrice > 0)
                      _buildMiniInfo(
                        icon: PhosphorIcons.tag(),
                        label: 'Cost',
                        value: 'Rs ${item.purchasePrice.toStringAsFixed(0)}',
                      ),
                    if (item.mrp > 0)
                      _buildMiniInfo(
                        icon: PhosphorIcons.clipboard(),
                        label: 'MRP',
                        value: 'Rs ${item.mrp.toStringAsFixed(0)}',
                      ),
                    if (item.purchasePrice > 0 && item.sellingPrice > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${item.profitMarginPercent.toStringAsFixed(0)}% profit',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.incomeColor,
                            letterSpacing: 0.2,
                          ),
                        ),
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

                  // Stock row: quantity + alert + buttons
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
                            Text(
                              '${computedStock.toStringAsFixed(computedStock.truncateToDouble() == computedStock ? 0 : 1)} ${item.unit}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Alert info
                      Flexible(
                        child: Text(
                          isUrdu
                              ? 'الرٹ: ${item.minStockAlert.toStringAsFixed(0)}'
                              : 'Alert: ${item.minStockAlert.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            fontFamily: fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quick buttons
                      _buildQuickButton(
                        icon: PhosphorIcons.minus(),
                        onPressed: onQuickRemove,
                        color: AppTheme.expenseColor,
                        tooltip: isUrdu ? 'کم کریں' : 'Reduce',
                      ),
                      const SizedBox(width: 6),
                      _buildQuickButton(
                        icon: PhosphorIcons.plus(),
                        onPressed: onQuickAdd,
                        color: AppTheme.themeColor,
                        tooltip: isUrdu ? 'بڑھائیں' : 'Add',
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
                          child: Text(
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
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        Text(
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
  // Quick Action Button
  // ═════════════════════════════════════════════
  Widget _buildQuickButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
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