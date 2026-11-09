// lib/core/widgets/stock_card.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/theme/app_theme.dart';

class StockCard extends StatelessWidget {
  static final NumberFormat _quantityFormat =
      NumberFormat('0.##########', 'en_US');

  static const Map<String, String> _unitLabelsUrdu = {
    'Pieces': 'عدد',
    'Kg': 'کلو',
    'Gram': 'گرام',
    'Liter': 'لیٹر',
    'Meter': 'میٹر',
    'Sqft': 'مربع فٹ',
    'Dozen': 'درجن',
    'Box': 'ڈبہ',
    'Bag': 'بوری',
    'Maund': 'من',
    'Bottle': 'بوتل',
    'Packet': 'پیکٹ',
    'Tola': 'تولہ',
    'Other': 'دیگر',
  };

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
    final hasValidStock = computedStock.isFinite;
    final stockForDisplay = hasValidStock ? computedStock : null;
    final minAlert = item.minStockAlert.isFinite && item.minStockAlert > 0
        ? item.minStockAlert
        : 0.0;
    final isOutOfStock = item.trackStock && computedStock <= 0;
    final isLowStock = item.trackStock &&
        minAlert > 0 &&
        computedStock <= minAlert &&
        !isOutOfStock;
    final isInvalidStock = item.trackStock && !hasValidStock;
    final unitLabel =
        isUrdu ? _unitLabelsUrdu[item.unit] ?? item.unit : item.unit;

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
    } else if (isInvalidStock) {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFD97706).withValues(alpha: 0.12);
      statusBorder = const Color(0xFFD97706).withValues(alpha: 0.30);
      statusText = isUrdu ? 'غلط مقدار' : 'Invalid Stock';
      statusIcon = PhosphorIcons.warning(PhosphorIconsStyle.fill);
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

    // ═══════════════════════════════════════════
    // Progress calculation
    // ═══════════════════════════════════════════
    final maxRef =
        minAlert > 0 ? (minAlert * 10.0).clamp(100.0, double.infinity) : 100.0;

    final progress = item.trackStock && hasValidStock
        ? (computedStock / maxRef).clamp(0.0, 1.0)
        : 0.0;
    final minLinePos = minAlert > 0 ? (minAlert / maxRef).clamp(0.0, 1.0) : 0.0;
    final averageCost = stockService.calculateWeightedAverageCost(item.id);
    final stockCost = item.trackStock &&
            hasValidStock &&
            averageCost.isFinite &&
            averageCost > 0
        ? computedStock.clamp(0.0, double.infinity) * averageCost
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOutOfStock
              ? AppTheme.expenseColor.withValues(alpha: 0.25)
              : (isLowStock || isInvalidStock
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
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppTheme.themeColor.withValues(alpha: 0.05),
            highlightColor: AppTheme.themeColor.withValues(alpha: 0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════════════
                // TOP: Image + 2 Lines of Info
                // ═══════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ─── Image (80×80) ───
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  statusColor.withValues(alpha: 0.12),
                                  statusColor.withValues(alpha: 0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.30),
                                width: 2,
                              ),
                            ),
                            child: _buildItemImage(item, statusColor),
                          ),
                          if (item.featured)
                            Positioned(
                              top: -5,
                              right: -5,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.verifiedGold,
                                      Color(0xFFB8860B),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
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
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // ─── Info: صرف 2 لائنیں ───
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ─── Line 1: Name (بڑا) ───
                            UrduAwareText(
                              displayName,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkColor,
                                fontFamily: fontFamily,
                                letterSpacing: -0.3,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // ─── Line 2: Category + SKU + Alert + Status ───
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Category (بڑا)
                                if (item.categoryName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.themeColor
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: UrduAwareText(
                                      categoryName,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.themeColor,
                                        fontFamily: fontFamily,
                                      ),
                                    ),
                                  ),
                                // SKU
                                if (item.sku.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: UrduAwareText(
                                      '#${item.sku}',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textSecondary,
                                        fontFamily: 'monospace',
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                // Alert (کم از کم)
                                if (item.trackStock && minAlert > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIcons.bellRinging(
                                              PhosphorIconsStyle.fill),
                                          size: 9,
                                          color: const Color(0xFFB45309),
                                        ),
                                        const SizedBox(width: 2),
                                        UrduAwareText(
                                          '${isUrdu ? "کم از کم" : "Min"}: ${_formatQuantity(minAlert)} $unitLabel',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFB45309),
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Status badge (دائیں طرف)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: statusBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusIcon,
                                        size: 10,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 3),
                                      UrduAwareText(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: statusColor,
                                          fontFamily: fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════
                // STOCK AND PRICE SUMMARY
                // ═══════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCell(
                          value: item.trackStock && stockForDisplay != null
                              ? '${_formatQuantity(stockForDisplay)} $unitLabel'
                              : '—',
                          label: isUrdu ? 'موجودہ اسٹاک' : 'STOCK',
                          valueColor: statusColor,
                          bgOverride: statusColor.withValues(alpha: 0.08),
                          borderOverride: statusColor.withValues(alpha: 0.20),
                          fontFamily: fontFamily,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildStatCell(
                          value: item.sellingPrice.isFinite
                              ? Formatters.formatAmountWithCurrency(
                                  item.sellingPrice,
                                )
                              : '—',
                          label: isUrdu ? 'فروخت فی یونٹ' : 'SELL PRICE',
                          valueColor: AppTheme.darkColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildStatCell(
                          value: stockCost != null
                              ? Formatters.formatAmountWithCurrency(stockCost)
                              : '—',
                          label: isUrdu ? 'اسٹاک لاگت' : 'STOCK COST',
                          valueColor: AppTheme.goldColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.trackStock) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _buildProgressBar(
                      progress: progress,
                      minLinePos: minLinePos,
                      statusColor: statusColor,
                      minAlert: minAlert,
                      maxRef: maxRef,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double value) {
    if (!value.isFinite) return '—';
    return _quantityFormat.format(value);
  }

  // ═════════════════════════════════════════════
  // Stat Cell — bg/border override کے ساتھ
  // ═════════════════════════════════════════════
  Widget _buildStatCell({
    required String value,
    required String label,
    required Color valueColor,
    String? fontFamily,
    Color? bgOverride,
    Color? borderOverride,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: bgOverride ?? Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: borderOverride ?? AppTheme.backgroundColor,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UrduAwareText(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: valueColor,
              height: 1.1,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontFamily: null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          UrduAwareText(
            label,
            style: TextStyle(
              fontSize: 10.5,
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

  // ═════════════════════════════════════════════
  // Progress Bar + Min Line
  // ═════════════════════════════════════════════
  Widget _buildProgressBar({
    required double progress,
    required double minLinePos,
    required Color statusColor,
    required double minAlert,
    required double maxRef,
    required bool isUrdu,
    required String? fontFamily,
  }) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 14,
              child: Stack(
                children: [
                  // Track
                  Positioned(
                    top: 3,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor,
                                statusColor.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Min line marker
                  if (minLinePos > 0 && minLinePos < 1)
                    Positioned(
                      left: (width * minLinePos) - 4,
                      top: 0,
                      child: Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(2),
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
        const SizedBox(height: 4),
        // Labels
        SizedBox(
          height: 12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  // 0
                  Positioned(
                    left: 0,
                    child: UrduAwareText(
                      '0',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        fontFamily: null,
                      ),
                    ),
                  ),
                  // Min label
                  if (minLinePos > 0 && minLinePos < 1)
                    Positioned(
                      left: (width * minLinePos) - 30,
                      child: SizedBox(
                        width: 60,
                        child: UrduAwareText(
                          '${isUrdu ? "کم از کم" : "Min"} ${_formatQuantity(minAlert)}',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFDC2626),
                            fontFamily: fontFamily,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  // Max
                  Positioned(
                    right: 0,
                    child: UrduAwareText(
                      _formatQuantity(maxRef),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        fontFamily: null,
                      ),
                    ),
                  ),
                ],
              );
            },
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
      size: 34,
      color: statusColor,
    );

    if (path == null || path.isEmpty) return fallback;

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
