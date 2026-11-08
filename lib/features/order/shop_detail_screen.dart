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
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';
import 'package:account_app/features/order/order_preview_screen.dart';
import 'package:account_app/features/order/widgets/shop_item_card_widget.dart';
import 'package:account_app/features/order/widgets/trust_popup_dialog.dart';

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _shopRatingSubscription;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
    _listenToPublicItems();
    _listenToShopTrust();
  }

  void _listenToShopTrust() {
    final shopRef =
        FirebaseFirestore.instance.collection('public_shops').doc(_shop.id);
    _shopRatingSubscription = shopRef.snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        if (!mounted) return;
        setState(() {
          if (data != null) {
            _shop = _shop.copyWith(
              customerCount: (data['customerCount'] as num?)?.toInt() ??
                  _shop.customerCount,
              satisfiedCustomerPercent:
                  (data['quickBillSatisfactionPercent'] as num?)?.toInt() ??
                      _shop.satisfiedCustomerPercent,
              billCount:
                  (data['quickBillCount'] as num?)?.toInt() ?? _shop.billCount,
              showTrust: data['showTrust'] != false,
            );
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        debugPrint('Could not load shop trust info: $error');
      },
    );
  }

  void _listenToPublicItems() {
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
              final brandVal = (data['brand'] ?? '').toString();
              final modelVal = (data['model'] ?? '').toString();
              final allowReturnVal = data['allowReturn'] == true;
              final rawImages = data['images'];
              List<String> imagesList = [];
              if (rawImages is List) {
                imagesList = rawImages
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty && e.length > 4)
                    .toList();
              }
              return ShopItem(
                id: doc.id,
                stockItemId: doc.id,
                name: (data['name'] ?? '').toString(),
                nameUrdu: (data['nameUrdu'] ?? '').toString(),
                description: (data['description'] ?? '').toString(),
                brand: brandVal.isNotEmpty ? brandVal : null,
                model: modelVal.isNotEmpty ? modelVal : null,
                allowReturn: allowReturnVal,
                rate: (data['rate'] as num?)?.toDouble() ?? 0,
                oldRate: (data['oldRate'] as num?)?.toDouble(),
                unit: (data['unit'] ?? '').toString(),
                emoji: '📦',
                category: (data['category'] ?? 'عام').toString(),
                imageUrl: (data['imageUrl'] ?? '').toString(),
                images: imagesList,
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
    _shopRatingSubscription?.cancel();
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
                  hintText: isUrdu ? 'آئٹم تلاش کریں...' : 'Search items...',
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
                        ? _buildShimmerCatalogGrid()
                        : _itemsError != null
                            ? Center(
                                child: UrduAwareText(
                                  isUrdu
                                      ? 'اشیاء لوڈ نہیں ہو سکیں: $_itemsError'
                                      : 'Could not load items: $_itemsError',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : filtered.isEmpty
                                ? _buildEmptyState(
                                    icon: PhosphorIcons.magnifyingGlass(),
                                    title: isUrdu
                                        ? 'کوئی آئٹم نہیں ملا'
                                        : 'No items found',
                                    sub: isUrdu
                                        ? 'دوسری کیٹیگری آزمائیں'
                                        : 'Try another category',
                                  )
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 4, 8, 100),
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

  Widget? _buildBottomCartBar(BuildContext context, bool isUrdu) {
    final selectedItems = _shop.items.where((i) => i.quantity > 0).toList();
    if (selectedItems.isEmpty) return null;

    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final totalCount = selectedItems.fold<double>(
        0, (quantityTotal, item) => quantityTotal + item.quantity);
    final totalPrice =
        selectedItems.fold<double>(0, (amount, item) => amount + item.total);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  isUrdu
                      ? '${totalCount.toInt()} اشیاء منتخب'
                      : '${totalCount.toInt()} items selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                UrduAwareText(
                  Formatters.formatAmountWithCurrency(totalPrice),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.themeColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AppButton(
              text: isUrdu ? 'آرڈر کا جائزہ لیں' : 'Preview Order',
              icon: PhosphorIcons.shoppingCartSimple(),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderPreviewScreen(
                      shop: _shop,
                      selectedItems: selectedItems,
                      isUrdu: isUrdu,
                    ),
                  ),
                );
                if (result == true) {
                  setState(() {
                    for (var item in _shop.items) {
                      item.quantity = 0;
                    }
                  });
                }
              },
            ),
          ),
        ],
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
                tooltip: _isSearchVisible
                    ? (isUrdu ? 'بند کریں' : 'Close search')
                    : (isUrdu ? 'تلاش کریں' : 'Search'),
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
    final hasBanner =
        shop.bannerImageUrl != null && shop.bannerImageUrl!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
                          phone: '',
                          address: shop.area,
                          profileImage: shop.profileImageUrl,
                          isLarge: true,
                          customSize: 48,
                          borderRadius: 14,
                          textColor: Colors.white,
                          subtitleColor: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => TrustPopupDialog.show(
                          context: context,
                          shopName: shop.name,
                          ownerName: shop.owner,
                          area: shop.area,
                          customerCount: shop.customerCount,
                          satisfiedCustomerPercent:
                              shop.satisfiedCustomerPercent,
                          billCount: shop.billCount,
                          itemsCount: shop.availableItemCount,
                          isUrdu: isUrdu,
                        ),
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
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
                                PhosphorIcons.shieldCheck(
                                    PhosphorIconsStyle.fill),
                                size: 11,
                                color: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 3),
                              UrduAwareText(
                                '${shop.satisfiedCustomerPercent}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
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
                        isUrdu ? 'فاصلہ' : 'Distance',
                      ),
                      _miniHeaderStat(
                        PhosphorIcons.clock(),
                        shop.deliveryTime,
                        isUrdu ? 'ڈیلیوری وقت' : 'Delivery time',
                      ),
                      _miniHeaderStat(
                        PhosphorIcons.truck(),
                        shop.deliveryFee,
                        isUrdu ? 'ڈیلیوری چارجز' : 'Delivery fee',
                      ),
                      _miniHeaderStat(
                        PhosphorIcons.package(),
                        '${shop.items.length}',
                        isUrdu ? 'کل اشیاء' : 'Items',
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

  Widget _buildShimmerCatalogGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.backgroundColor,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonShimmer(
              width: double.infinity,
              height: 110,
              borderRadius: 0,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonShimmer(
                    width: 120,
                    height: 14,
                    borderRadius: 6,
                  ),
                  SizedBox(height: 8),
                  SkeletonShimmer(
                    width: 80,
                    height: 14,
                    borderRadius: 6,
                  ),
                  SizedBox(height: 12),
                  SkeletonShimmer(
                    width: 60,
                    height: 10,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
