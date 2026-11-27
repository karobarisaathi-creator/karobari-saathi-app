import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/worker_service.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/utils/party_summary_utils.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/stock_card.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/features/settings/master_profile_screen.dart';
import 'package:account_app/features/shopkeeper/inventory_health_screen.dart';
import 'package:account_app/features/shopkeeper/customer_bills_screen.dart';
import 'package:account_app/features/shopkeeper/add_edit_stock_item_screen.dart';
import 'package:account_app/features/shopkeeper/sales_analytics_screen.dart';
import 'package:account_app/features/shopkeeper/stock_detail_screen.dart';
import 'package:account_app/features/contracts/contracts_list_screen.dart';
import 'package:account_app/features/contracts/workers_list_screen.dart';
import 'package:account_app/features/contracts/bulk_attendance_screen.dart';
import 'package:account_app/features/accounts/party_list_screen.dart';
import 'package:account_app/features/accounts/reports_screen.dart';
import 'widgets/home_activity_feed.dart';
import 'widgets/shopkeeper_tools_grid.dart';

// ═══════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final bool isEmbedded;

  const HomeScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _shopName = '';
  String _userName = '';
  String _profession = '';
  String _about = '';
  String _address = '';
  String? _profileImageUrl;
  bool _isMenuExpanded = false;
  int _financialSummaryIndex = 0;
  Timer? _financialSummaryTimer;

  int get _todayQuickBillsCount {
    try {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return databaseService
          .getAllTransactions()
          .where((t) =>
              t.isQuickBill &&
              DateFormat('yyyy-MM-dd').format(t.date) == todayKey)
          .length;
    } catch (_) {
      return 0;
    }
  }

  double get _todayQuickBillsAmount {
    try {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return databaseService
          .getAllTransactions()
          .where((t) =>
              t.isQuickBill &&
              DateFormat('yyyy-MM-dd').format(t.date) == todayKey)
          .fold(0.0, (sum, t) => sum + t.amount.abs());
    } catch (_) {
      return 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _financialSummaryTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) {
          setState(
              () => _financialSummaryIndex = (_financialSummaryIndex + 1) % 4);
        }
      },
    );
    _loadProfileInfo();
  }

  @override
  void dispose() {
    _financialSummaryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? '';
        _profileImageUrl = user.photoURL;
      });
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _shopName = (data?['shopName'] ?? '').toString();
            _userName =
                (data?['displayName'] ?? user.displayName ?? '').toString();
            _profession = (data?['profession'] ?? '').toString();
            _about = (data?['about'] ?? '').toString();
            _address = (data?['businessAddress'] ?? '').toString();
            _profileImageUrl = (data?['profileImage'] ??
                    data?['photoURL'] ??
                    user.photoURL ??
                    '')
                .toString();
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    final stockService = Provider.of<StockService>(context);
    final databaseService = Provider.of<DatabaseService>(context);
    final contractService = Provider.of<ContractService>(context);
    final summary = stockService.getStockSummary();

    final totalPurchaseValue = summary['totalPurchaseValue'] as double? ?? 0.0;
    final totalSalesValue =
        summary['totalSalesPotentialValue'] as double? ?? 0.0;
    final totalItems = summary['totalItems'] as int? ?? 0;
    final lowStockCount = summary['lowStockCount'] as int? ?? 0;
    final inventoryHealthScore = stockService.isLoading
        ? null
        : _calculateInventoryHealthScore(stockService);
    final contracts = contractService.contracts;
    final allTransactions = databaseService.getAllTransactions();
    final activeSeasonIds = databaseService
        .getMasterProfessions()
        .where((profession) => profession.isActive ?? true)
        .expand((profession) => databaseService.getSeasons(profession.id))
        .where((season) => season.isActive ?? true)
        .map((season) => season.id)
        .toSet();
    final professionTransactions = allTransactions.where(
      (transaction) => activeSeasonIds.contains(transaction.professionId),
    );
    final professionIncome = professionTransactions
        .where((transaction) => transaction.type == 'income')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final professionExpense = professionTransactions
        .where((transaction) => transaction.type == 'expense')
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final totalContractAmount = contracts.fold<double>(
        0, (total, contract) => total + contract.totalAmount);
    final contractDueAmount = contracts.fold<double>(
      0,
      (total, contract) => total + contract.remainingBalance,
    );
    final installmentAmount = contracts.fold<double>(
      0,
      (total, contract) => total + contract.totalPaid,
    );
    final partySummary = PartySummaryUtils.calculateSummary(
      accounts: databaseService.accounts,
      transactions: allTransactions,
    );

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            _buildHeader(
              context,
              isUrdu,
              fontFamily,
              fontWeight,
              totalPurchaseValue,
              totalSalesValue,
              lowStockCount,
              professionIncome,
              professionExpense,
              totalContractAmount,
              contractDueAmount,
              installmentAmount,
              partySummary.partyCount,
              partySummary.totalReceivable,
              partySummary.totalPayable,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuickActions(
                      context,
                      isUrdu,
                      fontFamily,
                      totalItems,
                      inventoryHealthScore,
                      stockService.isLoading,
                    ),
                    const SizedBox(height: 8),
                    const HomeActivityFeed(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _calculateInventoryHealthScore(StockService stockService) {
    final items = stockService.items
        .where((item) => !item.isArchived && item.trackStock)
        .toList();
    if (items.isEmpty) return null;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentSaleItemIds = stockService.movements
        .where((movement) =>
            movement.type == StockMovementType.sale &&
            !movement.timestamp.isBefore(thirtyDaysAgo) &&
            !movement.timestamp.isAfter(now))
        .map((movement) => movement.stockItemId)
        .toSet();
    final unhealthyItemIds = <String>{};

    for (final item in items) {
      final currentStock = stockService.calculateCurrentStock(item.id);
      if (!currentStock.isFinite) {
        unhealthyItemIds.add(item.id);
        continue;
      }

      if (currentStock <= 0 ||
          (item.minStockAlert.isFinite &&
              item.minStockAlert > 0 &&
              currentStock <= item.minStockAlert) ||
          (now.difference(item.createdAt).inDays >= 30 &&
              currentStock > 0 &&
              !recentSaleItemIds.contains(item.id))) {
        unhealthyItemIds.add(item.id);
      }
    }

    return (((items.length - unhealthyItemIds.length) / items.length) * 100)
        .round()
        .clamp(0, 100);
  }

  Color _inventoryHealthColor(int? score) {
    if (score == null) return AppTheme.themeColor;
    if (score >= 75) return AppTheme.greenColor;
    if (score >= 50) return AppTheme.verifiedGold;
    return AppTheme.expenseColor;
  }

  // ═══ HEADER (Gradient background with Shop Name & Karobari Saathi Label) ═══
  Widget _buildHeader(
    BuildContext context,
    bool isUrdu,
    String fontFamily,
    FontWeight fontWeight,
    double purchaseVal,
    double salesVal,
    int lowStockCount,
    double professionIncome,
    double professionExpense,
    double totalContractAmount,
    double contractDueAmount,
    double installmentAmount,
    int partyCount,
    double totalReceivable,
    double totalPayable,
  ) {
    final profileName =
        _userName.isNotEmpty ? _userName : (isUrdu ? 'صارف' : 'User');
    final locationText = _address.isNotEmpty
        ? _address
        : (isUrdu ? 'لاہور، پاکستان' : 'Pakistan');
    final summaryStats = <Widget>[];

    void addSummaryStat(String value, String label, Color color) {
      summaryStats.add(_statMini(value, label, color, fontFamily, isUrdu));
    }

    if (_financialSummaryIndex == 0) {
      addSummaryStat('$partyCount', isUrdu ? 'پارٹیاں' : 'Parties',
          const Color(0xFFA3E635));
      addSummaryStat(
        Formatters.formatAmountWithCurrency(totalReceivable),
        isUrdu ? 'لینے ہیں' : 'To Receive',
        const Color(0xFF93C5FD),
      );
      addSummaryStat(
        Formatters.formatAmountWithCurrency(totalPayable),
        isUrdu ? 'دینے ہیں' : 'To Pay',
        const Color(0xFFFCA5A5),
      );
    } else if (_financialSummaryIndex == 1) {
      addSummaryStat(
        Formatters.formatAmountWithCurrency(professionIncome),
        isUrdu ? 'پیشے کی آمدن' : 'Profession Income',
        const Color(0xFFA3E635),
      );
      addSummaryStat(
        Formatters.formatAmountWithCurrency(professionExpense),
        isUrdu ? 'پیشے کے اخراجات' : 'Profession Expenses',
        const Color(0xFFFCA5A5),
      );
      addSummaryStat(
        Formatters.formatAmountWithCurrency(
            professionIncome - professionExpense),
        isUrdu ? 'پیشے کا منافع' : 'Profession Profit',
        const Color(0xFF93C5FD),
      );
    } else if (_financialSummaryIndex == 2) {
      addSummaryStat(
        Formatters.formatAmountWithCurrency(totalContractAmount),
        isUrdu ? 'کل ٹھیکہ رقم' : 'Total Contract',
        const Color(0xFFA3E635),
      );
      addSummaryStat(
        Formatters.formatAmountWithCurrency(contractDueAmount),
        isUrdu ? 'ٹھیکہ بقایا' : 'Contract Due',
        const Color(0xFFFCA5A5),
      );
      addSummaryStat(
        Formatters.formatAmountWithCurrency(installmentAmount),
        isUrdu ? 'قسطوں کی رقم' : 'Installments',
        const Color(0xFF93C5FD),
      );
    } else {
      addSummaryStat(
        Formatters.formatAmountWithCurrency(purchaseVal),
        isUrdu ? 'خرید مالیت' : 'Purchase Val',
        const Color(0xFFA3E635),
      );
      addSummaryStat(
        Formatters.formatAmountWithCurrency(salesVal),
        isUrdu ? 'فروخت مالیت' : 'Sales Val',
        const Color(0xFF93C5FD),
      );
      addSummaryStat('$lowStockCount', isUrdu ? 'کم اسٹاک' : 'Low Stock',
          const Color(0xFFFBBF24));
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.slateColor,
            AppTheme.verifiedGold,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 16),
      child: Column(
        children: [
          // Top Title Bar (Shop Name / Karobari Saathi Label + Business Tools Button)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Shop Name / Karobari Saathi Title
                Expanded(
                  child: UrduAwareText(
                    _shopName.isNotEmpty
                        ? _shopName
                        : (isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Business Tools Action Icon
                IconButton(
                  icon: Icon(
                    _isMenuExpanded
                        ? Icons.close_rounded
                        : PhosphorIcons.slidersHorizontal(),
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: isUrdu ? 'کاروباری ٹولز' : 'Business Tools',
                  onPressed: () =>
                      setState(() => _isMenuExpanded = !_isMenuExpanded),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.5),
              child: Stack(
                children: [
                  // Banner White Background
                  Positioned.fill(
                    child: _buildHeaderBannerFallback(),
                  ),

                  // Profile Card Info using ProfileInfoWidget
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ProfileInfoWidget(
                      name: profileName,
                      phone: '',
                      category: _profession.trim().isEmpty
                          ? null
                          : _profession.trim(),
                      isCategoryInline: true,
                      categoryColor: Colors.white,
                      address: locationText,
                      isVerticalCategory: false,
                      bottom: _about.trim().isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: UrduAwareText(
                                _about.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ),
                      profileImage: _profileImageUrl,
                      isLarge: true,
                      customSize: 48,
                      borderRadius: 14,
                      textColor: Colors.white,
                      subtitleColor: Colors.white70,
                      onAvatarTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MasterProfileScreen(),
                          ),
                        ).then((_) => _loadProfileInfo());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isMenuExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: ShopkeeperToolsGrid(
              isUrdu: isUrdu,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Row(
              key: ValueKey(_financialSummaryIndex),
              children: [
                for (var index = 0; index < summaryStats.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(child: summaryStats[index]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBannerFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _statMini(
    String value,
    String label,
    Color dotColor,
    String fontFamily,
    bool isUrdu,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: UrduAwareText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                UrduAwareText(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══ SECTION HEAD ═══
  Widget _buildSectionHead({
    required bool isUrdu,
    required String fontFamily,
    required String title,
    required IconData icon,
    bool showAction = false,
    VoidCallback? onActionTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.themeColor),
            const SizedBox(width: 8),
            UrduAwareText(
              title,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
              ),
            ),
          ],
        ),
        if (showAction)
          GestureDetector(
            onTap: onActionTap,
            child: Row(
              children: [
                UrduAwareText(
                  isUrdu ? 'سب دیکھیں' : 'View All',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.themeColor,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left_rounded,
                    size: 14, color: AppTheme.themeColor),
              ],
            ),
          ),
      ],
    );
  }

  // ═══ QUICK ACTIONS ═══
  Widget _buildQuickActions(
    BuildContext context,
    bool isUrdu,
    String fontFamily,
    int totalItems,
    int? inventoryHealthScore,
    bool isInventoryLoading,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══ MAIN GROUP CARD 1: CONTRACTS & PROJECTS ═══
        _buildGroupCard(
          header: _buildSectionHead(
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            title: isUrdu ? 'ٹھیکے اور پراجیکٹس' : 'Contracts & Projects',
            icon: PhosphorIcons.fileText(),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Consumer<WorkerService>(
                    builder: (context, workerService, _) {
                      final workerCount = workerService.workers.length;
                      return _quickActionCard(
                        isUrdu: isUrdu,
                        fontFamily: fontFamily,
                        title: isUrdu ? 'مزدوروں کی لسٹ' : 'Workers List',
                        sub: isUrdu
                            ? 'تمام مزدوروں اور کاریگروں کا ریکارڈ'
                            : 'All workers & technicians record',
                        icon: PhosphorIcons.users(),
                        color: AppTheme.themeColor,
                        badge: workerCount > 0
                            ? '$workerCount ${isUrdu ? 'مزدور' : 'Workers'}'
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkersListScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickActionCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    title: isUrdu ? 'متعدد حاضری' : 'Bulk Attendance',
                    sub: isUrdu
                        ? 'ایک ساتھ تمام مزدوروں کی حاضری'
                        : 'Mark attendance for all workers',
                    icon: PhosphorIcons.calendarCheck(),
                    color: AppTheme.themeColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BulkAttendanceScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ═══ MAIN GROUP CARD 2: SHOP ═══
        _buildGroupCard(
          header: _buildSectionHead(
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            title: isUrdu ? 'شاپ' : 'Shop',
            icon: PhosphorIcons.storefront(),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: _quickActionCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    title: isUrdu ? 'نیا آئٹم' : 'New Item',
                    sub: isUrdu
                        ? 'نیا پروڈکٹ شامل کریں'
                        : 'Add new stock product',
                    icon: Icons.add_circle_outline_rounded,
                    color: AppTheme.themeColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditStockItemScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickActionCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    title: isUrdu ? 'اسٹاک اشیاء' : 'Stock Items',
                    sub: isUrdu
                        ? 'تمام اسٹاک پراڈکٹس کی لسٹ'
                        : 'All inventory stock items',
                    icon: Icons.inventory_2_rounded,
                    color: AppTheme.themeColor,
                    badge: totalItems > 0 ? '$totalItems' : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StockListScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _quickActionCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    title: isUrdu ? 'انوینٹری صحت' : 'Inventory Health',
                    sub: isUrdu
                        ? 'کم اسٹاک، رفتار اور اشاریے'
                        : 'Low stock, velocity & metrics',
                    icon: Icons.monitor_heart_rounded,
                    color: _inventoryHealthColor(inventoryHealthScore),
                    badge: isInventoryLoading
                        ? '…'
                        : inventoryHealthScore == null
                            ? '—'
                            : '$inventoryHealthScore%',
                    badgeColor: _inventoryHealthColor(inventoryHealthScore),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InventoryHealthScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickActionCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    title: isUrdu ? 'سیل ریکارڈ' : 'Sales Record',
                    sub: isUrdu
                        ? 'فوری بل سے کی گئی نقد اور ادھار سیل'
                        : 'Quick bill cash & credit sales',
                    icon: Icons.receipt_long_rounded,
                    color: AppTheme.verifiedGold,
                    badge:
                        '$_todayQuickBillsCount | ${Formatters.formatCompact(_todayQuickBillsAmount)}',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerBillsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupCard({
    required Widget header,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required bool isUrdu,
    required String fontFamily,
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    String? badge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: UrduAwareText(
                      badge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor ?? color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            UrduAwareText(
              title,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            UrduAwareText(
              sub,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ═══ ALERT CARD ═══
  Widget _buildAlertCard(
    BuildContext context,
    bool isUrdu,
    String fontFamily,
    int lowStockCount,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryHealthScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.verifiedGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.verifiedGold.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.verifiedGold,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.verifiedGold.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    isUrdu ? '⚠️ کم اسٹاک الرٹ' : '⚠️ Low Stock Alert',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  UrduAwareText(
                    isUrdu
                        ? '$lowStockCount اشیاء اسٹاک سے کم ہیں'
                        : '$lowStockCount items below minimum stock',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
                color: Color(0xFFB45309), size: 24),
          ],
        ),
      ),
    );
  }

  // ═══ ACTIVITY LIST ═══
  Widget _buildActivityList(
    StockService stockService,
    bool isUrdu,
    String fontFamily,
  ) {
    final movements = stockService.movements.take(4).toList();

    if (movements.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E5EC), width: 1.5),
        ),
        child: Center(
          child: UrduAwareText(
            isUrdu
                ? 'کوئی حالیہ ہسٹری موجود نہیں'
                : 'No recent stock movements',
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: fontFamily,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E5EC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: List.generate(movements.length, (index) {
          final m = movements[index];
          final isLast = index == movements.length - 1;

          String typeLabel = isUrdu ? 'اسٹاک ہسٹری' : 'Stock Log';
          String amountType = 'income';
          IconData icon = Icons.swap_vert_rounded;

          if (m.type == StockMovementType.purchase ||
              m.type == StockMovementType.customerReturn) {
            typeLabel = isUrdu ? 'اسٹاک آمد (+)' : 'Stock In (+)';
            amountType = 'income';
            icon = Icons.arrow_downward_rounded;
          } else if (m.type == StockMovementType.sale ||
              m.type == StockMovementType.supplierReturn) {
            typeLabel = isUrdu ? 'اسٹاک اخراج (-)' : 'Stock Out (-)';
            amountType = 'expense';
            icon = Icons.arrow_outward_rounded;
          }

          return _activityItem(
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            name: m.stockItemName,
            quantity: m.quantity.toStringAsFixed(0),
            tag: typeLabel,
            tagType: amountType == 'income' ? 'bill' : 'order',
            amount: 'Rs. ${Formatters.formatAmountWithCurrency(m.unitPrice)}',
            amountType: amountType,
            icon: icon,
            isLast: isLast,
          );
        }),
      ),
    );
  }

  Widget _activityItem({
    required bool isUrdu,
    required String fontFamily,
    required String name,
    required String quantity,
    required String tag,
    required String tagType,
    required String amount,
    required String amountType,
    required IconData icon,
    required bool isLast,
  }) {
    Color iconBg;
    Color iconFg;
    Color amountColor;
    Color? tagBg;
    Color? tagFg;

    switch (amountType) {
      case 'income':
        iconBg = AppTheme.incomeColor.withValues(alpha: 0.12);
        iconFg = AppTheme.incomeColor;
        amountColor = AppTheme.incomeColor;
        break;
      case 'expense':
        iconBg = AppTheme.expenseColor.withValues(alpha: 0.12);
        iconFg = AppTheme.expenseColor;
        amountColor = AppTheme.expenseColor;
        break;
      default:
        iconBg = AppTheme.verifiedGold.withValues(alpha: 0.12);
        iconFg = AppTheme.verifiedGold;
        amountColor = AppTheme.verifiedGold;
    }

    if (tagType == 'bill') {
      tagBg = AppTheme.themeColor.withValues(alpha: 0.12);
      tagFg = AppTheme.themeColor;
    } else if (tagType == 'order') {
      tagBg = AppTheme.verifiedGold.withValues(alpha: 0.12);
      tagFg = AppTheme.verifiedGold;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFEEF1F5)),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconFg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  name,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    UrduAwareText.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: quantity,
                            style: const TextStyle(fontFamily: null),
                          ),
                          TextSpan(
                            text: ' اشیاء',
                            style: TextStyle(fontFamily: fontFamily),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB0B8C1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (tagBg != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: UrduAwareText(
                          tag,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: tagFg!,
                          ),
                        ),
                      )
                    else
                      UrduAwareText(
                        tag,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          UrduAwareText(
            amount,
            style: TextStyle(
              fontFamily: null,
              fontSize: amountType == 'order' ? 12 : 13.5,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// STOCK LIST SCREEN
// ═══════════════════════════════════════════
class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  String _searchQuery = '';
  bool _isAscending = true;
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ScreenAppBar(
        title: isUrdu ? 'اسٹاک اشیاء' : 'Stock Items',
        isUrdu: isUrdu,
        actions: [
          IconButton(
            tooltip: _showSearch
                ? (isUrdu ? 'تلاش بند کریں' : 'Close search')
                : (isUrdu ? 'تلاش کریں' : 'Search'),
            icon: Icon(
              _showSearch ? PhosphorIcons.x() : PhosphorIcons.magnifyingGlass(),
            ),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchQuery = '';
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar (Conditional)
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SearchSortBar(
                hintText: isUrdu ? 'آئٹم تلاش کریں...' : 'Search stock item...',
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                onSortToggled: () =>
                    setState(() => _isAscending = !_isAscending),
                isAscending: _isAscending,
              ),
            ),

          // 📄 Items List
          Expanded(
            child: _buildItemList(stockService, isUrdu, fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(
    StockService stockService,
    bool isUrdu,
    String fontFamily,
  ) {
    var items = stockService.items
        .where((item) => !item.isArchived)
        .toList(growable: true);

    if (_searchQuery.isNotEmpty) {
      items = items.where((i) {
        final nameMatches =
            i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                i.nameUrdu.contains(_searchQuery);
        final codeMatches = i.barcode.contains(_searchQuery) ||
            i.sku.toLowerCase().contains(_searchQuery.toLowerCase());
        return nameMatches || codeMatches;
      }).toList();
    }

    items.sort((a, b) => _isAscending
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.name.toLowerCase().compareTo(a.name.toLowerCase()));

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.package(), size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              UrduAwareText(
                isUrdu ? 'کوئی آئٹم نہیں ملی' : 'No stock items found',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return StockCard(
          item: item,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockDetailScreen(item: item),
              ),
            );
          },
        );
      },
    );
  }
}
