// lib/features/shopkeeper/stock_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'add_edit_stock_item_screen.dart';
import 'stock_adjustment_dialog.dart';
import 'package:account_app/core/widgets/image_gallery_viewer.dart';

class StockDetailScreen extends StatelessWidget {
  static const Map<String, String> _categoryNamesUrdu = {
    'General': 'عمومی',
    'عام (General)': 'عمومی',
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

  const StockDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final computedStock = stockService.calculateCurrentStock(item.id);
    final avgCost = stockService.calculateWeightedAverageCost(item.id);
    final isOutOfStock = item.trackStock && computedStock <= 0;
    final isLowStock =
        item.trackStock && computedStock <= item.minStockAlert && !isOutOfStock;

    final movementMap = <String, StockMovement>{};
    for (final movement
        in stockService.movements.where((m) => m.stockItemId == item.id)) {
      final key = movement.id.isNotEmpty
          ? movement.id
          : '${movement.stockItemId}|${movement.type.name}|${movement.quantity}|${movement.timestamp.millisecondsSinceEpoch}';
      movementMap[key] = movement;
    }
    final itemMovements = movementMap.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'آئٹم تفصیل' : 'Item Details',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ 1. Hero Card ═══
            _buildHeroCard(
              context,
              computedStock,
              avgCost,
              isOutOfStock,
              isLowStock,
              isUrdu,
              fontFamily,
            ),

            // ═══ 2. Quick Actions ═══
            if (item.trackStock) ...[
              const SizedBox(height: 8),
              _buildActionButtons(context, isUrdu, fontFamily),
              const SizedBox(height: 8),
            ],

            // ═══ 3. Pricing Card removed (now in top boxes) ═══

            // ═══ 4. Details Card ═══
            if (_hasDetails()) ...[
              _buildDetailsCard(isUrdu, fontFamily),
            ],

            const SizedBox(height: 8),

            // ═══ 5. Movement History ═══
            _buildHistorySection(
              context,
              itemMovements,
              isUrdu,
              fontFamily,
              computedStock,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  bool _hasDetails() {
    return item.description.isNotEmpty ||
        item.brand.isNotEmpty ||
        item.model.isNotEmpty ||
        item.supplierName.isNotEmpty ||
        item.batchNo.isNotEmpty ||
        item.warranty > 0;
  }

  // ═════════════════════════════════════════════
  // Status Helper
  // ═════════════════════════════════════════════
  _StatusData _getStatusData(bool isUrdu, bool isOutOfStock, bool isLowStock) {
    if (!item.trackStock) {
      return _StatusData(
        color: AppTheme.goldColor,
        bg: AppTheme.goldColor.withValues(alpha: 0.10),
        border: AppTheme.goldColor.withValues(alpha: 0.20),
        text: isUrdu ? 'ٹریک نہیں' : 'Not Tracked',
        icon: PhosphorIcons.infinity(),
      );
    } else if (isOutOfStock) {
      return _StatusData(
        color: AppTheme.expenseColor,
        bg: AppTheme.expenseColor.withValues(alpha: 0.10),
        border: AppTheme.expenseColor.withValues(alpha: 0.25),
        text: isUrdu ? 'ختم اسٹاک' : 'Out of Stock',
        icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
      );
    } else if (isLowStock) {
      return _StatusData(
        color: const Color(0xFFD97706),
        bg: const Color(0xFFD97706).withValues(alpha: 0.12),
        border: const Color(0xFFD97706).withValues(alpha: 0.30),
        text: isUrdu ? 'کم اسٹاک' : 'Low Stock',
        icon: PhosphorIcons.warning(PhosphorIconsStyle.fill),
      );
    } else {
      return _StatusData(
        color: AppTheme.goldColor,
        bg: AppTheme.goldColor.withValues(alpha: 0.10),
        border: AppTheme.goldColor.withValues(alpha: 0.25),
        text: isUrdu ? 'اسٹاک موجود' : 'In Stock',
        icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
      );
    }
  }

  // ═════════════════════════════════════════════
  // 1. HERO CARD — Gallery Style
  // ═════════════════════════════════════════════
  Widget _buildHeroCard(
    BuildContext context,
    double computedStock,
    double avgCost,
    bool isOutOfStock,
    bool isLowStock,
    bool isUrdu,
    String? fontFamily,
  ) {
    final displayName = item.name;
    final categoryName = isUrdu
        ? _categoryNamesUrdu[item.categoryName.trim()] ?? item.categoryName
        : item.categoryName;
    final status = _getStatusData(isUrdu, isOutOfStock, isLowStock);

    // ═══ Progress calculation ═══
    final minAlert = item.minStockAlert;
    final maxRef = minAlert > 0
        ? (minAlert * 10.0).clamp(100.0, double.infinity)
        : 100.0;
    final progress =
        item.trackStock ? (computedStock / maxRef).clamp(0.0, 1.0) : 1.0;
    final minLinePos = minAlert > 0 ? (minAlert / maxRef).clamp(0.0, 1.0) : 0.0;

    final unitValue = avgCost > 0 ? avgCost : item.purchasePrice;
    final totalValue = computedStock * unitValue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════
            // GALLERY SECTION — Full width image
            // ═══════════════════════════════════════
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              status.color.withValues(alpha: 0.15),
                              status.color.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                      // Image with tap to zoom
                      GestureDetector(
                        onTap: () {
                          if (item.allImages.isNotEmpty) {
                            openFullScreenImageGallery(
                              context,
                              item.allImages,
                              initialIndex: 0,
                            );
                          }
                        },
                        child: _buildItemImage(item, status.color),
                      ),

                      // Featured badge (top-right)
                      if (item.featured)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.verifiedGold,
                                  Color(0xFFB45309),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.verifiedGold
                                      .withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                UrduAwareText(
                                  isUrdu ? 'نمایاں' : 'Featured',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Image count badge (bottom-right)
                      if (item.allImages.length > 1)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.darkColor.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: UrduAwareText(
                              '1 / ${item.allImages.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════
            // INFO SECTION — Name start-aligned + Tags
            // ═══════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name — start-aligned, big
                  UrduAwareText(
                    displayName,
                    textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      letterSpacing: -0.4,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Meta row — start-aligned
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Category
                      if (item.categoryName.isNotEmpty)
                        _buildTag(
                          text: categoryName,
                          color: AppTheme.themeColor,
                          bg: AppTheme.themeColor.withValues(alpha: 0.10),
                          fontFamily: fontFamily,
                        ),
                      // SKU
                      if (item.sku.isNotEmpty)
                        _buildTag(
                          text: '#${item.sku}',
                          color: AppTheme.textSecondary,
                          bg: AppTheme.backgroundColor,
                          fontFamily: null,
                          isMono: true,
                        ),
                      // Alert (min)
                      if (item.trackStock && minAlert > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.bellRinging(
                                    PhosphorIconsStyle.fill),
                                size: 10,
                                color: const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 3),
                              UrduAwareText(
                                '${isUrdu ? "کم از کم" : "Min"}: ${minAlert.toStringAsFixed(0)} ${item.unit}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: status.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, size: 11, color: status.color),
                            const SizedBox(width: 4),
                            UrduAwareText(
                              status.text,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: status.color,
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

            // ═══════════════════════════════════════
            // METRICS SECTION — 3-cell + Progress
            // ═══════════════════════════════════════
            if (item.trackStock) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.backgroundColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label
                    Center(
                      child: UrduAwareText(
                        (isUrdu ? 'اسٹاک کا جائزہ' : 'STOCK OVERVIEW')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.6,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2 rows of 3 boxes each (Current, Total, Purchase, Selling, MRP, Wholesale)
                    Column(
                      children: [
                        Row(
                          children: [
                            // 1. Current Stock
                            Expanded(
                              child: _buildStatCell(
                                value: computedStock.toStringAsFixed(
                                  computedStock.truncateToDouble() == computedStock
                                      ? 0
                                      : 1,
                                ),
                                label: isUrdu ? 'موجودہ' : 'CURRENT',
                                valueColor: status.color,
                                bgOverride: status.color.withValues(alpha: 0.08),
                                borderOverride:
                                    status.color.withValues(alpha: 0.20),
                                fontFamily: fontFamily,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 2. Total Value
                            Expanded(
                              child: _buildStatCell(
                                value: totalValue > 0
                                    ? Formatters.formatAmountWithCurrency(
                                        totalValue)
                                    : '—',
                                label: isUrdu ? 'کل ویلیو' : 'TOTAL',
                                valueColor: AppTheme.goldColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 3. Purchase Price
                            Expanded(
                              child: _buildStatCell(
                                value: Formatters.formatAmountWithCurrency(
                                  avgCost > 0 ? avgCost : item.purchasePrice,
                                ),
                                label: isUrdu ? 'خرید ریٹ' : 'PURCHASE',
                                valueColor: AppTheme.darkColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // 4. Selling Price
                            Expanded(
                              child: _buildStatCell(
                                value: Formatters.formatAmountWithCurrency(
                                  item.sellingPrice,
                                ),
                                label: isUrdu ? 'فروخت ریٹ' : 'SELLING',
                                valueColor: AppTheme.themeColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 5. MRP
                            Expanded(
                              child: _buildStatCell(
                                value: item.mrp > 0
                                    ? Formatters.formatAmountWithCurrency(item.mrp)
                                    : '—',
                                label: isUrdu ? 'ایم آر پی' : 'MRP',
                                valueColor: AppTheme.darkColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 6. Wholesale Price
                            Expanded(
                              child: _buildStatCell(
                                value: item.wholesalePrice > 0
                                    ? Formatters.formatAmountWithCurrency(
                                        item.wholesalePrice)
                                    : '—',
                                label: isUrdu ? 'تھوک ریٹ' : 'WHOLESALE',
                                valueColor: AppTheme.darkColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Progress bar with min-line
                    _buildStockProgress(
                      progress: progress,
                      minLinePos: minLinePos,
                      statusColor: status.color,
                      minAlert: minAlert,
                      maxRef: maxRef,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ],
                ),
              ),
            ],

            // ═══════════════════════════════════════
            // Not-tracked fallback (اگر trackStock false ہو)
            // ═══════════════════════════════════════
            if (!item.trackStock)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.backgroundColor,
                      width: 1,
                    ),
                  ),
                  color: AppTheme.backgroundColor.withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.infinity(),
                      size: 16,
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
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Tag Builder
  // ═════════════════════════════════════════════
  Widget _buildTag({
    required String text,
    required Color color,
    required Color bg,
    String? fontFamily,
    bool isMono = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: UrduAwareText(
        text,
        style: TextStyle(
          fontSize: isMono ? 10 : 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: isMono ? 'monospace' : fontFamily,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // 2. ACTION BUTTONS
  // ═════════════════════════════════════════════
  Widget _buildActionButtons(
    BuildContext context,
    bool isUrdu,
    String? fontFamily,
  ) {
    return Column(
      children: [
        if (item.trackStock) ...[
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: isUrdu ? 'سامان خریدا' : 'Stock In',
                  icon: PhosphorIcons.plusCircle(),
                  color: AppTheme.incomeColor,
                  size: AppButtonSize.large,
                  isFullWidth: true,
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => StockAdjustmentDialog(
                        item: item,
                        initialType: StockMovementType.purchase,
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  text: isUrdu ? 'سامان بیچا' : 'Stock Out',
                  icon: PhosphorIcons.minusCircle(),
                  color: AppTheme.expenseColor,
                  size: AppButtonSize.large,
                  isFullWidth: true,
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => StockAdjustmentDialog(
                        item: item,
                        initialType: StockMovementType.sale,
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment',
                  icon: PhosphorIcons.sliders(),
                  color: AppTheme.verifiedGold,
                  size: AppButtonSize.large,
                  isFullWidth: true,
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => StockAdjustmentDialog(
                        item: item,
                        initialType: StockMovementType.adjustment,
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  text: isUrdu ? 'واپسی' : 'Returns',
                  icon: PhosphorIcons.arrowClockwise(),
                  color: AppTheme.themeColor,
                  size: AppButtonSize.large,
                  isFullWidth: true,
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => StockAdjustmentDialog(
                        item: item,
                        initialType: StockMovementType.customerReturn,
                        showTypeSelector: true,
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: isUrdu ? 'آئٹم میں ترمیم کریں' : 'Edit Item',
                icon: PhosphorIcons.pencilSimple(),
                color: const Color(0xFF7C3AED),
                size: AppButtonSize.large,
                isFullWidth: true,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddEditStockItemScreen(initialItem: item),
                    ),
                  );
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // 3. PRICING CARD
  // ═════════════════════════════════════════════
  Widget _buildPricingCard(
    double avgCost,
    bool isUrdu,
    String? fontFamily,
  ) {
    return _buildCard(
      title: isUrdu ? 'قیمت اور ریٹ' : 'Pricing & Rates',
      icon: PhosphorIcons.money(),
      fontFamily: fontFamily,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.backgroundColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildPriceStat(
                      label: isUrdu ? 'اوسط لاگت' : 'AVG COST',
                      value: '${Formatters.formatAmountWithCurrency(avgCost)}',
                      icon: PhosphorIcons.money(),
                      fontFamily: fontFamily,
                    ),
                    Container(
                        width: 1, height: 60, color: AppTheme.backgroundColor),
                    _buildPriceStat(
                      label: isUrdu ? 'فروخت قیمت' : 'SALE PRICE',
                      value:
                          '${Formatters.formatAmountWithCurrency(item.sellingPrice)}',
                      icon: PhosphorIcons.tag(),
                      fontFamily: fontFamily,
                      isHighlight: true,
                      profitPercent: item.purchasePrice > 0
                          ? item.profitMarginPercent
                          : null,
                    ),
                  ],
                ),
                Container(height: 1, color: AppTheme.backgroundColor),
                Row(
                  children: [
                    _buildPriceStat(
                      label: isUrdu ? 'تھوک قیمت' : 'WHOLESALE',
                      value: item.wholesalePrice > 0
                          ? '${Formatters.formatAmountWithCurrency(item.wholesalePrice)}'
                          : '—',
                      icon: PhosphorIcons.buildings(),
                      fontFamily: fontFamily,
                    ),
                    Container(
                        width: 1, height: 60, color: AppTheme.backgroundColor),
                    _buildPriceStat(
                      label: isUrdu ? 'ایم آر پی' : 'MRP',
                      value: item.mrp > 0
                          ? '${Formatters.formatAmountWithCurrency(item.mrp)}'
                          : '—',
                      icon: PhosphorIcons.clipboard(),
                      fontFamily: fontFamily,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStat({
    required String label,
    required String value,
    required IconData icon,
    String? fontFamily,
    bool isHighlight = false,
    double? profitPercent,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 11,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                const SizedBox(width: 5),
                Expanded(
                  child: UrduAwareText(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.3,
                      fontFamily: fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            UrduAwareText(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isHighlight ? AppTheme.themeColor : AppTheme.darkColor,
                letterSpacing: -0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (profitPercent != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.goldColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: UrduAwareText(
                  '+${profitPercent.toStringAsFixed(0)}% ${fontFamily != null ? 'منافع' : 'profit'}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.goldColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // 4. DETAILS CARD
  // ═════════════════════════════════════════════
  Widget _buildDetailsCard(bool isUrdu, String? fontFamily) {
    return _buildCard(
      title: isUrdu ? 'اضافی معلومات' : 'Additional Info',
      icon: PhosphorIcons.info(),
      fontFamily: fontFamily,
      child: Column(
        children: [
          if (item.brand.isNotEmpty)
            _buildDetailRow(
              icon: PhosphorIcons.factory(),
              label: isUrdu ? 'برانڈ' : 'Brand',
              value: item.brand,
              fontFamily: fontFamily,
            ),
          if (item.model.isNotEmpty)
            _buildDetailRow(
              icon: PhosphorIcons.wrench(),
              label: isUrdu ? 'ماڈل' : 'Model',
              value: item.model,
              fontFamily: fontFamily,
              isMono: true,
            ),
          if (item.supplierName.isNotEmpty)
            _buildDetailRow(
              icon: PhosphorIcons.storefront(),
              label: isUrdu ? 'سپلائر' : 'Supplier',
              value: item.supplierName,
              fontFamily: fontFamily,
            ),
          if (item.batchNo.isNotEmpty)
            _buildDetailRow(
              icon: PhosphorIcons.hash(),
              label: isUrdu ? 'بیچ نمبر' : 'Batch No.',
              value: item.batchNo,
              fontFamily: fontFamily,
              isMono: true,
            ),
          if (item.warranty > 0)
            _buildDetailRow(
              icon: PhosphorIcons.shieldCheck(),
              label: isUrdu ? 'وارنٹی' : 'Warranty',
              value:
                  isUrdu ? '${item.warranty} مہینے' : '${item.warranty} months',
              fontFamily: fontFamily,
              isLast: item.description.isEmpty,
            ),
          if (item.description.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.backgroundColor,
                  width: 1,
                ),
              ),
              child: UrduAwareText(
                item.description,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? fontFamily,
    bool isMono = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppTheme.backgroundColor,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: AppTheme.themeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                fontFamily: fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: UrduAwareText(
              value,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkColor,
                fontFamily: isMono ? 'monospace' : fontFamily,
                letterSpacing: isMono ? 0.3 : 0,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // 5. HISTORY SECTION
  // ═════════════════════════════════════════════
  Widget _buildHistorySection(
    BuildContext context,
    List<StockMovement> movements,
    bool isUrdu,
    String? fontFamily,
    double computedStock,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              Icon(PhosphorIcons.clockCounterClockwise(),
                  size: 18, color: AppTheme.themeColor),
              const SizedBox(width: 8),
              UrduAwareText(
                isUrdu ? 'اسٹاک ہسٹری' : 'Movement History',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: UrduAwareText(
                  isUrdu
                      ? '${movements.length} انٹریز'
                      : '${movements.length} entries',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.themeColor,
                    letterSpacing: 0.3,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Empty state
        if (movements.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.backgroundColor,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.clockCounterClockwise(),
                  size: 44,
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                UrduAwareText(
                  isUrdu
                      ? 'کوئی ہسٹری موجود نہیں'
                      : 'No movements recorded yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                UrduAwareText(
                  isUrdu
                      ? 'اسٹاک کم یا زیادہ کریں تو یہاں دکھے گا'
                      : 'Stock adjustments will appear here',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          )
        else
          ...movements.map(
            (m) => _buildMovementItem(context, m, isUrdu, fontFamily),
          ),
      ],
    );
  }

  Widget _buildMovementItem(
    BuildContext context,
    StockMovement movement,
    bool isUrdu,
    String? fontFamily,
  ) {
    // Determine type config
    Color iconColor;
    Color iconBg;
    IconData icon;
    String typeLabel;
    String sign;
    bool isPlus;

    switch (movement.type) {
      case StockMovementType.purchase:
        iconColor = AppTheme.incomeColor;
        iconBg = AppTheme.incomeColor.withValues(alpha: 0.10);
        icon = PhosphorIcons.arrowDownLeft();
        typeLabel = isUrdu ? 'خریداری (اسٹاک اِن)' : 'Purchase (Stock In)';
        sign = '+';
        isPlus = true;
        break;
      case StockMovementType.customerReturn:
        iconColor = AppTheme.incomeColor;
        iconBg = AppTheme.incomeColor.withValues(alpha: 0.10);
        icon = PhosphorIcons.arrowDownLeft();
        typeLabel = isUrdu ? 'گاہک کی واپسی' : 'Customer Return';
        sign = '+';
        isPlus = true;
        break;
      case StockMovementType.sale:
        iconColor = AppTheme.expenseColor;
        iconBg = AppTheme.expenseColor.withValues(alpha: 0.10);
        icon = PhosphorIcons.arrowUpRight();
        typeLabel = isUrdu ? 'فروخت (اسٹاک آؤٹ)' : 'Sale (Stock Out)';
        sign = '−';
        isPlus = false;
        break;
      case StockMovementType.supplierReturn:
        iconColor = AppTheme.expenseColor;
        iconBg = AppTheme.expenseColor.withValues(alpha: 0.10);
        icon = PhosphorIcons.arrowUpRight();
        typeLabel = isUrdu ? 'سپلائر کو واپسی' : 'Supplier Return';
        sign = '−';
        isPlus = false;
        break;
      case StockMovementType.adjustment:
        iconColor = AppTheme.verifiedGold;
        iconBg = AppTheme.verifiedGold.withValues(alpha: 0.10);
        icon = PhosphorIcons.sliders();
        typeLabel = isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment';
        sign = movement.quantity >= 0 ? '+' : '−';
        isPlus = movement.quantity >= 0;
        break;
    }

    final db = Provider.of<DatabaseService>(context, listen: false);
    final linkedTx = movement.transactionId.isNotEmpty
        ? db.getTransaction(movement.transactionId)
        : null;

    final rawRef = linkedTx?.referenceNumber?.trim() ?? '';
    final fullBillRef = rawRef.isNotEmpty
        ? (rawRef.toUpperCase().startsWith('QB-')
            ? rawRef.toUpperCase()
            : 'QB-$rawRef')
        : null;
    final billNo = fullBillRef != null
        ? (isUrdu
            ? 'بل #\u2066$fullBillRef\u2069'
            : 'Bill #$fullBillRef')
        : null;

    final dateStr = DateFormat('dd MMM', isUrdu ? 'ur' : 'en').format(movement.timestamp);
    final timeStr = DateFormat('h:mm a', isUrdu ? 'ur' : 'en').format(movement.timestamp);
    final isolatedTime = '\u2066$timeStr\u2069';

    final qtyAbs = movement.quantity.abs();

    String cleanNote = movement.note.trim();
    if (cleanNote.startsWith('Transaction ') ||
        cleanNote == movement.transactionId ||
        cleanNote.startsWith('mov_') ||
        cleanNote.startsWith('tx_')) {
      cleanNote = '';
    }
    if (billNo != null &&
        (cleanNote.startsWith('Bill #') || cleanNote.startsWith('بل #'))) {
      cleanNote = '';
    }

    String cleanReason = movement.reason.trim();
    if (cleanReason == 'Transaction sale' ||
        cleanReason == 'Transaction purchase' ||
        cleanReason == 'Purchase' ||
        cleanReason == 'Sale' ||
        cleanReason == 'خریداری' ||
        cleanReason == 'فروخت') {
      cleanReason = '';
    }

    final metaParts = <String>[
      if (movement.partyName.isNotEmpty)
        isUrdu ? 'پارٹی: ${movement.partyName}' : 'Party: ${movement.partyName}',
      if (billNo != null) billNo,
      isolatedTime,
    ];

    final detailTextList = <String>[];
    if (cleanReason.isNotEmpty) {
      detailTextList.add(cleanReason);
    }
    if (cleanNote.isNotEmpty) {
      if (!detailTextList.contains(cleanNote)) {
        detailTextList.add(cleanNote);
      }
    }
    final detailText = detailTextList.join(' • ');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.backgroundColor,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: UrduAwareText(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    UrduAwareText(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                UrduAwareText(
                  metaParts.join(' • '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detailText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  UrduAwareText(
                    detailText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.themeColor,
                      fontFamily: fontFamily,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Quantity + Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UrduAwareText(
                '$sign${qtyAbs.toStringAsFixed(qtyAbs.truncateToDouble() == qtyAbs ? 0 : 1)} ${item.unit}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isPlus ? AppTheme.incomeColor : AppTheme.expenseColor,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontFamily: fontFamily,
                ),
              ),
              if (movement.unitPrice > 0) ...[
                const SizedBox(height: 2),
                UrduAwareText(
                  '${Formatters.formatAmountWithCurrency(movement.unitPrice)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Card Builder (with header)
  // ═════════════════════════════════════════════
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? fontFamily,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.themeColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 15, color: AppTheme.themeColor),
                  ),
                  const SizedBox(width: 10),
                  UrduAwareText(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                      letterSpacing: -0.2,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppTheme.backgroundColor),
            child,
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Stat Cell
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
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: bgOverride ?? Colors.white,
        borderRadius: BorderRadius.circular(10),
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
              fontSize: 14,
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
              fontSize: 8,
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
  // Stock Progress Bar with min-line
  // ═════════════════════════════════════════════
  Widget _buildStockProgress({
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
                  if (minLinePos > 0 && minLinePos < 1)
                    Positioned(
                      left: (width * minLinePos) - 30,
                      child: SizedBox(
                        width: 60,
                        child: UrduAwareText(
                          '${isUrdu ? "کم از کم" : "Min"} ${minAlert.toStringAsFixed(0)}',
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
                  Positioned(
                    right: 0,
                    child: UrduAwareText(
                      maxRef.toStringAsFixed(0),
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
      size: 38,
      color: statusColor,
    );

    if (path == null || path.isEmpty) return fallback;

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
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

// ═════════════════════════════════════════════
// Status Data Helper
// ═════════════════════════════════════════════
class _StatusData {
  final Color color;
  final Color bg;
  final Color border;
  final String text;
  final IconData icon;

  _StatusData({
    required this.color,
    required this.bg,
    required this.border,
    required this.text,
    required this.icon,
  });
}
