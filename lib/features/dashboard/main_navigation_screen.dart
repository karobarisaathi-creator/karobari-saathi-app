import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dashboard_screen.dart';
import 'package:account_app/features/professions/professions_screen.dart';
import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/notifications/notifications_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/app_drawer.dart';
import 'package:account_app/core/services/notification_service.dart';

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
        const NotificationsScreen(),
      ];

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;

    // Calculate dynamic bottom bar height
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double textScaleFactor = MediaQuery.of(context).textScaleFactor;

    final double dynamicHeight = (kBottomNavigationBarHeight *
            (textScaleFactor > 1.2 ? textScaleFactor * 0.8 : 1.0))
        .clamp(kBottomNavigationBarHeight, kBottomNavigationBarHeight * 1.5);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: dynamicHeight + bottomPadding,
        color: AppTheme.darkColor,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppTheme.darkColor,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.5),
              currentIndex: _selectedIndex,
              onTap: onItemTapped,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              iconSize: 24.0,
              selectedFontSize: 0,
              unselectedFontSize: 0,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(PhosphorIcons.users(), size: 24),
                  activeIcon: Icon(PhosphorIcons.users(PhosphorIconsStyle.fill),
                      size: 24),
                  label: isUrdu ? 'کھاتے' : 'Parties',
                ),
                BottomNavigationBarItem(
                  icon: Icon(PhosphorIcons.briefcase(), size: 24),
                  activeIcon: Icon(
                      PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
                      size: 24),
                  label: isUrdu ? 'پیشہ' : 'Professions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(PhosphorIcons.receipt(), size: 24),
                  activeIcon: Icon(
                      PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                      size: 24),
                  label: isUrdu ? 'فوری بل' : 'Quick Bill',
                ),
                BottomNavigationBarItem(
                  icon: Consumer<NotificationService>(
                    builder: (context, notifService, child) {
                      return Badge(
                        label: Text(notifService.unreadCount.toString()),
                        isLabelVisible: notifService.unreadCount > 0,
                        child: Icon(PhosphorIcons.bell(), size: 24),
                      );
                    },
                  ),
                  activeIcon: Consumer<NotificationService>(
                    builder: (context, notifService, child) {
                      return Badge(
                        label: Text(notifService.unreadCount.toString()),
                        isLabelVisible: notifService.unreadCount > 0,
                        child: Icon(PhosphorIcons.bell(PhosphorIconsStyle.fill),
                            size: 24),
                      );
                    },
                  ),
                  label: isUrdu ? 'اطلاعات' : 'Notifications',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
