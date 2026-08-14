// lib/features/artisans/screens/artisan_work_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/dispute_model.dart';
import 'package:account_app/core/services/artisan_pro_service.dart';
import 'package:account_app/features/artisans/widgets/work_agreement_dialog.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';

class ArtisanWorkOrdersScreen extends StatefulWidget {
  final String artisanId;

  const ArtisanWorkOrdersScreen({super.key, required this.artisanId});

  @override
  State<ArtisanWorkOrdersScreen> createState() =>
      _ArtisanWorkOrdersScreenState();
}

class _ArtisanWorkOrdersScreenState extends State<ArtisanWorkOrdersScreen> {
  final ArtisanWorkOrderService _service = ArtisanWorkOrderService();
  final ArtisanProService _proService = ArtisanProService();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام' : 'My Work Orders',
      ),
      body: StreamBuilder<List<ArtisanWorkOrder>>(
        stream: _service.getArtisanWorkOrders(widget.artisanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order, isUrdu, fontFamily);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
      ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
    final statusColors = {
      'negotiating': Colors.orange,
      'quoted': Colors.purple,
      'confirmed': Colors.blue,
      'in_progress': Colors.indigo,
      'completed': Colors.green,
      'rated': AppTheme.goldColor,
    };

    final statusLabels = {
      'negotiating': isUrdu ? 'ڈیل ہو رہی ہے' : 'Negotiating',
      'quoted': isUrdu ? 'قیمت دے دی گئی' : 'Quoted',
      'confirmed': isUrdu ? 'منظور شدہ' : 'Confirmed',
      'in_progress': isUrdu ? 'جاری' : 'In Progress',
      'completed': isUrdu ? 'مکمل' : 'Completed',
      'rated': isUrdu ? 'ریٹنگ دی گئی' : 'Rated',
    };

    final bool isNegotiating = order.status == 'negotiating' || order.status == 'quoted';
    final bool needsQuote = order.status == 'negotiating' && (order.amount == null || order.amount == 0);
    final bool waitingForCustomer = order.status == 'quoted' && !order.customerAgreed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColors[order.status]?.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColors[order.status] ?? Colors.grey),
                  ),
                  child: Text(
                    statusLabels[order.status] ?? order.status,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColors[order.status],
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.workDescription,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                fontFamily: fontFamily,
                height: 1.4,
              ),
            ),
            if (order.amount != null && order.amount! > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.money(), color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      isUrdu ? 'طے شدہ رقم:' : 'Fixed Amount:',
                      style: TextStyle(fontFamily: fontFamily, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      'Rs ${order.amount!.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Icon(PhosphorIcons.calendar(), size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                
                // Dispute Button
                if (order.status != 'completed' && order.status != 'rated' && order.disputeStatus == null)
                  IconButton(
                    onPressed: () => _raiseDispute(order, isUrdu, fontFamily),
                    icon: const Icon(Icons.gavel_outlined, color: Colors.redAccent, size: 20),
                    tooltip: isUrdu ? 'تنازع' : 'Dispute',
                  ),

                // Invoice Button
                if (order.status == 'completed' || order.status == 'rated')
                  IconButton(
                    onPressed: () => _downloadInvoice(order, isUrdu),
                    icon: const Icon(Icons.description_outlined, color: Colors.blue, size: 20),
                    tooltip: isUrdu ? 'رسید' : 'Invoice',
                  ),
                
                // Actions
                if (needsQuote)
                   _buildActionButton(
                    onPressed: () => _showQuoteDialog(order, isUrdu, fontFamily),
                    label: isUrdu ? 'رقم بتائیں' : 'Enter Price',
                    color: Colors.orange,
                    fontFamily: fontFamily,
                  ),
                
                if (waitingForCustomer)
                  Text(
                    isUrdu ? 'گاہک کی منظوری کا انتظار...' : 'Waiting for customer...',
                    style: TextStyle(fontFamily: fontFamily, fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                  ),

                if (order.status == 'confirmed')
                  _buildActionButton(
                    onPressed: () => _service.updateStatus(widget.artisanId, order.id, 'in_progress'),
                    label: isUrdu ? 'کام شروع کریں' : 'Start Work',
                    color: Colors.blue,
                    fontFamily: fontFamily,
                  ),

                if (order.status == 'in_progress')
                  _buildActionButton(
                    onPressed: () => _service.updateStatus(widget.artisanId, order.id, 'completed'),
                    label: isUrdu ? 'مکمل کریں' : 'Complete',
                    color: Colors.green,
                    fontFamily: fontFamily,
                  ),
                
                if (order.isRated)
                   _buildRatingBadge(order.rating),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback onPressed, required String label, required Color color, required String fontFamily}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)),
    );
  }

  Widget _buildRatingBadge(double? rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.goldColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: AppTheme.goldColor, size: 14),
          const SizedBox(width: 4),
          Text('${rating ?? 0}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.goldColor)),
        ],
      ),
    );
  }

  void _showQuoteDialog(ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
    final quoteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isUrdu ? 'رقم درج کریں' : 'Enter Price', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: quoteController,
          keyboardType: TextInputType.number,
          style: TextStyle(fontFamily: fontFamily),
          decoration: InputDecoration(
            hintText: isUrdu ? 'کل رقم (روپے میں)' : 'Total Amount (Rs)',
            hintStyle: TextStyle(fontFamily: fontFamily),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(isUrdu ? 'کینسل' : 'Cancel', style: TextStyle(fontFamily: fontFamily))
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(quoteController.text);
              if (amount != null && amount > 0) {
                // Update Order
                await _service.updateStatus(widget.artisanId, order.id, 'quoted');
                await FirebaseFirestore.instance
                  .collection('artisans')
                  .doc(widget.artisanId)
                  .collection('work_orders')
                  .doc(order.id)
                  .update({'amount': amount});
                
                // Send Notification
                final nService = Provider.of<NotificationService>(context, listen: false);
                final user = FirebaseAuth.instance.currentUser;
                await nService.sendQuoteNotification(
                  customerUid: order.customerId,
                  artisanName: user?.displayName ?? 'Artisan',
                  amount: amount,
                  workOrderId: order.id,
                );

                // Audit Log
                await _proService.logAction(
                  action: 'quote_provided',
                  userId: widget.artisanId,
                  workOrderId: order.id,
                  details: {'amount': amount},
                );

                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.themeColor),
            child: Text(isUrdu ? 'بھیجیں' : 'Send', style: TextStyle(color: Colors.white, fontFamily: fontFamily, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _raiseDispute(ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
    final reasonController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedReason = isUrdu ? 'کام معیاری نہیں' : 'Quality issue';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isUrdu ? '⚖️ تنازع درج کریں' : '⚖️ Raise Dispute', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedReason,
              decoration: InputDecoration(
                labelText: isUrdu ? 'تنازع کی قسم' : 'Dispute Type',
                labelStyle: TextStyle(fontFamily: fontFamily),
                border: const OutlineInputBorder(),
              ),
              items: (isUrdu 
                ? ['کام معیاری نہیں', 'ادائیگی نہیں کی گئی', 'کام مکمل نہیں کیا', 'دوسرے ایشوز']
                : ['Quality issue', 'Payment not made', 'Work not completed', 'Other issues']
              ).map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontFamily: fontFamily)))).toList(),
              onChanged: (value) => selectedReason = value ?? '',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              style: TextStyle(fontFamily: fontFamily),
              decoration: InputDecoration(
                labelText: isUrdu ? 'تفصیل' : 'Description',
                labelStyle: TextStyle(fontFamily: fontFamily),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'کینسل' : 'Cancel', style: TextStyle(fontFamily: fontFamily)),
          ),
          ElevatedButton(
            onPressed: () async {
              final dispute = Dispute(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                workOrderId: order.id,
                raisedBy: FirebaseAuth.instance.currentUser!.uid,
                reason: selectedReason,
                description: descriptionController.text.trim(),
                createdAt: DateTime.now(),
              );
              
              await _proService.submitDispute(dispute);
              await _proService.logAction(
                action: 'dispute_raised',
                userId: widget.artisanId,
                workOrderId: order.id,
                details: {'reason': selectedReason},
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isUrdu ? 'تنازع درج کر دیا گیا ہے' : 'Dispute raised successfully', style: TextStyle(fontFamily: fontFamily)),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(isUrdu ? 'درج کریں' : 'Submit', style: TextStyle(color: Colors.white, fontFamily: fontFamily, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(ArtisanWorkOrder order, bool isUrdu) async {
    try {
      final path = await _proService.generateInvoice(order);
      Share.shareXFiles([XFile(path)], text: isUrdu ? 'کام کی رسید' : 'Work Invoice');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
            isUrdu ? 'ابھی تک کوئی آرڈر موصول نہیں ہوا' : 'No orders received yet',
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
