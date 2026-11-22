// lib/features/order/nearby_businesses_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/models/contractor_company_model.dart';
import 'package:account_app/core/services/location_service.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';
import 'package:account_app/features/order/shop_detail_screen.dart';
import 'package:account_app/features/order/widgets/shop_card_widget.dart';
import 'package:account_app/features/order/widgets/contractor_company_card_widget.dart';

// ═══════════════════════════════════════════════════════════════
// IN-MEMORY CACHE FOR NEARBY BUSINESSES
// ═══════════════════════════════════════════════════════════════
class _NearbyShopsCache {
  static List<Shop>? cachedShops;
  static DateTime? lastShopsFetchTime;

  static bool isShopsCacheValid({Duration ttl = const Duration(minutes: 5)}) {
    if (cachedShops == null || lastShopsFetchTime == null) return false;
    return DateTime.now().difference(lastShopsFetchTime!) < ttl;
  }
}

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN: NEARBY BUSINESSES LIST
// ═══════════════════════════════════════════════════════════════
class NearbyBusinessesScreen extends StatefulWidget {
  const NearbyBusinessesScreen({super.key});

  @override
  State<NearbyBusinessesScreen> createState() => _NearbyBusinessesScreenState();
}

class _NearbyBusinessesScreenState extends State<NearbyBusinessesScreen> {
  String _shopQuery = '';
  String _sortBy = 'recent';
  bool _isSearchVisible = false;
  bool _openShopsOnly = false;
  bool _isLoading = false;
  String? _loadError;
  double? _userLatitude;
  double? _userLongitude;

  final TextEditingController _searchCtrl = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Shop> _shops = const [];
  List<ContractorCompany> _contractorCompanies = const [];
  String? _contractorLoadError;

  @override
  void initState() {
    super.initState();
    _loadPublicShops();
    _loadPublicContractors();
    unawaited(_loadCurrentLocation());
  }

