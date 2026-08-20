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
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/features/artisans/widgets/unified_work_order_card.dart';
import 'package:account_app/features/artisans/widgets/work_negotiation_popup.dart';
import 'package:share_plus/share_plus.dart';
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

          // 🆕 صرف وہ کام دکھائیں جو فائنل (Confirmed) ہو چکے ہوں
          final orders = snapshot.data
                  ?.where(
                      (o) => o.status != 'negotiating' && o.status != 'quoted')
                  .toList() ??
              [];

          if (orders.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return UnifiedWorkOrderCard(
                order: order,
                isArtisanMode: false,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                onTap: () {
                  // Finalized orders might still need discussion
                  showDialog(
                    context: context,
                    builder: (context) =>
                        WorkNegotiationPopup(workOrder: order, isDirect: true),
                  );
                },
                onAction: () {
                  if (order.status == 'completed') {
                    _showRatingDialog(order, isUrdu);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
      ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
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
    final bool waitingForArtisan =
        isNegotiating && (order.amount == null || order.amount == 0);
    final bool needsCustomerApproval =
        isNegotiating && !waitingForArtisan && !order.customerAgreed;

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
                      final name = snapshot.data?.name ??
                          (isUrdu ? 'کاریگر' : 'Artisan');
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              if (order.lockedScope != null) ...[
                const SizedBox(height: 12),
                _buildLockedScope(order.lockedScope!, isUrdu, fontFamily),
              ],
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
                      Icon(PhosphorIcons.money(),
                          color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isUrdu ? 'کاریگر کا ماوضعہ:' : 'Artisan Quote:',
                        style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        'Rs ${order.amount!.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green),
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
                      Icon(PhosphorIcons.calendar(),
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.formatDate(order.createdAt),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (waitingForArtisan)
                    Text(
                      isUrdu ? 'ریٹ کا انتظار...' : 'Waiting for price...',
                      style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 12,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic),
                    ),
                  if (needsCustomerApproval)
                    AppButton(
                      text: isUrdu ? '✅ ڈیل فائنل کریں' : 'Finalize Deal',
                      onPressed: () => _finalizeDeal(order, isUrdu),
                      icon: PhosphorIcons.checkCircle(),
                      color: AppTheme.incomeColor,
                      size: AppButtonSize.small,
                    ),
                  if (order.status == 'completed')
                    AppButton(
                      text: isUrdu ? '⭐ ریٹنگ دیں' : 'Rate Now',
                      onPressed: () => _showRatingDialog(order, isUrdu),
                      icon: PhosphorIcons.star(),
                      color: AppTheme.verifiedGold,
                      size: AppButtonSize.small,
                    ),
                  if (order.status == 'rated') _buildRatingBadge(order.rating),
                  if (order.lockedScope != null)
                    IconButton(
                      onPressed: () => _downloadAgreement(order, isUrdu),
                      icon: Icon(PhosphorIcons.scroll(),
                          color: Colors.amber.shade800, size: 20),
                      tooltip: isUrdu
                          ? 'معاہدہ ڈاؤن لوڈ کریں'
                          : 'Download Agreement',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
              color: AppTheme.goldColor, size: 14),
          const SizedBox(width: 4),
          Text('${rating ?? 0}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldColor)),
        ],
      ),
    );
  }

  Future<void> _downloadAgreement(ArtisanWorkOrder order, bool isUrdu) async {
    try {
      final path = await ArtisanProService().generateAgreement(order);
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
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
                fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }

  void _finalizeDeal(ArtisanWorkOrder order, bool isUrdu) async {
    setState(() => _isLoading = true);

    try {
      // 1. Order کو confirmed کریں
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
            'status': 'confirmed', // ✅ confirmed
          });
        }
      });

      // 2. دونوں کو نوٹیفکیشن بھیجیں
      await _notifyBothParties(order, isUrdu);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? '✅ ڈیل فائنل ہو گئی!' : '✅ Deal finalized!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrders(); // Refresh
      }
    } catch (e) {
      debugPrint("Error finalizing deal: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _notifyBothParties(ArtisanWorkOrder order, bool isUrdu) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // گاہک کو نوٹیفکیشن
    final customerNotifId =
        "deal_finalized_${DateTime.now().millisecondsSinceEpoch}";
    await FirebaseFirestore.instance
        .collection('users')
        .doc(order.customerId)
        .collection('notifications')
        .doc(customerNotifId)
        .set({
      'id': customerNotifId,
      'title': isUrdu ? '✅ ڈیل فائنل ہو گئی!' : '✅ Deal Finalized!',
      'message': isUrdu
          ? 'آپ نے کاریگر کے ساتھ ڈیل فائنل کر لی ہے۔ کاریگر جلد کام شروع کرے گا۔'
          : 'You have finalized the deal with the artisan. They will start work soon.',
      'type': 'general',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'data': {
        'type': 'deal_finalized',
        'orderId': order.id,
        'artisanId': order.artisanId,
      },
    });

    // کاریگر کو نوٹیفکیشن
    final artisanNotifId =
        "new_work_order_${DateTime.now().millisecondsSinceEpoch}";
    await FirebaseFirestore.instance
        .collection('users')
        .doc(order.artisanId)
        .collection('notifications')
        .doc(artisanNotifId)
        .set({
      'id': artisanNotifId,
      'title': isUrdu ? '🆕 نیا کام ملا!' : '🆕 New Work Order!',
      'message': isUrdu
          ? 'گاہک نے آپ کے ساتھ ڈیل فائنل کر لی ہے۔ براہ کرم "میرے کام" میں جا کر کام شروع کریں۔'
          : 'Customer has finalized the deal with you. Please go to "My Work" to start.',
      'type': 'general',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'data': {
        'type': 'new_work_order',
        'orderId': order.id,
        'customerId': order.customerId,
      },
    });
  }

  void _showRatingDialog(ArtisanWorkOrder order, bool isUrdu) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isUrdu ? '⭐ اپنی رائے دیں' : 'Write a Review',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu ? 'کاریگر کا کام کیسا رہا؟' : 'How was the work?',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1.0),
                    icon: Icon(
                      index < selectedRating
                          ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                          : PhosphorIcons.star(),
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isUrdu
                      ? 'اپنا تجربہ لکھیں...'
                      : 'Write your experience...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'کینسل' : 'Cancel'),
            ),
            AppButton(
              text: isUrdu ? 'جمع کریں' : 'Submit',
              color: AppTheme.goldColor,
              size: AppButtonSize.small,
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isUrdu
                            ? 'براہ کرم تبصرہ لکھیں'
                            : 'Please write a comment')),
                  );
                  return;
                }

                try {
                  // ریویو جمع کریں
                  await ArtisanService().addReview(
                    artisanId: order.artisanId,
                    workOrderId: order.id,
                    rating: selectedRating,
                    comment: comment,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _loadOrders();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isUrdu
                            ? '✅ آپ کا فیڈ بیک جمع ہوگیا، شکریہ!'
                            : 'Thank you for your feedback!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error submitting review: $e");
                }
              },
            ),
          ],
        ),
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
