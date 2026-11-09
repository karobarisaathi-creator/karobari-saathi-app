// lib/features/shopkeeper/inventory_health_screen.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/features/shopkeeper/stock_detail_screen.dart';

class InventoryHealthScreen extends StatefulWidget {
  const InventoryHealthScreen({super.key});

  @override
  State<InventoryHealthScreen> createState() => _InventoryHealthScreenState();
}

class _InventoryHealthScreenState extends State<InventoryHealthScreen> {
  // کون سی category کھلی ہے — 'out' | 'low' | 'dead' | 'aging' | null
  String? _activeList;

  // Aging bucket منتخب — 0..3 یا null
  int? _activeAgingBucket;

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    // ═══ Metrics ═══
    final summary = stockService.getStockSummary();
    final totalPurchaseValue = summary['totalPurchaseValue'] as double? ?? 0.0;
    final activeTrackedItems = stockService.items
        .where((item) => !item.isArchived && item.trackStock)
        .toList();
    final totalItems = activeTrackedItems.length;

    final lowStockItems = activeTrackedItems.where((item) {
      final currentStock = stockService.calculateCurrentStock(item.id);
      return currentStock > 0 && currentStock <= item.minStockAlert;
    }).toList();

    final outOfStockItems = activeTrackedItems.where((item) {
      return stockService.calculateCurrentStock(item.id) <= 0;
    }).toList();

