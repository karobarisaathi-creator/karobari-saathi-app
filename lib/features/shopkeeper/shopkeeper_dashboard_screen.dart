import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/stock_card.dart';
import 'package:account_app/features/accounts/reports_screen.dart';
import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/settings/master_profile_screen.dart';
import 'package:account_app/features/shopkeeper/low_stock_items_screen.dart';
import 'package:account_app/features/shopkeeper/stock_history_screen.dart';
import 'package:account_app/features/shopkeeper/add_edit_stock_item_screen.dart';
import 'package:account_app/features/shopkeeper/sales_analytics_screen.dart';
import 'package:account_app/features/shopkeeper/stock_detail_screen.dart';
import 'package:account_app/features/shopkeeper/stock_adjustment_dialog.dart';

// ═══════════════════════════════════════════
// COLORS
// ═══════════════════════════════════════════
class ShopkeeperColors {
  static const theme = Color(0xFF1D6ED6);
  static const themeDark = Color(0xFF1557A8);
  static const dark = Color(0xFF123248);
  static const darkHeader = Color(0xFF0F2A40);
  static const income = Color(0xFF515D11);
  static const expense = Color(0xFFC83120);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFBBF24);
  static const purple = Color(0xFF8B5CF6);
  static const purpleLight = Color(0xFFA78BFA);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFE8EAF0);
  static const gray100 = Color(0xFFEEF1F5);
  static const gray200 = Color(0xFFE1E5EC);
  static const gray400 = Color(0xFFB0B8C1);
}

// ═══════════════════════════════════════════
// SHOPKEEPER DASHBOARD SCREEN
// ═══════════════════════════════════════════
class ShopkeeperDashboardScreen extends StatefulWidget {
  const ShopkeeperDashboardScreen({super.key});

  @override
  State<ShopkeeperDashboardScreen> createState() =>
      _ShopkeeperDashboardScreenState();
}

