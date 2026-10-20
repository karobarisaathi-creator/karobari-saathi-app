// lib/features/order/my_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

// ═══════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════
class OrderItem {
  final String emoji;
  final String name;
  final double qty;
  final String unit;
  final double rate;

  const OrderItem({
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

  // ═════════════════════════════════════════════════════════════
  // DEMO DATA
  // ═════════════════════════════════════════════════════════════
  final List<MyOrder> _orders = [
    MyOrder(
      id: '#ORD-2024-1587',
      shopName: 'الفلاح کریانہ اسٹور',
      shopLogo: '🛒',
      owner: 'محمد علی',
      verified: true,
      status: 'pending',
      placedAt: 'آج 2:30 PM',
      eta: '3:15 PM تک',
      items: const [
        OrderItem(emoji: '🌾', name: 'باسمتی چاول پریمیم', qty: 5, unit: 'کلو', rate: 320),
        OrderItem(emoji: '🍬', name: 'چینی ریفائنڈ', qty: 2, unit: 'کلو', rate: 145),
        OrderItem(emoji: '🍵', name: 'چائے پتی', qty: 1, unit: 'پیکٹ', rate: 450),
      ],
      subtotal: 2640,
      delivery: 40,
      discount: 0,
      total: 2680,
      paymentMethod: 'کیش آن ڈیلیوری',
      address: 'گھر 12، بلاک B، گلبرگ III، لاہور',
      timeline: const [
        OrderTimelineStep(label: 'آرڈر دیا گیا', time: 'آج 2:30 PM', state: 'done'),
        OrderTimelineStep(label: 'تصدیق شدہ', time: 'آج 2:32 PM', state: 'done'),
        OrderTimelineStep(label: 'تیاری جاری', time: 'ابھی', state: 'active'),
        OrderTimelineStep(label: 'ڈیلیوری', time: 'متوقع 3:15 PM', state: 'pending'),
        OrderTimelineStep(label: 'پہنچ گیا', time: '—', state: 'pending'),
      ],
    ),
    MyOrder(
      id: '#ORD-2024-1586',
      shopName: 'احمد جنرل اسٹور',
      shopLogo: '🏪',
      owner: 'احمد خان',
      verified: true,
      status: 'confirmed',
      placedAt: 'آج 11:15 AM',
      eta: '12:00 PM تک',
      items: const [
        OrderItem(emoji: '🥛', name: 'دودھ تازہ', qty: 3, unit: 'لیٹر', rate: 180),
        OrderItem(emoji: '🥚', name: 'انڈے', qty: 1, unit: 'درجن', rate: 340),
        OrderItem(emoji: '🍞', name: 'بریڈ', qty: 2, unit: 'عدد', rate: 150),
      ],
      subtotal: 1180,
      delivery: 0,
      discount: 50,
      total: 1130,
      paymentMethod: 'کیش آن ڈیلیوری',
      address: 'گھر 12، بلاک B، گلبرگ III، لاہور',
      timeline: const [
        OrderTimelineStep(label: 'آرڈر دیا گیا', time: 'آج 11:15 AM', state: 'done'),
        OrderTimelineStep(label: 'تصدیق شدہ', time: 'آج 11:17 AM', state: 'done'),
        OrderTimelineStep(label: 'تیاری جاری', time: 'آج 11:20 AM', state: 'active'),
        OrderTimelineStep(label: 'ڈیلیوری', time: 'متوقع 12:00 PM', state: 'pending'),
        OrderTimelineStep(label: 'پہنچ گیا', time: '—', state: 'pending'),
      ],
    ),
    MyOrder(
      id: '#ORD-2024-1585',
      shopName: 'بلال ٹریڈرز',
      shopLogo: '🏬',
      owner: 'بلال احمد',
      verified: true,
      status: 'delivered',
      placedAt: 'کل 4:45 PM',
      eta: 'پہنچ گیا',
      items: const [
        OrderItem(emoji: '🍎', name: 'سیب', qty: 2, unit: 'کلو', rate: 350),
        OrderItem(emoji: '🍌', name: 'کیلا', qty: 1, unit: 'درجن', rate: 180),
        OrderItem(emoji: '🍊', name: 'مالٹا', qty: 1, unit: 'کلو', rate: 250),
      ],
      subtotal: 1130,
      delivery: 30,
      discount: 0,
      total: 1160,
      paymentMethod: 'کیش آن ڈیلیوری',
      address: 'گھر 12، بلاک B، گلبرگ III، لاہور',
      timeline: const [
        OrderTimelineStep(label: 'آرڈر دیا گیا', time: 'کل 4:45 PM', state: 'done'),
        OrderTimelineStep(label: 'تصدیق شدہ', time: 'کل 4:48 PM', state: 'done'),
        OrderTimelineStep(label: 'تیاری مکمل', time: 'کل 5:05 PM', state: 'done'),
        OrderTimelineStep(label: 'ڈیلیوری', time: 'کل 5:30 PM', state: 'done'),
        OrderTimelineStep(label: 'پہنچ گیا', time: 'کل 5:35 PM', state: 'done'),
      ],
    ),
    MyOrder(
      id: '#ORD-2024-1584',
      shopName: 'فاطمہ مارٹ',
      shopLogo: '🏭',
      owner: 'فاطمہ بی بی',
      verified: true,
      status: 'cancelled',
      placedAt: 'کل 8:20 AM',
      eta: 'منسوخ',
      items: const [
        OrderItem(emoji: '🍯', name: 'آرگینک شہد', qty: 1, unit: 'کلو', rate: 1500),
      ],
      subtotal: 1500,
      delivery: 50,
      discount: 0,
      total: 1550,
      paymentMethod: 'کیش آن ڈیلیوری',
      address: 'گھر 12، بلاک B، گلبرگ III، لاہور',
      timeline: const [
        OrderTimelineStep(label: 'آرڈر دیا گیا', time: 'کل 8:20 AM', state: 'done'),
        OrderTimelineStep(label: 'منسوخ کر دیا', time: 'کل 8:25 AM', state: 'cancelled'),
      ],
    ),
  ];

  // ═════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════
  List<MyOrder> get _filteredOrders {
    return _orders.where((o) {
      return _activeFilter == 'all' || o.status == _activeFilter;
    }).toList();
  }

  int _countByStatus(String status) =>
      _orders.where((o) => o.status == status).length;

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے آرڈرز' : 'My Orders',
      ),
      body: Column(
        children: [
          // Stats Row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: _buildStatsRow(isUrdu, fontFamily),
          ),

          // Orders list
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(isUrdu, fontFamily)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _buildOrderCard(
                      filtered[i],
                      isUrdu,
                      fontFamily,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // STATS ROW
  // ═════════════════════════════════════════════════════════════
  Widget _buildStatsRow(bool isUrdu, String? fontFamily) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: '${_orders.length}',
            label: isUrdu ? 'کل آرڈرز' : 'Total Orders',
            color: AppTheme.themeColor,
            fontFamily: fontFamily,
            onTap: () => setState(() => _activeFilter = 'all'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: '${_countByStatus('pending')}',
            label: isUrdu ? 'زیر التوا' : 'Pending',
            color: AppTheme.verifiedGold,
            fontFamily: fontFamily,
            onTap: () => setState(() => _activeFilter = 'pending'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: '${_countByStatus('delivered')}',
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                                color: AppTheme.themeColor.withValues(alpha: 0.4),
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
                                border: Border.all(color: Colors.white, width: 2),
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
                          ...order.items.take(3).toList().asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            return Positioned(
                              right: i * 26.0,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEEF4FF), Color(0xFFDCE7F7)],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
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
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      onPressed: () => _reorder(order, isUrdu, fontFamily),
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
                  color: isDone ? AppTheme.incomeColor : AppTheme.backgroundColor,
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
                      ? (isActive ? AppTheme.verifiedGold : AppTheme.incomeColor)
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
                        : (isDone ? AppTheme.incomeColor : AppTheme.textSecondary),
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
              isUrdu ? 'ابھی تک کوئی آرڈر نہیں دیا گیا' : 'No orders placed yet',
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
  void _reorder(MyOrder order, bool isUrdu, String? fontFamily) {
    AppToast.info(
      context,
      isUrdu
          ? '🔁 ${order.shopName} سے دوبارہ آرڈر بن رہا ہے'
          : '🔁 Reordering from ${order.shopName}',
    );
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
                                  isLast: entry.key == order.timeline.length - 1,
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
                              border: Border.all(color: AppTheme.backgroundColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFEEF4FF), Color(0xFFDCE7F7)],
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'منسوخ کریں' : 'Cancel',
                              icon: PhosphorIcons.xCircle(),
                              variant: AppButtonVariant.outlined,
                              color: AppTheme.expenseColor,
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
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
