import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/features/artisans/widgets/work_order_list_item.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام کا ریکارڈ' : 'My Job History',
      ),
      body: StreamBuilder<List<ArtisanWorkOrder>>(
        stream: ArtisanWorkOrderService().streamCustomerWorkOrders(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedOrders.length,
            itemBuilder: (context, index) {
              final order = sortedOrders[index];
              return WorkOrderListItem(
                order: order,
                isArtisanMode: false,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                onChatTap: () {
                  final notificationService =
                      Provider.of<NotificationService>(context, listen: false);
                  notificationService.setNotificationsTabIndex(1);
                  notificationService.setTargetExpandOrderId(order.id);
                  MainNavigationScreen.switchTab(4);
                  Navigator.pop(context);
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
          Icon(PhosphorIcons.clipboardText(),
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی ریکارڈ نہیں ملا' : 'No records found',
            style: TextStyle(
                fontSize: 18, color: Colors.grey, fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? 'آپ نے ابھی تک کسی کاریگر کو ہائر نہیں کیا'
                : 'You haven\'t hired any artisan yet',
            style: TextStyle(
                fontSize: 14, color: Colors.grey[400], fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }
}
