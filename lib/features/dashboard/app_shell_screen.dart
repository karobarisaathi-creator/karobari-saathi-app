import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:account_app/core/widgets/main_bottom_nav_bar.dart';
import 'package:account_app/features/accounts/party_list_screen.dart';
import 'package:account_app/features/notifications/notifications_screen.dart';
import 'package:account_app/features/professions/professions_screen.dart';
import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/shopkeeper/shopkeeper_dashboard_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  static final GlobalKey<AppShellScreenState> navigationKey =
      GlobalKey<AppShellScreenState>();

  static void switchTab(int index) {
    navigationKey.currentState?.onItemTapped(index);
  }

  static Future<void> refreshRole() async {
    await navigationKey.currentState?._checkUserRole();
  }

  @override
  State<AppShellScreen> createState() => AppShellScreenState();
}

class AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        const ShopkeeperDashboardScreen(isEmbedded: true),
        const PartyListScreen(),
        const QuickBillItemSelectionScreen(),
        ProfessionsScreen(),
        const NotificationsScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) setState(() {});
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app shell screen',
          context: ErrorDescription('while refreshing the signed-in user role'),
        ),
      );
    }
  }

  void onItemTapped(int index) {
    if (index >= 0 && index < _screens.length && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: MainBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: onItemTapped,
      ),
    );
  }
}
