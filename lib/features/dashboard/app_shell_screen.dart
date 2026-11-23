import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/widgets/main_bottom_nav_bar.dart';
import 'package:account_app/features/contracts/contracts_list_screen.dart';
import 'package:account_app/features/accounts/party_list_screen.dart';
import 'package:account_app/features/notifications/notifications_screen.dart';
import 'package:account_app/features/professions/professions_screen.dart';
import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/shopkeeper/home_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  static final GlobalKey<AppShellScreenState> navigationKey =
      GlobalKey<AppShellScreenState>();

  static void switchTab(int index) {
    navigationKey.currentState?.onItemTapped(index);
  }

  @override
  State<AppShellScreen> createState() => AppShellScreenState();
}

class AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        HomeScreen(
          isEmbedded: true,
        ),
        const PartyListScreen(),
        const QuickBillItemSelectionScreen(),
        ProfessionsScreen(),
        const ContractsListScreen(),
        const NotificationsScreen(),
      ];

  void onItemTapped(int index) {
    if (index >= 0 && index < _screens.length && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
    if (index == 5) unawaited(_requestNotificationPermission());
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await Provider.of<NotificationService>(context, listen: false)
          .requestNotificationsPermission();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app shell screen',
          context: ErrorDescription(
              'while requesting notification permission from the inbox'),
        ),
      );
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
