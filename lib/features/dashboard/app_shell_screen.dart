import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/models/bottom_bar_profile_type.dart';
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

  static Future<void> refreshRole() async {
    await navigationKey.currentState?._checkUserRole();
  }

  @override
  State<AppShellScreen> createState() => AppShellScreenState();
}

class AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;
  BottomBarProfileType _profileType = BottomBarProfileType.simple;

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
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        final hasShop = data['role'] == 'shopkeeper' ||
            (data['shopName'] ?? '').toString().trim().isNotEmpty;
        final hasCompany =
            (data['businessName'] ?? '').toString().trim().isNotEmpty;
        setState(() {
          _profileType = hasShop
              ? BottomBarProfileType.shopkeeper
              : hasCompany
                  ? BottomBarProfileType.contractor
                  : BottomBarProfileType.simple;
        });
      }
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
    if (index == 4) unawaited(_requestNotificationPermission());
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
        profileType: _profileType,
      ),
    );
  }
}
