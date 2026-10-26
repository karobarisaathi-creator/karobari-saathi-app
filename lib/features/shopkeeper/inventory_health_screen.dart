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

class _InventoryHealthScreenState extends State<InventoryHealthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

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

    final turnover = stockService.calculateInventoryTurnover();
    final holdingDays = stockService.calculateHoldingDays();
    final stockoutRate = stockService.calculateStockoutRate();
    final deadStock = <StockItem>[];
    final fastItems = <StockItem>[];
    final slowItems = <StockItem>[];
    for (final item in activeTrackedItems) {
      final recentSalesCount = recentSalesCounts[item.id] ?? 0;
      if (recentSalesCount >= 10) {
        fastItems.add(item);
      } else if (recentSalesCount > 0) {
        slowItems.add(item);
      } else if (stockService.calculateCurrentStock(item.id) > 0) {
        deadStock.add(item);
      }
    }

    final deadStockValue = deadStock.fold<double>(
      0,
      (sum, item) =>
          sum +
          (stockService.calculateCurrentStock(item.id) *
              stockService.calculateWeightedAverageCost(item.id)),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'انوینٹری صحت' : 'Inventory Health',
      ),
      body: Column(
        children: [
          // ═══ Tab Bar ═══
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.themeColor,
              labelColor: AppTheme.themeColor,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.gauge(), size: 14),
                      const SizedBox(width: 4),
                      Text(isUrdu ? 'خلاصہ' : 'Summary'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.lightning(), size: 14),
                      const SizedBox(width: 4),
                      Text(isUrdu ? 'رفتار' : 'Velocity'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.warningCircle(), size: 14),
                      const SizedBox(width: 4),
                      Text(isUrdu ? 'خطرات' : 'Alerts'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ═══ Tab Views ═══
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ═══ Tab 1: Summary ═══
                _buildSummaryTab(
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  totalItems: totalItems,
                  outOfStockCount: outOfStockItems.length,
                  lowStockCount: lowStockItems.length,
                  totalPurchaseValue: totalPurchaseValue,
                  turnover: turnover,
                  holdingDays: holdingDays,
                  stockoutRate: stockoutRate,
                  deadStockValue: deadStockValue,
                  deadStockCount: deadStock.length,
                ),

                // ═══ Tab 2: Velocity ═══
                _buildVelocityTab(
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  fastCount: fastItems.length,
                  slowCount: slowItems.length,
                  deadCount: deadStock.length,
                  fastItems: fastItems,
                  slowItems: slowItems,
                  deadItems: deadStock,
                  stockService: stockService,
                ),

                // ═══ Tab 3: Alerts ═══
                _buildAlertsTab(
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  lowStockItems: lowStockItems,
                  outOfStockItems: outOfStockItems,
                  deadStock: deadStock,
                  stockService: stockService,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab({
    required bool isUrdu,
    required String fontFamily,
    required int totalItems,
    required int outOfStockCount,
    required int lowStockCount,
    required double totalPurchaseValue,
    required double turnover,
    required double holdingDays,
    required double stockoutRate,
    required double deadStockValue,
    required int deadStockCount,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthSummaryCard(
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            totalItems: totalItems,
            outOfStockCount: outOfStockCount,
            lowStockCount: lowStockCount,
            totalPurchaseValue: totalPurchaseValue,
          ),
          const SizedBox(height: 8),
          _buildAdvancedMetricsCard(
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            turnover: turnover,
            holdingDays: holdingDays,
            stockoutRate: stockoutRate,
            deadStockValue: deadStockValue,
            deadStockCount: deadStockCount,
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityTab({
    required bool isUrdu,
    required String fontFamily,
    required int fastCount,
    required int slowCount,
    required int deadCount,
    required List<StockItem> fastItems,
    required List<StockItem> slowItems,
    required List<StockItem> deadItems,
    required StockService stockService,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVelocityCard(
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            fastCount: fastCount,
            slowCount: slowCount,
            deadCount: deadCount,
          ),
          const SizedBox(height: 8),
          if (fastItems.isNotEmpty) ...[
            _buildSectionHeader(
              icon: PhosphorIcons.checkCircle(),
              title: isUrdu
                  ? 'تیز فروخت ($fastCount)'
                  : 'Fast Selling ($fastCount)',
              color: AppTheme.incomeColor,
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 8),
            ...fastItems.take(10).map((item) => _buildVelocityItemCard(
                  item: item,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  velocity: 'fast',
                  stockService: stockService,
                )),
            const SizedBox(height: 16),
          ],
          if (slowItems.isNotEmpty) ...[
            _buildSectionHeader(
              icon: PhosphorIcons.clock(),
              title: isUrdu
                  ? 'سست فروخت ($slowCount)'
                  : 'Slow Moving ($slowCount)',
              color: Colors.orange,
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 8),
            ...slowItems.take(10).map((item) => _buildVelocityItemCard(
                  item: item,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  velocity: 'slow',
                  stockService: stockService,
                )),
            const SizedBox(height: 16),
          ],
          if (deadItems.isNotEmpty) ...[
            _buildSectionHeader(
              icon: PhosphorIcons.warning(),
              title: isUrdu
                  ? 'مردہ اسٹاک ($deadCount)'
                  : 'Dead Stock ($deadCount)',
              color: AppTheme.expenseColor,
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 8),
            ...deadItems.take(10).map((item) => _buildVelocityItemCard(
                  item: item,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  velocity: 'dead',
                  stockService: stockService,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsTab({
    required bool isUrdu,
    required String fontFamily,
    required List<StockItem> lowStockItems,
    required List<StockItem> outOfStockItems,
    required List<StockItem> deadStock,
    required StockService stockService,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (outOfStockItems.isNotEmpty) ...[
            _buildSectionHeader(
              icon: PhosphorIcons.prohibit(),
              title: isUrdu
                  ? 'ختم شدہ اسٹاک (${outOfStockItems.length})'
                  : 'Out of Stock (${outOfStockItems.length})',
              color: AppTheme.expenseColor,
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 8),
            ...outOfStockItems.map((item) => _buildAlertItemCard(
                  item: item,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  alertType: 'out',
                  stockService: stockService,
                )),
            const SizedBox(height: 16),
          ],
          if (lowStockItems.isNotEmpty) ...[
            _buildSectionHeader(
              icon: PhosphorIcons.warning(),
              title: isUrdu
                  ? 'کم اسٹاک (${lowStockItems.length})'
                  : 'Low Stock (${lowStockItems.length})',
              color: Colors.orange,
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 8),
            ...lowStockItems.map((item) => _buildAlertItemCard(
                  item: item,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  alertType: 'low',
                  stockService: stockService,
                )),
            const SizedBox(height: 16),
          ],
          if (deadStock.isNotEmpty) ...[
            _buildSectionHeader(
              icon: PhosphorIcons.skull(),
              title: isUrdu
                  ? 'مردہ اسٹاک (${deadStock.length})'
                  : 'Dead Stock (${deadStock.length})',
              color: AppTheme.expenseColor,
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 8),
            ...deadStock.map((item) => _buildAlertItemCard(
                  item: item,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  alertType: 'dead',
                  stockService: stockService,
                )),
          ],
          if (outOfStockItems.isEmpty &&
              lowStockItems.isEmpty &&
              deadStock.isEmpty)
            _buildEmptyState(isUrdu, fontFamily),
        ],
      ),
    );
  }

  Widget _buildHealthSummaryCard({
    required bool isUrdu,
    required String fontFamily,
    required int totalItems,
    required int outOfStockCount,
    required int lowStockCount,
    required double totalPurchaseValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chartLineUp(),
                  color: AppTheme.themeColor, size: 20),
              const SizedBox(width: 8),
              UrduAwareText(
                isUrdu ? 'انوینٹری صحت کا خلاصہ' : 'Inventory Health Summary',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHealthStat(
                  title: isUrdu ? 'کل اشیاء' : 'Total Items',
                  value: totalItems.toString(),
                  icon: PhosphorIcons.package(),
                  color: AppTheme.themeColor,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthStat(
                  title: isUrdu ? 'آؤٹ آف اسٹاک' : 'Out of Stock',
                  value: outOfStockCount.toString(),
                  icon: PhosphorIcons.warning(),
                  color: AppTheme.expenseColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHealthStat(
                  title: isUrdu ? 'کم اسٹاک الرٹس' : 'Low Stock Alerts',
                  value: lowStockCount.toString(),
                  icon: PhosphorIcons.bell(),
                  color: Colors.orange,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthStat(
                  title: isUrdu ? 'کل اسٹاک سرمایا' : 'Stock Capital',
                  value:
                      Formatters.formatAmountWithCurrency(totalPurchaseValue),
                  icon: PhosphorIcons.currencyCircleDollar(),
                  color: AppTheme.incomeColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedMetricsCard({
    required bool isUrdu,
    required String fontFamily,
    required double turnover,
    required double holdingDays,
    required double stockoutRate,
    required double deadStockValue,
    required int deadStockCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chartBar(),
                  size: 18, color: AppTheme.themeColor),
              const SizedBox(width: 8),
              UrduAwareText(
                isUrdu
                    ? 'ایڈوانسڈ انوینٹری اشاریے'
                    : 'Advanced Inventory Metrics',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMetricRow(
            icon: PhosphorIcons.arrowsClockwise(),
            label: isUrdu ? 'انوینٹری ٹرن اوور ریٹ' : 'Inventory Turnover Rate',
            value: '${turnover.toStringAsFixed(2)}x',
            valueColor: AppTheme.themeColor,
            fontFamily: fontFamily,
            hint: isUrdu
                ? 'سالانہ اسٹاک گردش کی رفتار'
                : 'Annual stock rotation speed',
          ),
          const Divider(height: 16),
          _buildMetricRow(
            icon: PhosphorIcons.calendar(),
            label: isUrdu ? 'ہولڈنگ ڈیز (اوسط)' : 'Inventory Holding Days',
            value: '${holdingDays.toStringAsFixed(0)} دن',
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            hint: isUrdu ? 'اسٹاک کتنے دن تک چلے گا' : 'Days stock will last',
          ),
          const Divider(height: 16),
          _buildMetricRow(
            icon: PhosphorIcons.warningOctagon(),
            label: isUrdu ? 'اسٹاک آؤٹ ریٹ' : 'Stockout Rate',
            value: '${stockoutRate.toStringAsFixed(1)}%',
            valueColor: stockoutRate <= 5
                ? AppTheme.incomeColor
                : stockoutRate <= 15
                    ? Colors.orange
                    : AppTheme.expenseColor,
            fontFamily: fontFamily,
            hint: isUrdu
                ? (stockoutRate <= 5
                    ? 'بہت اچھا — کم اشیاء ختم'
                    : 'خراب — بہت سے اشیاء ختم')
                : (stockoutRate <= 5
                    ? 'Excellent — few out'
                    : 'Poor — many out'),
          ),
          const Divider(height: 16),
          _buildMetricRow(
            icon: PhosphorIcons.skull(),
            label: isUrdu ? 'مردہ اسٹاک' : 'Dead Stock',
            value: Formatters.formatAmountWithCurrency(deadStockValue),
            valueColor: deadStockCount == 0
                ? AppTheme.incomeColor
                : AppTheme.expenseColor,
            fontFamily: fontFamily,
            hint: isUrdu
                ? '$deadStockCount اشیاء — نقصان سے بچیں'
                : '$deadStockCount items — avoid loss',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    required String fontFamily,
    required String hint,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: valueColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UrduAwareText(
                label,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkColor,
                ),
              ),
              const SizedBox(height: 2),
              UrduAwareText(
                hint,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        UrduAwareText(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: valueColor,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildVelocityCard({
    required bool isUrdu,
    required String fontFamily,
    required int fastCount,
    required int slowCount,
    required int deadCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.lightning(),
                  size: 18, color: AppTheme.themeColor),
              const SizedBox(width: 8),
              UrduAwareText(
                isUrdu ? 'اشیاء کی رفتار' : 'Item Velocity',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildVelocityStat(
                  icon: PhosphorIcons.checkCircle(),
                  label: isUrdu ? 'تیز' : 'Fast',
                  sublabel: isUrdu ? '10+ / 30 دن' : '10+ / 30d',
                  count: fastCount,
                  color: AppTheme.incomeColor,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVelocityStat(
                  icon: PhosphorIcons.clock(),
                  label: isUrdu ? 'سست' : 'Slow',
                  sublabel: isUrdu ? '1-9 / 30 دن' : '1-9 / 30d',
                  count: slowCount,
                  color: Colors.orange,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVelocityStat(
                  icon: PhosphorIcons.warning(),
                  label: isUrdu ? 'مردہ' : 'Dead',
                  sublabel: isUrdu ? '30 دن سے کوئی نہیں' : 'none in 30d',
                  count: deadCount,
                  color: AppTheme.expenseColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityStat({
    required IconData icon,
    required String label,
    required String sublabel,
    required int count,
    required Color color,
    required String fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          UrduAwareText(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: '',
            ),
          ),
          const SizedBox(height: 2),
          UrduAwareText(
            label,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          UrduAwareText(
            sublabel,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required String fontFamily,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        UrduAwareText(
          title,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildVelocityItemCard({
    required StockItem item,
    required bool isUrdu,
    required String fontFamily,
    required String velocity,
    required StockService stockService,
  }) {
    final currentStock = stockService.calculateCurrentStock(item.id);
    Color color;
    IconData icon;

    switch (velocity) {
      case 'fast':
        color = AppTheme.incomeColor;
        icon = PhosphorIcons.checkCircle();
        break;
      case 'slow':
        color = Colors.orange;
        icon = PhosphorIcons.clock();
        break;
      default:
        color = AppTheme.expenseColor;
        icon = PhosphorIcons.warning();
    }

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDetailScreen(item: item),
          ),
        );
        if (result == true && mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    item.name,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  UrduAwareText(
                    '${currentStock.toStringAsFixed(0)} ${item.unit} · ${Formatters.formatAmountWithCurrency(item.sellingPrice)}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(),
              size: 12,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItemCard({
    required StockItem item,
    required bool isUrdu,
    required String fontFamily,
    required String alertType,
    required StockService stockService,
  }) {
    final currentStock = stockService.calculateCurrentStock(item.id);
    final value = currentStock * item.purchasePrice;
    Color color;
    IconData icon;
    String statusLabel;

    switch (alertType) {
      case 'out':
        color = AppTheme.expenseColor;
        icon = PhosphorIcons.prohibit();
        statusLabel = isUrdu ? 'ختم' : 'Out';
        break;
      case 'low':
        color = Colors.orange;
        icon = PhosphorIcons.warning();
        statusLabel = isUrdu ? 'کم' : 'Low';
        break;
      default:
        color = AppTheme.expenseColor;
        icon = PhosphorIcons.skull();
        statusLabel = isUrdu ? 'مردہ' : 'Dead';
    }

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDetailScreen(item: item),
          ),
        );
        if (result == true && mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    item.name,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  UrduAwareText(
                    alertType == 'out'
                        ? (isUrdu ? 'ختم شدہ' : 'Out of stock')
                        : '${currentStock.toStringAsFixed(0)} ${item.unit} · ${Formatters.formatAmountWithCurrency(value)}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: UrduAwareText(
                statusLabel,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: UrduAwareText(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
              fontFamily: '',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.checkCircle(),
              size: 64,
              color: Colors.green[400],
            ),
            const SizedBox(height: 16),
            UrduAwareText(
              isUrdu
                  ? 'تمام انوینٹری بہترین حالت میں ہے!'
                  : 'All inventory health status is optimal!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
