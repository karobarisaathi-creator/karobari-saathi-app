import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dashboard_screen.dart';
import 'package:account_app/features/artisans/artisan_home_screen.dart';
import 'package:account_app/features/professions/professions_screen.dart';
import 'package:account_app/features/settings/settings_screen.dart';
import 'package:account_app/features/inventory/marketplace_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:provider/provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static _MainNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigationScreenState>();
  }

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    ProfessionsScreen(),
    const ArtisanHomeScreen(),
    MarketplaceScreen(),
    SettingsScreen(),
  ];

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    
    // Calculate dynamic bottom bar height based on device settings
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    // Adjust height for larger fonts/display zoom
    final double dynamicHeight = (kBottomNavigationBarHeight * 
        (textScaleFactor > 1.2 ? textScaleFactor * 0.8 : 1.0)).clamp(
      kBottomNavigationBarHeight, 
      kBottomNavigationBarHeight * 1.5
    );

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: dynamicHeight + bottomPadding,
        color: AppTheme.darkColor,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // Prevent text scaling in nav bar
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
                  activeIcon: Icon(PhosphorIcons.users(PhosphorIconsStyle.fill), size: 24),
                  label: 'Parties',
                ),
                BottomNavigationBarItem(
                  icon: Icon(PhosphorIcons.briefcase(), size: 24),
                  activeIcon: Icon(PhosphorIcons.briefcase(PhosphorIconsStyle.fill), size: 24),
                  label: 'Professions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(PhosphorIcons.hammer(), size: 24),
                  activeIcon: Icon(PhosphorIcons.hammer(PhosphorIconsStyle.fill), size: 24),
                  label: isUrdu ? 'ماہرین' : 'Experts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(PhosphorIcons.storefront(), size: 24),
                  activeIcon: Icon(PhosphorIcons.storefront(PhosphorIconsStyle.fill), size: 24),
                  label: 'Marketplace',
                ),
                BottomNavigationBarItem(
                  icon: Icon(PhosphorIcons.gear(), size: 24),
                  activeIcon: Icon(PhosphorIcons.gear(PhosphorIconsStyle.fill), size: 24),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
