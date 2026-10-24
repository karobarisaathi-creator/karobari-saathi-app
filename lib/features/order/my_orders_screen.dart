// lib/features/order/my_orders_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/order/services/shop_order_service.dart';

// ═══════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════
class OrderItem {
  final String itemId;
  final String emoji;
  final String name;
  final double qty;
  final String unit;
  final double rate;

  const OrderItem({
    required this.itemId,
    required this.emoji,
    required this.name,
    required this.qty,
    required this.unit,
    required this.rate,
  });

  double get total => qty * rate;
}

class OrderTimelineStep {
  final String label;
  final String time;
  final String state; // 'done' | 'active' | 'pending' | 'cancelled'

  const OrderTimelineStep({
    required this.label,
    required this.time,
    required this.state,
  });
}

class MyOrder {
  final String id;
  final String shopId;
  final String shopName;
  final String shopLogo;
  final String owner;
  final bool verified;
  final String status; // 'pending' | 'confirmed' | 'delivered' | 'cancelled'
  final String placedAt;
  final String eta;
  final List<OrderItem> items;
  final double subtotal;
  final double delivery;
  final double discount;
  final double total;
  final String paymentMethod;
  final String address;
  final List<OrderTimelineStep> timeline;

  const MyOrder({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.shopLogo,
    required this.owner,
    required this.verified,
    required this.status,
    required this.placedAt,
    required this.eta,
    required this.items,
    required this.subtotal,
    required this.delivery,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.address,
    required this.timeline,
  });
}

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _activeFilter = 'all';
  final ShopOrderService _shopOrderService = ShopOrderService();
  final Set<String> _busyOrderActions = {};

  // ═════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════
  List<MyOrder> _filteredOrders(List<MyOrder> orders) {
    return orders.where((o) {
      return _activeFilter == 'all' || o.status == _activeFilter;
    }).toList();
  }

  int _countByStatus(List<MyOrder> orders, String status) =>
      orders.where((o) => o.status == status).length;

  MyOrder _orderFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    bool isUrdu,
  ) {
    final data = document.data();
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((rawItem) {
            final item = Map<String, dynamic>.from(rawItem);
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
            final rate = (item['rate'] as num?)?.toDouble() ?? 0;
            return OrderItem(
              itemId: (item['itemId'] ?? item['id'] ?? '').toString(),
              emoji: '📦',
              name: (item['name'] ?? item['nameUrdu'] ?? '').toString(),
              qty: quantity,
              unit: (item['unit'] ?? '').toString(),
              rate: rate,
            );
          }).toList()
        : <OrderItem>[];
    final status = switch (data['status']) {
      'accepted' => 'confirmed',
      'rejected' => 'cancelled',
      final String value => value,
      _ => 'pending',
    };
    final createdAt = data['createdAt'];
    final placedAt = createdAt is Timestamp
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
        : '—';
    final total = (data['total'] as num?)?.toDouble() ??
        items.fold<double>(0, (total, item) => total + item.total);
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? total;
    final isRejected = status == 'cancelled';
    final acceptedAt = data['acceptedAt'];
    final rejectedAt = data['rejectedAt'];
    final cancelledAt = data['cancelledAt'];
    final timeline = <OrderTimelineStep>[
      OrderTimelineStep(
        label: isUrdu ? 'آرڈر دیا گیا' : 'Order placed',
        time: placedAt,
        state: isRejected ? 'done' : (status == 'pending' ? 'active' : 'done'),
      ),
      if (isRejected)
        OrderTimelineStep(
          label: isUrdu ? 'آرڈر منسوخ ہوا' : 'Order cancelled',
          time: (cancelledAt ?? rejectedAt) is Timestamp
              ? DateFormat('dd MMM yyyy, hh:mm a').format(
                  ((cancelledAt ?? rejectedAt) as Timestamp).toDate(),
                )
              : '—',
          state: 'cancelled',
        )
      else if (status == 'confirmed' || status == 'delivered') ...[
        OrderTimelineStep(
          label: isUrdu ? 'آرڈر قبول ہوا' : 'Order accepted',
          time: acceptedAt is Timestamp
              ? DateFormat('dd MMM yyyy, hh:mm a').format(acceptedAt.toDate())
              : '—',
          state: 'done',
        ),
        OrderTimelineStep(
          label: isUrdu ? 'آرڈر تیار ہو رہا ہے' : 'Preparing order',
          time: '—',
          state: status == 'confirmed' ? 'active' : 'done',
        ),
      ],
    ];

    return MyOrder(
      id: document.id,
      shopId: (data['shopId'] ?? document.reference.parent.parent?.id ?? '')
          .toString(),
      shopName: (data['shopName'] ?? 'Shop').toString(),
      shopLogo: '🛒',
      owner: (data['shopOwnerName'] ?? '').toString(),
      verified: data['verified'] == true,
      status: status,
      placedAt: placedAt,
      eta: '—',
      items: items,
      subtotal: subtotal,
      delivery: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      total: total,
      paymentMethod:
          (data['paymentMethod'] ?? (isUrdu ? 'متعین نہیں' : 'Not specified'))
              .toString(),
      address:
          (data['address'] ?? (isUrdu ? 'فراہم نہیں کیا گیا' : 'Not provided'))
              .toString(),
      timeline: timeline,
    );
  }

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے آرڈرز' : 'My Orders',
      ),
      body: user == null
          ? Center(
              child: UrduAwareText(
                isUrdu
                    ? 'آرڈرز دیکھنے کے لیے سائن اِن کریں'
                    : 'Sign in to view orders',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontFamily: fontFamily,
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('orders')
                  .where('customerId', isEqualTo: user.uid)
                  .snapshots(),
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
                          color: AppTheme.expenseColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.themeColor),
                  );
                }

                final orderDocuments = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aCreatedAt = a.data()['createdAt'];
                    final bCreatedAt = b.data()['createdAt'];
                    final aDate = aCreatedAt is Timestamp
                        ? aCreatedAt.toDate()
                        : DateTime.fromMillisecondsSinceEpoch(0);
                    final bDate = bCreatedAt is Timestamp
                        ? bCreatedAt.toDate()
                        : DateTime.fromMillisecondsSinceEpoch(0);
                    return bDate.compareTo(aDate);
                  });
                final orders = orderDocuments
                    .map((document) => _orderFromSnapshot(document, isUrdu))
                    .toList();
                final filtered = _filteredOrders(orders);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: _buildStatsRow(isUrdu, fontFamily, orders),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState(isUrdu, fontFamily)
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) => _buildOrderCard(
                                filtered[i],
                                isUrdu,
                                fontFamily,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // STATS ROW
  // ═════════════════════════════════════════════════════════════
  Widget _buildStatsRow(
    bool isUrdu,
    String? fontFamily,
    List<MyOrder> orders,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: '${orders.length}',
            label: isUrdu ? 'کل آرڈرز' : 'Total Orders',
            color: AppTheme.themeColor,
            fontFamily: fontFamily,
            onTap: () => setState(() => _activeFilter = 'all'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: '${_countByStatus(orders, 'pending')}',
            label: isUrdu ? 'زیر التوا' : 'Pending',
            color: AppTheme.verifiedGold,
            fontFamily: fontFamily,
            onTap: () => setState(() => _activeFilter = 'pending'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: '${_countByStatus(orders, 'delivered')}',
            label: isUrdu ? 'مکمل شدہ' : 'Delivered',
            color: AppTheme.incomeColor,
            fontFamily: fontFamily,
            onTap: () => setState(() => _activeFilter = 'delivered'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? fontFamily,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // ORDER CARD
  // ═════════════════════════════════════════════════════════════
  Widget _buildOrderCard(MyOrder order, bool isUrdu, String? fontFamily) {
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openDetail(order, isUrdu, fontFamily),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header: shop + status ───
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.themeColor, Color(0xFF4A8FE3)],
                            ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.themeColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              order.shopLogo,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        if (order.verified)
                          Positioned(
                            bottom: -2,
                            left: -2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppTheme.verifiedGold,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Center(
                                child: Text(
                                  '✓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: UrduAwareText(
                                  order.shopName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.darkColor,
                                    fontFamily: fontFamily,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (order.verified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7E6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: UrduAwareText(
                                    isUrdu ? '✓ تصدیق' : '✓ Verified',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFB45309),
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              UrduAwareText(
                                order.placedAt,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  fontFamily: fontFamily,
                                ),
                              ),
                              _dot(),
                              Text(
                                order.id,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(order.status, isUrdu, fontFamily),
                  ],
                ),
              ),

              // ─── Items preview ───
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    // Emojis
                    SizedBox(
                      height: 34,
                      width: 100,
                      child: Stack(
                        children: [
                          ...order.items
                              .take(3)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            return Positioned(
                              right: i * 26.0,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEEF4FF),
                                      Color(0xFFDCE7F7)
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    item.emoji,
                                    style: const TextStyle(fontSize: 17),
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (order.items.length > 3)
                            Positioned(
                              right: 3 * 26.0,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.darkColor,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '+${order.items.length - 3}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UrduAwareText(
                            _itemsSummary(order, isUrdu),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          UrduAwareText(
                            isUrdu
                                ? 'کل ${order.items.length} آئٹمز'
                                : '${order.items.length} items total',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Progress tracker ───
              if (order.status == 'pending' || order.status == 'confirmed')
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: _buildProgressTracker(order, isUrdu, fontFamily),
                ),

              // ─── Footer ───
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UrduAwareText(
                          isUrdu ? 'کل رقم' : 'Total',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            fontFamily: fontFamily,
                          ),
                        ),
                        Text(
                          'Rs ${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AppButton(
                      text: isUrdu ? 'دوبارہ' : 'Reorder',
                      icon: PhosphorIcons.arrowClockwise(),
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.small,
                      onPressed: () => _reorder(order, isUrdu),
                    ),
                    const SizedBox(width: 6),
                    AppButton(
                      text: isUrdu ? 'تفصیل' : 'Details',
                      icon: PhosphorIcons.info(),
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: () => _openDetail(order, isUrdu, fontFamily),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: Color(0xFFB0B8C1),
            shape: BoxShape.circle,
          ),
        ),
      );

  // ═════════════════════════════════════════════════════════════
  // STATUS BADGE
  // ═════════════════════════════════════════════════════════════
  Widget _buildStatusBadge(String status, bool isUrdu, String? fontFamily) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        icon = PhosphorIcons.clock();
        label = isUrdu ? 'زیر التوا' : 'Pending';
        break;
      case 'confirmed':
        bg = const Color(0xFFDBEAFE);
        fg = AppTheme.themeColor;
        icon = PhosphorIcons.checkCircle();
        label = isUrdu ? 'تصدیق شدہ' : 'Confirmed';
        break;
      case 'delivered':
        bg = const Color(0xFFECFCCB);
        fg = AppTheme.incomeColor;
        icon = PhosphorIcons.checkCircle();
        label = isUrdu ? 'مکمل شدہ' : 'Delivered';
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = AppTheme.expenseColor;
        icon = PhosphorIcons.xCircle();
        label = isUrdu ? 'منسوخ' : 'Cancelled';
        break;
      default:
        bg = AppTheme.backgroundColor;
        fg = AppTheme.textSecondary;
        icon = PhosphorIcons.info();
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          UrduAwareText(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: fg,
              fontFamily: fontFamily,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // PROGRESS TRACKER
  // ═════════════════════════════════════════════════════════════
  Widget _buildProgressTracker(MyOrder order, bool isUrdu, String? fontFamily) {
    final stages = [
      isUrdu ? 'آرڈر دیا' : 'Placed',
      isUrdu ? 'تصدیق' : 'Confirm',
      isUrdu ? 'تیاری' : 'Prepare',
      isUrdu ? 'ڈیلیوری' : 'Deliver',
      isUrdu ? 'پہنچا' : 'Done',
    ];
    final doneCount = order.status == 'pending' ? 2 : 3;

    return Column(
      children: [
        // Dots + lines
        Row(
          children: List.generate(stages.length * 2 - 1, (index) {
            if (index.isOdd) {
              // Line
              final lineIndex = index ~/ 2;
              final isDone = lineIndex < doneCount - 1;
              return Expanded(
                child: Container(
                  height: 2,
                  color:
                      isDone ? AppTheme.incomeColor : AppTheme.backgroundColor,
                ),
              );
            } else {
              // Dot
              final dotIndex = index ~/ 2;
              final isDone = dotIndex < doneCount;
              final isActive = dotIndex == doneCount - 1;
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isDone
                      ? (isActive
                          ? AppTheme.verifiedGold
                          : AppTheme.incomeColor)
                      : AppTheme.backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.verifiedGold.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isDone
                    ? const Icon(
                        Icons.check,
                        size: 8,
                        color: Colors.white,
                      )
                    : null,
              );
            }
          }),
        ),
        const SizedBox(height: 5),
        // Labels
        Row(
          children: stages.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final isActive = i == doneCount - 1;
            final isDone = i < doneCount - 1;
            return Expanded(
              child: Center(
                child: UrduAwareText(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppTheme.verifiedGold
                        : (isDone
                            ? AppTheme.incomeColor
                            : AppTheme.textSecondary),
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _itemsSummary(MyOrder order, bool isUrdu) {
    final names = order.items.take(2).map((i) => i.name).join('، ');
    final remaining = order.items.length - 2;
    return remaining > 0 ? '$names، +$remaining' : names;
  }

  // ═════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═════════════════════════════════════════════════════════════
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
              isUrdu ? 'کوئی آرڈر نہیں ملا' : 'No orders found',
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
                  ? 'ابھی تک کوئی آرڈر نہیں دیا گیا'
                  : 'No orders placed yet',
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

  // ═════════════════════════════════════════════════════════════
  // ACTIONS
  // ═════════════════════════════════════════════════════════════
  Future<void> _reorder(
    MyOrder order,
    bool isUrdu,
  ) async {
    if (order.shopId.isEmpty) {
      AppToast.error(
        context,
        isUrdu
            ? 'اس آرڈر کی دکان دستیاب نہیں'
            : 'This order shop is unavailable',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isUrdu ? 'دوبارہ آرڈر کریں؟' : 'Reorder?'),
        content: Text(
          isUrdu
              ? 'موجودہ قیمت اور دستیابی کے مطابق ${order.shopName} کو نیا آرڈر بھیجا جائے گا۔'
              : 'A new order will be sent to ${order.shopName} using current prices and availability.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isUrdu ? 'واپس' : 'Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isUrdu ? 'آرڈر کریں' : 'Place order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final actionKey = 'reorder:${order.id}';
    if (!_busyOrderActions.add(actionKey)) return;
    try {
      await _shopOrderService.reorderOrder(
        shopId: order.shopId,
        orderId: order.id,
      );
      if (mounted) {
        AppToast.success(
          context,
          isUrdu ? 'نیا آرڈر بھیج دیا گیا' : 'New order placed',
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'دوبارہ آرڈر مکمل نہیں ہو سکا: $error'
              : 'Could not place the reordered order: $error',
        );
      }
    } finally {
      _busyOrderActions.remove(actionKey);
    }
  }

  Future<void> _contactShop(MyOrder order, bool isUrdu) async {
    if (order.shopId.isEmpty) {
      AppToast.error(
        context,
        isUrdu
            ? 'دکان کی معلومات دستیاب نہیں'
            : 'Shop information is unavailable',
      );
      return;
    }

    try {
      final shopSnapshot = await FirebaseFirestore.instance
          .collection('public_shops')
          .doc(order.shopId)
          .get();
      final shopData = shopSnapshot.data();
      var phone = (shopData?['phoneNumber'] ?? shopData?['phone'] ?? '')
          .toString()
          .trim();
      if (phone.isEmpty) {
        final ownerSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(order.shopId)
            .get();
        final ownerData = ownerSnapshot.data();
        phone = (ownerData?['phoneNumber'] ?? ownerData?['phone'] ?? '')
            .toString()
            .trim();
      }
      if (phone.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context,
            isUrdu
                ? 'دکان کا فون نمبر دستیاب نہیں'
                : 'The shop phone number is unavailable',
          );
        }
        return;
      }

      final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!launched && mounted) {
        AppToast.error(
          context,
          isUrdu ? 'فون کال ایپ نہیں کھل سکی' : 'Could not open the phone app',
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'دکان سے رابطہ نہیں ہو سکا: $error'
              : 'Could not contact the shop: $error',
        );
      }
    }
  }

  Future<void> _cancelOrder(
    MyOrder order,
    bool isUrdu,
    BuildContext modalContext,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isUrdu ? 'آرڈر منسوخ کریں؟' : 'Cancel order?'),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی یہ آرڈر منسوخ کرنا چاہتے ہیں؟'
              : 'Are you sure you want to cancel this order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isUrdu ? 'نہیں' : 'Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isUrdu ? 'منسوخ کریں' : 'Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (order.shopId.isEmpty) {
      AppToast.error(
        context,
        isUrdu
            ? 'اس آرڈر کی دکان دستیاب نہیں'
            : 'This order shop is unavailable',
      );
      return;
    }

    final actionKey = 'cancel:${order.id}';
    if (!_busyOrderActions.add(actionKey)) return;
    try {
      await _shopOrderService.cancelCustomerOrder(
        shopId: order.shopId,
        orderId: order.id,
      );
      if (mounted) {
        AppToast.success(
          context,
          isUrdu ? 'آرڈر منسوخ ہوگیا' : 'Order cancelled',
        );
      }
      if (modalContext.mounted) Navigator.pop(modalContext);
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'آرڈر منسوخ نہیں ہو سکا: $error'
              : 'Could not cancel order: $error',
        );
      }
    } finally {
      _busyOrderActions.remove(actionKey);
    }
  }

  // ═════════════════════════════════════════════════════════════
  // DETAIL MODAL
  // ═════════════════════════════════════════════════════════════
  void _openDetail(MyOrder order, bool isUrdu, String? fontFamily) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Head
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.themeColor, Color(0xFF4A8FE3)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.themeColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        order.shopLogo,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          order.shopName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.id}  •  ${order.placedAt}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF1F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFFEEF1F5), height: 1),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── Timeline ───
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: order.timeline
                            .asMap()
                            .entries
                            .map((entry) => _buildTimelineItem(
                                  entry.value,
                                  isLast:
                                      entry.key == order.timeline.length - 1,
                                  fontFamily: fontFamily,
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Items ───
                    _buildModalSectionTitle(
                      icon: PhosphorIcons.package(),
                      title: isUrdu ? 'آرڈر کی تفصیل' : 'Order Details',
                      fontFamily: fontFamily,
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppTheme.backgroundColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFEEF4FF),
                                        Color(0xFFDCE7F7)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.emoji,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      UrduAwareText(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.darkColor,
                                          fontFamily: fontFamily,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.qty.toInt()} ${item.unit} × Rs ${item.rate.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Rs ${item.total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),

                    const SizedBox(height: 12),

                    // ─── Bill summary ───
                    _buildModalSectionTitle(
                      icon: PhosphorIcons.receipt(),
                      title: isUrdu ? 'بل کی تفصیل' : 'Bill Summary',
                      fontFamily: fontFamily,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            isUrdu ? 'ذیلی کل' : 'Subtotal',
                            'Rs ${order.subtotal.toStringAsFixed(0)}',
                            fontFamily: fontFamily,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            isUrdu ? 'ڈیلیوری فیس' : 'Delivery Fee',
                            order.delivery == 0
                                ? (isUrdu ? 'مفت' : 'Free')
                                : 'Rs ${order.delivery.toStringAsFixed(0)}',
                            valueColor: order.delivery == 0
                                ? AppTheme.incomeColor
                                : null,
                            fontFamily: fontFamily,
                          ),
                          if (order.discount > 0) ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              isUrdu ? 'رعایت' : 'Discount',
                              '- Rs ${order.discount.toStringAsFixed(0)}',
                              valueColor: AppTheme.incomeColor,
                              fontFamily: fontFamily,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.only(top: 8),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Color(0xFFE1E5EC),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                UrduAwareText(
                                  isUrdu ? 'کل رقم' : 'Total',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.darkColor,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                                Text(
                                  'Rs ${order.total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.themeColor,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ─── Delivery info ───
                    _buildModalSectionTitle(
                      icon: PhosphorIcons.mapPin(),
                      title: isUrdu ? 'ترسیل کی معلومات' : 'Delivery Info',
                      fontFamily: fontFamily,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            isUrdu ? 'پتہ' : 'Address',
                            order.address,
                            smallValue: true,
                            fontFamily: fontFamily,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            isUrdu ? 'ادائیگی' : 'Payment',
                            order.paymentMethod,
                            smallValue: true,
                            fontFamily: fontFamily,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ─── Actions ───
                    if (order.status == 'pending' ||
                        order.status == 'confirmed') ...[
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'رابطہ' : 'Contact',
                              icon: PhosphorIcons.phone(),
                              variant: AppButtonVariant.outlined,
                              onPressed: () => _contactShop(order, isUrdu),
                            ),
                          ),
                          if (order.status == 'pending') ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppButton(
                                text: isUrdu ? 'منسوخ کریں' : 'Cancel',
                                icon: PhosphorIcons.xCircle(),
                                variant: AppButtonVariant.outlined,
                                color: AppTheme.expenseColor,
                                onPressed: () =>
                                    _cancelOrder(order, isUrdu, ctx),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else if (order.status == 'delivered') ...[
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'رسید' : 'Receipt',
                              icon: PhosphorIcons.receipt(),
                              variant: AppButtonVariant.outlined,
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'ریٹنگ دیں' : 'Rate',
                              icon: PhosphorIcons.star(),
                              variant: AppButtonVariant.primary,
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // MODAL HELPERS
  // ═════════════════════════════════════════════════════════════
  Widget _buildModalSectionTitle({
    required IconData icon,
    required String title,
    String? fontFamily,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.themeColor),
        const SizedBox(width: 6),
        UrduAwareText(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkColor,
            fontFamily: fontFamily,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    OrderTimelineStep step, {
    required bool isLast,
    String? fontFamily,
  }) {
    Color dotColor;
    IconData icon;

    switch (step.state) {
      case 'done':
        dotColor = AppTheme.incomeColor;
        icon = Icons.check;
        break;
      case 'active':
        dotColor = AppTheme.verifiedGold;
        icon = Icons.access_time;
        break;
      case 'cancelled':
        dotColor = AppTheme.expenseColor;
        icon = Icons.close;
        break;
      default:
        dotColor = AppTheme.backgroundColor;
        icon = Icons.circle;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: step.state == 'active'
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, size: 12, color: Colors.white),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: step.state == 'done'
                        ? AppTheme.incomeColor
                        : AppTheme.backgroundColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    step.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: step.state == 'active'
                          ? AppTheme.verifiedGold
                          : (step.state == 'done'
                              ? AppTheme.incomeColor
                              : AppTheme.darkColor),
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(height: 2),
                  UrduAwareText(
                    step.time,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool smallValue = false,
    String? fontFamily,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: UrduAwareText(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: smallValue ? 11 : 12,
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppTheme.darkColor,
              fontFamily: smallValue ? fontFamily : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
