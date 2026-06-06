import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/product_card.dart';
import 'package:account_app/core/widgets/app_filter_chip.dart';
import 'item_detail_screen.dart';
import 'add_inventory_item_screen.dart';

enum ViewMode { grid, list }

class SellerItemsScreen extends StatefulWidget {
  final String sellerUid;
  final String sellerName;
  final Map<String, String>? initialProfile; // New field

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
  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.grid;
  Map<String, String>? _sellerProfile;

  String _getFont(String? text, bool isAppUrdu) {
    if (!isAppUrdu || text == null || text.isEmpty) return '';
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'NooriNastaleeq' : '';
  }

  @override
  void initState() {
    super.initState();
    _sellerProfile = widget.initialProfile; // Use passed profile immediately
    _loadData();
  }

  Future<void> _loadData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // 1. Load from local cache first (Immediate)
    final cachedItems = db.getRemoteCachedItems(widget.sellerUid);
    if (cachedItems.isNotEmpty && mounted) {
      setState(() {
        _items = cachedItems.where((item) => item.accountId == widget.sellerUid).toList();
        _isLoading = false;
      });
    }

    // 2. Fetch fresh profile in background
    final profile = await db.findPublicProfileByUid(widget.sellerUid);

    // 3. Fetch fresh items from Firestore (Already filtered by sellerUid in the service)
    final fetchedItems = await db.getRemoteInventoryItems(widget.sellerUid);
    
    if (mounted) {
      setState(() {
        _sellerProfile = profile;
        _items = fetchedItems;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.sellerUid;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Centered Profile Header with Theme Background
                _buildModernHeader(isUrdu, fontFamily),

                // 2. Control Bar (Count & View Mode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.shoppingBag(), size: 16, color: AppTheme.themeColor),
                            const SizedBox(width: 6),
                            Text(
                              '${_items.length} ${isUrdu ? 'مصنوعات' : 'Items'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.themeColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _viewMode = _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Icon(
                            _viewMode == ViewMode.grid ? PhosphorIcons.list() : PhosphorIcons.gridFour(),
                            color: AppTheme.themeColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Products List
                Expanded(
                  child: _items.isEmpty
                      ? _buildEmptyState(isUrdu, fontFamily)
                      : _buildProductsList(isUrdu, fontFamily),
                ),
              ],
            ),
      floatingActionButton: isOwner 
          ? FloatingActionButton.extended(
              onPressed: () => _showCategoryPicker(isUrdu, fontFamily),
              backgroundColor: AppTheme.goldColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                isUrdu ? 'آئٹم شامل کریں' : 'Add Item',
                style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
              ),
            )
          : null,
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

  Widget _buildModernHeader(bool isUrdu, String fontFamily) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isMe = user?.uid == widget.sellerUid;
    final String? photoUrl = isMe ? user?.photoURL : _sellerProfile?['photoUrl'];
    final String displayName = isMe ? (user?.displayName ?? widget.sellerName) : (_sellerProfile?['name'] ?? widget.sellerName);
    final bool isUrduName = RegExp(r'[\u0600-\u06FF]').hasMatch(displayName);

    return SizedBox(
      height: 225, // Compact height for banner + info row
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Background Cover (Banner)
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.darkColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
          ),

          // 2. Back Button (Right Side)
          Positioned(
            top: 45,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. Share Button (Left Side)
          Positioned(
            top: 45,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 18),
                onPressed: () {},
              ),
            ),
          ),

          // 4. Stats Inside Banner (Left & Right of centered image)
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBannerStat('${_items.length}', isUrdu ? 'اشیاء' : 'Items', PhosphorIcons.package(), fontFamily),
                  _buildBannerStat(isUrdu ? 'تیز' : 'Fast', isUrdu ? 'رسپانس' : 'Response', PhosphorIcons.lightning(PhosphorIconsStyle.fill), fontFamily, iconColor: Colors.amber),
                ],
              ),
            ),
          ),

          // 5. Profile Image (Centered & Overlapping)
          Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: (photoUrl != null && photoUrl.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorWidget: (context, url, error) => const Icon(Icons.storefront, size: 40, color: Colors.white70),
                            )
                          : const Icon(Icons.storefront, size: 40, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 6. Name and Tag (Far Left & Far Right, below Banner)
          Positioned(
            top: 170,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Name on the Far Left
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: isUrduName ? 22 : 18,
                              fontWeight: FontWeight.bold, 
                              color: AppTheme.darkColor,
                              fontFamily: _getFont(displayName, isUrdu)
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 130),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.themeColor.withValues(alpha: 0.05), // Light theme color background
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, color: AppTheme.themeColor, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isUrdu ? 'تصدیق شدہ' : 'Verified',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.themeColor, // Darker color
                                fontFamily: fontFamily,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildBannerStat(String value, String label, IconData icon, String fontFamily, {Color? iconColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor ?? Colors.white),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: Colors.white,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList(bool isUrdu, String fontFamily) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.sellerUid;
    
    if (_viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
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
              _loadData(); // Sync on return
            },
            onDelete: isOwner ? () => _confirmDelete(item, isUrdu, fontFamily) : null,
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
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
              _loadData(); // Sync on return
            },
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
              _loadData(); // Refresh list
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
}
