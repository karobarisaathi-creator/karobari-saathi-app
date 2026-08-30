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
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام' : 'My Work Orders',
        showBackButton: false,
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedOrders.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
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
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              );
            },
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

}
