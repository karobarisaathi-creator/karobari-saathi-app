import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/product_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/app_filter_chip.dart';
import 'item_detail_screen.dart';
import 'add_inventory_item_screen.dart';

enum ViewMode { grid, list }

class SellerItemsScreen extends StatefulWidget {
  final String sellerUid;
  final String sellerName;
  final Map<String, String>? initialProfile;

  const SellerItemsScreen({
    super.key,
    required this.sellerUid,
    required this.sellerName,
    this.initialProfile,
  });

  @override
  State<SellerItemsScreen> createState() => _SellerItemsScreenState();
}

class _SellerItemsScreenState extends State<SellerItemsScreen> {
  List<InventoryItem> _items = [];
  List<InventoryItem> _filteredItems = [];
  List<InventoryItem> _bannerItems = [];
  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.grid;
  Map<String, String>? _sellerProfile;
  String? _storeName;
  String? _storeImage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isAscending = true;

  // Banner Slider Controller & Timer
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  String _getFont(String? text, bool isAppUrdu) {
    if (!isAppUrdu || text == null || text.isEmpty) return '';
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'NooriNastaleeq' : '';
  }

  @override
  void initState() {
    super.initState();
    _sellerProfile = widget.initialProfile;
    _loadData();
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_bannerItems.isNotEmpty && _bannerController.hasClients) {
        _currentBannerPage = (_currentBannerPage + 1) % _bannerItems.length;
        _bannerController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final cachedItems = db.getRemoteCachedItems(widget.sellerUid);
    if (cachedItems.isNotEmpty && mounted) {
      setState(() {
        _items = cachedItems.where((item) => item.accountId == widget.sellerUid).toList();
        _isLoading = false;
        _applyFilters();
      });
    }

    final profile = await db.findPublicProfileByUid(widget.sellerUid);
    final fetchedItems = await db.getRemoteInventoryItems(widget.sellerUid);
    
    if (mounted) {
      setState(() {
        _sellerProfile = profile;
        if (FirebaseAuth.instance.currentUser?.uid == widget.sellerUid) {
          _storeName = profile?['storeName'];
          _storeImage = profile?['storeImage'];
        }
        _items = fetchedItems;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      final filtered = _items.where((item) {
        final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesSearch;
      }).toList();

      // Apply sorting for the main list
      filtered.sort((a, b) => _isAscending 
          ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : b.name.toLowerCase().compareTo(a.name.toLowerCase()));

      _filteredItems = filtered;

      // Logic for Smart Banner (Featured > Most Liked > Latest)
      final sortedForBanner = List<InventoryItem>.from(_items);
      sortedForBanner.sort((a, b) {
        // 1. Featured first
        if (a.isFeatured && !b.isFeatured) return -1;
        if (!a.isFeatured && b.isFeatured) return 1;
        
        // 2. Most liked
        if (a.likes != b.likes) return b.likes.compareTo(a.likes);
        
        // 3. Latest created
        return b.createdAt.compareTo(a.createdAt);
      });

      _bannerItems = sortedForBanner.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.sellerUid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildTopAppBar(isUrdu, fontFamily),
                        SearchSortBar(
                          controller: _searchController,
                          hintText: isUrdu ? 'آئٹم تلاش کریں...' : 'Search items...',
                          onSearchChanged: (v) {
                            _searchQuery = v;
                            _applyFilters();
                          },
                          onSortToggled: () {
                            setState(() {
                              _isAscending = !_isAscending;
                              _applyFilters();
                            });
                          },
                          isAscending: _isAscending,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (_bannerItems.isNotEmpty) _buildFeaturedBanner(isUrdu, fontFamily),
                        _buildSectionHeader(isUrdu, fontFamily),
                        _filteredItems.isEmpty
                            ? _buildEmptyState(isUrdu, fontFamily)
                            : _buildProductsList(isUrdu, fontFamily, isOwner),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isOwner ? _buildBottomAction(isUrdu, fontFamily) : null,
    );
  }

  Widget _buildTopAppBar(bool isUrdu, String fontFamily) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isMe = user?.uid == widget.sellerUid;
    final myAccount = isMe ? Provider.of<DatabaseService>(context, listen: false).getAccount(user?.uid ?? '') : null;
    
    // Priority logic: Firestore Profile > Local Hive Account > Firebase Auth > Fallback
    String displayName = isMe 
        ? (_storeName ?? myAccount?.storeName ?? myAccount?.name ?? user?.displayName ?? (isUrdu ? 'میرا اسٹور' : 'My Store'))
        : (_sellerProfile?['storeName'] ?? _sellerProfile?['name'] ?? widget.sellerName);
    
    // Final check to prevent "Unknown" flicker
    if (displayName.isEmpty || displayName == 'null') {
      displayName = isMe ? (isUrdu ? 'میرا اسٹور' : 'My Store') : widget.sellerName;
    }
    
    final String? photoUrl = isMe 
        ? (_storeImage ?? myAccount?.storeImage ?? myAccount?.profileImage ?? user?.photoURL)
        : (_sellerProfile?['storeImage'] ?? _sellerProfile?['photoUrl'] ?? '');

    final bool isVerified = isMe 
        ? myAccount?.isVerified ?? false
        : _sellerProfile?['isVerified'] == 'true' || _sellerProfile?['isVerified'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileInfoWidget(
            name: displayName,
            phone: '',
            profileImage: photoUrl,
            isVerified: isVerified,
            topLabel: isUrdu ? 'خوش آمدید' : 'Welcome Back 👋',
            isLarge: false,
            textColor: Colors.white,
            subtitleColor: Colors.white.withOpacity(0.7),
            isStore: true,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.verifiedGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.verifiedGold.withOpacity(0.4)),
                    ),
                    child: Text(
                      isUrdu ? 'تصدیق شدہ سیلر' : 'Verified Seller',
                      style: TextStyle(
                        color: AppTheme.verifiedGold,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                if (!isMe) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showReportSellerDialog(isUrdu, fontFamily),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.report_gmailerrorred, color: Colors.white60, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: () => _showCategoryPicker(isUrdu, fontFamily),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 24),
            label: Text(
              isUrdu ? 'نئی آئٹم شامل کریں' : 'Add New Item',
              style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  void _showReportSellerDialog(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUrdu ? 'سیلر کی رپورٹ کریں' : 'Report Seller',
          style: TextStyle(color: Colors.white, fontFamily: fontFamily),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption(isUrdu ? 'جعلی سیلر / فراڈ' : 'Fake Seller / Fraud', isUrdu, fontFamily),
            _buildReportOption(isUrdu ? 'بدتمیزی / غلط زبان' : 'Inappropriate Language', isUrdu, fontFamily),
            _buildReportOption(isUrdu ? 'غلط قیمتیں' : 'Misleading Prices', isUrdu, fontFamily),
            _buildReportOption(isUrdu ? 'دیگر مسائل' : 'Other Issues', isUrdu, fontFamily),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String label, bool isUrdu, String fontFamily) {
    return ListTile(
      title: Text(label, style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: fontFamily)),
      onTap: () async {
        Navigator.pop(context);
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        try {
          await FirebaseFirestore.instance.collection('seller_reports').add({
            'sellerUid': widget.sellerUid,
            'reporterUid': user.uid,
            'reason': label,
            'timestamp': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isUrdu ? 'رپورٹ جمع کر دی گئی ہے' : 'Report submitted')),
            );
          }
        } catch (e) {
          debugPrint("Report error: $e");
        }
      },
    );
  }

  Widget _buildFeaturedBanner(bool isUrdu, String fontFamily) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) => setState(() => _currentBannerPage = index),
            itemCount: _bannerItems.length,
            itemBuilder: (context, index) {
              final featured = _bannerItems[index];
              final String? photoUrl = featured.imagePaths.isNotEmpty ? featured.imagePaths.first : null;

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: featured))),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: photoUrl != null
                        ? DecorationImage(image: photoUrl.startsWith('http') ? CachedNetworkImageProvider(photoUrl) : FileImage(File(photoUrl)) as ImageProvider, fit: BoxFit.cover)
                        : null,
                    color: Colors.grey[200],
                  ),
                  child: Stack(
                    children: [
                      // Glass Box at Bottom
                      Positioned(
                        bottom: 15,
                        left: 15,
                        right: 15,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          featured.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${featured.rating} (${featured.likes})',
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(PhosphorIcons.mapPin(), color: Colors.white70, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        featured.location ?? "",
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Rs ${featured.defaultRate.toStringAsFixed(0)}',
                                        style: const TextStyle(color: AppTheme.goldColor, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bookmark/Featured Badge
                      if (featured.isFeatured)
                        Positioned(
                          top: 15,
                          left: 15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.goldColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isUrdu ? 'خاص' : 'Featured',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 15,
                        right: 15,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(PhosphorIcons.bookmarkSimple(), size: 20, color: AppTheme.darkColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Indicator Dots
        if (_bannerItems.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_bannerItems.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentBannerPage == index ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentBannerPage == index ? AppTheme.themeColor : Colors.grey[300],
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isUrdu ? 'تمام مصنوعات' : 'All Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: fontFamily),
          ),
          GestureDetector(
            onTap: () => setState(() => _viewMode = _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid),
            child: Row(
              children: [
                Icon(
                  _viewMode == ViewMode.grid ? PhosphorIcons.list() : PhosphorIcons.gridFour(),
                  color: AppTheme.themeColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  isUrdu ? (_viewMode == ViewMode.grid ? 'فہرست' : 'گرڈ') : (_viewMode == ViewMode.grid ? 'List' : 'Grid'),
                  style: TextStyle(fontSize: 13, color: AppTheme.themeColor, fontWeight: FontWeight.bold, fontFamily: fontFamily),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(bool isUrdu, String fontFamily, bool isOwner) {
    if (_viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return ProductCard(
            item: item,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            view: ProductCardView.grid,
            isMyItem: isOwner,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
              );
              _loadData();
            },
            onEdit: isOwner ? () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddInventoryItemScreen(itemToEdit: item),
                ),
              );
              if (result == true) _loadData();
            } : null,
            onDelete: isOwner ? () => _confirmDelete(item, isUrdu, fontFamily) : null,
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return ProductCard(
            item: item,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            view: ProductCardView.list,
            isMyItem: isOwner,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
              );
              _loadData();
            },
            onEdit: isOwner ? () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddInventoryItemScreen(itemToEdit: item),
                ),
              );
              if (result == true) _loadData();
            } : null,
            onDelete: isOwner ? () => _confirmDelete(item, isUrdu, fontFamily) : null,
          );
        },
      );
    }
  }

  void _confirmDelete(InventoryItem item, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'آئٹم ڈیلیٹ کریں؟' : 'Delete Item?', style: TextStyle(fontFamily: fontFamily)),
        content: Text(
          isUrdu ? 'کیا آپ واقعی اس آئٹم کو ختم کرنا چاہتے ہیں؟ یہ عمل واپس نہیں لیا جا سکے گا۔' : 'Are you sure you want to delete this item? This action cannot be undone.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'کینسل' : 'Cancel', style: TextStyle(fontFamily: fontFamily)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = Provider.of<DatabaseService>(context, listen: false);
              await db.deleteInventoryItem(item.id);
              _loadData();
            },
            child: Text(isUrdu ? 'ڈیلیٹ کریں' : 'Delete', style: TextStyle(color: Colors.red, fontFamily: fontFamily, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.package(), size: 64, color: Colors.grey[300]!),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی مصنوعات نہیں ملی' : 'No products found',
            style: TextStyle(color: Colors.grey[500], fontFamily: fontFamily, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(bool isUrdu, String fontFamily) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              isUrdu ? 'کیٹیگری منتخب کریں' : 'Select Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: AppFilterChip.productCategories.length,
                itemBuilder: (context, index) {
                  final cat = AppFilterChip.productCategories[index];
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddInventoryItemScreen(initialCategory: cat.id)),
                      );
                      if (result == true) _loadData();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon, color: AppTheme.themeColor, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isUrdu ? cat.labelUr : cat.labelEn,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: fontFamily),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
