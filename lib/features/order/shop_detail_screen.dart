// lib/features/order/shop_detail_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/location_chip_widget.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/features/order/widgets/shop_item_card_widget.dart';

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

  static const Map<String, String> _categoryNamesUrdu = {
    'General': 'عمومی',
    'Grocery': 'کریانہ',
    'Food': 'خوراک',
    'Beverages': 'مشروبات',
    'Clothing': 'کپڑے',
    'Electronics': 'الیکٹرانکس',
    'Household': 'گھریلو سامان',
    'Personal Care': 'ذاتی استعمال',
    'Medicine': 'ادویات',
    'Other': 'دیگر',
  };

  String _formatCategory(String cat, bool isUrdu) {
    if (cat == '__all__') return isUrdu ? 'سب' : 'All';
    if (isUrdu) {
      return _categoryNamesUrdu[cat] ?? cat;
    }
    return cat;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
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
            // Single Unified Tall Dark Header
            _buildTallHeader(context),

            // Expandable Search Bar below header
            if (_isSearchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SearchSortBar(
                  controller: _searchCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        final label = _formatCategory(cat, isUrdu);

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

                  const SizedBox(height: 4),

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
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              return ShopItemCardWidget(
                                item: item,
                                shop: _shop,
                                showStepper: false,
                                onQuantityIncrement: () {},
                                onQuantityDecrement: () {},
                                onQuantitySet: (_) {},
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
    );
  }

  // ═════════════════════════════════════════════════════════════
  // TALL DARK HEADER WITH SHOP DETAIL CARD INSIDE
  // ═════════════════════════════════════════════════════════════
  Widget _buildTallHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

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
      padding: EdgeInsets.fromLTRB(4, topPadding + 4, 4, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation Row (matching CustomAppBar)
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: isUrdu ? 'پیچھے جائیں' : 'Back',
              ),
              Expanded(
                child: UrduAwareText(
                  _shop.name,
                  style: TextStyle(
                    fontSize: isUrdu ? 20 : 18,
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                    color: Colors.white,
                    fontFamily: fontFamily,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSearchVisible
                      ? PhosphorIcons.x()
                      : PhosphorIcons.magnifyingGlass(),
                  color: Colors.white,
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
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Shop Header Card INSIDE Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildShopDetailHeaderCard(_shop),
          ),
        ],
      ),
    );
  }

  Widget _buildShopDetailHeaderCard(Shop shop) {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final hasBanner = shop.bannerImageUrl != null &&
        shop.bannerImageUrl!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                        name: shop.owner.isNotEmpty ? shop.owner : shop.name,
                        phone: shop.area.isNotEmpty ? shop.area : shop.name,
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

                // Mini Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniHeaderStatWidget(
                      LocationChipWidget(
                        latitude: shop.latitude,
                        longitude: shop.longitude,
                        address: shop.area,
                        showAddress: false,
                        showTime: false,
                        isUrdu: isUrdu,
                        isChip: false,
                        color: Colors.white,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _miniHeaderStatWidget(Widget valueWidget, String label) {
    return Column(
      children: [
        valueWidget,
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
