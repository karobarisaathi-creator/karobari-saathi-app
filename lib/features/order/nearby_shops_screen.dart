// lib/features/order/nearby_shops_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/features/order/shop_detail_screen.dart';
import 'package:account_app/features/order/widgets/shop_card_widget.dart';

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
    final name = (data['shopName'] ?? data['displayName'] ?? 'دکان').toString();
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
      rating: (data['rating'] is num)
          ? (data['rating'] as num).toDouble()
          : 0,
      reviews: (data['reviews'] is num)
          ? (data['reviews'] as num).toInt()
          : 0,
      deliveryTime: (data['deliveryTime'] ?? '').toString(),
      timeVal: (data['timeVal'] is num)
          ? (data['timeVal'] as num).toInt()
          : 0,
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
      bannerImageUrl: (data['bannerImageUrl'] ?? data['shopBannerUrl'] ?? '').toString(),
      profileImageUrl: (data['profileImageUrl'] ?? data['photoURL'] ?? '').toString(),
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'قریبی دکاندار',
        showBackButton: Navigator.canPop(context),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible
                  ? PhosphorIcons.x()
                  : PhosphorIcons.magnifyingGlass(),
            ),
            tooltip: _isSearchVisible ? 'بند کریں' : 'تلاش کریں',
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
                  hintText: 'دکان، مالک یا علاقہ تلاش کریں...',
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
                              'دکاندار لوڈ نہیں ہو سکے: $_loadError',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _buildShopListScreen(),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // SHOP LIST
  // ═════════════════════════════════════════════════════════════
  Widget _buildShopListScreen() {
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
                'نئی دکانیں',
                PhosphorIcons.mapPin(),
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                'rating',
                'زیادہ ریٹنگ',
                PhosphorIcons.star(),
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                'time',
                'جلد ڈیلیوری',
                PhosphorIcons.clock(),
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                'open',
                'کھلی دکانیں',
                PhosphorIcons.storefront(),
                isOpenFilter: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // List using ShopCardWidget
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: PhosphorIcons.magnifyingGlass(),
                  title: 'کوئی دکان نہیں ملی',
                  sub: 'دوسرا نام آزمائیں',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => ShopCardWidget(
                    shop: filtered[i],
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
                  fontFamily: 'NooriNastaleeq',
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
              fontFamily: 'NooriNastaleeq',
            ),
          ),
          const SizedBox(height: 6),
          UrduAwareText(
            sub,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontFamily: 'NooriNastaleeq',
            ),
          ),
        ],
      ),
    );
  }
}
