import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/artisan_pro_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/features/artisans/widgets/work_agreement_dialog.dart';
import 'artisan_detail_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  bool _isLoading = true;
  List<ArtisanWorkOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final service = ArtisanWorkOrderService();
    try {
      final orders = await service.getCustomerWorkOrders(user.uid);
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading customer orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام کا ریکارڈ' : 'My Job History',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmptyState(isUrdu, fontFamily)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _buildOrderCard(order, isUrdu, fontFamily);
                  },
                ),
    );
  }

  Widget _buildOrderCard(ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
    Color statusColor = Colors.orange;
    String statusText = isUrdu ? 'پینڈنگ' : 'Pending';

    if (order.status == 'negotiating') {
      statusColor = Colors.orange;
      statusText = isUrdu ? 'ڈیل ہو رہی ہے' : 'Negotiating';
    } else if (order.status == 'confirmed') {
      statusColor = Colors.blue;
      statusText = isUrdu ? 'منظور شدہ' : 'Confirmed';
    } else if (order.status == 'in_progress') {
      statusColor = Colors.indigo;
      statusText = isUrdu ? 'جاری' : 'In Progress';
    } else if (order.status == 'completed') {
      statusColor = Colors.green;
      statusText = isUrdu ? 'مکمل' : 'Completed';
    } else if (order.status == 'rated') {
      statusColor = AppTheme.verifiedGold;
      statusText = isUrdu ? 'فیڈ بیک دیا گیا' : 'Rated';
    } else if (order.status == 'rejected') {
      statusColor = Colors.red;
      statusText = isUrdu ? 'مسترد' : 'Rejected';
    }

    final bool isNegotiating = order.status == 'negotiating';
    final bool waitingForArtisan = isNegotiating && (order.amount == null || order.amount == 0);
    final bool needsCustomerApproval = isNegotiating && !waitingForArtisan && !order.customerAgreed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          // Go to artisan detail for re-hire
          final artisanService = ArtisanService();
          final profile = await artisanService.getProfile(order.artisanId);
          if (mounted && profile != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArtisanDetailScreen(
                  artisanId: profile.id,
                  initialArtisan: profile,
                ),
              ),
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
                  FutureBuilder<ArtisanProfile?>(
                    future: ArtisanService().getProfile(order.artisanId),
                    builder: (context, snapshot) {
                      final name = snapshot.data?.name ?? (isUrdu ? 'کاریگر' : 'Artisan');
                      return Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily,
                        ),
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.workDescription,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontFamily: fontFamily,
                ),
              ),
              if (order.amount != null && order.amount! > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.money(), color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isUrdu ? 'کاریگر کا ماوضعہ:' : 'Artisan Quote:',
                        style: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        'Rs ${order.amount!.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIcons.calendar(), size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.formatDate(order.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  
                  if (waitingForArtisan)
                    Text(
                      isUrdu ? 'ریٹ کا انتظار...' : 'Waiting for price...',
                      style: TextStyle(fontFamily: fontFamily, fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                    ),

                  if (needsCustomerApproval)
                    ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(order, isUrdu, fontFamily),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(isUrdu ? 'منظور کریں' : 'Approve Deal', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.incomeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                  if (order.status == 'completed' || order.status == 'rated')
                    Row(
                      children: [
                        Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 16, color: AppTheme.verifiedGold),
                        const SizedBox(width: 4),
                        Text(
                          order.rating?.toString() ?? '5.0',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApproveDialog(ArtisanWorkOrder order, bool isUrdu, String fontFamily) async {
    final artisanProfile = await ArtisanService().getProfile(order.artisanId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => WorkAgreementDialog(
        artisanName: artisanProfile?.name ?? 'Artisan',
        customerName: order.customerName,
        amount: order.amount ?? 0,
        workDescription: order.workDescription,
        isUrdu: isUrdu,
        fontFamily: fontFamily,
        onAgree: () async {
          await FirebaseFirestore.instance
              .collectionGroup('work_orders')
              .where('id', isEqualTo: order.id)
              .get()
              .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.update({
                'customerAgreed': true,
                'customerAcceptedTerms': true,
                'agreedAt': FieldValue.serverTimestamp(),
                'status': 'confirmed',
              });
            }
          });

          // Log Action
          await ArtisanProService().logAction(
            action: 'contract_signed_by_customer',
            userId: order.customerId,
            workOrderId: order.id,
            details: {'amount': order.amount},
          );

          _loadOrders();
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.clipboardText(), size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی ریکارڈ نہیں ملا' : 'No records found',
            style: TextStyle(fontSize: 18, color: Colors.grey, fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu ? 'آپ نے ابھی تک کسی کاریگر کو ہائر نہیں کیا' : 'You haven\'t hired any artisan yet',
            style: TextStyle(fontSize: 14, color: Colors.grey[400], fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }
}
