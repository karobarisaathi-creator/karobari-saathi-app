// lib/features/order/nearby_shops_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/features/order/shop_detail_screen.dart';
import 'package:account_app/features/order/widgets/shop_card_widget.dart';
import 'package:account_app/features/order/widgets/shop_catalog_item_card.dart';
import 'package:account_app/features/order/widgets/item_detail_dialog.dart';

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN: NEARBY SHOPS LIST
// ═══════════════════════════════════════════════════════════════
class OrderSelectionScreen extends StatefulWidget {
  const OrderSelectionScreen({super.key});

  @override
  State<OrderSelectionScreen> createState() => _OrderSelectionScreenState();
}

class _OrderSelectionScreenState extends State<OrderSelectionScreen> {
  String _shopQuery = '';
  String _sortBy = 'recent';
  bool _isSearchVisible = false;
  bool _openShopsOnly = false;
  bool _isLoading = false;
  String? _loadError;

  final TextEditingController _searchCtrl = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Shop> _shops = const [];

  @override
  void initState() {
    super.initState();
    _loadPublicShops();
  }

  Future<void> _loadPublicShops() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('public_shops')
          .orderBy('updatedAt', descending: true)
          .get();

      if (!mounted) return;
      final loaded = snapshot.docs
          .where((doc) =>
              doc.data()['role'] == 'shopkeeper' &&
              doc.id != FirebaseAuth.instance.currentUser?.uid)
          .map((doc) => _shopFromMap(doc.id, doc.data()))
          .where((shop) => shop.name.trim().isNotEmpty)
          .toList();

