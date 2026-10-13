// lib/features/order/shop_detail_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/features/order/widgets/shop_item_card_widget.dart';
import 'package:account_app/features/order/services/shop_order_service.dart';
import 'package:account_app/core/widgets/app_toast.dart';

class ShopDetailScreen extends StatefulWidget {
  final Shop shop;

  const ShopDetailScreen({
    super.key,
    required this.shop,
  });

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Shop _shop;
  String _activeCategory = '__all__';
  String _itemQuery = '';
  bool _isSearchVisible = false;
  bool _isLoadingItems = true;
  bool _isSubmittingOrder = false;
  String? _itemsError;

  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _itemsSubscription;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
    _listenToPublicItems();
  }

  void _listenToPublicItems() {
    if (const {'ali', 'ahmed', 'bilal', 'fatima'}.contains(_shop.id)) {
      _isLoadingItems = false;
      return;
    }
    _itemsSubscription = FirebaseFirestore.instance
        .collection('public_shops')
        .doc(_shop.id)
        .collection('items')
        .snapshots()
        .listen(
      (snapshot) {
        final items = snapshot.docs
            .map((doc) {
              final data = doc.data();
              final quantity = (data['availableQuantity'] as num?)?.toDouble();
              final tracksStock = data['trackStock'] != false;
              return ShopItem(
                id: doc.id,
                stockItemId: doc.id,
                name: (data['name'] ?? '').toString(),
                nameUrdu: (data['nameUrdu'] ?? '').toString(),
                description: (data['description'] ?? '').toString(),
                rate: (data['rate'] as num?)?.toDouble() ?? 0,
                oldRate: (data['oldRate'] as num?)?.toDouble(),
                unit: (data['unit'] ?? '').toString(),
                emoji: '📦',
                category: (data['category'] ?? 'عام').toString(),
                imageUrl: (data['imageUrl'] ?? '').toString(),
                rating: (data['rating'] as num?)?.toDouble() ?? 0,
                stock: tracksStock ? (quantity ?? 0) : 1000000000,
                quantity: _shop.items
                        .where((previous) => previous.id == doc.id)
                        .firstOrNull
                        ?.quantity ??
                    0,
              );
            })
            .where((item) => item.name.trim().isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _shop = _shop.copyWith(items: items, itemCount: items.length);
          _isLoadingItems = false;
          _itemsError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoadingItems = false;
          _itemsError = error.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _selectedCount => _shop.items.where((i) => i.quantity > 0).length;

  double get _cartTotal => _shop.items.fold(0, (s, i) => s + i.total);

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      '__all__',
      ..._shop.items.map((i) => i.category).toSet()
    ];

    final filtered = _shop.items.where((item) {
      final catMatch =
          _activeCategory == '__all__' || item.category == _activeCategory;
      final qMatch = _itemQuery.isEmpty || item.name.contains(_itemQuery);
      return catMatch && qMatch;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Tall Dark Header (Shopkeeper Dashboard Style)
            _buildTallHeader(context),

            // Expandable Search Bar below header
            if (_isSearchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: SearchSortBar(
                  controller: _searchCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  hintText: 'آئٹم تلاش کریں...',
                  onSearchChanged: (v) {
                    setState(() => _itemQuery = v);
                  },
                ),
              ),

            // Category Chips & Items List
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Category chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final cat = categories[i];
                        final isActive = cat == _activeCategory;
                        final count = cat == '__all__'
                            ? _shop.items.length
                            : _shop.items
                                .where((x) => x.category == cat)
                                .length;
                        final label = cat == '__all__' ? 'سب' : cat;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _activeCategory = cat),
                            borderRadius: BorderRadius.circular(999),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.darkColor
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isActive
                                      ? AppTheme.darkColor
                                      : AppTheme.backgroundColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UrduAwareText(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.white.withValues(alpha: 0.22)
                                          : Colors.black
                                              .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: UrduAwareText(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: isActive
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Section label
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 15,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [AppTheme.themeColor, AppTheme.goldColor],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        UrduAwareText(
                          _activeCategory == '__all__'
                              ? 'تمام آئٹمز'
                              : _activeCategory,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkColor,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: UrduAwareText(
                            '${filtered.length} آئٹمز',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Items list
                  Expanded(
                    child: _isLoadingItems
                        ? const Center(child: CircularProgressIndicator())
                        : _itemsError != null
                            ? Center(
                                child: UrduAwareText(
                                  'آئٹمز لوڈ نہیں ہو سکیں: $_itemsError',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : filtered.isEmpty
                        ? _buildEmptyState(
                            icon: PhosphorIcons.magnifyingGlass(),
                            title: 'کوئی آئٹم نہیں ملا',
                            sub: 'دوسری کیٹیگری آزمائیں',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              return ShopItemCardWidget(
                                item: item,
                                shop: _shop,
                                onQuantityIncrement: () {
                                  setState(() => item.quantity += 1);
                                },
                                onQuantityDecrement: () {
                                  setState(() => item.quantity =
                                      (item.quantity - 1)
                                          .clamp(0, double.infinity));
                                },
                                onQuantitySet: (val) {
                                  setState(() => item.quantity = val);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedCount > 0 ? _buildCartBar() : null,
    );
  }

  // ═════════════════════════════════════════════════════════════
  // TALL DARK HEADER
  // ═════════════════════════════════════════════════════════════
  Widget _buildTallHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation Row
          Row(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
                tooltip: 'پچھلی اسکرین',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Expanded(
                child: UrduAwareText(
                  'دکان کی تفصیلات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSearchVisible
                      ? PhosphorIcons.x()
                      : PhosphorIcons.magnifyingGlass(),
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: _isSearchVisible ? 'بند کریں' : 'تلاش کریں',
                onPressed: () {
                  setState(() {
                    _isSearchVisible = !_isSearchVisible;
                    if (!_isSearchVisible) {
                      _searchCtrl.clear();
                      _itemQuery = '';
                    }
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Shop Header Card
          _buildShopDetailHeaderCard(_shop),
        ],
      ),
    );
  }

  Widget _buildShopDetailHeaderCard(Shop shop) {
    final hasBanner = shop.bannerImageUrl != null &&
        shop.bannerImageUrl!.trim().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          // Banner Image Cover Background (if present)
          if (hasBanner)
            Positioned.fill(
              child: Image.network(
                shop.bannerImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),

          // Dark Overlay Gradient for text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: hasBanner ? 0.55 : 0.2),
                    Colors.black.withValues(alpha: hasBanner ? 0.85 : 0.5),
                  ],
                ),
              ),
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Profile & Name using ProfileInfoWidget
                Row(
                  children: [
                    Expanded(
                      child: ProfileInfoWidget(
                        name: shop.name,
                        phone: '${shop.owner}  •  ${shop.area}',
                        profileImage: shop.profileImageUrl,
                        isLarge: true,
                        customSize: 48,
                        borderRadius: 14,
                        textColor: Colors.white,
                        subtitleColor: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.star(PhosphorIconsStyle.fill),
                            size: 11,
                            color: AppTheme.verifiedGold,
                          ),
                          const SizedBox(width: 3),
                          UrduAwareText(
                            '${shop.rating}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),

                // Mini Stats Row using PhosphorIcons instead of emojis!
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniHeaderStat(
                      PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
                      shop.distance,
                      'فاصلہ',
                    ),
                    _miniHeaderStat(
                      PhosphorIcons.clock(),
                      shop.deliveryTime,
                      'ڈیلیوری وقت',
                    ),
                    _miniHeaderStat(
                      PhosphorIcons.truck(),
                      shop.deliveryFee,
                      'ڈیلیوری چارجز',
                    ),
                    _miniHeaderStat(
                      PhosphorIcons.package(),
                      '${shop.items.length}',
                      'کل آئٹمز',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniHeaderStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            UrduAwareText(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        UrduAwareText(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // CART BAR
  // ═════════════════════════════════════════════════════════════
  Widget _buildCartBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _viewBill,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.themeColor,
                                Color(0xFF4A8FE3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            PhosphorIcons.shoppingCart(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.verifiedGold,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.darkColor,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: UrduAwareText(
                              '$_selectedCount',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const UrduAwareText(
                            'کل آرڈر',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                          UrduAwareText(
                            'Rs ${_cartTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.themeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const UrduAwareText(
                            'بل دیکھیں',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            PhosphorIcons.arrowLeft(),
                            size: 13,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewBill() {
    final selected = _shop.items.where((i) => i.quantity > 0).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    '🏪 ${_shop.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  UrduAwareText(
                    '👤 ${_shop.owner}  •  📍 ${_shop.area}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFEEF1F5), height: 1),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: selected.length,
                itemBuilder: (context, i) {
                  final item = selected[i];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        UrduAwareText(item.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UrduAwareText(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.darkColor,
                                ),
                              ),
                              UrduAwareText(
                                '${item.quantity.toInt()} × Rs ${item.rate.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        UrduAwareText(
                          'Rs ${item.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.themeColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEF1F5))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const UrduAwareText(
                        'کل رقم',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkColor,
                        ),
                      ),
                      UrduAwareText(
                        'Rs ${_cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.themeColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmittingOrder
                          ? null
                          : () => _submitOrder(ctx, selected),
                      child: _isSubmittingOrder
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const UrduAwareText(
                        'آرڈر دکان کو بھیجیں',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOrder(
    BuildContext sheetContext,
    List<ShopItem> selected,
  ) async {
    if (_isSubmittingOrder) return;
    final navigator = Navigator.of(context);
    final sheetNavigator = Navigator.of(sheetContext);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmittingOrder = true);
    try {
      await ShopOrderService().placeOrder(
        shop: _shop,
        items: selected,
        total: _cartTotal,
      );
      if (!mounted) return;
      setState(() {
        for (final item in _shop.items) {
          item.quantity = 0;
        }
        _isSubmittingOrder = false;
      });
      sheetNavigator.pop();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: UrduAwareText('آرڈر دکان کو بھیج دیا گیا؛ قبول ہونے پر اسٹاک کم ہوگا'),
          backgroundColor: AppTheme.incomeColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingOrder = false);
      AppToast.error(context, 'آرڈر نہیں بھیجا جا سکا: $error');
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, size: 38, color: AppTheme.themeColor),
          ),
          const SizedBox(height: 18),
          UrduAwareText(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 6),
          UrduAwareText(
            sub,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
