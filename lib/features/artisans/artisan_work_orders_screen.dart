// lib/features/artisans/screens/artisan_work_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'widgets/work_order_list_item.dart';

class ArtisanWorkOrdersScreen extends StatefulWidget {
  final String artisanId;

  const ArtisanWorkOrdersScreen({super.key, required this.artisanId});

  @override
  State<ArtisanWorkOrdersScreen> createState() =>
      _ArtisanWorkOrdersScreenState();
}

class _ArtisanWorkOrdersScreenState extends State<ArtisanWorkOrdersScreen> {
  final ArtisanWorkOrderService _service = ArtisanWorkOrderService();
  late Stream<List<ArtisanWorkOrder>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = _service.getArtisanWorkOrders(widget.artisanId);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام' : 'My Work Orders',
        showBackButton: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      body: StreamBuilder<List<ArtisanWorkOrder>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          // ماہانہ حساب کتاب (صرف منظور شدہ یا مکمل کاموں کے لیے)
          final confirmedOrders = orders.where((o) => 
            o.status != 'negotiating' && o.status != 'quoted' && o.status != 'rejected'
          ).toList();
          
          final now = DateTime.now();
          final currentMonthOrders = confirmedOrders.where((o) => 
            o.createdAt.month == now.month && o.createdAt.year == now.year
          ).toList();
          
          final totalAmount = currentMonthOrders.fold<double>(0, (sum, item) => sum + (item.amount ?? 0));
          final totalCount = currentMonthOrders.length;

          // Remove duplicates and sort by latest activity
          final Map<String, ArtisanWorkOrder> uniqueOrders = {};
          for (var o in orders) {
            uniqueOrders[o.id] = o;
          }
          final sortedOrders = uniqueOrders.values.toList();
          sortedOrders.sort((a, b) {
            final aTime = a.updatedAt ?? a.createdAt;
            final bTime = b.updatedAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });

          return Column(
            children: [
              _buildLargeDarkHeader(totalAmount, totalCount, isUrdu, fontFamily),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedOrders.length,
                  itemBuilder: (context, index) {
                    final order = sortedOrders[index];
                    return WorkOrderListItem(
                      order: order,
                      isArtisanMode: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      onChatTap: () {
                        final notificationService =
                            Provider.of<NotificationService>(context,
                                listen: false);
                        notificationService.setNotificationsTabIndex(1);
                        notificationService.setTargetExpandOrderId(order.id);
                        MainNavigationScreen.switchTab(4);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.package(), size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی کام نہیں ملا' : 'No work orders',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? 'ابھی تک کوئی آرڈر موصول نہیں ہوا'
                : 'No orders received yet',
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

  Widget _buildLargeDarkHeader(double totalAmount, int totalCount, bool isUrdu, String fontFamily) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 45,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          _buildSummaryItem(
            isUrdu ? 'اس مہینے کی کمائی' : 'Earnings this month',
            'Rs. ${totalAmount.toStringAsFixed(0)}',
            Colors.greenAccent,
            fontFamily,
            PhosphorIcons.wallet(),
          ),
          Container(width: 1, height: 30, color: Colors.white12),
          _buildSummaryItem(
            isUrdu ? 'مکمل کام' : 'Jobs Done',
            '$totalCount',
            Colors.blueAccent,
            fontFamily,
            PhosphorIcons.briefcase(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color iconColor, String fontFamily, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: fontFamily),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: '',
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
}
