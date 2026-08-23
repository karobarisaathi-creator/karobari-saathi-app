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
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:share_plus/share_plus.dart';
import 'widgets/work_negotiation_popup.dart';
import 'widgets/unified_work_order_card.dart';

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
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام' : 'My Work Orders',
        showBackButton: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white, // Ensure white text/icons
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      body: StreamBuilder<List<ArtisanWorkOrder>>(
        stream: _service.getArtisanWorkOrders(widget.artisanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // تمام کام دکھائیں، بشمول وہ جو ابھی بات چیت (Negotiation) کے مرحلے میں ہیں
          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          // 🆕 ماہانہ حساب کتاب (صرف منظور شدہ یا مکمل کاموں کے لیے)
          final confirmedOrders = orders.where((o) => 
            o.status != 'negotiating' && o.status != 'quoted' && o.status != 'rejected'
          ).toList();
          
          final now = DateTime.now();
          final currentMonthOrders = confirmedOrders.where((o) => 
            o.createdAt.month == now.month && o.createdAt.year == now.year
          ).toList();
          
          final totalAmount = currentMonthOrders.fold<double>(0, (sum, item) => sum + (item.amount ?? 0));
          final totalCount = currentMonthOrders.length;

          return Column(
            children: [
              _buildLargeDarkHeader(totalAmount, totalCount, isUrdu, fontFamily),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return UnifiedWorkOrderCard(
                      order: order,
                      isArtisanMode: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      onTap: () {
                        if (order.status == 'negotiating' || order.status == 'quoted') {
                          showDialog(
                            context: context,
                            builder: (context) => WorkNegotiationPopup(
                              workOrder: order, 
                              isDirect: true
                            ),
                          );
                        }
                      },
                      onAction: () {
                        if (order.status == 'confirmed') {
                          _startWork(order, isUrdu);
                        } else if (order.status == 'in_progress') {
                          _completeWork(order, isUrdu);
                        }
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (order.status == 'negotiating' || order.status == 'quoted') {
            showDialog(
              context: context,
              builder: (context) =>
                  WorkNegotiationPopup(workOrder: order, isDirect: true),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ProfileInfoWidget(
                      name: order.customerName,
                      phone: order.customerPhone,
                      customSize: 32,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColors[order.status]?.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: statusColors[order.status] ?? Colors.grey),
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
              if (order.lockedScope != null) ...[
                const SizedBox(height: 12),
                _buildLockedScope(order.lockedScope!, isUrdu, fontFamily),
              ],
              if (order.amount != null && order.amount! > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
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
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
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

                  // Agreement Download Button
                  if (order.lockedScope != null)
                    IconButton(
                      onPressed: () => _downloadAgreement(order, isUrdu),
                      icon: Icon(PhosphorIcons.scroll(),
                          color: Colors.amber.shade800, size: 20),
                      tooltip: isUrdu
                          ? 'معاہدہ ڈاؤن لوڈ کریں'
                          : 'Download Agreement',
                    ),

                  // Dispute Button (Only after deal is confirmed)
                  if (order.status != 'negotiating' &&
                      order.status != 'quoted' &&
                      order.status != 'completed' &&
                      order.status != 'rated' &&
                      order.disputeStatus == null)
                    IconButton(
                      onPressed: () => _raiseDispute(order, isUrdu, fontFamily),
                      icon: Icon(PhosphorIcons.gavel(),
                          color: Colors.redAccent, size: 20),
                      tooltip: isUrdu ? 'تنازع' : 'Dispute',
                    ),

                  // Invoice Button
                  if (order.status == 'completed' || order.status == 'rated')
                    IconButton(
                      onPressed: () => _downloadInvoice(order, isUrdu),
                      icon: Icon(PhosphorIcons.fileText(),
                          color: Colors.blue, size: 20),
                      tooltip: isUrdu ? 'رسید' : 'Invoice',
                    ),

                  // Actions
                  if (order.status == 'negotiating' || order.status == 'quoted')
                    Text(
                      isUrdu ? 'بات چیت کے لیے کلک کریں' : 'Tap to negotiate',
                      style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 12,
                          color: AppTheme.themeColor,
                          fontWeight: FontWeight.bold),
                    ),

                  if (order.status == 'confirmed')
                    _buildActionButton(
                      onPressed: () => _startWork(order, isUrdu),
                      label: isUrdu ? 'کام شروع کریں' : 'Start Work',
                      color: Colors.blue,
                      fontFamily: fontFamily,
                    ),

                  if (order.status == 'in_progress')
                    _buildActionButton(
                      onPressed: () => _completeWork(order, isUrdu),
                      label: isUrdu ? 'مکمل کریں' : 'Complete',
                      color: Colors.green,
                      fontFamily: fontFamily,
                    ),

                  if (order.isRated) _buildRatingBadge(order.rating),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startWork(ArtisanWorkOrder order, bool isUrdu) async {
    try {
      // 1. Status کو in_progress کریں
      await _service.updateStatus(order.artisanId, order.id, 'in_progress');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'کام شروع ہو گیا!' : 'Work started!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error starting work: $e");
    }
  }

  Future<void> _completeWork(ArtisanWorkOrder order, bool isUrdu) async {
    try {
      // 1. Status کو completed کریں
      await _service.updateStatus(order.artisanId, order.id, 'completed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'کام مکمل ہو گیا!' : 'Work completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error completing work: $e");
    }
  }

  Widget _buildLockedScope(String scope, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.lockKey(),
                  color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                isUrdu
                    ? 'لاک شدہ معاہدہ (اسٹامپ پیپر)'
                    : 'Locked Agreement (Stamp Paper)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            scope,
            style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
                fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required VoidCallback onPressed,
      required String label,
      required Color color,
      required String fontFamily}) {
    return AppButton(
      text: label,
      onPressed: onPressed,
      color: color,
      size: AppButtonSize.small,
    );
  }

  Widget _buildRatingBadge(double? rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
              color: AppTheme.darkColor, size: 14),
          const SizedBox(width: 4),
          Text('${rating ?? 0}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor)),
        ],
      ),
    );
  }

  void _showQuoteDialog(
      ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
    final quoteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isUrdu ? 'رقم درج کریں' : 'Enter Price',
            style:
                TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold)),
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
              child: Text(isUrdu ? 'کینسل' : 'Cancel',
                  style: TextStyle(fontFamily: fontFamily))),
          AppButton(
            text: isUrdu ? 'بھیجیں' : 'Send',
            onPressed: () async {
              final amount = double.tryParse(quoteController.text);
              if (amount != null && amount > 0) {
                // Update Order
                await _service.updateStatus(
                    widget.artisanId, order.id, 'quoted');
                await FirebaseFirestore.instance
                    .collection('artisans')
                    .doc(widget.artisanId)
                    .collection('work_orders')
                    .doc(order.id)
                    .update({'amount': amount});

                // Send Notification
                final nService =
                    Provider.of<NotificationService>(context, listen: false);
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
            color: AppTheme.themeColor,
            size: AppButtonSize.small,
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
        title: Text(isUrdu ? '⚖️ تنازع درج کریں' : '⚖️ Raise Dispute',
            style:
                TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold)),
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
                      ? [
                          'کام معیاری نہیں',
                          'ادائیگی نہیں کی گئی',
                          'کام مکمل نہیں کیا',
                          'دوسرے ایشوز'
                        ]
                      : [
                          'Quality issue',
                          'Payment not made',
                          'Work not completed',
                          'Other issues'
                        ])
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: TextStyle(fontFamily: fontFamily))))
                  .toList(),
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
            child: Text(isUrdu ? 'کینسل' : 'Cancel',
                style: TextStyle(fontFamily: fontFamily)),
          ),
          AppButton(
            text: isUrdu ? 'درج کریں' : 'Submit',
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
                    content: Text(
                        isUrdu
                            ? 'تنازع درج کر دیا گیا ہے'
                            : 'Dispute raised successfully',
                        style: TextStyle(fontFamily: fontFamily)),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            color: Colors.orange,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(ArtisanWorkOrder order, bool isUrdu) async {
    try {
      final path = await _proService.generateInvoice(order);
      Share.shareXFiles([XFile(path)],
          text: isUrdu ? 'کام کی رسید' : 'Work Invoice');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _downloadAgreement(ArtisanWorkOrder order, bool isUrdu) async {
    try {
      final path = await _proService.generateAgreement(order);
      Share.shareXFiles([XFile(path)],
          text: isUrdu ? 'کام کا معاہدہ' : 'Work Agreement');
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
