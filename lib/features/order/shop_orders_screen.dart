import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/order/services/shop_order_service.dart';

class ShopOrdersScreen extends StatelessWidget {
  const ShopOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'دکان کے آرڈرز'),
        body: const Center(child: UrduAwareText('آرڈرز دیکھنے کے لیے سائن اِن کریں')),
      );
    }

    final orders = FirebaseFirestore.instance
        .collection('public_shops')
        .doc(user.uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const CustomAppBar(title: 'دکان کے آرڈرز'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: UrduAwareText(
                  'آرڈرز لوڈ نہیں ہوسکے: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: UrduAwareText('ابھی کوئی آرڈر موصول نہیں ہوا'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              return _OrderCard(
                shopId: user.uid,
                orderId: doc.id,
                data: doc.data(),
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final String shopId;
  final String orderId;
  final Map<String, dynamic> data;

  const _OrderCard({
    required this.shopId,
    required this.orderId,
    required this.data,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _busy = false;

  Future<void> _updateOrder({required bool accept}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ShopOrderService();
      if (accept) {
        await service.acceptOrder(
          shopId: widget.shopId,
          orderId: widget.orderId,
        );
      } else {
        await service.rejectOrder(
          shopId: widget.shopId,
          orderId: widget.orderId,
        );
      }
      if (!mounted) return;
      AppToast.success(
        context,
        accept ? 'آرڈر قبول ہوگیا اور اسٹاک اپڈیٹ ہوگیا' : 'آرڈر مسترد ہوگیا',
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, 'آرڈر اپڈیٹ نہیں ہوسکا: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.data['status'] ?? 'pending').toString();
    final rawItems = widget.data['items'];
    final items = rawItems is List ? rawItems.whereType<Map>().toList() : const [];
    final total = (widget.data['total'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: UrduAwareText(
                    (widget.data['customerName'] ?? 'گاہک').toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ),
                UrduAwareText(
                  status == 'pending'
                      ? 'زیرِ انتظار'
                      : status == 'accepted'
                          ? 'قبول شدہ'
                          : 'مسترد',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: status == 'accepted'
                        ? AppTheme.incomeColor
                        : status == 'rejected'
                            ? AppTheme.expenseColor
                            : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if ((widget.data['customerPhone'] ?? '').toString().isNotEmpty)
              UrduAwareText(
                widget.data['customerPhone'].toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            const Divider(height: 20),
            for (final rawItem in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: UrduAwareText(
                        (rawItem['nameUrdu']?.toString().isNotEmpty == true
                                ? rawItem['nameUrdu']
                                : rawItem['name'] ?? '')
                            .toString(),
                      ),
                    ),
                    UrduAwareText(
                      '${rawItem['quantity']} × Rs ${(rawItem['rate'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(
                  child: UrduAwareText(
                    'کل رقم',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                UrduAwareText(
                  'Rs ${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.themeColor,
                  ),
                ),
              ],
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _updateOrder(accept: false),
                      child: const UrduAwareText('مسترد کریں'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : () => _updateOrder(accept: true),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const UrduAwareText('قبول کریں'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