class _ShopkeeperDashboardScreenState extends State<ShopkeeperDashboardScreen> {
  String _shopName = '';
  String _userName = '';
  String _address = '';

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
    final lowStockCount = summary['lowStockCount'] as int? ?? 0;

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: ShopkeeperColors.bg,
        appBar: CustomAppBar(
          title: isUrdu ? 'شاپ کیپر ڈیش بورڈ' : 'Shopkeeper Dashboard',
          backgroundColor: ShopkeeperColors.darkHeader,
          elevation: 0,
          showBackButton: Navigator.canPop(context),
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
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHead(
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      title: isUrdu ? 'فوری کام' : 'Quick Actions',
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActions(context, isUrdu, fontFamily),
                    const SizedBox(height: 20),
                    _buildAlertCard(
                      context,
                      isUrdu,
                      fontFamily,
                      lowStockCount + (summary['outOfStockCount'] as int? ?? 0),
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
                            builder: (_) => const StockHistoryScreen(),
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
    final displayName = _shopName.isNotEmpty
        ? _shopName
        : (_userName.isNotEmpty
            ? _userName
            : (isUrdu ? 'کریانہ اسٹور' : 'My Store'));
    final initial =
        displayName.isNotEmpty ? displayName[0] : (isUrdu ? 'ش' : 'S');
    final locationText = _address.isNotEmpty
        ? _address
        : (isUrdu ? 'لاہور، پاکستان' : 'Pakistan');

    return Container(
      decoration: const BoxDecoration(
        color: ShopkeeperColors.darkHeader,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Profile Strip
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterProfileScreen(),
                ),
              ).then((_) => _loadProfileInfo());
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ShopkeeperColors.theme,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        left: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isUrdu ? 'شاپ کیپر' : 'Shopkeeper',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: ShopkeeperColors.theme,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locationText,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 11,
                            fontWeight: fontWeight,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _switchRoleBtn(context, isUrdu, fontFamily),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              _statMini(
                  'Rs ${purchaseVal.toStringAsFixed(0)}',
                  isUrdu ? 'خرید مالیت' : 'Purchase Val',
                  const Color(0xFFA3E635),
                  fontFamily,
                  isUrdu),
              const SizedBox(width: 8),
              _statMini(
                  'Rs ${salesVal.toStringAsFixed(0)}',
                  isUrdu ? 'فروخت مالیت' : 'Sales Val',
                  const Color(0xFF93C5FD),
                  fontFamily,
                  isUrdu),
              const SizedBox(width: 8),
              _statMini('$lowStockCount', isUrdu ? 'کم اسٹاک' : 'Low Stock',
                  const Color(0xFFFBBF24), fontFamily, isUrdu),
            ],
          ),
        ],
      ),
    );
  }

  Widget _switchRoleBtn(BuildContext context, bool isUrdu, String fontFamily) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MasterProfileScreen(),
          ),
        ).then((_) => _loadProfileInfo());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 5),
            Text(
              isUrdu ? 'بدلیں' : 'Switch',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
              child: Text(
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
                  child: Text(
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
            Icon(icon, size: 16, color: ShopkeeperColors.theme),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ShopkeeperColors.dark,
              ),
            ),
          ],
        ),
        if (showAction)
          GestureDetector(
            onTap: onActionTap,
            child: Row(
              children: [
                Text(
                  isUrdu ? 'سب دیکھیں' : 'View All',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ShopkeeperColors.theme,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left_rounded,
                    size: 14, color: ShopkeeperColors.theme),
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
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'نیا بل' : 'New Sale',
                sub: isUrdu ? 'فوری بل بنائیں' : 'Create a quick bill',
                icon: Icons.receipt_long_rounded,
                color1: ShopkeeperColors.warning,
                color2: ShopkeeperColors.warningLight,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuickBillItemSelectionScreen(),
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
                title: isUrdu ? 'نیا آئٹم' : 'New Item',
                sub: isUrdu ? 'نیا پروڈکٹ شامل کریں' : 'Add new stock product',
                icon: Icons.add_circle_outline_rounded,
                color1: ShopkeeperColors.purple,
                color2: ShopkeeperColors.purpleLight,
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
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'اسٹاک آئٹمز' : 'Stock Items',
                sub: isUrdu
                    ? 'تمام اسٹاک پراڈکٹس کی لسٹ'
                    : 'All inventory stock items',
                icon: Icons.inventory_2_rounded,
                color1: const Color(0xFF0EA5E9),
                color2: const Color(0xFF38BDF8),
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
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'اسٹاک ہسٹری' : 'Stock History',
                sub: isUrdu
                    ? 'لین دین اور آمدورفت ہسٹری'
                    : 'Stock movements history log',
                icon: Icons.history_rounded,
                color1: const Color(0xFF8B5CF6),
                color2: const Color(0xFFA78BFA),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StockHistoryScreen(),
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
                title: isUrdu ? 'خرید و فروخت رپورٹ' : 'Sales Analytics',
                sub: isUrdu
                    ? 'سیلز اور منافع کا تفصیلی تجزیہ'
                    : 'Sales, purchase & profit analytics',
                icon: Icons.bar_chart_rounded,
                color1: ShopkeeperColors.income,
                color2: const Color(0xFF6B7A1F),
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
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionCard(
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                title: isUrdu ? 'مالی رپورٹس' : 'Financial Reports',
                sub: isUrdu
                    ? 'مکمل کاروباری رپورٹس'
                    : 'General financial reports',
                icon: Icons.description_rounded,
                color1: ShopkeeperColors.expense,
                color2: const Color(0xFFE04B36),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportsScreen(),
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

  Widget _quickActionCard({
    required bool isUrdu,
    required String fontFamily,
    required String title,
    required String sub,
    required IconData icon,
    required Color color1,
    required Color color2,
    String? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color1.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: ShopkeeperColors.dark.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (badge != null)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color1,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color1, color2]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color1.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ShopkeeperColors.dark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 10.5,
                    color: ShopkeeperColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ShopkeeperColors.warning.withValues(alpha: 0.08),
              ShopkeeperColors.warning.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ShopkeeperColors.warning.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    ShopkeeperColors.warning,
                    ShopkeeperColors.warningLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: ShopkeeperColors.warning.withValues(alpha: 0.3),
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
                  Text(
                    isUrdu ? '⚠️ کم اسٹاک الرٹ' : '⚠️ Low Stock Alert',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopkeeperColors.gray200, width: 1.5),
        ),
        child: Center(
          child: Text(
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopkeeperColors.gray200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ShopkeeperColors.dark.withValues(alpha: 0.04),
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
            time: '${m.quantity.toStringAsFixed(0)} آئٹمز',
            tag: typeLabel,
            tagType: amountType == 'income' ? 'bill' : 'order',
            amount: 'Rs. ${m.unitPrice.toStringAsFixed(0)}',
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
    required String time,
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
        iconBg = ShopkeeperColors.income.withValues(alpha: 0.12);
        iconFg = ShopkeeperColors.income;
        amountColor = ShopkeeperColors.income;
        break;
      case 'expense':
        iconBg = ShopkeeperColors.expense.withValues(alpha: 0.12);
        iconFg = ShopkeeperColors.expense;
        amountColor = ShopkeeperColors.expense;
        break;
      default:
        iconBg = ShopkeeperColors.warning.withValues(alpha: 0.12);
        iconFg = ShopkeeperColors.warning;
        amountColor = ShopkeeperColors.warning;
    }

    if (tagType == 'bill') {
      tagBg = ShopkeeperColors.theme.withValues(alpha: 0.12);
      tagFg = ShopkeeperColors.theme;
    } else if (tagType == 'order') {
      tagBg = ShopkeeperColors.warning.withValues(alpha: 0.12);
      tagFg = ShopkeeperColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: ShopkeeperColors.gray100),
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
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ShopkeeperColors.dark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 10,
                        color: ShopkeeperColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: ShopkeeperColors.gray400,
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
                        child: Text(
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
                      Text(
                        tag,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 10,
                          color: ShopkeeperColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontFamily: fontFamily,
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

    final summary = stockService.getStockSummary();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          isUrdu ? 'اسٹاک آئٹمز' : 'Stock Items',
          style: TextStyle(
            color: Colors.white,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
          IconButton(
            icon: Icon(
              PhosphorIcons.plusCircle(),
              color: Colors.white,
              size: 26,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditStockItemScreen(),
                ),
              );
            },
            tooltip: isUrdu ? 'نیا آئٹم' : 'Add Item',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 📊 Top Valuation Summary Header
          _buildSummaryHeader(summary, isUrdu, fontFamily),

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

  Widget _buildSummaryHeader(
    Map<String, dynamic> summary,
    bool isUrdu,
    String fontFamily,
  ) {
    final totalPurchaseValue = summary['totalPurchaseValue'] as double? ?? 0.0;
    final totalSalesPotentialValue =
        summary['totalSalesPotentialValue'] as double? ?? 0.0;
    final lowStockCount = summary['lowStockCount'] as int? ?? 0;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.sizeOf(context).height > 0
            ? MediaQuery.of(context).padding.top + 56
            : 56,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryItem(
                isUrdu ? 'خرید مالیت' : 'Purchase Value',
                'Rs. ${totalPurchaseValue.toStringAsFixed(0)}',
                PhosphorIcons.arrowDownLeft(),
                fontFamily,
              ),
              _buildDivider(),
              _buildSummaryItem(
                isUrdu ? 'فروخت مالیت' : 'Sales Value',
                'Rs. ${totalSalesPotentialValue.toStringAsFixed(0)}',
                PhosphorIcons.arrowUpRight(),
                fontFamily,
              ),
              _buildDivider(),
              _buildSummaryItem(
                isUrdu ? 'کم اسٹاک الرٹس' : 'Low Stock',
                '$lowStockCount ${isUrdu ? 'آئٹمز' : 'items'}',
                PhosphorIcons.bellRinging(),
                fontFamily,
                isWarning: lowStockCount > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    String fontFamily, {
    bool isWarning = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isWarning ? const Color(0xFFFBBF24) : Colors.white70,
              fontSize: 11,
              fontFamily: fontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 12,
                  color: isWarning ? const Color(0xFFFBBF24) : Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 20, width: 1, color: Colors.white12);
  }

  Widget _buildItemList(
    StockService stockService,
    bool isUrdu,
    String fontFamily,
  ) {
    var items = stockService.items;

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
              Text(
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
      padding: const EdgeInsets.all(16),
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
          onQuickAdd: () {
            showDialog(
              context: context,
              builder: (context) => StockAdjustmentDialog(
                item: item,
                initialType: StockMovementType.purchase,
              ),
            );
          },
          onQuickRemove: () {
            showDialog(
              context: context,
              builder: (context) => StockAdjustmentDialog(
                item: item,
                initialType: StockMovementType.sale,
              ),
            );
          },
        );
      },
    );
  }
}
