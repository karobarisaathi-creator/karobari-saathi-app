// lib/features/order/shop_detail_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';
import 'package:account_app/features/order/order_preview_screen.dart';
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
  double _communityRating = 0;
  int _communityReviewCount = 0;
  double? _myRating;
  bool _isLoadingRating = true;
  bool _isSavingRating = false;
  String? _ratingError;

  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _itemsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _shopRatingSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _myRatingSubscription;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
    _listenToPublicItems();
    _listenToShopRating();
  }

  void _listenToShopRating() {
    final shopRef =
        FirebaseFirestore.instance.collection('public_shops').doc(_shop.id);
    _shopRatingSubscription = shopRef.snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        if (!mounted) return;
        setState(() {
          _communityRating =
              (data?['communityRating'] as num?)?.toDouble() ?? 0;
          _communityReviewCount =
              (data?['communityReviewCount'] as num?)?.toInt() ?? 0;
          _isLoadingRating = false;
          _ratingError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoadingRating = false;
          _ratingError = error.toString();
        });
      },
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == _shop.id) return;
    _myRatingSubscription =
        shopRef.collection('reviews').doc(user.uid).snapshots().listen(
      (snapshot) {
        final rating = snapshot.data()?['rating'];
        if (!mounted) return;
        setState(() {
          _myRating = rating is num ? rating.toDouble() : null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        debugPrint('Could not load the current user shop rating: $error');
      },
    );
  }

  Future<void> _showRatingDialog(bool isUrdu) async {
    final user = FirebaseAuth.instance.currentUser;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    if (user == null) {
      AppToast.warning(
        context,
        isUrdu
            ? 'ریٹنگ دینے کے لیے سائن اِن کریں'
            : 'Sign in to rate this shop',
      );
      return;
    }
    if (user.uid == _shop.id) {
      AppToast.warning(
        context,
        isUrdu
            ? 'آپ اپنی دکان کو ریٹ نہیں کر سکتے'
            : 'You cannot rate your own shop',
      );
      return;
    }

    final controller = TextEditingController();
    var selectedRating = _myRating?.round() ?? 0;
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: UrduAwareText(isUrdu ? 'دکان کو ریٹ کریں' : 'Rate this shop', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UrduAwareText(
                  isUrdu
                      ? 'اپنا تجربہ بتائیں — کمیونٹی ریٹنگ'
                      : 'Share your experience — Community rating',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: fontFamily),
                ),
                const SizedBox(height: 4),
                UrduAwareText(
                  isUrdu
                      ? 'ایک اکاؤنٹ سے ایک ریٹنگ؛ آپ بعد میں اسے بدل سکتے ہیں'
                      : 'One rating per account; you can update it later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: fontFamily, fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        tooltip: '${index + 1}',
                        visualDensity: VisualDensity.compact,
                        onPressed: _isSavingRating
                            ? null
                            : () => setDialogState(
                                  () => selectedRating = index + 1,
                                ),
                        icon: Icon(
                          index < selectedRating
                              ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                              : PhosphorIcons.star(),
                          color: AppTheme.verifiedGold,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: isUrdu ? 'تبصرہ (اختیاری)' : 'Review (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  _isSavingRating ? null : () => Navigator.pop(dialogContext),
              child: UrduAwareText(isUrdu ? 'واپس' : 'Cancel', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800)),
            ),
            FilledButton(
              onPressed: selectedRating == 0 || _isSavingRating
                  ? null
                  : () => Navigator.pop(dialogContext, {
                        'rating': selectedRating,
                        'comment': controller.text.trim(),
                      }),
              child: UrduAwareText(isUrdu ? 'جمع کریں' : 'Submit', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () => controller.dispose());
    if (result == null || !mounted) return;

    setState(() => _isSavingRating = true);
    try {
      await FirebaseFirestore.instance
          .collection('public_shops')
          .doc(_shop.id)
          .collection('reviews')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'rating': result['rating'],
        'comment': result['comment'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _myRating = (result['rating'] as int).toDouble());
      AppToast.success(
        context,
        isUrdu ? 'آپ کی ریٹنگ محفوظ ہوگئی' : 'Your rating was saved',
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        isUrdu
            ? 'ریٹنگ محفوظ نہیں ہوسکی: $error'
            : 'Could not save your rating: $error',
      );
    } finally {
      if (mounted) setState(() => _isSavingRating = false);
    }
  }

  void _showCommunityReviews(bool isUrdu) {
    final reviewsQuery = FirebaseFirestore.instance
        .collection('public_shops')
        .doc(_shop.id)
        .collection('reviews')
        .orderBy('updatedAt', descending: true)
        .limit(20);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: UrduAwareText(
                  isUrdu ? 'کمیونٹی ریویوز' : 'Community reviews',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: reviewsQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            isUrdu
                                ? 'ریویوز لوڈ نہیں ہوسکے: ${snapshot.error}'
                                : 'Could not load reviews: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final reviews = snapshot.data!.docs;
                    if (reviews.isEmpty) {
                      return Center(
                        child: Text(
                          isUrdu ? 'ابھی کوئی ریویو نہیں' : 'No reviews yet',
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final review = reviews[index].data();
                        final rating = (review['rating'] as num?)?.toInt() ?? 0;
                        final comment = (review['comment'] ?? '').toString();
                        return ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.star(PhosphorIconsStyle.fill),
                                color: AppTheme.verifiedGold,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text('$rating'),
                            ],
                          ),
                          title: Text(
                            comment.isEmpty
                                ? (isUrdu ? 'صرف ریٹنگ' : 'Rating only')
                                : comment,
                          ),
                          subtitle: Text(
                            isUrdu
                                ? 'کمیونٹی ریٹنگ — تصدیق شدہ خریداری نہیں'
                                : 'Community rating — not a verified purchase',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
    _myRatingSubscription?.cancel();
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

            _buildRatingSummary(isUrdu),

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

  Widget _buildRatingSummary(bool isUrdu) {
    final user = FirebaseAuth.instance.currentUser;
    final canRate = user != null && user.uid != _shop.id;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final ratingText = _isLoadingRating
        ? (isUrdu ? 'لوڈ ہو رہی ہے...' : 'Loading rating...')
        : _ratingError != null
            ? (isUrdu ? 'ریٹنگ لوڈ نہیں ہوسکی' : 'Could not load rating')
            : _communityReviewCount == 0
                ? (isUrdu ? 'ابھی کوئی ریٹنگ نہیں' : 'No ratings yet')
                : '${_communityRating.toStringAsFixed(1)} · $_communityReviewCount ${isUrdu ? 'ریٹنگز' : 'ratings'}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.backgroundColor),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.star(PhosphorIconsStyle.fill),
            color: AppTheme.verifiedGold,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  ratingText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
                if (_communityReviewCount > 0)
                  UrduAwareText(
                    isUrdu ? 'کمیونٹی ریٹنگ' : 'Community rating',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontFamily: fontFamily,
                    ),
                  ),
              ],
            ),
          ),
          if (_communityReviewCount > 0 || canRate)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_communityReviewCount > 0)
                  TextButton(
                    onPressed: () => _showCommunityReviews(isUrdu),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: UrduAwareText(
                      isUrdu ? 'ریویوز' : 'Reviews',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: fontFamily),
                    ),
                  ),
                if (canRate) ...[
                  if (_communityReviewCount > 0) const SizedBox(width: 4),
                  TextButton(
                    onPressed: _isSavingRating
                        ? null
                        : () => _showRatingDialog(isUrdu),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: UrduAwareText(
                      _myRating == null
                          ? (isUrdu ? 'ریٹ کریں' : 'Rate')
                          : (isUrdu
                              ? '${_myRating!.toInt()}★'
                              : '${_myRating!.toInt()}★'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: fontFamily),
                    ),
                  ),
                ],
              ],
            ),
        ],
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
                              _communityReviewCount == 0
                                  ? '—'
                                  : _communityRating.toStringAsFixed(1),
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
