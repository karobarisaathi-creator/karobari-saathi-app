// lib/features/navigation/main_navigation_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_drawer.dart';
import 'package:account_app/features/dashboard/dashboard_screen.dart';
import 'package:account_app/features/notifications/notifications_screen.dart';
import 'package:account_app/features/order/nearby_shops_screen.dart';
import 'package:account_app/features/professions/professions_screen.dart';
import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/shopkeeper/shopkeeper_dashboard_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static final GlobalKey<_MainNavigationScreenState> navigationKey =
      GlobalKey<_MainNavigationScreenState>();

  static void switchTab(int index) {
    navigationKey.currentState?.onItemTapped(index);
  }

  static Future<void> refreshRole() async {
    await navigationKey.currentState?._checkUserRole();
  }

  static _MainNavigationScreenState? of(BuildContext context) {
    return navigationKey.currentState ??
        context.findAncestorStateOfType<_MainNavigationScreenState>();
  }

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isShopkeeperRole = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          final role = doc.data()?['role']?.toString();
          setState(() {
            final isShopkeeperRole = role == 'shopkeeper';
            if (_isShopkeeperRole != isShopkeeperRole) {
              _selectedIndex = 0;
            }
            _isShopkeeperRole = isShopkeeperRole;
          });
        }
      } catch (_) {}
    }
  }

  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  List<Widget> get _screens => _isShopkeeperRole
      ? [
          DashboardScreen(),
          ProfessionsScreen(),
          const QuickBillItemSelectionScreen(),
          const ShopkeeperDashboardScreen(),
          const NotificationsScreen(),
        ]
      : [
          DashboardScreen(),
          ProfessionsScreen(),
          const OrderSelectionScreen(),
          const NotificationsScreen(),
        ];

  void onItemTapped(int index) {
    if (index < _screens.length) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_selectedIndex >= _screens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: const BoxDecoration(
          color: AppTheme.darkColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(15),
          ),
        ),
        child: SizedBox(
          height: 60,
          child: _isShopkeeperRole
              ? _buildShopkeeperNavBar(isUrdu, fontFamily)
              : _buildSimpleNavBar(isUrdu, fontFamily),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Simple Profile Nav Bar (4 Items with Center Pill)
  // ═════════════════════════════════════════════════════════
  Widget _buildSimpleNavBar(bool isUrdu, String? fontFamily) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ═══ Parties / Accounts (Tab 0) ═══
        Expanded(
          flex: 2,
          child: _buildNavItem(
            index: 0,
            icon: PhosphorIcons.users(),
            activeIcon: PhosphorIcons.users(PhosphorIconsStyle.fill),
          ),
        ),

        // ═══ Professions / Projects (Tab 1) ═══
        Expanded(
          flex: 2,
          child: _buildNavItem(
            index: 1,
            icon: PhosphorIcons.briefcase(),
            activeIcon: PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
          ),
        ),

        // ═══ Order Selection (Center Pill) (Tab 2) ═══
        Expanded(
          flex: 5,
          child: _buildOrderPill(isUrdu, fontFamily),
        ),

        // ═══ Notifications (Tab 3) ═══
        Expanded(
          flex: 2,
          child: _buildNotificationItem(index: 3),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════
  // Shopkeeper Profile Nav Bar (5 Items)
  // ═════════════════════════════════════════════════════════
  Widget _buildShopkeeperNavBar(bool isUrdu, String? fontFamily) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ═══ Parties / Accounts (Tab 0) ═══
        Expanded(
          flex: 2,
          child: _buildNavItem(
            index: 0,
            icon: PhosphorIcons.users(),
            activeIcon: PhosphorIcons.users(PhosphorIconsStyle.fill),
          ),
        ),

        // ═══ Professions / Projects (Tab 1) ═══
        Expanded(
          flex: 2,
          child: _buildNavItem(
            index: 1,
            icon: PhosphorIcons.briefcase(),
            activeIcon: PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
          ),
        ),

        // ═══ Quick Bill (Center Pill) (Tab 2) ═══
        Expanded(
          flex: 5,
          child: _buildQuickBillPill(isUrdu, fontFamily),
        ),

        // ═══ Shopkeeper Dashboard (Tab 3) ═══
        Expanded(
          flex: 2,
          child: _buildNavItem(
            index: 3,
            icon: Icons.storefront_rounded,
            activeIcon: Icons.storefront_rounded,
          ),
        ),

        // ═══ Notifications (Tab 4) ═══
        Expanded(
          flex: 2,
          child: _buildNotificationItem(index: 4),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════
  // Regular Nav Item
  // ═════════════════════════════════════════════════════════
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isActive = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 66,
          alignment: Alignment.center,
          child: Icon(
            isActive ? activeIcon : icon,
            size: 22,
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Quick Bill Center Pill
  // ═════════════════════════════════════════════════════════
  Widget _buildQuickBillPill(bool isUrdu, String? fontFamily) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTapped(2),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 66,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIcons.receipt(),
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: UrduAwareText(
                    isUrdu ? 'فوری بل' : 'Bill',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: fontFamily,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Nearby Shops Center Pill (Simple Profile)
  // ═════════════════════════════════════════════════════════
  Widget _buildOrderPill(bool isUrdu, String? fontFamily) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTapped(2),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 66,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.themeColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.themeColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: UrduAwareText(
                    isUrdu ? 'دکاندار' : 'Shops',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: fontFamily,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Notifications Item (with badge)
  // ═════════════════════════════════════════════════════════
  Widget _buildNotificationItem({int index = 2}) {
    final isActive = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 66,
          alignment: Alignment.center,
          child: Consumer<NotificationService>(
            builder: (context, notifService, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive
                        ? PhosphorIcons.bell(PhosphorIconsStyle.fill)
                        : PhosphorIcons.bell(),
                    size: 22,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  if (notifService.unreadCount > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.darkColor,
                            width: 1.5,
                          ),
                        ),
                        child: UrduAwareText(
                          notifService.unreadCount > 99
                              ? '99+'
                              : '${notifService.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