  Future<void> _loadPublicContractors() async {
    try {
      final snapshot = await _firestore
          .collection('public_contractors')
          .orderBy('updatedAt', descending: true)
          .limit(30)
          .get();
      if (!mounted) return;

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final companies = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) => ContractorCompany.fromMap(doc.id, doc.data()))
          .where((company) =>
              company.name.isNotEmpty && company.businessArea.isNotEmpty)
          .toList();
      setState(() {
        _contractorCompanies = companies;
        _contractorLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _contractorLoadError = error.toString());
    }
  }

  Future<void> _refreshNearbyBusinesses() async {
    await Future.wait([
      _loadPublicShops(forceRefresh: true),
      _loadPublicContractors(),
    ]);
  }

  Future<void> _loadCurrentLocation() async {
    final coordinates = await LocationService.getCurrentCoordinates();
    if (!mounted || coordinates == null) return;
    setState(() {
      _userLatitude = coordinates['latitude'];
      _userLongitude = coordinates['longitude'];
    });
  }

  Future<void> _loadPublicShops({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Check in-memory cache first for instant 0ms load time
    if (!forceRefresh && _NearbyShopsCache.isShopsCacheValid()) {
      setState(() {
        _shops = _NearbyShopsCache.cachedShops!;
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    if (_NearbyShopsCache.cachedShops != null && !forceRefresh) {
      _shops = _NearbyShopsCache.cachedShops!;
    } else if (_NearbyShopsCache.cachedShops == null) {
      setState(() => _isLoading = true);
    }

    try {
      final snapshot = await _firestore
          .collection('public_shops')
          .orderBy('updatedAt', descending: true)
          .limit(30)
          .get();

      if (!mounted) return;
      final loaded = snapshot.docs
          .where((doc) =>
              doc.data()['role'] == 'shopkeeper' &&
              doc.id != FirebaseAuth.instance.currentUser?.uid)
          .map((doc) => _shopFromMap(doc.id, doc.data()))
          .where((shop) => shop.name.trim().isNotEmpty)
          .toList();

      _NearbyShopsCache.cachedShops = loaded;
      _NearbyShopsCache.lastShopsFetchTime = DateTime.now();

      _shops = loaded;
      _loadError = null;
    } catch (error) {
      if (!mounted) return;
      if (_NearbyShopsCache.cachedShops != null) {
        _shops = _NearbyShopsCache.cachedShops!;
        _loadError = null;
      } else {
        _shops = [];
        _loadError = error.toString();
      }
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

  double _distanceForShop(Shop shop) {
    if (_userLatitude != null &&
        _userLongitude != null &&
        shop.latitude != null &&
        shop.longitude != null) {
      return Geolocator.distanceBetween(
        _userLatitude!,
        _userLongitude!,
        shop.latitude!,
        shop.longitude!,
      );
    }
    return shop.distanceVal;
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
      appBar: ScreenAppBar(
        title: isUrdu ? 'قریبی کاروبار' : 'Nearby Businesses',
        isUrdu: isUrdu,
        actions: [
          IconButton(
            tooltip: _isSearchVisible
                ? (isUrdu ? 'تلاش بند کریں' : 'Close search')
                : (isUrdu ? 'تلاش کریں' : 'Search'),
            icon: Icon(
              _isSearchVisible
                  ? PhosphorIcons.x()
                  : PhosphorIcons.magnifyingGlass(),
            ),
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
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  if (_isSearchVisible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: SearchSortBar(
                        controller: _searchCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        hintText: isUrdu
                            ? 'دکان، کمپنی یا علاقہ تلاش کریں...'
                            : 'Search shops, companies, or areas...',
                        onSearchChanged: (value) {
                          setState(() => _shopQuery = value);
                        },
                      ),
                    ),
                  Expanded(
                    child: _isLoading
                        ? _buildShimmerLoadingList()
                        : _loadError != null &&
                                _shops.isEmpty &&
                                _contractorCompanies.isEmpty
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

    if (_sortBy == 'time') {
      filtered.sort((a, b) => a.timeVal.compareTo(b.timeVal));
    } else if (_sortBy == 'nearest') {
      filtered
          .sort((a, b) => _distanceForShop(a).compareTo(_distanceForShop(b)));
    }

    final filteredCompanies = _contractorCompanies.where((company) {
      if (_shopQuery.isEmpty) return true;
      return company.name.contains(_shopQuery) ||
          company.businessArea.contains(_shopQuery);
    }).toList();
    final hasContent = filtered.isNotEmpty ||
        filteredCompanies.isNotEmpty ||
        _contractorLoadError != null ||
        _loadError != null;

    return Column(
      children: [
        const SizedBox(height: 10),
        // Sort Connected Segmented Bar (Matching Quick Bill Category Strip Design)
        _buildSortSegmentedBar(isUrdu, fontFamily),

        const SizedBox(height: 8),

        // Full-width shop cards
        Expanded(
          child: !hasContent
              ? _buildEmptyState(
                  icon: PhosphorIcons.magnifyingGlass(),
                  title: isUrdu
                      ? 'کوئی دکان یا کمپنی نہیں ملی'
                      : 'No shops or companies found',
                  sub: isUrdu ? 'دوسرا نام آزمائیں' : 'Try another search',
                  fontFamily: fontFamily,
                )
              : RefreshIndicator(
                  color: AppTheme.themeColor,
                  onRefresh: _refreshNearbyBusinesses,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    children: [
                      if (_loadError != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: UrduAwareText(
                            isUrdu
                                ? 'دکانیں لوڈ نہیں ہو سکیں: $_loadError'
                                : 'Could not load shops: $_loadError',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.expenseColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ...filtered.map(
                        (shop) => _ShopSectionWidget(
                          key: ValueKey(shop.id),
                          shop: shop,
                          onTap: () => _openShopDetail(shop),
                        ),
                      ),
                      if (filteredCompanies.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                          child: UrduAwareText(
                            isUrdu
                                ? 'قریبی ٹھیکہ دار کمپنیاں'
                                : 'Contractor Companies',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        ),
                        ...filteredCompanies.map(
                          (company) => ContractorCompanyCardWidget(
                            key: ValueKey('contractor-${company.id}'),
                            company: company,
                          ),
                        ),
                      ],
                      if (_contractorLoadError != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: UrduAwareText(
                            isUrdu
                                ? 'ٹھیکہ دار کمپنیاں لوڈ نہیں ہو سکیں: $_contractorLoadError'
                                : 'Could not load contractor companies: $_contractorLoadError',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.expenseColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSortSegmentedBar(bool isUrdu, String? fontFamily) {
    final sortOptions = [
      (
        'recent',
        isUrdu ? 'نئی دکانیں' : 'Recent',
        PhosphorIcons.mapPin(),
        false
      ),
      (
        'nearest',
        isUrdu ? 'قریبی ترین' : 'Nearest',
        PhosphorIcons.navigationArrow(),
        false
      ),
      (
        'time',
        isUrdu ? 'جلد ڈیلیوری' : 'Fast delivery',
        PhosphorIcons.clock(),
        false
      ),
      (
        'open',
        isUrdu ? 'کھلی دکانیں' : 'Open shops',
        PhosphorIcons.storefront(),
        true
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < sortOptions.length; i++) ...[
                  if (i > 0)
                    Container(width: 1, color: const Color(0xFFE2E8F0)),
                  _buildCategorySegment(
                    label: sortOptions[i].$2,
                    icon: sortOptions[i].$3,
                    isActive: sortOptions[i].$4
                        ? _openShopsOnly
                        : _sortBy == sortOptions[i].$1,
                    fontFamily: fontFamily,
                    onTap: () => setState(() {
                      if (sortOptions[i].$4) {
                        _openShopsOnly = !_openShopsOnly;
                      } else {
                        _sortBy = sortOptions[i].$1;
                      }
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySegment({
    required String label,
    required IconData icon,
    required bool isActive,
    required String? fontFamily,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive ? AppTheme.themeColor : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.darkColor,
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

  Widget _buildShimmerLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonShimmer(width: 180, height: 16, borderRadius: 6),
              const SizedBox(height: 10),
              SizedBox(
                height: 270,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => Container(
                    width: 290,
                    height: 270,
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
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SkeletonShimmer(
                                width: 160,
                                height: 16,
                                borderRadius: 6,
                              ),
                              SizedBox(height: 8),
                              SkeletonShimmer(
                                width: 120,
                                height: 14,
                                borderRadius: 6,
                              ),
                              SizedBox(height: 16),
                              SkeletonShimmer(
                                width: 200,
                                height: 12,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SkeletonShimmer(
                                    width: 100,
                                    height: 14,
                                    borderRadius: 6,
                                  ),
                                  SkeletonShimmer(
                                    width: 60,
                                    height: 14,
                                    borderRadius: 6,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShopSectionWidget extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;

  const _ShopSectionWidget({
    super.key,
    required this.shop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      height: 270,
      child: ShopCardWidget(
        shop: shop,
        onTap: onTap,
      ),
    );
  }
}
