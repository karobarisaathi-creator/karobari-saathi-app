// lib/features/order/shop_orders_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/order/services/shop_order_service.dart';

class ShopOrdersScreen extends StatelessWidget {
  const ShopOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: CustomAppBar(
          title: isUrdu ? 'دکان کے آرڈرز' : 'Shop Orders',
        ),
        body: Center(
          child: UrduAwareText(
            isUrdu ? 'آرڈرز دیکھنے کے لیے سائن اِن کریں' : 'Sign in to view orders',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
            ),
          ),
        ),
      );
    }

    final ordersStream = FirebaseFirestore.instance
        .collection('public_shops')
        .doc(user.uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'دکان کے آرڈرز' : 'Shop Orders',
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: UrduAwareText(
                  isUrdu
                      ? 'آرڈرز لوڈ نہیں ہوسکے: ${snapshot.error}'
                      : 'Could not load orders: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.expenseColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.themeColor,
              ),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _OrderCard(
                shopId: user.uid,
                orderId: doc.id,
                data: doc.data(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String? fontFamily) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.themeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                PhosphorIcons.receipt(),
                size: 42,
                color: AppTheme.themeColor,
              ),
            ),
            const SizedBox(height: 18),
            UrduAwareText(
              isUrdu ? 'ابھی کوئی آرڈر موصول نہیں ہوا' : 'No orders received yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 6),
            UrduAwareText(
              isUrdu
                  ? 'جب گاہک آپ کی دکان سے سامان کا آرڈر بھیجیں گے تو وہ یہاں دکھائی دیں گے'
                  : 'When customers place orders from your shop, they will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final String shopId;
  final String orderId;
  final Map<String, dynamic> data;
  final bool isUrdu;
  final String? fontFamily;

  const _OrderCard({
    required this.shopId,
    required this.orderId,
    required this.data,
    required this.isUrdu,
    this.fontFamily,
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
        accept
            ? (widget.isUrdu
                ? '✓ آرڈر قبول ہو گیا اور اسٹاک اپڈیٹ ہو گیا'
                : '✓ Order accepted & stock updated')
            : (widget.isUrdu ? 'آرڈر مسترد کر دیا گیا' : 'Order rejected'),
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        widget.isUrdu
            ? 'آرڈر اپڈیٹ نہیں ہو سکا: $error'
            : 'Could not update order: $error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.data['status'] ?? 'pending').toString();
    final rawItems = widget.data['items'];
    final items =
        rawItems is List ? rawItems.whereType<Map>().toList() : const [];
    final total = (widget.data['total'] as num?)?.toDouble() ?? 0;
    final customerName =
        (widget.data['customerName'] ?? (widget.isUrdu ? 'گاہک' : 'Customer'))
            .toString();
    final customerPhone = (widget.data['customerPhone'] ?? '').toString();

    // Status Styling
    Color statusBg;
    Color statusFg;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'accepted':
        statusBg = const Color(0xFFECFCCB);
        statusFg = AppTheme.incomeColor;
        statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
        statusLabel = widget.isUrdu ? 'قبول شدہ' : 'Accepted';
        break;
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2);
        statusFg = AppTheme.expenseColor;
        statusIcon = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
        statusLabel = widget.isUrdu ? 'مسترد' : 'Rejected';
        break;
      default:
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFFD97706);
        statusIcon = PhosphorIcons.clock(PhosphorIconsStyle.fill);
        statusLabel = widget.isUrdu ? 'زیرِ انتظار' : 'Pending';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Row + Status Badge
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    PhosphorIcons.user(PhosphorIconsStyle.fill),
                    size: 20,
                    color: AppTheme.themeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        customerName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkColor,
                          fontFamily: widget.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customerPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.phone(),
                              size: 11,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            UrduAwareText(
                              customerPhone,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusFg),
                      const SizedBox(width: 4),
                      UrduAwareText(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: statusFg,
                          fontFamily: widget.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFEEF1F5), height: 1),
            const SizedBox(height: 10),

            // Itemized List
            for (final rawItem in items) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: UrduAwareText(
                        (rawItem['nameUrdu']?.toString().isNotEmpty == true
                                ? rawItem['nameUrdu']
                                : rawItem['name'] ?? '')
                            .toString(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkColor,
                          fontFamily: widget.fontFamily,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: UrduAwareText(
                        '${rawItem['quantity']} ${rawItem['unit'] ?? ''} × Rs ${(rawItem['rate'] as num?)?.toStringAsFixed(0) ?? '0'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          fontFamily: widget.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(color: Color(0xFFEEF1F5), height: 1),
            const SizedBox(height: 10),

            // Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                UrduAwareText(
                  widget.isUrdu ? 'کل رقم' : 'Total Amount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: widget.fontFamily,
                  ),
                ),
                UrduAwareText(
                  'Rs ${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.themeColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),

            // Action Buttons for Pending Orders
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: widget.isUrdu ? 'مسترد کریں' : 'Reject',
                      variant: AppButtonVariant.outlined,
                      color: AppTheme.expenseColor,
                      isLoading: _busy,
                      onPressed: _busy ? null : () => _updateOrder(accept: false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      text: widget.isUrdu ? 'قبول کریں' : 'Accept',
                      variant: AppButtonVariant.primary,
                      color: AppTheme.incomeColor,
                      isLoading: _busy,
                      onPressed: _busy ? null : () => _updateOrder(accept: true),
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
