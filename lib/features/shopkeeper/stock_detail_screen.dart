// lib/features/shopkeeper/stock_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'add_edit_stock_item_screen.dart';
import 'stock_adjustment_dialog.dart';

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

    final itemMovements = stockService.movements
        .where((m) => m.stockItemId == item.id)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'آئٹم تفصیل' : 'Item Details',
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.pencilSimple()),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddEditStockItemScreen(initialItem: item),
                ),
              );
            },
            tooltip: isUrdu ? 'ترمیم کریں' : 'Edit Item',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 14),

            // ═══ 2. Quick Actions ═══
            if (item.trackStock) ...[
              _buildActionButtons(context, isUrdu, fontFamily),
              const SizedBox(height: 14),
            ],

            // ═══ 3. Pricing Card ═══
            _buildPricingCard(avgCost, isUrdu, fontFamily),
            const SizedBox(height: 14),

            // ═══ 4. Details Card ═══
            if (_hasDetails()) ...[
              _buildDetailsCard(isUrdu, fontFamily),
              const SizedBox(height: 14),
            ],

            // ═══ 5. Movement History ═══
            _buildHistorySection(
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
        color: AppTheme.incomeColor,
        bg: AppTheme.incomeColor.withValues(alpha: 0.10),
        border: AppTheme.incomeColor.withValues(alpha: 0.25),
        text: isUrdu ? 'اسٹاک موجود' : 'In Stock',
        icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
      );
    }
  }

  // ═════════════════════════════════════════════
  // 1. HERO CARD
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
    final displayName =
        isUrdu && item.nameUrdu.isNotEmpty ? item.nameUrdu : item.name;
    final categoryName = isUrdu
        ? _categoryNamesUrdu[item.categoryName.trim()] ?? item.categoryName
        : item.categoryName;
    final status = _getStatusData(isUrdu, isOutOfStock, isLowStock);

    // Progress (0..1)
    final maxRef = item.minStockAlert > 0
        ? (item.minStockAlert * 3).clamp(1.0, double.infinity)
        : 30.0;
    final progress =
        item.trackStock ? (computedStock / maxRef).clamp(0.0, 1.0) : 1.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFAFCFF)],
        ),
        borderRadius: BorderRadius.circular(22),
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
        child: Stack(
          children: [
            // decorative glow
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      status.color.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Image + Info
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with ring
                      Stack(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  status.color.withValues(alpha: 0.12),
                                  status.color.withValues(alpha: 0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: status.color.withValues(alpha: 0.25),
                                width: 2,
                              ),
                            ),
                            child: _buildItemImage(item, status.color),
                          ),
                          if (item.featured)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.verifiedGold,
                                      Color(0xFFB8860B),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.verifiedGold
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
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

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Name + Status Badge on the same line
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.darkColor,
                                      fontFamily: fontFamily,
                                      letterSpacing: -0.4,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Status badge ("اسٹاک موجود") on the opposite side
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: status.bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: status.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(status.icon,
                                          size: 12, color: status.color),
                                      const SizedBox(width: 4),
                                      Text(
                                        status.text,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: status.color,
                                          fontFamily: fontFamily,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Tags (Category, SKU)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (item.categoryName.isNotEmpty)
                                  _buildTag(
                                    text: categoryName,
                                    color: AppTheme.themeColor,
                                    bg: AppTheme.themeColor
                                        .withValues(alpha: 0.10),
                                    fontFamily: fontFamily,
                                  ),
                                if (item.sku.isNotEmpty)
                                  _buildTag(
                                    text: '#${item.sku}',
                                    color: AppTheme.textSecondary,
                                    bg: AppTheme.backgroundColor,
                                    fontFamily: null,
                                    isMono: true,
                                  ),
                              ],
                            ),

                            // Alert tag under Category/SKU (without background box)
                            if (item.minStockAlert > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorIcons.bellRinging(),
                                    size: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isUrdu
                                        ? 'الرٹ: ${item.minStockAlert.toStringAsFixed(0)}'
                                        : 'Alert: ${item.minStockAlert.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stock Hero section
                if (item.trackStock)
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    decoration: BoxDecoration(
                      color: AppTheme.themeColor.withValues(alpha: 0.02),
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
                        // Big number + Total Value pill
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Big number
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  computedStock.toStringAsFixed(
                                    computedStock.truncateToDouble() ==
                                            computedStock
                                        ? 0
                                        : 1,
                                  ),
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: status.color,
                                    letterSpacing: -2,
                                    height: 1,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.unit,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // Total value pill
                            if (item.purchasePrice > 0 || avgCost > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: status.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: status.color.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIcons.money(),
                                      size: 12,
                                      color: status.color,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${isUrdu ? "کل مالیت" : "Total"}: Rs ${(computedStock * (avgCost > 0 ? avgCost : item.purchasePrice)).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: status.color,
                                        fontFamily: fontFamily,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 8,
                            color: AppTheme.backgroundColor,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      status.color,
                                      status.color.withValues(alpha: 0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
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
      child: Text(
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
        Row(
          children: [
            Expanded(
              child: _buildGradientActionButton(
                text: isUrdu ? 'سامان خریدا (+)' : 'Stock In (+)',
                icon: PhosphorIcons.plusCircle(),
                colors: [AppTheme.incomeColor, const Color(0xFF6B7A1F)],
                shadowColor: AppTheme.incomeColor.withValues(alpha: 0.3),
                fontFamily: fontFamily,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => StockAdjustmentDialog(
                      item: item,
                      initialType: StockMovementType.purchase,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGradientActionButton(
                text: isUrdu ? 'سامان بیچا (−)' : 'Stock Out (−)',
                icon: PhosphorIcons.minusCircle(),
                colors: [AppTheme.expenseColor, const Color(0xFFE04B36)],
                shadowColor: AppTheme.expenseColor.withValues(alpha: 0.3),
                fontFamily: fontFamily,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => StockAdjustmentDialog(
                      item: item,
                      initialType: StockMovementType.sale,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildGradientActionButton(
                text: isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment',
                icon: PhosphorIcons.sliders(),
                colors: [const Color(0xFFD97706), const Color(0xFFF59E0B)],
                shadowColor: const Color(0xFFD97706).withValues(alpha: 0.3),
                fontFamily: fontFamily,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => StockAdjustmentDialog(
                      item: item,
                      initialType: StockMovementType.adjustment,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGradientActionButton(
                text: isUrdu ? 'واپسی' : 'Returns',
                icon: PhosphorIcons.arrowClockwise(),
                colors: [const Color(0xFF4A8FE3), const Color(0xFF2563EB)],
                shadowColor: const Color(0xFF4A8FE3).withValues(alpha: 0.3),
                fontFamily: fontFamily,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => StockAdjustmentDialog(
                      item: item,
                      initialType: StockMovementType.customerReturn,
                      showTypeSelector: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientActionButton({
    required String text,
    required IconData icon,
    required List<Color> colors,
    required Color shadowColor,
    required VoidCallback onPressed,
    String? fontFamily,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                      value: 'Rs ${avgCost.toStringAsFixed(0)}',
                      icon: PhosphorIcons.money(),
                      fontFamily: fontFamily,
                    ),
                    Container(
                        width: 1, height: 60, color: AppTheme.backgroundColor),
                    _buildPriceStat(
                      label: isUrdu ? 'فروخت قیمت' : 'SALE PRICE',
                      value: 'Rs ${item.sellingPrice.toStringAsFixed(0)}',
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
                          ? 'Rs ${item.wholesalePrice.toStringAsFixed(0)}'
                          : '—',
                      icon: PhosphorIcons.buildings(),
                      fontFamily: fontFamily,
                    ),
                    Container(
                        width: 1, height: 60, color: AppTheme.backgroundColor),
                    _buildPriceStat(
                      label: isUrdu ? 'ایم آر پی' : 'MRP',
                      value: item.mrp > 0
                          ? 'Rs ${item.mrp.toStringAsFixed(0)}'
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
                  child: Text(
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
            Text(
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
                  color: AppTheme.incomeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${profitPercent.toStringAsFixed(0)}% ${fontFamily != null ? 'منافع' : 'profit'}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.incomeColor,
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
              margin: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.backgroundColor,
                  width: 1,
                ),
              ),
              child: Text(
                item.description,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFamily: fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
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
              Text(
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
                child: Text(
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
                Text(
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
                Text(
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
            (m) => _buildMovementItem(m, isUrdu, fontFamily),
          ),
      ],
    );
  }

  Widget _buildMovementItem(
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
        iconColor = const Color(0xFFD97706);
        iconBg = const Color(0xFFD97706).withValues(alpha: 0.12);
        icon = PhosphorIcons.sliders();
        typeLabel = isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment';
        sign = movement.quantity >= 0 ? '+' : '−';
        isPlus = movement.quantity >= 0;
        break;
    }

    final formattedDate =
        DateFormat('dd MMM, hh:mm a').format(movement.timestamp);
    final qtyAbs = movement.quantity.abs();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.backgroundColor,
          width: 1.5,
        ),
      ),
      child: Row(
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
                Text(
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
                const SizedBox(height: 3),
                Text(
                  movement.note.isNotEmpty ? movement.note : formattedDate,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Quantity + Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
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
                Text(
                  'Rs ${movement.unitPrice.toStringAsFixed(0)}',
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
                  Text(
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
