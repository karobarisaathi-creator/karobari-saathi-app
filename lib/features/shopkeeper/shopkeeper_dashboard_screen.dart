import 'package:account_app/features/shopkeeper/stock_history_screen.dart';
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
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/stock_card.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/features/settings/master_profile_screen.dart';
import 'package:account_app/features/shopkeeper/low_stock_items_screen.dart';
import 'package:account_app/features/shopkeeper/customer_bills_screen.dart';
import 'package:account_app/features/shopkeeper/add_edit_stock_item_screen.dart';
import 'package:account_app/features/shopkeeper/sales_analytics_screen.dart';
import 'package:account_app/features/shopkeeper/stock_detail_screen.dart';
import 'package:account_app/features/order/nearby_shops_screen.dart';
import 'widgets/shopkeeper_tools_grid.dart';


// ═══════════════════════════════════════════
// SHOPKEEPER DASHBOARD SCREEN
// ═══════════════════════════════════════════
class ShopkeeperDashboardScreen extends StatefulWidget {
  final bool isEmbedded;

  const ShopkeeperDashboardScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<ShopkeeperDashboardScreen> createState() =>
      _ShopkeeperDashboardScreenState();
}

class _ShopkeeperDashboardScreenState extends State<ShopkeeperDashboardScreen> {
  String _shopName = '';
  String _userName = '';
  String _address = '';
  String? _bannerImageUrl;
  String? _profileImageUrl;
  bool _isMenuExpanded = false;
  int _nearbyShopsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
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
            _address = (data?['businessAddress'] ?? '').toString();
            _bannerImageUrl =
                (data?['bannerImage'] ?? data?['bannerImageUrl'] ?? data?['bannerUrl'] ?? '').toString();
            _profileImageUrl =
                (data?['profileImage'] ?? data?['photoURL'] ?? user.photoURL ?? '').toString();
          });
        }

        final shopsSnapshot = await FirebaseFirestore.instance
            .collection('public_shops')
            .get();
        final currentUid = user.uid;
        final nearbyCount = shopsSnapshot.docs
            .where((doc) =>
                doc.data()['role'] == 'shopkeeper' &&
                doc.id != currentUid &&
                (doc.data()['shopName'] ?? doc.data()['displayName'] ?? '').toString().trim().isNotEmpty)
            .length;
        if (mounted) {
          setState(() {
            _nearbyShopsCount = nearbyCount;
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
    final summary = stockService.getStockSummary();

    final totalPurchaseValue = summary['totalPurchaseValue'] as double? ?? 0.0;
    final totalSalesValue =
        summary['totalSalesPotentialValue'] as double? ?? 0.0;
    final totalItems = summary['totalItems'] as int? ?? 0;
    final lowStockCount = summary['lowStockCount'] as int? ?? 0;

    final appBarTitle = _shopName.isNotEmpty
        ? _shopName
        : (isUrdu ? 'شاپ کیپر ڈیش بورڈ' : 'Shopkeeper Dashboard');

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: CustomAppBar(
          title: appBarTitle,
          backgroundColor: AppTheme.darkColor,
          elevation: 0,
          shape: const RoundedRectangleBorder(),
          showBackButton: !widget.isEmbedded && Navigator.canPop(context),
          actions: [
            IconButton(
              icon: Icon(
                _isMenuExpanded ? Icons.close_rounded : PhosphorIcons.slidersHorizontal(),
                color: Colors.white,
              ),
              tooltip: isUrdu ? 'کاروباری ٹولز' : 'Business Tools',
              onPressed: () {
                setState(() => _isMenuExpanded = !_isMenuExpanded);
              },
            ),
          ],
        ),
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
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _buildQuickActions(
                      context,
                      isUrdu,
                      fontFamily,
                      totalItems,
                      lowStockCount + (summary['outOfStockCount'] as int? ?? 0),
                      _nearbyShopsCount,
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHead(
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      title: isUrdu ? 'اسٹاک کی معلومات' : 'Stock Movements',
                      icon: Icons.access_time_rounded,
                      showAction: true,
                      onActionTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StockHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActivityList(stockService, isUrdu, fontFamily),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ HEADER (Solid background, no gradient) ═══
  Widget _buildHeader(
    BuildContext context,
    bool isUrdu,
    String fontFamily,
    FontWeight fontWeight,
    double purchaseVal,
    double salesVal,
    int lowStockCount,
  ) {
    final profileName = _userName.isNotEmpty
        ? _userName
        : (isUrdu ? 'صارف' : 'User');
    final locationText = _address.isNotEmpty
        ? _address
        : (isUrdu ? 'لاہور، پاکستان' : 'Pakistan');

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
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
                  // Banner Image Cover
                  Positioned.fill(
                    child: _bannerImageUrl != null &&
                            _bannerImageUrl!.trim().isNotEmpty
                        ? Image.network(
                            _bannerImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildHeaderBannerFallback(),
                          )
                        : _buildHeaderBannerFallback(),
                  ),

                  // Dark overlay gradient for maximum text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Profile Card Info using ProfileInfoWidget
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ProfileInfoWidget(
                      name: profileName,
                      phone: '',
                      address: locationText,
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

          // Expandable Menu Grid (between profile card and stat boxes)
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
          Row(
            children: [
              _statMini(
                'Rs ${Formatters.formatAmount(purchaseVal)}',
                isUrdu ? 'خرید مالیت' : 'Purchase Val',
                const Color(0xFFA3E635),
                fontFamily,
                isUrdu,
              ),
              const SizedBox(width: 8),
              _statMini(
                'Rs ${Formatters.formatAmount(salesVal)}',
                isUrdu ? 'فروخت مالیت' : 'Sales Val',
                const Color(0xFF93C5FD),
                fontFamily,
                isUrdu,
              ),
              const SizedBox(width: 8),
              _statMini(
                '$lowStockCount',
                isUrdu ? 'کم اسٹاک' : 'Low Stock',
                const Color(0xFFFBBF24),
                fontFamily,
                isUrdu,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF334155),
          ],
        ),
      ),
    );
  }

  Widget _statMini(
    String value,
    String label,
    Color dotColor,
    String fontFamily,
    bool isUrdu,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                Flexible(
                  child: UrduAwareText(
                    label,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    int lowStockCount,
    int nearbyShopsCount,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'نیا آئٹم' : 'New Item',
                sub: isUrdu ? 'نیا پروڈکٹ شامل کریں' : 'Add new stock product',
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
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'اسٹاک آئٹمز' : 'Stock Items',
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'قریبی دکاندار' : 'Nearby Shops',
                sub: isUrdu ? 'دوسرے دکانداروں سے رابطہ' : 'Connect with nearby shops',
                icon: PhosphorIcons.storefront(),
                color: AppTheme.themeColor,
                badge: nearbyShopsCount > 0 ? '$nearbyShopsCount' : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderSelectionScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'کم اسٹاک الرٹ' : 'Low Stock Alert',
                sub: isUrdu ? 'کم اسٹاک والی پروڈکٹس' : 'Items running low',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.themeColor,
                badge: lowStockCount > 0 ? '$lowStockCount' : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LowStockItemsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final databaseService = Provider.of<DatabaseService>(context);
            final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final todayQuickBillsCount = databaseService
                .getAllTransactions()
                .where((t) => 
                    t.isQuickBill &&
                    t.type == 'income' &&
                    DateFormat('yyyy-MM-dd').format(t.date) == todayKey)
                .length;

            return Row(
              children: [
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
                    badge: '$todayQuickBillsCount',
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
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionCard(
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    title: isUrdu ? 'خرید و فروخت رپورٹ' : 'Sales Analytics',
                    sub: isUrdu
                        ? 'سیلز اور منافع کا تفصیلی تجزیہ'
                        : 'Sales, purchase & profit analytics',
                    icon: Icons.bar_chart_rounded,
                    color: AppTheme.themeColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SalesAnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkColor.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                if (badge != null)
                  Transform.translate(
                    offset: const Offset(0, -4),
                    child: UrduAwareText(
                      badge,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.themeColor,
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
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            UrduAwareText(
              sub,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 10,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
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
            builder: (_) => const LowStockItemsScreen(),
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
                        ? '$lowStockCount آئٹمز اسٹاک سے کم ہیں'
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
            amount: 'Rs. ${Formatters.formatAmount(m.unitPrice)}',
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
                            text: ' آئٹمز',
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
      appBar: CustomAppBar(
        title: isUrdu ? 'اسٹاک آئٹمز' : 'Stock Items',
        backgroundColor: AppTheme.darkColor,
        elevation: 0,
        showBackButton: Navigator.canPop(context),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off : PhosphorIcons.magnifyingGlass(),
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                }
              });
            },
            tooltip: isUrdu ? 'تلاش' : 'Search',
          ),
          const SizedBox(width: 8),
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