    // ═══ Dead stock (30+ دن میں کوئی فروخت نہیں) ═══
    final recentSalesCounts = <String, int>{};
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    for (final movement in stockService.movements) {
      if (movement.type == StockMovementType.sale &&
          !movement.timestamp.isBefore(thirtyDaysAgo)) {
        recentSalesCounts.update(
          movement.stockItemId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final deadStockItems = activeTrackedItems.where((item) {
      final recentSales = recentSalesCounts[item.id] ?? 0;
      final currentStock = stockService.calculateCurrentStock(item.id);
      return recentSales == 0 && currentStock > 0;
    }).toList();

    // ═══ Dead stock value ═══
    final deadStockValue = deadStockItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          (stockService.calculateCurrentStock(item.id) *
              stockService.calculateWeightedAverageCost(item.id)),
    );

    // ═══ Out of stock value (کھویا ہوا) ═══
    final outStockValue = outOfStockItems.fold<double>(
      0,
      (sum, item) => sum + (item.minStockAlert * item.purchasePrice),
    );

    // ═══ Low stock value ═══
    final lowStockValue = lowStockItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item.minStockAlert - stockService.calculateCurrentStock(item.id)) *
              item.purchasePrice),
    );

    // ═══ Health Score ═══
    final healthScore = _calculateHealthScore(
      totalItems: totalItems,
      outCount: outOfStockItems.length,
      lowCount: lowStockItems.length,
      deadCount: deadStockItems.length,
    );

    // ═══ Aging buckets ═══
    final agingBuckets = _buildAgingBuckets(
      items: activeTrackedItems,
      stockService: stockService,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'انوینٹری صحت' : 'Inventory Health',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Hero Health Score ═══
            _buildHeroScore(
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              score: healthScore,
              totalItems: totalItems,
              totalValue: totalPurchaseValue,
              outCount: outOfStockItems.length,
              lowCount: lowStockItems.length,
              deadCount: deadStockItems.length,
            ),
            const SizedBox(height: 12),

            // ═══ Traffic Lights ═══
            Row(
              children: [
                Expanded(
                  child: _buildTrafficCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    category: 'out',
                    icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                    count: outOfStockItems.length,
                    label: isUrdu ? 'ختم' : 'Out',
                    lightColor: AppTheme.expenseColor,
                    lightBg: AppTheme.expenseColor.withValues(alpha: 0.1),
                    isActive: _activeList == 'out',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTrafficCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    category: 'low',
                    icon: PhosphorIcons.warning(PhosphorIconsStyle.fill),
                    count: lowStockItems.length,
                    label: isUrdu ? 'کم' : 'Low',
                    lightColor: AppTheme.verifiedGold,
                    lightBg: AppTheme.verifiedGold.withValues(alpha: 0.1),
                    isActive: _activeList == 'low',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTrafficCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    category: 'dead',
                    icon: PhosphorIcons.hourglass(PhosphorIconsStyle.fill),
                    count: deadStockItems.length,
                    label: isUrdu ? 'مردہ' : 'Dead',
                    lightColor: AppTheme.incomeColor,
                    lightBg: AppTheme.incomeColor.withValues(alpha: 0.1),
                    isActive: _activeList == 'dead',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ═══ Expandable List — منتخب category ═══
            if (_activeList == 'out')
              _buildExpandList(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu
                    ? 'ختم شدہ اشیاء (${outOfStockItems.length})'
                    : 'Out of Stock (${outOfStockItems.length})',
                subtitle: isUrdu
                    ? 'ویلیو: ${Formatters.formatAmountWithCurrency(outStockValue)}'
                    : 'Value: ${Formatters.formatAmountWithCurrency(outStockValue)}',
                items: outOfStockItems,
                category: 'out',
                stockService: stockService,
              ),
            if (_activeList == 'low')
              _buildExpandList(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu
                    ? 'کم اسٹاک (${lowStockItems.length})'
                    : 'Low Stock (${lowStockItems.length})',
                subtitle: isUrdu
                    ? 'ویلیو: ${Formatters.formatAmountWithCurrency(lowStockValue)}'
                    : 'Value: ${Formatters.formatAmountWithCurrency(lowStockValue)}',
                items: lowStockItems,
                category: 'low',
                stockService: stockService,
              ),
            if (_activeList == 'dead')
              _buildExpandList(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu
                    ? 'مردہ اسٹاک (${deadStockItems.length})'
                    : 'Dead Stock (${deadStockItems.length})',
                subtitle: isUrdu
                    ? 'ویلیو: ${Formatters.formatAmountWithCurrency(deadStockValue)}'
                    : 'Value: ${Formatters.formatAmountWithCurrency(deadStockValue)}',
                items: deadStockItems,
                category: 'dead',
                stockService: stockService,
              ),

            const SizedBox(height: 14),

            // ═══ Aging Section ═══
            _buildSectionTitle(
              icon: PhosphorIcons.package(),
              title: isUrdu ? 'اسٹاک کی عمر' : 'Stock Aging',
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 8),
            _buildAgingCard(
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              buckets: agingBuckets,
              stockService: stockService,
            ),

            // ═══ Aging expand list ═══
            if (_activeAgingBucket != null)
              _buildExpandList(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: agingBuckets[_activeAgingBucket!].label(isUrdu),
                subtitle: isUrdu
                    ? '${agingBuckets[_activeAgingBucket!].items.length} اشیاء'
                    : '${agingBuckets[_activeAgingBucket!].items.length} items',
                items: agingBuckets[_activeAgingBucket!].items,
                category: 'aging',
                stockService: stockService,
              ),

            const SizedBox(height: 14),

            // ═══ Dead stock summary card ═══
            if (deadStockItems.isNotEmpty) ...[
              _buildSectionTitle(
                icon: PhosphorIcons.warning(),
                title: isUrdu ? 'مردہ اسٹاک' : 'Dead Stock',
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 8),
              _buildDeadStockSummary(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                count: deadStockItems.length,
                value: deadStockValue,
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Health Score
  // ═════════════════════════════════════════════════════════════
  int _calculateHealthScore({
    required int totalItems,
    required int outCount,
    required int lowCount,
    required int deadCount,
  }) {
    if (totalItems == 0) return 100;
    final healthy = totalItems - outCount - lowCount - deadCount;
    final score = (healthy / totalItems) * 100;
    return score.clamp(0, 100).round();
  }

  // ═════════════════════════════════════════════════════════════
  // Aging Buckets
  // ═════════════════════════════════════════════════════════════
  List<_AgingBucket> _buildAgingBuckets({
    required List<StockItem> items,
    required StockService stockService,
  }) {
    final now = DateTime.now();

    final buckets = <_AgingBucket>[
      _AgingBucket(
        key: 'fresh',
        labelEn: '0-30 days',
        labelUr: '0-30 دن',
        minDays: 0,
        maxDays: 30,
        color: AppTheme.incomeColor,
      ),
      _AgingBucket(
        key: 'mid',
        labelEn: '31-90 days',
        labelUr: '31-90 دن',
        minDays: 31,
        maxDays: 90,
        color: AppTheme.verifiedGold,
      ),
      _AgingBucket(
        key: 'old',
        labelEn: '91-180 days',
        labelUr: '91-180 دن',
        minDays: 91,
        maxDays: 180,
        color: AppTheme.themeColor,
      ),
      _AgingBucket(
        key: 'dead',
        labelEn: '180+ days',
        labelUr: '180+ دن',
        minDays: 181,
        maxDays: 99999,
        color: AppTheme.expenseColor,
      ),
    ];

    for (final item in items) {
      final currentStock = stockService.calculateCurrentStock(item.id);
      if (currentStock <= 0) continue;

      // آخری خریداری کی تاریخ (یا item کی تخلیق)
      DateTime? lastPurchaseDate;
      for (final m in stockService.movements) {
        if (m.stockItemId == item.id &&
            m.type == StockMovementType.purchase) {
          if (lastPurchaseDate == null ||
              m.timestamp.isAfter(lastPurchaseDate)) {
            lastPurchaseDate = m.timestamp;
          }
        }
      }

      final referenceDate = lastPurchaseDate ?? now;
      final ageDays = now.difference(referenceDate).inDays;

      for (final bucket in buckets) {
        if (ageDays >= bucket.minDays && ageDays <= bucket.maxDays) {
          bucket.items.add(item);
          break;
        }
      }
    }

    return buckets;
  }

  // ═════════════════════════════════════════════════════════════
  // Hero Score Card
  // ═════════════════════════════════════════════════════════════
  Widget _buildHeroScore({
    required bool isUrdu,
    required String? fontFamily,
    required int score,
    required int totalItems,
    required double totalValue,
    required int outCount,
    required int lowCount,
    required int deadCount,
  }) {
    final scoreColor = score >= 75
        ? AppTheme.incomeColor
        : score >= 50
            ? AppTheme.verifiedGold
            : AppTheme.expenseColor;

    final statusLabel = score >= 75
        ? (isUrdu ? 'صحت مند' : 'Healthy')
        : score >= 50
            ? (isUrdu ? 'توجہ چاہیے' : 'Needs Attention')
            : (isUrdu ? 'تشویشناک' : 'Critical');

    final healthyCount = totalItems - outCount - lowCount - deadCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.themeColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.20),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UrduAwareText(
                      '$score',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: fontFamily,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    UrduAwareText(
                      isUrdu ? 'اسکور' : 'SCORE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.5,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  '${isUrdu ? 'انوینٹری کی صحت' : 'Inventory Health'} — $statusLabel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                UrduAwareText(
                  '${isUrdu ? 'کل ویلیو: ' : 'Total value: '}${Formatters.formatAmountWithCurrency(totalValue)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.90),
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildHeroStat(
                      color: AppTheme.incomeColor,
                      count: healthyCount,
                      label: isUrdu ? 'صحیح' : 'healthy',
                      fontFamily: fontFamily,
                    ),
                    _buildHeroStat(
                      color: AppTheme.verifiedGold,
                      count: lowCount,
                      label: isUrdu ? 'کم' : 'low',
                      fontFamily: fontFamily,
                    ),
                    _buildHeroStat(
                      color: AppTheme.expenseColor,
                      count: outCount,
                      label: isUrdu ? 'ختم' : 'out',
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

  Widget _buildHeroStat({
    required Color color,
    required int count,
    required String label,
    String? fontFamily,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        UrduAwareText(
          '$count $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Traffic Card (Clickable) - No shadow, no border
  // ═════════════════════════════════════════════════════════════
  Widget _buildTrafficCard({
    required bool isUrdu,
    required String? fontFamily,
    required String category,
    required IconData icon,
    required int count,
    required String label,
    required Color lightColor,
    required Color lightBg,
    required bool isActive,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _activeList = _activeList == category ? null : category;
            _activeAgingBucket = null;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.themeColor.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: lightBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: lightColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UrduAwareText(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkColor,
                        height: 1,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    UrduAwareText(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                isActive ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
                size: 12,
                color: isActive ? AppTheme.themeColor : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Expand List - No shadow, no border
  // ═════════════════════════════════════════════════════════════
  Widget _buildExpandList({
    required bool isUrdu,
    required String? fontFamily,
    required String title,
    required String subtitle,
    required List<StockItem> items,
    required String category,
    required StockService stockService,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: UrduAwareText(
            isUrdu ? 'کوئی شے نہیں' : 'No items',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(height: 2),
                        UrduAwareText(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _activeList = null;
                          _activeAgingBucket = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.verifiedGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: UrduAwareText(
                          isUrdu ? 'بند ✕' : 'Close ✕',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.verifiedGold,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            // Items
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: items.map((item) {
                  return _buildExpandItem(
                    item: item,
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    category: category,
                    stockService: stockService,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandItem({
    required StockItem item,
    required bool isUrdu,
    required String? fontFamily,
    required String category,
    required StockService stockService,
  }) {
    final currentStock = stockService.calculateCurrentStock(item.id);
    final color = category == 'out'
        ? AppTheme.expenseColor
        : category == 'low'
            ? AppTheme.verifiedGold
            : AppTheme.incomeColor;
    final bgColor = category == 'out'
        ? AppTheme.expenseColor.withValues(alpha: 0.1)
        : category == 'low'
            ? AppTheme.verifiedGold.withValues(alpha: 0.1)
            : AppTheme.incomeColor.withValues(alpha: 0.1);
    final iconData = category == 'out'
        ? PhosphorIcons.xCircle(PhosphorIconsStyle.fill)
        : category == 'low'
            ? PhosphorIcons.warning(PhosphorIconsStyle.fill)
            : PhosphorIcons.hourglass(PhosphorIconsStyle.fill);

    final qtyLabel = category == 'out'
        ? (isUrdu ? 'ختم' : 'OUT')
        : '${currentStock.toStringAsFixed(0)} ${item.unit}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailScreen(item: item),
            ),
          );
          if (result == true && mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(iconData, size: 14, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UrduAwareText(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    UrduAwareText(
                      isUrdu
                          ? 'کم از کم: ${item.minStockAlert.toStringAsFixed(0)} ${item.unit}'
                          : 'Min: ${item.minStockAlert.toStringAsFixed(0)} ${item.unit}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: UrduAwareText(
                  qtyLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                PhosphorIcons.caretRight(),
                size: 11,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Aging Card - No shadow, no border
  // ═════════════════════════════════════════════════════════════
  Widget _buildAgingCard({
    required bool isUrdu,
    required String? fontFamily,
    required List<_AgingBucket> buckets,
    required StockService stockService,
  }) {
    final total = buckets.fold<int>(0, (sum, b) => sum + b.items.length);
    final totalVal = total == 0 ? 1 : total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (int i = 0; i < buckets.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildAgingBarRow(
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              bucket: buckets[i],
              pct: (buckets[i].items.length / totalVal) * 100,
              isActive: _activeAgingBucket == i,
              onTap: () {
                setState(() {
                  _activeAgingBucket = _activeAgingBucket == i ? null : i;
                  _activeList = null;
                });
              },
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendItem(
                color: AppTheme.incomeColor,
                label: isUrdu ? 'تازہ' : 'Fresh',
                fontFamily: fontFamily,
              ),
              _buildLegendItem(
                color: AppTheme.verifiedGold,
                label: isUrdu ? 'درمیانہ' : 'Mid',
                fontFamily: fontFamily,
              ),
              _buildLegendItem(
                color: AppTheme.themeColor,
                label: isUrdu ? 'پرانا' : 'Old',
                fontFamily: fontFamily,
              ),
              _buildLegendItem(
                color: AppTheme.expenseColor,
                label: isUrdu ? 'مردہ' : 'Dead',
                fontFamily: fontFamily,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgingBarRow({
    required bool isUrdu,
    required String? fontFamily,
    required _AgingBucket bucket,
    required double pct,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: UrduAwareText(
                  bucket.label(isUrdu),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppTheme.themeColor
                        : AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (pct / 100).clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bucket.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: UrduAwareText(
                  '${bucket.items.length} · ${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isActive ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
                size: 11,
                color: isActive ? AppTheme.themeColor : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    String? fontFamily,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Dead Stock Summary - No shadow, no border
  // ═════════════════════════════════════════════════════════════
  Widget _buildDeadStockSummary({
    required bool isUrdu,
    required String? fontFamily,
    required int count,
    required double value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.incomeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              PhosphorIcons.hourglass(PhosphorIconsStyle.fill),
              size: 18,
              color: AppTheme.incomeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  isUrdu
                      ? '$count اشیاء · 30+ دن سے نہیں بکیں'
                      : '$count items · No sales in 30+ days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                UrduAwareText(
                  isUrdu
                      ? 'ویلیو: ${Formatters.formatAmountWithCurrency(value)} پھنسی ہوئی'
                      : 'Value: ${Formatters.formatAmountWithCurrency(value)} stuck',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.expenseColor,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Section Title
  // ═════════════════════════════════════════════════════════════
  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    String? fontFamily,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: UrduAwareText(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
                fontFamily: fontFamily,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Aging Bucket Model
// ═════════════════════════════════════════════════════════════
class _AgingBucket {
  final String key;
  final String labelEn;
  final String labelUr;
  final int minDays;
  final int maxDays;
  final Color color;
  final List<StockItem> items;

  _AgingBucket({
    required this.key,
    required this.labelEn,
    required this.labelUr,
    required this.minDays,
    required this.maxDays,
    required this.color,
  }) : items = [];

  String label(bool isUrdu) => isUrdu ? labelUr : labelEn;
}
