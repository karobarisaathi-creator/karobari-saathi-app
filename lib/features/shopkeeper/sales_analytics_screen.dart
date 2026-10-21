// lib/features/shopkeeper/sales_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_analytics_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_analytics_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isMonthlyView = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isMonthlyView = _tabController.index == 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════════

  String _formatCompact(double amount) {
    final sign = amount < 0 ? '-' : '';
    final absoluteAmount = amount.abs();
    if (absoluteAmount >= 1000000) {
      return 'Rs $sign${(absoluteAmount / 1000000).toStringAsFixed(2)}M';
    }
    if (absoluteAmount >= 1000) {
      return 'Rs $sign${(absoluteAmount / 1000).toStringAsFixed(0)}K';
    }
    return 'Rs $sign${Formatters.formatAmount(absoluteAmount)}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _getFullMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _getUrduMonthName(int month) {
    const months = [
      'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
      'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  double _getChangePercent(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous.abs()) * 100;
  }

  void _previousPeriod() {
    setState(() {
      if (_isMonthlyView) {
        if (_selectedMonth == 1) {
          _selectedMonth = 12;
          _selectedYear--;
        } else {
          _selectedMonth--;
        }
      } else {
        _selectedYear--;
      }
    });
  }

  void _nextPeriod() {
    if (!_canGoNext) return;
    setState(() {
      if (_isMonthlyView) {
        if (_selectedMonth == 12) {
          _selectedMonth = 1;
          _selectedYear++;
        } else {
          _selectedMonth++;
        }
      } else {
        _selectedYear++;
        _selectedMonth = DateTime.now().month;
      }
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    if (_isMonthlyView) {
      return _selectedYear < now.year ||
          (_selectedYear == now.year && _selectedMonth < now.month);
    }
    return _selectedYear < now.year;
  }



  // ═════════════════════════════════════════════════════════════
  // Daily Data (ماہانہ چارٹ کے لیے)
  // ═════════════════════════════════════════════════════════════
  /// `stockMovements` سے روزانہ کی خرید/فروخت نکالیں
  List<StockDailyStats> _buildDailyStats(
      List<StockItem> items,
      List<dynamic> stockMovements,
      int year,
      int month,
      ) {
    return StockAnalyticsService.buildDailyStats(
      items: items,
      movements: stockMovements.whereType<StockMovement>().toList(),
      year: year,
      month: month,
    );
  }

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final stockService = Provider.of<StockService>(context);
    final databaseService = Provider.of<DatabaseService>(context);
    final partyNamesById = {
      for (final account in databaseService.accounts) account.id: account.name,
    };
    final stockMovements = StockAnalyticsService.includeUnlinkedTransactions(
      items: stockService.items,
      movements: stockService.movements,
      transactions: databaseService.getAllTransactions(),
      partyNamesById: partyNamesById,
    );
    final yearlyStats = StockAnalyticsService.buildYearlyStats(
      items: stockService.items,
      movements: stockMovements,
      year: _selectedYear,
    );
    final previousYearStats = StockAnalyticsService.buildYearlyStats(
      items: stockService.items,
      movements: stockMovements,
      year: _selectedYear - 1,
    );

    final currentMonthStats = yearlyStats.months[_selectedMonth - 1];

    final previousMonth = _selectedMonth == 1 ? 12 : _selectedMonth - 1;
    final previousMonthStats =
    (_selectedMonth == 1 ? previousYearStats : yearlyStats)
        .months[previousMonth - 1];

    final salesChange = _getChangePercent(
      currentMonthStats.salesRevenue,
      previousMonthStats.salesRevenue,
    );
    final investChange = _getChangePercent(
      currentMonthStats.purchaseValue,
      previousMonthStats.purchaseValue,
    );
    final itemStart = _isMonthlyView
        ? DateTime(_selectedYear, _selectedMonth)
        : DateTime(_selectedYear);
    final itemEnd = _isMonthlyView
        ? DateTime(_selectedYear, _selectedMonth + 1)
        : DateTime(_selectedYear + 1);
    final itemStats = StockAnalyticsService.buildItemStats(
      items: stockService.items,
      movements: stockMovements,
      start: itemStart,
      endExclusive: itemEnd,
    );
    final partyStats = StockAnalyticsService.buildPartyStats(
      items: stockService.items,
      movements: stockMovements,
      start: itemStart,
      endExclusive: itemEnd,
      partyNamesById: partyNamesById,
      cashCustomerId: QuickBillConstants.cashCustomerAccountId,
      cashCustomerName: isUrdu ? 'کیش سیل' : 'Cash sales',
      unknownCustomerName: isUrdu ? 'نامعلوم گاہک' : 'Unknown customer',
      unnamedSupplierName: isUrdu ? 'نامعلوم سپلائر' : 'Unknown supplier',
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'خرید و فروخت رپورٹ' : 'Purchase & Sales',
        showBackButton: true,
      ),
      body: stockService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.darkColor,
              labelColor: AppTheme.darkColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: isUrdu ? 'ماہانہ' : 'Monthly'),
                Tab(text: isUrdu ? 'سالانہ' : 'Yearly'),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodNavigator(isUrdu, fontFamily),
                  const SizedBox(height: 8),

                  _buildHeroSection(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    sales: _isMonthlyView
                        ? currentMonthStats.salesRevenue
                        : yearlyStats.salesRevenue,
                    investment: _isMonthlyView
                        ? currentMonthStats.purchaseValue
                        : yearlyStats.purchaseValue,
                    profit: _isMonthlyView
                        ? currentMonthStats.grossProfit
                        : yearlyStats.grossProfit,
                    profitMargin: _isMonthlyView
                        ? currentMonthStats.profitMargin
                        : yearlyStats.profitMargin,
                    salesChange: _isMonthlyView ? salesChange : 0,
                    investChange: _isMonthlyView ? investChange : 0,
                    isMonthly: _isMonthlyView,
                  ),
                  if ((_isMonthlyView
                      ? currentMonthStats.uncostedSalesQuantity
                      : yearlyStats.uncostedSalesQuantity) >
                      0) ...[
                    const SizedBox(height: 8),
                    _buildCostWarning(isUrdu, fontFamily),
                  ],
                  const SizedBox(height: 8),

                  // ═══ Chart ═══
                  _isMonthlyView
                      ? _buildDailyChart(
                    stockService.items,
                    stockMovements,
                    _selectedYear,
                    _selectedMonth,
                    isUrdu,
                    fontFamily,
                  )
                      : _buildYearlyChart(
                    yearlyStats,
                    isUrdu,
                    fontFamily,
                  ),
                  const SizedBox(height: 8),

                  _buildSectionTitle(
                    icon: PhosphorIcons.package(),
                    title: isUrdu ? 'آئٹم وار منافع' : 'Item-wise Profit',
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                  const SizedBox(height: 8),
                  _buildItemBreakdown(itemStats, isUrdu, fontFamily),
                  const SizedBox(height: 8),

                  _buildSectionTitle(
                    icon: PhosphorIcons.users(),
                    title: isUrdu
                        ? 'پارٹی وار خرید و فروخت'
                        : 'Party-wise Activity',
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                  const SizedBox(height: 8),
                  _buildPartyBreakdown(partyStats, isUrdu, fontFamily),
                  const SizedBox(height: 8),

                  _buildSectionTitle(
                    icon: PhosphorIcons.chartLine(),
                    title: _isMonthlyView
                        ? (isUrdu ? 'ماہانہ خلاصہ' : 'Monthly Summary')
                        : (isUrdu ? 'سالانہ خلاصہ' : 'Yearly Summary'),
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                  const SizedBox(height: 8),
                  _isMonthlyView
                      ? _buildMonthlySummary(
                    currentMonthStats,
                    itemStats.length,
                    isUrdu,
                    fontFamily,
                  )
                      : _buildYearlySummary(
                    yearlyStats,
                    itemStats.length,
                    isUrdu,
                    fontFamily,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Period Navigator
  // ═════════════════════════════════════════════════════════════
  Widget _buildPeriodNavigator(bool isUrdu, String? fontFamily) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Row(
        children: [
          _buildNavBtn(
            icon: PhosphorIcons.caretLeft(),
            onTap: _previousPeriod,
            enabled: true,
          ),
          Expanded(
            child: Column(
              children: [
                UrduAwareText(
                  _isMonthlyView
                      ? (isUrdu ? 'منتخب مہینہ' : 'SELECTED MONTH')
                      : (isUrdu ? 'منتخب سال' : 'SELECTED YEAR'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                UrduAwareText.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _isMonthlyView
                            ? '${isUrdu ? _getUrduMonthName(_selectedMonth) : _getFullMonthName(_selectedMonth)} '
                            : '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: '$_selectedYear',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkColor,
                          fontFamily: null,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildNavBtn(
            icon: PhosphorIcons.caretRight(),
            onTap: _nextPeriod,
            enabled: _canGoNext,
          ),
        ],
      ),
    );
  }

  Widget _buildNavBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: enabled
                ? AppTheme.backgroundColor
                : AppTheme.backgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? AppTheme.darkColor
                : AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Hero Cards
  // ═════════════════════════════════════════════════════════════
  Widget _buildHeroSection({
    required bool isUrdu,
    required String? fontFamily,
    required double sales,
    required double investment,
    required double profit,
    required double profitMargin,
    double salesChange = 0,
    double investChange = 0,
    required bool isMonthly,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHeroCard(
                icon: PhosphorIcons.arrowUpRight(),
                label: isUrdu ? 'رعایت کے بعد فروخت' : 'NET SALES',
                value: _formatCompact(sales),
                changePercent: isMonthly ? salesChange : 0,
                color: salesChange >= 0
                    ? AppTheme.incomeColor
                    : AppTheme.expenseColor,
                bgColor: AppTheme.incomeColor.withValues(alpha: 0.10),
                fontFamily: fontFamily,
                showChange: isMonthly,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHeroCard(
                icon: PhosphorIcons.arrowDownLeft(),
                label: isUrdu ? 'خریداری کی رقم' : 'PURCHASE VALUE',
                value: _formatCompact(investment),
                changePercent: isMonthly ? investChange : 0,
                color: AppTheme.themeColor,
                bgColor: AppTheme.themeColor.withValues(alpha: 0.10),
                fontFamily: fontFamily,
                showChange: isMonthly,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildHeroCard(
          icon: PhosphorIcons.money(),
          label: isUrdu ? 'مجموعی اسٹاک منافع' : 'GROSS STOCK PROFIT',
          value: _formatCompact(profit),
          changePercent: 0,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFD97706).withValues(alpha: 0.10),
          fontFamily: fontFamily,
          subtitle:
          '${profitMargin.toStringAsFixed(1)}% ${isUrdu ? "منافع" : "profit margin"}',
          showChange: false,
          fullWidth: true,
          isUrdu: isUrdu,
        ),
      ],
    );
  }

  Widget _buildHeroCard({
    required IconData icon,
    required String label,
    required String value,
    required double changePercent,
    required Color color,
    required Color bgColor,
    String? fontFamily,
    String? subtitle,
    bool showChange = true,
    bool fullWidth = false,
    bool isUrdu = false,
  }) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: UrduAwareText(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.4,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          UrduAwareText(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
              letterSpacing: -0.6,
              fontFamily: null,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (showChange || subtitle != null) ...[
            const SizedBox(height: 8),
            if (subtitle != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: UrduAwareText.rich(
                  TextSpan(
                    children: [
                      if (subtitle.contains('%')) ...[
                        TextSpan(
                          text: '${subtitle.split(' ')[0]} ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                            fontFamily: null,
                          ),
                        ),
                        TextSpan(
                          text: isUrdu ? 'منافع' : 'profit margin',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ] else
                        TextSpan(
                          text: subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                            fontFamily: null,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: changePercent >= 0
                      ? AppTheme.incomeColor.withValues(alpha: 0.10)
                      : AppTheme.expenseColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      changePercent >= 0
                          ? PhosphorIcons.caretUp()
                          : PhosphorIcons.caretDown(),
                      size: 10,
                      color: changePercent >= 0
                          ? AppTheme.incomeColor
                          : AppTheme.expenseColor,
                    ),
                    const SizedBox(width: 3),
                    UrduAwareText(
                      '${changePercent >= 0 ? "+" : ""}${changePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.incomeColor,
                        fontFamily: null,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // ⭐ سالانہ چارٹ — 12 ماہ
  // ═════════════════════════════════════════════════════════════
  Widget _buildYearlyChart(
      StockYearlyStats yearly,
      bool isUrdu,
      String? fontFamily,
      ) {
    double maxValue = 1;
    for (final m in yearly.months) {
      if (m.salesRevenue > maxValue) maxValue = m.salesRevenue;
      if (m.purchaseValue > maxValue) maxValue = m.purchaseValue;
      if (m.grossProfit.abs() > maxValue) maxValue = m.grossProfit.abs();
    }

    final now = DateTime.now();
    final currentMonthIndex =
    (yearly.year == now.year) ? now.month - 1 : -1;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.chartBar(),
                  size: 15,
                  color: AppTheme.themeColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: UrduAwareText(
                    isUrdu
                        ? 'سال ${yearly.year} — ماہانہ خرید، فروخت اور منافع'
                        : 'Year ${yearly.year} — Monthly Sales, Purchases & Profit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildLegendDot(
                  color: AppTheme.incomeColor,
                  label: isUrdu ? 'فروخت' : 'Sales',
                  fontFamily: fontFamily,
                ),
                const SizedBox(width: 8),
                _buildLegendDot(
                  color: AppTheme.themeColor,
                  label: isUrdu ? 'خرید' : 'Purchase',
                  fontFamily: fontFamily,
                ),
                const SizedBox(width: 8),
                _buildLegendDot(
                  color: const Color(0xFFD97706),
                  label: isUrdu ? 'منافع' : 'Profit',
                  fontFamily: fontFamily,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: yearly.months.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                final isActive = idx == currentMonthIndex;

                final salesH = maxValue > 0
                    ? (m.salesRevenue / maxValue) * 120
                    : 0.0;
                final purchaseH = maxValue > 0
                    ? (m.purchaseValue / maxValue) * 120
                    : 0.0;
                final profitH = maxValue > 0
                    ? (m.grossProfit.abs() / maxValue) * 120
                    : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Sales bar
                            Flexible(
                              child: Container(
                                width: 4.5,
                                height: salesH == 0 ? 2 : salesH,
                                decoration: BoxDecoration(
                                  color: AppTheme.incomeColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 0.5),
                            // Purchase bar
                            Flexible(
                              child: Container(
                                width: 4.5,
                                height: purchaseH == 0 ? 2 : purchaseH,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.themeColor
                                      : AppTheme.themeColor
                                      .withValues(alpha: 0.75),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 0.5),
                            // Profit bar
                            Flexible(
                              child: Container(
                                width: 4.5,
                                height: profitH == 0 ? 2 : profitH,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        UrduAwareText(
                          isUrdu
                              ? _getUrduMonthName(idx + 1)
                              : _getMonthName(idx + 1),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isActive
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: isActive
                                ? AppTheme.themeColor
                                : AppTheme.textSecondary,
                            fontFamily: isUrdu ? fontFamily : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // ⭐ ماہانہ چارٹ — روزانہ (30-31 دن)
  // ═════════════════════════════════════════════════════════════
  Widget _buildDailyChart(
      List<StockItem> items,
      List<dynamic> stockMovements,
      int year,
      int month,
      bool isUrdu,
      String? fontFamily,
      ) {
    final daily = _buildDailyStats(items, stockMovements, year, month);

    double maxValue = 1;
    for (final d in daily) {
      if (d.sales > maxValue) maxValue = d.sales;
      if (d.purchase > maxValue) maxValue = d.purchase;
      if (d.profit.abs() > maxValue) maxValue = d.profit.abs();
    }

    final today = DateTime.now();
    final isCurrentMonth = (year == today.year && month == today.month);
    final todayDay = isCurrentMonth ? today.day : -1;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.chartBar(),
                  size: 15,
                  color: AppTheme.themeColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: UrduAwareText(
                    isUrdu
                        ? '${_getUrduMonthName(month)} $year — روزانہ خرید، فروخت اور منافع'
                        : '${_getFullMonthName(month)} $year — Daily Sales, Purchases & Profit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildLegendDot(
                  color: AppTheme.incomeColor,
                  label: isUrdu ? 'فروخت' : 'Sales',
                  fontFamily: fontFamily,
                ),
                const SizedBox(width: 8),
                _buildLegendDot(
                  color: AppTheme.themeColor,
                  label: isUrdu ? 'خرید' : 'Purchase',
                  fontFamily: fontFamily,
                ),
                const SizedBox(width: 8),
                _buildLegendDot(
                  color: const Color(0xFFD97706),
                  label: isUrdu ? 'منافع' : 'Profit',
                  fontFamily: fontFamily,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: daily.asMap().entries.map((entry) {
                final d = entry.value;
                final isToday = d.day == todayDay;

                final salesH = maxValue > 0
                    ? (d.sales / maxValue) * 100
                    : 0.0;
                final purchaseH = maxValue > 0
                    ? (d.purchase / maxValue) * 100
                    : 0.0;
                final profitH = maxValue > 0
                    ? (d.profit.abs() / maxValue) * 100
                    : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Sales bar
                            Flexible(
                              child: Container(
                                width: 2.2,
                                height: salesH == 0 ? 1 : salesH,
                                decoration: BoxDecoration(
                                  color: AppTheme.incomeColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 0.3),
                            // Purchase bar
                            Flexible(
                              child: Container(
                                width: 2.2,
                                height: purchaseH == 0 ? 1 : purchaseH,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppTheme.themeColor
                                      : AppTheme.themeColor
                                      .withValues(alpha: 0.75),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 0.3),
                            // Profit bar
                            Flexible(
                              child: Container(
                                width: 2.2,
                                height: profitH == 0 ? 1 : profitH,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (d.day == 1 ||
                            d.day % 5 == 0 ||
                            d.day == daily.length)
                          UrduAwareText(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: isToday
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: isToday
                                  ? AppTheme.themeColor
                                  : AppTheme.textSecondary,
                              fontFamily: null,
                            ),
                            maxLines: 1,
                          )
                        else
                          const SizedBox(height: 11),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot({
    required Color color,
    required String label,
    String? fontFamily,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  String _formatQuantity(double quantity) {
    if (!quantity.isFinite) return '—';
    return quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
  }

  // ═════════════════════════════════════════════════════════════
  // Item Breakdown
  // ═════════════════════════════════════════════════════════════
  Widget _buildItemBreakdown(
      List<StockItemStats> items,
      bool isUrdu,
      String? fontFamily,
      ) {
    if (items.isEmpty) {
      return Container(
        margin: EdgeInsets.zero,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        ),
        child: UrduAwareText(
          isUrdu
              ? 'اس مدت میں اسٹاک کی خرید یا فروخت درج نہیں ہوئی۔'
              : 'No stock purchases or sales were recorded for this period.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.zero,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Color(0xFFEEF1F5)),
            _buildItemStatsRow(items[index], isUrdu, fontFamily),
          ],
        ],
      ),
    );
  }

  Widget _buildItemStatsRow(
      StockItemStats item,
      bool isUrdu,
      String? fontFamily,
      ) {
    final hasUncostedSales = item.uncostedSalesQuantity > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: UrduAwareText(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              UrduAwareText(
                '${isUrdu ? 'منافع' : 'Profit'}: ${_formatCompact(item.grossProfit)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: item.grossProfit >= 0
                      ? AppTheme.incomeColor
                      : AppTheme.expenseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          UrduAwareText(
            isUrdu
                ? 'خرید ${_formatQuantity(item.purchaseQuantity)} ${item.unit} · فروخت ${_formatQuantity(item.salesQuantity)} ${item.unit} · باقی ${_formatQuantity(item.endingStockQuantity)} ${item.unit}'
                : 'Bought ${_formatQuantity(item.purchaseQuantity)} ${item.unit} · Sold ${_formatQuantity(item.salesQuantity)} ${item.unit} · In stock ${_formatQuantity(item.endingStockQuantity)} ${item.unit}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
            ),
          ),
          if (hasUncostedSales) ...[
            const SizedBox(height: 4),
            UrduAwareText(
              isUrdu
                  ? 'ان فروخت شدہ یونٹس کی خرید لاگت درج نہیں؛ منافع نامکمل ہو سکتا ہے۔'
                  : 'Purchase cost is missing for some sold units; profit may be incomplete.',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.expenseColor,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Party Breakdown
  // ═════════════════════════════════════════════════════════════
  Widget _buildPartyBreakdown(
      List<StockPartyStats> parties,
      bool isUrdu,
      String? fontFamily,
      ) {
    if (parties.isEmpty) {
      return Container(
        margin: EdgeInsets.zero,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        ),
        child: UrduAwareText(
          isUrdu
              ? 'اس مدت میں پارٹی کے ساتھ کوئی اسٹاک خرید یا فروخت درج نہیں۔'
              : 'No party-linked stock purchases or sales were recorded for this period.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
      );
    }

    final customers = parties.where((party) => party.isSale).toList();
    final suppliers = parties.where((party) => !party.isSale).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (customers.isNotEmpty) ...[
          for (var i = 0; i < customers.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildPartyCard(customers[i], isUrdu, fontFamily),
          ],
        ],
        if (suppliers.isNotEmpty) ...[
          if (customers.isNotEmpty) const SizedBox(height: 8),
          _buildPartyGroupTitle(
            isUrdu ? 'سپلائرز سے خریداری' : 'Purchases from Suppliers',
            fontFamily,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < suppliers.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildPartyCard(suppliers[i], isUrdu, fontFamily),
          ],
        ],
      ],
    );
  }

  Widget _buildPartyGroupTitle(
      String title,
      String? fontFamily,
      ) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, top: 4),
      child: UrduAwareText(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.textSecondary,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildPartyCard(
      StockPartyStats party,
      bool isUrdu,
      String? fontFamily,
      ) {
    final amountColor =
    party.totalValue < 0 ? AppTheme.expenseColor : AppTheme.darkColor;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: UrduAwareText(
                  party.partyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              UrduAwareText(
                _formatCompact(party.totalValue),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: amountColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (var index = 0; index < party.items.length; index++) ...[
            if (index > 0) const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: UrduAwareText(
                    '${isUrdu && party.items[index].itemNameUrdu.isNotEmpty ? party.items[index].itemNameUrdu : party.items[index].itemName} · ${isUrdu ? 'خالص' : 'Net'} ${_formatQuantity(party.items[index].quantity)} ${party.items[index].unit}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                UrduAwareText(
                  _formatCompact(party.items[index].value),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: party.items[index].value < 0
                        ? AppTheme.expenseColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostWarning(bool isUrdu, String? fontFamily) {
    return Container(
      margin: EdgeInsets.zero,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.expenseColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.expenseColor.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: UrduAwareText(
        isUrdu
            ? 'کچھ فروخت شدہ مال کی خرید لاگت موجود نہیں؛ مجموعی منافع نامکمل یا زیادہ دکھ سکتا ہے۔'
            : 'Purchase cost is missing for some sold stock; gross profit may be incomplete or overstated.',
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.expenseColor,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Monthly Summary
  // ═════════════════════════════════════════════════════════════
  Widget _buildMonthlySummary(
      StockMonthlyStats monthStats,
      int itemCount,
      bool isUrdu,
      String? fontFamily,
      ) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        children: [
          _buildYearlyRow(
            icon: PhosphorIcons.arrowUpRight(),
            iconColor: AppTheme.incomeColor,
            iconBg: AppTheme.incomeColor.withValues(alpha: 0.10),
            name: isUrdu
                ? '${_getUrduMonthName(_selectedMonth)} کی کل فروخت'
                : 'Total Sales ${_getFullMonthName(_selectedMonth)}',
            meta: isUrdu ? 'اس مہینے کی خالص فروخت' : 'Net sales this month',
            value: _formatCompact(monthStats.salesRevenue),
            valueColor: AppTheme.incomeColor,
            fontFamily: fontFamily,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.arrowDownLeft(),
            iconColor: AppTheme.themeColor,
            iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
            name: isUrdu ? 'کل خریداری کی لاگت' : 'Total Purchase Cost',
            meta: isUrdu ? 'اس مہینے کی خریداری' : 'Purchases this month',
            value: _formatCompact(monthStats.purchaseValue),
            valueColor: AppTheme.themeColor,
            fontFamily: fontFamily,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.money(),
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFD97706).withValues(alpha: 0.10),
            name: isUrdu ? 'مجموعی اسٹاک منافع' : 'Gross Stock Profit',
            meta:
            '${monthStats.profitMargin.toStringAsFixed(1)}% ${isUrdu ? "مارجن" : "margin"}',
            value: _formatCompact(monthStats.grossProfit),
            valueColor: monthStats.grossProfit >= 0
                ? AppTheme.incomeColor
                : AppTheme.expenseColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.receipt(),
            iconColor: AppTheme.themeColor,
            iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
            name: isUrdu ? 'خریداری کے بل' : 'Purchase Bills',
            meta: isUrdu ? 'اس مہینے کے اندراج' : 'Entries this month',
            value: '${monthStats.purchaseCount}',
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.receipt(),
            iconColor: AppTheme.expenseColor,
            iconBg: AppTheme.expenseColor.withValues(alpha: 0.10),
            name: isUrdu ? 'فروخت کے بل' : 'Sales Bills',
            meta: isUrdu ? 'اس مہینے کے اندراج' : 'Entries this month',
            value: '${monthStats.salesCount}',
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.package(),
            iconColor: AppTheme.themeColor,
            iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
            name: isUrdu ? 'خرید و فروخت والے آئٹمز' : 'Items Moved',
            meta: isUrdu ? 'منفرد آئٹمز کی تعداد' : 'Unique items moved',
            value: '$itemCount',
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Yearly Summary
  // ═════════════════════════════════════════════════════════════
  Widget _buildYearlySummary(
      StockYearlyStats yearly,
      int itemCount,
      bool isUrdu,
      String? fontFamily,
      ) {
    final monthsWithData =
        yearly.months.where((m) => m.salesRevenue > 0).length;
    final now = DateTime.now();
    final monthsElapsed = yearly.year < now.year ? 12 : now.month;
    final avgMonthly = yearly.averageMonthlySales(throughMonth: monthsElapsed);

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        children: [
          _buildYearlyRow(
            icon: PhosphorIcons.arrowUpRight(),
            iconColor: AppTheme.incomeColor,
            iconBg: AppTheme.incomeColor.withValues(alpha: 0.10),
            name: isUrdu
                ? 'کل فروخت ${yearly.year}'
                : 'Total Sales ${yearly.year}',
            meta: isUrdu
                ? '$monthsWithData ماہ جن میں فروخت ہوئی'
                : '$monthsWithData months with sales',
            value: _formatCompact(yearly.salesRevenue),
            valueColor: AppTheme.incomeColor,
            fontFamily: fontFamily,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.arrowDownLeft(),
            iconColor: AppTheme.themeColor,
            iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
            name: isUrdu ? 'کل خریداری کی لاگت' : 'Total Purchase Cost',
            meta: isUrdu ? 'اسٹاک خریداری موومنٹس' : 'Stock purchase movements',
            value: _formatCompact(yearly.purchaseValue),
            valueColor: AppTheme.themeColor,
            fontFamily: fontFamily,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.money(),
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFD97706).withValues(alpha: 0.10),
            name: isUrdu ? 'مجموعی اسٹاک منافع' : 'Gross Stock Profit',
            meta:
            '${yearly.profitMargin.toStringAsFixed(1)}% ${isUrdu ? "مارجن" : "margin"}',
            value: _formatCompact(yearly.grossProfit),
            valueColor: yearly.grossProfit >= 0
                ? AppTheme.incomeColor
                : AppTheme.expenseColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.receipt(),
            iconColor: AppTheme.themeColor,
            iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
            name: isUrdu ? 'خریداری کے بل' : 'Purchase Bills',
            meta: isUrdu
                ? 'منفرد خریداری اندراج'
                : 'Unique purchase transactions',
            value: '${yearly.purchaseCount}',
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.receipt(),
            iconColor: AppTheme.expenseColor,
            iconBg: AppTheme.expenseColor.withValues(alpha: 0.10),
            name: isUrdu ? 'فروخت کے بل' : 'Sales Bills',
            meta: isUrdu ? 'منفرد فروخت اندراج' : 'Unique sales transactions',
            value: '${yearly.salesCount}',
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.package(),
            iconColor: AppTheme.themeColor,
            iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
            name: isUrdu ? 'خرید و فروخت والے آئٹمز' : 'Items Moved',
            meta: isUrdu ? 'منفرد آئٹمز کی تعداد' : 'Unique items moved',
            value: '$itemCount',
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          _buildYearlyRow(
            icon: PhosphorIcons.calendar(),
            iconColor: const Color(0xFF607D8B),
            iconBg: const Color(0xFF607D8B).withValues(alpha: 0.10),
            name: isUrdu ? 'ماہانہ اوسط فروخت' : 'Average Monthly Sales',
            meta: isUrdu
                ? 'جنوری تا ${_getFullMonthName(monthsElapsed)} · $monthsElapsed ماہ'
                : 'Jan–${_getFullMonthName(monthsElapsed).substring(0, 3)} · $monthsElapsed months',
            value: _formatCompact(avgMonthly),
            valueColor: AppTheme.darkColor,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String name,
    required String meta,
    required String value,
    required Color valueColor,
    String? fontFamily,
    bool isUrdu = false,
  }) {
    final nameParts = name.split(' ');
    final nameSpans = <InlineSpan>[];
    for (int i = 0; i < nameParts.length; i++) {
      final p = nameParts[i];
      final isNum = int.tryParse(p) != null || double.tryParse(p) != null;
      nameSpans.add(
        TextSpan(
          text: '${i == 0 ? '' : ' '}$p',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkColor,
            fontFamily: isNum ? null : fontFamily,
            letterSpacing: -0.2,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText.rich(TextSpan(children: nameSpans)),
                const SizedBox(height: 2),
                UrduAwareText(
                  meta,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    fontFamily: null,
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
              fontFamily: null,
              fontFeatures: const [FontFeature.tabularFigures()],
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
    required bool isUrdu,
    String? fontFamily,
  }) {
    final parts = title.split(' ');
    final textParts = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final p = parts[i];
      final isNum = double.tryParse(p) != null || int.tryParse(p) != null;
      textParts.add(
        TextSpan(
          text: '${i == 0 ? '' : ' '}$p',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
            fontFamily: isNum ? null : fontFamily,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 13,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: UrduAwareText.rich(
              TextSpan(children: textParts),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

