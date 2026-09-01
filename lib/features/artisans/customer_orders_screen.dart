import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/features/artisans/widgets/work_order_list_item.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'dart:async';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final _logger = LoggingService();
  final ArtisanWorkOrderService _workOrderService = ArtisanWorkOrderService();
  
  Stream<List<ArtisanWorkOrder>>? _ordersStream;
  StreamSubscription<List<ArtisanWorkOrder>>? _ordersSubscription;
  List<ArtisanWorkOrder> _orders = [];
  
  bool _isLoading = true;
  String? _error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _initializeStream();
  }

  void _initializeStream() {
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'User not logged in';
      });
      return;
    }

    _ordersStream = _workOrderService.streamCustomerWorkOrders(_userId!);
    _ordersSubscription = _ordersStream?.listen(
      _onOrdersReceived,
      onError: _onError,
    );
  }

  void _onOrdersReceived(List<ArtisanWorkOrder> orders) {
    if (!mounted) return;
    
    // Remove duplicates and sort by latest activity
    final Map<String, ArtisanWorkOrder> uniqueOrders = {};
    for (var order in orders) {
      uniqueOrders[order.id] = order;
    }
    
    final sortedOrders = uniqueOrders.values.toList();
    sortedOrders.sort((a, b) {
      final aTime = a.updatedAt ?? a.createdAt;
      final bTime = b.updatedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    setState(() {
      _orders = sortedOrders;
      _isLoading = false;
      _error = null;
    });
  }

  void _onOrderUpdated() {
    // This can be used to trigger UI updates if needed, 
    // but the stream already handles real-time changes.
  }

  void _onError(dynamic error) {
    _logger.error("Customer orders stream error", error);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void _navigateToChat(ArtisanWorkOrder order) {
    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    notificationService.setNotificationsTabIndex(1);
    notificationService.setTargetExpandOrderId(order.id);
    MainNavigationScreen.switchTab(4);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام کا ریکارڈ' : 'My Job History',
      ),
      body: _buildBody(isUrdu, fontFamily),
    );
  }

  Widget _buildBody(bool isUrdu, String fontFamily) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(isUrdu, fontFamily);
    }

    if (_orders.isEmpty) {
      return _buildEmptyState(isUrdu, fontFamily);
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      color: AppTheme.themeColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.withValues(alpha: 0.2),
        ),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return WorkOrderListItem(
            order: order,
            isArtisanMode: false,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            onChatTap: () => _navigateToChat(order),
            onOrderUpdated: _onOrderUpdated,
          );
        },
      ),
    );
  }

  Future<void> _refreshOrders() async {
    // Stream automatically updates, this is just for pull-to-refresh
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageService>(context, listen: false).isUrdu
                ? 'تازہ ترین معلومات'
                : 'Updated',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.clipboardText(),
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی ریکارڈ نہیں ملا' : 'No records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? 'آپ نے ابھی تک کسی کاریگر کو ہائر نہیں کیا'
                : 'You haven\'t hired any artisan yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.warningCircle(),
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'ڈیٹا لوڈ کرنے میں ناکامی' : 'Failed to load data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _initializeStream();
            },
            icon: const Icon(Icons.refresh),
            label: Text(
              isUrdu ? 'دوبارہ کوشش کریں' : 'Retry',
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
        ],
      ),
    );
  }
}