      _shops = loaded;
      _loadError = null;
    } catch (error) {
      if (!mounted) return;
      _shops = [];
      _loadError = error.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Shop _shopFromMap(String id, Map<String, dynamic> data) {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final name =
        (data['shopName'] ?? data['displayName'] ?? (isUrdu ? 'دکان' : 'Shop'))
            .toString();
    final owner = (data['ownerName'] ?? data['displayName'] ?? '').toString();
    final area = (data['businessAddress'] ?? '').toString();
    final tags = (data['tags'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList();

    return Shop(
      id: id,
      name: name,
      logoEmoji: '🛒',
      owner: owner,
      area: area,
      distance: (data['distance'] ?? '').toString(),
      distanceVal: (data['distanceVal'] is num)
          ? (data['distanceVal'] as num).toDouble()
          : double.infinity,
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0,
      reviews: (data['reviews'] is num) ? (data['reviews'] as num).toInt() : 0,
      deliveryTime: (data['deliveryTime'] ?? '').toString(),
      timeVal: (data['timeVal'] is num) ? (data['timeVal'] as num).toInt() : 0,
      minOrder: (data['minOrder'] ?? '').toString(),
      deliveryFee: (data['deliveryFee'] ?? '').toString(),
      isOpen: data['isOpen'] == true,
      tags: tags,
      items: const [],
      itemCount: (data['itemCount'] as num?)?.toInt() ?? 0,
      showOwnerName: data['showOwnerName'] != false,
      showArea: data['showArea'] != false,
      showDistance: data['showDistance'] != false,
      showDeliveryInfo: data['showDeliveryInfo'] != false,
      showRating: data['showRating'] != false,
      showItemsCount: data['showItemsCount'] != false,
      showTags: data['showTags'] == true,
      latitude: (data['latitude'] is num)
          ? (data['latitude'] as num).toDouble()
          : (data['lat'] is num)
              ? (data['lat'] as num).toDouble()
              : null,
      longitude: (data['longitude'] is num)
          ? (data['longitude'] as num).toDouble()
          : (data['lng'] is num)
              ? (data['lng'] as num).toDouble()
              : (data['lon'] is num)
                  ? (data['lon'] as num).toDouble()
                  : null,
      bannerImageUrl:
          (data['bannerImageUrl'] ?? data['shopBannerUrl'] ?? '').toString(),
      profileImageUrl:
          (data['profileImageUrl'] ?? data['photoURL'] ?? '').toString(),
    );
  }

  // ═════════════════════════════════════════════════════════════
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openShopDetail(Shop shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(shop: shop),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'قریبی دکاندار' : 'Nearby Shops',
        showBackButton: Navigator.canPop(context),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible
                  ? PhosphorIcons.x()
                  : PhosphorIcons.magnifyingGlass(),
            ),
            tooltip: _isSearchVisible
                ? (isUrdu ? 'بند کریں' : 'Close search')
                : (isUrdu ? 'تلاش کریں' : 'Search'),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchCtrl.clear();
                  _shopQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_isSearchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SearchSortBar(
                  controller: _searchCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  hintText: isUrdu
                      ? 'دکان، مالک یا علاقہ تلاش کریں...'
                      : 'Search shops, owners, or areas...',
                  onSearchChanged: (v) {
                    setState(() => _shopQuery = v);
                  },
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: UrduAwareText(
                              isUrdu
                                  ? 'دکاندار لوڈ نہیں ہو سکے: $_loadError'
                                  : 'Could not load shops: $_loadError',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _buildShopListScreen(isUrdu, fontFamily),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // SHOP LIST
  // ═════════════════════════════════════════════════════════════
  Widget _buildShopListScreen(bool isUrdu, String? fontFamily) {
    // Filter & Sort
    final filtered = _shops.where((s) {
      if (_openShopsOnly && !s.isOpen) return false;
      if (_shopQuery.isEmpty) return true;
      return s.name.contains(_shopQuery) ||
          s.owner.contains(_shopQuery) ||
          s.area.contains(_shopQuery);
    }).toList();

    if (_sortBy == 'rating') {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'time') {
      filtered.sort((a, b) => a.timeVal.compareTo(b.timeVal));
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        // Sort chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildSortChip(
                'recent',
                isUrdu ? 'نئی دکانیں' : 'Recent',
                PhosphorIcons.mapPin(),
                fontFamily: fontFamily,
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                'rating',
                isUrdu ? 'زیادہ ریٹنگ' : 'Top rated',
                PhosphorIcons.star(),
                fontFamily: fontFamily,
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                'time',
                isUrdu ? 'جلد ڈیلیوری' : 'Fast delivery',
                PhosphorIcons.clock(),
                fontFamily: fontFamily,
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                'open',
                isUrdu ? 'کھلی دکانیں' : 'Open shops',
                PhosphorIcons.storefront(),
                isOpenFilter: true,
                fontFamily: fontFamily,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // List using ShopSectionWidget (Shop Card + Horizontal Item Cards)
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: PhosphorIcons.magnifyingGlass(),
                  title: isUrdu ? 'کوئی دکان نہیں ملی' : 'No shops found',
                  sub: isUrdu ? 'دوسرا نام آزمائیں' : 'Try another search',
                  fontFamily: fontFamily,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _ShopSectionWidget(
                    shop: filtered[i],
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    onTap: () => _openShopDetail(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSortChip(
    String value,
    String label,
    IconData icon, {
    bool isOpenFilter = false,
    String? fontFamily,
  }) {
    final isActive = isOpenFilter ? _openShopsOnly : _sortBy == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          if (isOpenFilter) {
            _openShopsOnly = !_openShopsOnly;
          } else {
            _sortBy = value;
          }
        }),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.darkColor : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive ? AppTheme.darkColor : AppTheme.backgroundColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppTheme.textSecondary,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String sub,
    String? fontFamily,
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
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 6),
          UrduAwareText(
            sub,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopSectionWidget extends StatefulWidget {
  final Shop shop;
  final bool isUrdu;
  final String? fontFamily;
  final VoidCallback onTap;

  const _ShopSectionWidget({
    required this.shop,
    required this.isUrdu,
    required this.fontFamily,
    required this.onTap,
  });

  @override
  State<_ShopSectionWidget> createState() => _ShopSectionWidgetState();
}

class _ShopSectionWidgetState extends State<_ShopSectionWidget> {
  List<ShopItem> _items = [];
  bool _isLoadingItems = true;

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
    'عام': 'عام',
  };

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  void _fetchItems() {
    FirebaseFirestore.instance
        .collection('public_shops')
        .doc(widget.shop.id)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final items = snapshot.docs.map((doc) {
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
          rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
          stock: tracksStock ? (quantity ?? 0) : 1000000000,
        );
      }).where((item) => item.name.trim().isNotEmpty).toList();

      if (mounted) {
        setState(() {
          _items = items;
          _isLoadingItems = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _isLoadingItems = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _items.isNotEmpty ? _items.length : widget.shop.availableItemCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                UrduAwareText(
                  '🏪 ${widget.shop.name} · $totalCount ${widget.isUrdu ? 'اشیاء' : 'items'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    fontFamily: widget.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 270,
            child: _isLoadingItems
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: 1 + _items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return SizedBox(
                          width: 260,
                          height: 270,
                          child: ShopCardWidget(
                            shop: widget.shop.copyWith(items: _items, itemCount: totalCount),
                            onTap: widget.onTap,
                          ),
                        );
                      }
                      final item = _items[index - 1];
                      return SizedBox(
                        width: 260,
                        height: 270,
                        child: ShopCatalogItemCard(
                          item: item,
                          onTap: () => _showItemDetailModal(context, item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showItemDetailModal(BuildContext context, ShopItem item) {
    showItemDetailDialog(context, item);
  }
}
