// lib/features/navigation/main_navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/widgets/app_drawer.dart';
import 'package:account_app/features/dashboard/dashboard_screen.dart';
import 'package:account_app/features/professions/professions_screen.dart';
import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/stock/stock_list_screen.dart';
import 'package:account_app/features/notifications/notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static final GlobalKey<_MainNavigationScreenState> navigationKey =
  GlobalKey<_MainNavigationScreenState>();

  static void switchTab(int index) {
    navigationKey.currentState?.onItemTapped(index);
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

  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  List<Widget> get _screens => [
    DashboardScreen(),
    ProfessionsScreen(),
    const QuickBillItemSelectionScreen(),
    const StockListScreen(),
    const NotificationsScreen(),
  ];

  void onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
          // ⬇️ نیویگیشن بار کے اوپر والے کونے گول
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(15),
          ),
        ),
        child: SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ═══ Parties (Left) ═══
              Expanded(
                flex: 2,
                child: _buildNavItem(
                  index: 0,
                  icon: PhosphorIcons.users(),
                  activeIcon: PhosphorIcons.users(PhosphorIconsStyle.fill),
                ),
              ),

              // ═══ Professions ═══
              Expanded(
                flex: 2,
                child: _buildNavItem(
                  index: 1,
                  icon: PhosphorIcons.briefcase(),
                  activeIcon:
                  PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
                ),
              ),

              // ═══ Quick Bill (CENTER PILL) ═══
              Expanded(
                flex: 5,
                child: _buildQuickBillPill(isUrdu, fontFamily),
              ),

              // ═══ Stock ═══
              Expanded(
                flex: 2,
                child: _buildNavItem(
                  index: 3,
                  icon: PhosphorIcons.package(),
                  activeIcon: PhosphorIcons.package(PhosphorIconsStyle.fill),
                ),
              ),

              // ═══ Notifications ═══
              Expanded(
                flex: 2,
                child: _buildNotificationItem(),
              ),
            ],
          ),
        ),
      ),
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
  // Quick Bill Center Pill — بڑا بکس
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
            // ⬇️ بکس کا سائز بڑھایا
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
                  child: Text(
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
  // Notifications Item (with badge)
  // ═════════════════════════════════════════════════════════
  Widget _buildNotificationItem() {
    final isActive = _selectedIndex == 4;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTapped(4),
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
                        child: Text(
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