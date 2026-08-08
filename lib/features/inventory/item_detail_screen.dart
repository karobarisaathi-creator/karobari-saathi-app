import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/models/review_model.dart';
import 'package:account_app/core/models/ad_report_model.dart';
import 'package:account_app/features/inventory/chat_screen.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/verification_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_filter_chip.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/theme/app_theme.dart';

import 'package:account_app/features/visual_finder/visual_finder_screen.dart';
import 'seller_items_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final InventoryItem item;
  final bool isPreview;
  final VoidCallback? onConfirm;

  const ItemDetailScreen({
    super.key,
    required this.item,
    this.isPreview = false,
    this.onConfirm,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late bool _isFavorite;
  int _selectedImageIndex = 0;
  Map<String, String>? _sellerInfo;
  int _sellerTotalAds = 0;
  double _sellerAvgRating = 0.0;
  bool _isSellerVerified = false;
  bool _isLoadingSeller = false;
  bool _showFullContact = false;
  List<Review> _reviews = [];
  bool _isLoadingReviews = false;

  String _getFont(String? text, bool isAppUrdu, {bool forceUrdu = false}) {
    if (!isAppUrdu) return '';
    if (forceUrdu) return 'NooriNastaleeq';
    if (text == null || text.isEmpty) return '';
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'NooriNastaleeq' : '';
  }

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item.isFavorite ?? false;
    _loadSellerInfo();
    _loadReviews();
    _trackEngagement();
  }

  void _trackEngagement() {
    if (widget.isPreview) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      dbService.incrementView(widget.item.id);
      dbService.addRecentlyViewed(widget.item);
    });
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final reviews = await dbService.getItemReviews(widget.item.id);
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _showReviewDialog(bool isUrdu, String fontFamily) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar(isUrdu
          ? 'ریویو دینے کے لیے لاگ ان کریں'
          : 'Please login to give a review');
      return;
    }

    double rating = 5.0;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.darkColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isUrdu ? 'ریویو دیں' : 'Give a Review',
              style: TextStyle(color: Colors.white, fontFamily: fontFamily)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (index) => IconButton(
                          icon: Icon(
                            index < rating
                                ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                                : PhosphorIcons.star(),
                            color: Colors.amber,
                          ),
                          onPressed: () =>
                              setModalState(() => rating = index + 1.0),
                        )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      isUrdu ? 'اپنا تبصرہ لکھیں...' : 'Write your comment...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isUrdu ? 'کینسل' : 'Cancel',
                    style: TextStyle(
                        color: Colors.white54, fontFamily: fontFamily))),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(context);

                final review = Review(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  itemId: widget.item.id,
                  userId: user.uid,
                  userName: user.displayName ?? 'User',
                  rating: rating,
                  comment: controller.text.trim(),
                  timestamp: DateTime.now(),
                );

                final dbService =
                    Provider.of<DatabaseService>(context, listen: false);
                await dbService.addReview(review);
                _loadReviews(); // Refresh
                _loadSellerInfo(); // Refresh rating maybe
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.themeColor),
              child: Text(isUrdu ? 'شائع کریں' : 'Post',
                  style: TextStyle(
                      fontFamily: fontFamily, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenImage(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              final path = widget.item.imagePaths[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: path.startsWith('http')
                    ? CachedNetworkImageProvider(path)
                    : FileImage(File(path)) as ImageProvider,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
              );
            },
            itemCount: widget.item.imagePaths.length,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: initialIndex),
          ),
        ),
      ),
    );
  }

  Future<void> _loadSellerInfo() async {
    if (widget.item.accountId == null) return;
    setState(() => _isLoadingSeller = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final localAccount = dbService.getAccount(widget.item.accountId!);
    if (localAccount != null) {
      setState(() {
        _sellerInfo = {
          'uid': localAccount.id,
          'name': localAccount.name,
          'phone': localAccount.phone,
          'photoUrl': localAccount.profileImage ?? '',
          'isVerified': localAccount.isVerified.toString(),
        };
        _isSellerVerified = localAccount.isVerified;
        _isLoadingSeller = false;
      });
      return;
    }
    final profile =
        await dbService.findPublicProfileByUid(widget.item.accountId!);
    
    // Load Seller Stats (Total Ads & Avg Rating)
    final stats = await _fetchSellerStats(widget.item.accountId!);

    if (mounted) {
      setState(() {
        _sellerInfo = profile;
        _isSellerVerified = profile?['isVerified'] == 'true';
        _sellerTotalAds = stats['totalAds'] as int;
        _sellerAvgRating = stats['avgRating'] as double;
        _isLoadingSeller = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchSellerStats(String uid) async {
    try {
      final q = await FirebaseFirestore.instance.collectionGroup('inventory_items')
          .where('accountId', isEqualTo: uid).get();
      
      int totalAds = q.docs.length;
      double totalRating = 0;
      for (var doc in q.docs) {
        totalRating += (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
      }
      double avgRating = totalAds > 0 ? totalRating / totalAds : 0.0;
      
      return {'totalAds': totalAds, 'avgRating': avgRating};
    } catch (e) {
      return {'totalAds': 0, 'avgRating': 0.0};
    }
  }

  Future<void> _renewAd() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    setState(() => _isLoadingSeller = true);
    try {
      final newExpiry = DateTime.now().add(const Duration(days: 30));
      final updatedItem = widget.item.copyWith(
        adExpiryDate: newExpiry,
        updatedAt: DateTime.now(),
      );
      
      await dbService.updateInventoryItem(updatedItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'اشتہار کی مدت 30 دن بڑھا دی گئی ہے!' : 'Ad renewed for 30 more days!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to refresh
      }
    } catch (e) {
      _showErrorSnackBar('Renew failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSeller = false);
    }
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.mediumImpact();
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    setState(() {
      _isFavorite = !_isFavorite;
      if (_isFavorite) {
        widget.item.likes += 1;
      } else {
        widget.item.likes = (widget.item.likes > 0) ? widget.item.likes - 1 : 0;
      }
    });
    widget.item.isFavorite = _isFavorite;
    await dbService.updateInventoryItem(widget.item);
    await dbService.toggleFirestoreFavorite(widget.item.id, _isFavorite);
  }

  void _whatsappSeller() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    if (_sellerInfo == null || _sellerInfo!['phone'] == null) {
      _showMissingInfoSnackBar();
      return;
    }
    final rawPhone = _sellerInfo!['phone']!;
    if (rawPhone.trim().isEmpty) {
      _showMissingInfoSnackBar();
      return;
    }

    final phoneE164 = Formatters.normalizePhoneNumber(rawPhone);
    if (phoneE164 == null) {
      _showErrorSnackBar(
          isUrdu ? 'فون نمبر درست نہیں ہے' : 'Invalid phone number');
      return;
    }

    final phoneDigits = phoneE164.replaceAll('+', '');
    final sanitizedTitle = Formatters.sanitizeText(widget.item.name);
    final message = isUrdu
        ? "اسلام علیکم، مجھے آپ کی اس چیز میں دلچسپی ہے: $sanitizedTitle"
        : "Salam, I am interested in your product: $sanitizedTitle";

    final uri = Uri.parse(
        'https://wa.me/$phoneDigits?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await Provider.of<DatabaseService>(context, listen: false)
          .logContactEvent(
              itemId: widget.item.id,
              action: 'whatsapp_seller',
              targetPhone: phoneE164);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar(isUrdu ? 'واٹس ایپ نہیں ملا' : 'WhatsApp not found');
    }
  }

  void _callSeller() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    if (_sellerInfo == null || _sellerInfo!['phone'] == null) {
      _showMissingInfoSnackBar();
      return;
    }

    if (!_showFullContact) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.logContactEvent(
          itemId: widget.item.id, action: 'view_contact');
      setState(() => _showFullContact = true);
      return;
    }

    final rawPhone = _sellerInfo!['phone']!;
    if (rawPhone.trim().isEmpty) {
      _showMissingInfoSnackBar();
      return;
    }

    final phoneE164 = Formatters.normalizePhoneNumber(rawPhone);
    if (phoneE164 == null) {
      _showErrorSnackBar(
          isUrdu ? 'فون نمبر درست نہیں ہے' : 'Could not parse phone number');
      return;
    }

    final telUri = Uri(scheme: 'tel', path: phoneE164);
    if (await canLaunchUrl(telUri)) {
      await Provider.of<DatabaseService>(context, listen: false)
          .logContactEvent(
              itemId: widget.item.id,
              action: 'call_seller',
              targetPhone: phoneE164);
      await launchUrl(telUri);
    } else {
      _showErrorSnackBar(
          isUrdu ? 'فون ڈائلر نہیں کھل سکا' : 'Could not launch phone dialer');
    }
  }

  void _shareItem() async {
    HapticFeedback.lightImpact();
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    // Modernized link format for DeepLinkService
    final String url = 'https://accountapp.page.link/item/${widget.item.id}';
    final sanitizedTitle = Formatters.sanitizeText(widget.item.name);
    final String message = isUrdu
        ? "بازار پر یہ اشتہار دیکھیں: $sanitizedTitle\n$url"
        : "Check out this ad on Bazaar: $sanitizedTitle\n$url";

    Share.share(message);
    await dbService.logContactEvent(
        itemId: widget.item.id, action: 'share_item');
    dbService.incrementShare(widget.item.id);
  }

  void _showMissingInfoSnackBar() {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(isUrdu
              ? 'فروخت کنندہ کی معلومات دستیاب نہیں ہے'
              : 'Seller information not available')),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final screenHeight = MediaQuery.of(context).size.height;

    final itemName = Formatters.sanitizeText(widget.item.name);
    final itemBrand = Formatters.sanitizeText(widget.item.brand ?? '');
    final itemLocation = Formatters.sanitizeText(widget.item.location ?? '');
    final itemDescription =
        Formatters.sanitizeText(widget.item.description ?? '');

    return Scaffold(
      backgroundColor: AppTheme.darkColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkColor,
              AppTheme.darkColor.withValues(alpha: 0.85)
            ],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroImage(screenHeight),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: isUrdu ? 30 : 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: _getFont(itemName, isUrdu),
                                    ),
                                  ),
                                  if (itemBrand.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.1)),
                                      ),
                                      child: Text(
                                        itemBrand,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.themeColor
                                              .withValues(alpha: 0.9),
                                          fontFamily:
                                              _getFont(itemBrand, isUrdu),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs ${widget.item.defaultRate.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                if (widget.item.isNegotiable ?? false)
                                  Text(
                                    isUrdu ? 'کمی بیشی ممکن' : 'Negotiable',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.themeColor,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: fontFamily),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text('${widget.item.rating}/5',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white))
                            ]),
                            Row(children: [
                              Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill),
                                  color: const Color(0xFF128C7E), size: 20),
                              const SizedBox(width: 8),
                              Text('${widget.item.likes}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white))
                            ]),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (widget.item.imagePaths.length > 1)
                          _buildThumbnails(),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            if (widget.item.category != null)
                              _buildDetailChip(
                                icon: PhosphorIcons.tag(),
                                label: '',
                                value: isUrdu
                                    ? (AppFilterChip.productCategories
                                        .firstWhere(
                                            (c) => c.id == widget.item.category,
                                            orElse: () => AppFilterChip
                                                .productCategories.first)
                                        .labelUr)
                                    : (AppFilterChip.productCategories
                                        .firstWhere(
                                            (c) => c.id == widget.item.category,
                                            orElse: () => AppFilterChip
                                                .productCategories.first)
                                        .labelEn),
                                fontFamily: fontFamily,
                              ),
                            _buildDetailChip(
                              icon: PhosphorIcons.shieldCheck(),
                              label: isUrdu ? 'حالت: ' : 'Condition: ',
                              value: isUrdu
                                  ? (widget.item.condition == 'New'
                                      ? 'نیا'
                                      : 'استعمال شدہ')
                                  : (widget.item.condition ?? 'New'),
                              fontFamily: fontFamily,
                            ),
                            if (widget.item.warranty != null &&
                                widget.item.warranty!.isNotEmpty)
                              _buildDetailChip(
                                  icon: PhosphorIcons.certificate(),
                                  label: isUrdu ? 'وارنٹی: ' : 'Warranty: ',
                                  value: widget.item.warranty!,
                                  fontFamily: fontFamily),
                            if (widget.item.stockQuantity > 0)
                              _buildDetailChip(
                                  icon: PhosphorIcons.stack(),
                                  label: isUrdu ? 'اسٹاک: ' : 'Stock: ',
                                  value:
                                      '${widget.item.stockQuantity.toStringAsFixed(0)}${widget.item.unit.isNotEmpty ? " ${widget.item.unit}" : ""}',
                                  fontFamily: fontFamily),
                            if (itemLocation.isNotEmpty)
                              _buildDetailChip(
                                  icon: PhosphorIcons.mapPin(),
                                  label: isUrdu ? 'جگہ: ' : 'Location: ',
                                  value: itemLocation,
                                  fontFamily: fontFamily),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _buildSectionHeader(
                            isUrdu
                                ? 'تکنیکی تفصیلات'
                                : 'Technical Specifications',
                            isUrdu,
                            fontFamily),
                        _buildSpecsGrid(isUrdu, fontFamily),
                        const SizedBox(height: 32),
                        _buildSectionHeader(isUrdu ? 'تفصیل' : 'Description',
                            isUrdu, fontFamily),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1))),
                          child: Text(
                            Formatters.sanitizeText(
                                widget.item.description ?? ''),
                            style: TextStyle(
                                fontSize: isUrdu ? 18 : 15,
                                color: Colors.white70,
                                fontFamily: _getFont(
                                    Formatters.sanitizeText(
                                        widget.item.description ?? ''),
                                    isUrdu),
                                height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader(isUrdu ? 'ریویوز' : 'Reviews',
                                isUrdu, fontFamily),
                            if (!widget.isPreview)
                              TextButton.icon(
                                onPressed: () =>
                                    _showReviewDialog(isUrdu, fontFamily),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(isUrdu ? 'ریویو دیں' : 'Add Review',
                                    style: TextStyle(fontFamily: fontFamily)),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.themeColor),
                              ),
                          ],
                        ),
                        _buildReviewsSection(isUrdu, fontFamily),
                        const SizedBox(height: 32),
                        if (widget.item.accountId ==
                            FirebaseAuth.instance.currentUser?.uid) ...[
                          _buildSellerInsights(isUrdu, fontFamily),
                          const SizedBox(height: 16),
                          _buildRenewSection(isUrdu, fontFamily),
                        ],
                        const SizedBox(height: 32),
                        _buildSellerCard(isUrdu, fontFamily),
                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildTopButtons(),
            _buildBottomBar(isUrdu, fontFamily),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              color: Colors.white,
              fontSize: isUrdu ? 22 : 18,
              fontWeight: FontWeight.bold,
              fontFamily: fontFamily)),
    );
  }

  Widget _buildSpecsGrid(bool isUrdu, String fontFamily) {
    List<Widget> specTiles = [];

    void addSpec(IconData icon, String label, String? value) {
      if (value != null && value.isNotEmpty && value != 'null') {
        specTiles.add(_buildSpecItem(icon, label, value, isUrdu, fontFamily));
      }
    }

    final item = widget.item;
    // Mobile
    addSpec(PhosphorIcons.memory(), isUrdu ? 'ریم' : 'RAM', item.ram);
    addSpec(
        PhosphorIcons.database(), isUrdu ? 'سٹوریج' : 'Storage', item.storage);
    addSpec(
        PhosphorIcons.cpu(), isUrdu ? 'پروسیسر' : 'Processor', item.processor);
    addSpec(PhosphorIcons.shieldCheck(), isUrdu ? 'پی ٹی اے' : 'PTA',
        item.ptaStatus);
    addSpec(PhosphorIcons.batteryHigh(), isUrdu ? 'بیٹری' : 'Battery',
        item.batteryHealth);
    addSpec(PhosphorIcons.deviceMobile(), isUrdu ? 'سکرین' : 'Screen',
        item.screenCondition);
    addSpec(PhosphorIcons.hardDrive(), isUrdu ? 'باڈی' : 'Body',
        item.bodyCondition);

    // Vehicle
    addSpec(PhosphorIcons.engine(), isUrdu ? 'انجن' : 'Engine', item.engine);
    addSpec(PhosphorIcons.speedometer(), isUrdu ? 'مائلیج' : 'Mileage',
        item.mileage);
    addSpec(PhosphorIcons.gasPump(), isUrdu ? 'فیول' : 'Fuel', item.fuelType);
    addSpec(PhosphorIcons.gearSix(), isUrdu ? 'ٹرانسمیشن' : 'Transmission',
        item.transmission);
    addSpec(PhosphorIcons.mapPin(), isUrdu ? 'رجسٹریشن' : 'Registration',
        item.registration);
    addSpec(PhosphorIcons.warningCircle(), isUrdu ? 'ایکسڈینٹ' : 'Accident',
        item.accidentHistory);
    addSpec(PhosphorIcons.users(), isUrdu ? 'اونر' : 'Owner', item.ownerCount);

    // Real Estate
    addSpec(PhosphorIcons.ruler(), isUrdu ? 'رقبہ' : 'Area', item.area);
    addSpec(
        PhosphorIcons.bed(), isUrdu ? 'بیڈ رومز' : 'Bedrooms', item.bedrooms);
    addSpec(PhosphorIcons.drop(), isUrdu ? 'باتھ رومز' : 'Bathrooms',
        item.bathrooms);
    addSpec(PhosphorIcons.house(), isUrdu ? 'قسم' : 'Property Type',
        item.propertyType);

    // Livestock
    addSpec(PhosphorIcons.cow(), isUrdu ? 'نسل' : 'Breed', item.breed);
    addSpec(PhosphorIcons.calendar(), isUrdu ? 'عمر' : 'Age', item.age);
    addSpec(PhosphorIcons.scales(), isUrdu ? 'وزن' : 'Weight', item.weight);
    addSpec(PhosphorIcons.drop(), isUrdu ? 'دودھ' : 'Milk', item.milkCapacity);
    addSpec(PhosphorIcons.firstAid(), isUrdu ? 'ویکسین' : 'Vaccination',
        item.vaccination);

    // Electronics
    addSpec(PhosphorIcons.cpu(), isUrdu ? 'ماڈل' : 'Model', item.model);
    addSpec(PhosphorIcons.lightning(), isUrdu ? 'پاور' : 'Power', item.power);
    addSpec(PhosphorIcons.certificate(), isUrdu ? 'وارنٹی' : 'Warranty Type',
        item.warrantyType);

    // Clothing
    addSpec(PhosphorIcons.ruler(), isUrdu ? 'سائز' : 'Size', item.size);
    addSpec(PhosphorIcons.tShirt(), isUrdu ? 'فیبرک' : 'Fabric', item.fabric);

    // Furniture
    addSpec(
        PhosphorIcons.couch(), isUrdu ? 'مٹیریل' : 'Material', item.material);
    addSpec(PhosphorIcons.arrowsOut(), isUrdu ? 'پیمائش' : 'Dimensions',
        item.dimensions);
    addSpec(
        PhosphorIcons.wrench(), isUrdu ? 'اسمبلی' : 'Assembly', item.assembly);

    // Agriculture
    addSpec(PhosphorIcons.plant(), isUrdu ? 'فصل' : 'Crop', item.cropType);
    addSpec(PhosphorIcons.calendar(), isUrdu ? 'سیزن' : 'Season', item.season);
    addSpec(
        PhosphorIcons.sealCheck(), isUrdu ? 'کوالٹی' : 'Quality', item.quality);

    // Food
    addSpec(PhosphorIcons.scales(), isUrdu ? 'وزن' : 'Weight', item.foodWeight);
    addSpec(PhosphorIcons.calendarX(), isUrdu ? 'تاریخ تنسیخ' : 'Expiry',
        item.expiryDate);
    addSpec(PhosphorIcons.thermometerCold(), isUrdu ? 'سٹوریج' : 'Storage',
        item.storageType);
    addSpec(PhosphorIcons.checkCircle(), isUrdu ? 'حلال' : 'Halal', item.halal);

    // Medical
    addSpec(PhosphorIcons.pill(), isUrdu ? 'طاقت' : 'Strength', item.strength);
    addSpec(PhosphorIcons.package(), isUrdu ? 'تعداد' : 'Quantity',
        item.medicineQuantity);
    addSpec(PhosphorIcons.fileText(), isUrdu ? 'نسخہ' : 'Prescription',
        item.prescriptionRequired);

    // Services
    addSpec(PhosphorIcons.briefcase(), isUrdu ? 'سروس' : 'Service',
        item.serviceType);
    addSpec(PhosphorIcons.timer(), isUrdu ? 'تجربہ' : 'Experience',
        item.experience);
    addSpec(PhosphorIcons.clock(), isUrdu ? 'دستیابی' : 'Availability',
        item.availability);

    if (specTiles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: specTiles,
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value, bool isUrdu,
      String fontFamily) {
    return Row(
      children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTheme.themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.themeColor, size: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: isUrdu ? 14 : 11,
                      fontFamily: fontFamily)),
              Text(value,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isUrdu ? 16 : 13,
                      fontFamily: _getFont(value, isUrdu))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImage(double screenHeight) {
    return GestureDetector(
      onTap: () => _openFullScreenImage(_selectedImageIndex),
      child: Container(
        height: screenHeight * 0.45,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(32)),
          border: Border(
              bottom: BorderSide(
                  color: AppTheme.themeColor.withValues(alpha: 0.5), width: 4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Hero(
          tag: 'image_$_selectedImageIndex',
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: widget.item.imagePaths.isNotEmpty
                      ? _buildImage(
                          widget.item.imagePaths[_selectedImageIndex], BoxFit.cover)
                      : Container(
                          color: Colors.black12,
                          child: Icon(PhosphorIcons.package(),
                              size: 80, color: Colors.white)),
                ),
                // Indicator
                if (widget.item.imagePaths.length > 1)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedImageIndex + 1} / ${widget.item.imagePaths.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // Zoom Hint
                Positioned(
                  top: 20,
                  right: 20,
                  child: Icon(PhosphorIcons.magnifyingGlassPlus(), color: Colors.white.withOpacity(0.5), size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButtons() {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFloatingCircleButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.pop(context)),
            Row(
              children: [
                _buildFloatingCircleButton(
                  icon: PhosphorIcons.shareNetwork(),
                  iconColor: Colors.white,
                  onTap: _shareItem,
                ),
                const SizedBox(width: 8),
                _buildFloatingCircleButton(
                  icon: PhosphorIcons.flag(),
                  iconColor: Colors.white,
                  onTap: () => _showReportDialog(isUrdu, fontFamily),
                ),
                const SizedBox(width: 8),
                _buildFloatingCircleButton(
                  icon: _isFavorite
                      ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                      : PhosphorIcons.heart(),
                  iconColor:
                      _isFavorite ? const Color(0xFF128C7E) : Colors.white,
                  onTap: _toggleFavorite,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUrdu ? 'اشتہار رپورٹ کریں' : 'Report Ad',
          style: TextStyle(color: Colors.white, fontFamily: fontFamily),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption(
                isUrdu ? 'غلط قیمت' : 'Incorrect Price', isUrdu, fontFamily),
            _buildReportOption(isUrdu ? 'دھوکہ دہی / فراڈ' : 'Fraud / Scam',
                isUrdu, fontFamily),
            _buildReportOption(
                isUrdu ? 'غیر اخلاقی مواد' : 'Inappropriate Content',
                isUrdu,
                fontFamily),
            _buildReportOption(
                isUrdu ? 'چوری شدہ چیز' : 'Stolen Item', isUrdu, fontFamily),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String label, bool isUrdu, String fontFamily) {
    return ListTile(
      title: Text(label,
          style: TextStyle(
              color: Colors.white70, fontSize: 14, fontFamily: fontFamily)),
      onTap: () async {
        Navigator.pop(context);

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final report = AdReport(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          itemId: widget.item.id,
          itemOwnerId: widget.item.accountId ?? '',
          reporterId: user.uid,
          reason: label,
          reportedAt: DateTime.now(),
        );

        try {
          final dbService =
              Provider.of<DatabaseService>(context, listen: false);
          await dbService.reportAd(report);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isUrdu
                    ? 'شکریہ! آپ کی رپورٹ موصول ہو گئی ہے۔'
                    : 'Report submitted. Thank you!'),
                backgroundColor: AppTheme.themeColor,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }

  Widget _buildFloatingCircleButton(
      {required IconData icon, required VoidCallback onTap, Color? iconColor}) {
    return GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.black.withValues(alpha: 0.2),
            child: Icon(icon, color: iconColor ?? Colors.white, size: 18)));
  }

  Widget _buildThumbnails() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.item.imagePaths.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedImageIndex == index;
          return GestureDetector(
            onLongPress: () => _openFullScreenImage(index),
            onTap: () => setState(() => _selectedImageIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 60,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          isSelected ? AppTheme.themeColor : Colors.transparent,
                      width: 2)),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      _buildImage(widget.item.imagePaths[index], BoxFit.cover)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(bool isUrdu, String fontFamily) {
    if (widget.isPreview) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          decoration: BoxDecoration(
              color: AppTheme.darkColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                  top:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => VisualFinderScreen(
                                initialSearchQuery: widget.item.name))),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                          color: AppTheme.themeColor, size: 28),
                      const SizedBox(height: 4),
                      Text(isUrdu ? 'ڈیل فائنڈر' : 'Deal Finder',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily))
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: const BorderSide(color: Colors.white24),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Text(isUrdu ? 'تبدیلی کریں' : 'Edit Again',
                              style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: widget.onConfirm,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0),
                          child: Text(
                              isUrdu ? 'اشتہار شائع کریں' : 'Post Ad Now',
                              style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontWeight: FontWeight.bold)))),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                  color: AppTheme.darkColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 20,
                        offset: const Offset(0, -5))
                  ])),
          Positioned(
            bottom: 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ]),
              child: Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => VisualFinderScreen(
                                      initialSearchQuery: widget.item.name))),
                          icon: Icon(
                              PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                              size: 18),
                          label: Text(isUrdu ? 'ڈیل فائنڈر' : 'Deal Finder',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: fontFamily)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0))),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 3,
                      child: Row(children: [
                        Expanded(
                            child: ElevatedButton.icon(
                                onPressed:
                                    _isLoadingSeller ? null : _whatsappSeller,
                                icon: Icon(
                                    PhosphorIcons.whatsappLogo(
                                        PhosphorIconsStyle.fill),
                                    size: 18),
                                label: Text(isUrdu ? 'واٹس ایپ' : 'WhatsApp',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: fontFamily)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF128C7E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: 0))),
                        const SizedBox(width: 8),
                        Container(
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16)),
                            child: IconButton(
                                onPressed:
                                    _isLoadingSeller ? null : _callSeller,
                                icon: Icon(
                                    PhosphorIcons.phoneCall(
                                        PhosphorIconsStyle.fill),
                                    size: 20),
                                padding: const EdgeInsets.all(12))),
                      ])),
                  if (widget.item.accountId != FirebaseAuth.instance.currentUser?.uid) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_sellerInfo != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                              otherUserId: _sellerInfo!['uid']!, 
                              otherUserName: _sellerInfo!['name']!,
                              otherUserImage: _sellerInfo!['photoUrl'],
                            )));
                          }
                        },
                        icon: Icon(PhosphorIcons.chatCircleDots(PhosphorIconsStyle.fill), size: 18),
                        label: Text(
                          isUrdu ? 'چیٹ کریں' : 'Chat Now',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: fontFamily),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.verifiedGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewSection(bool isUrdu, String fontFamily) {
    final bool isExpired = widget.item.adExpiryDate != null && widget.item.adExpiryDate!.isBefore(DateTime.now());
    final bool isNearExpiry = widget.item.adExpiryDate != null && widget.item.adExpiryDate!.difference(DateTime.now()).inDays < 5;

    if (!isExpired && !isNearExpiry) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpired ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isExpired ? PhosphorIcons.clockCounterClockwise() : PhosphorIcons.warning(), 
               color: isExpired ? Colors.red : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? (isUrdu ? 'اشتہار ختم ہو چکا ہے' : 'Ad Expired') : (isUrdu ? 'اشتہار ختم ہونے والا ہے' : 'Expiring Soon'),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: fontFamily),
                ),
                Text(
                  isUrdu ? 'مزید 30 دن کے لیے اسے تازہ کریں' : 'Renew it for 30 more days',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: fontFamily),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _renewAd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.themeColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isUrdu ? 'تازہ کریں' : 'Renew', style: TextStyle(fontFamily: fontFamily, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(bool isUrdu, String fontFamily) {
    if (_isLoadingSeller)
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)));
    if (_sellerInfo == null) return const SizedBox.shrink();

    final phone = _sellerInfo!['phone'] ?? '';
    final displayPhone = _showFullContact ? phone : Formatters.maskPhoneNumber(phone);
    
    // ================= ENTERPRISE REPUTATION LOGIC =================
    String? reputation;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    
    final createdAtStr = _sellerInfo!['createdAt'] ?? '';
    if (createdAtStr.isNotEmpty) {
      final createdAt = DateTime.parse(createdAtStr);
      final ageDays = DateTime.now().difference(createdAt).inDays;
      
      if (_isSellerVerified) {
        reputation = isUrdu ? 'اعلیٰ درجے کا سیلر' : 'Top Rated Seller';
      } else if (ageDays > 180) {
        reputation = isUrdu ? 'پرانا اور قابل اعتماد' : 'Trusted Veteran';
      } else if (ageDays > 30) {
        reputation = isUrdu ? 'تجربہ کار سیلر' : 'Experienced Seller';
      } else {
        reputation = isUrdu ? 'نیا ممبر' : 'New Member';
      }
    }
    // ==============================================================

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileInfoWidget(
                  name: _sellerInfo!['name'] ?? '',
                  phone: displayPhone,
                  profileImage: _sellerInfo!['photoUrl'],
                  isVerified: _isSellerVerified,
                  reputationLabel: reputation, // Display the Trust Level
                  topLabel: isUrdu ? 'فروخت کنندہ' : 'Seller',
                  isLarge: false,
                  textColor: Colors.white,
                  subtitleColor: Colors.white54,
                ),
                if (_sellerTotalAds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 48),
                    child: Row(
                      children: [
                        _buildSmallStat(PhosphorIcons.package(), '$_sellerTotalAds ${isUrdu ? 'اشتہارات' : 'Ads'}'),
                        const SizedBox(width: 12),
                        _buildSmallStat(PhosphorIcons.star(PhosphorIconsStyle.fill), _sellerAvgRating.toStringAsFixed(1), color: Colors.amber),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!_showFullContact)
            TextButton(
              onPressed: () => setState(() => _showFullContact = true),
              child: Text(isUrdu ? 'نمبر دیکھیں' : 'Show Number',
                  style: TextStyle(
                      color: AppTheme.verifiedGold,
                      fontFamily: fontFamily,
                      fontSize: 12)),
            )
          else
            TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SellerItemsScreen(
                            sellerUid: _sellerInfo!['uid']!,
                            sellerName: _sellerInfo!['name']!,
                            initialProfile: _sellerInfo))),
                child: Text(isUrdu ? 'مصنوعات' : 'Products',
                    style: TextStyle(
                        color: AppTheme.themeColor,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily))),
        ],
      ),
    );
  }

  Widget _buildSmallStat(IconData icon, String label, {Color color = Colors.white54}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSellerInsights(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.themeColor.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chartBar(PhosphorIconsStyle.fill),
                  color: AppTheme.themeColor, size: 24),
              const SizedBox(width: 12),
              Text(
                isUrdu ? 'آپ کے اشتہار کی کارکردگی' : 'Your Ad Performance',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(PhosphorIcons.eye(), widget.item.views.toString(),
                  isUrdu ? 'ویوز' : 'Views', fontFamily),
              _buildStatItem(
                  PhosphorIcons.phoneCall(),
                  widget.item.contacts.toString(),
                  isUrdu ? 'رابطے' : 'Contacts',
                  fontFamily),
              _buildStatItem(
                  PhosphorIcons.heart(),
                  widget.item.likes.toString(),
                  isUrdu ? 'لائیکس' : 'Likes',
                  fontFamily),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, String fontFamily) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white38, fontSize: 12, fontFamily: fontFamily)),
      ],
    );
  }

  Widget _buildReviewsSection(bool isUrdu, String fontFamily) {
    if (_isLoadingReviews)
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    if (_reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Icon(PhosphorIcons.star(), size: 32, color: Colors.white24),
            const SizedBox(height: 12),
            Text(isUrdu ? 'کوئی ریویو نہیں ملا' : 'No reviews yet',
                style:
                    TextStyle(color: Colors.white54, fontFamily: fontFamily)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviews.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(review.userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Row(
                    children: List.generate(
                        5,
                        (idx) => Icon(
                              idx < review.rating
                                  ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                                  : PhosphorIcons.star(),
                              color: Colors.amber,
                              size: 14,
                            )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(review.comment,
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: _getFont(review.comment, isUrdu))),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy').format(review.timestamp),
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(
      {required IconData icon,
      required String label,
      required String value,
      required String fontFamily}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppTheme.themeColor),
        const SizedBox(width: 8),
        RichText(
            text: TextSpan(
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontFamily: fontFamily),
                children: [
              TextSpan(text: label),
              TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white))
            ]))
      ]),
    );
  }

  Widget _buildImage(String path, BoxFit fit) {
    if (path.startsWith('http'))
      return CachedNetworkImage(
          imageUrl: path,
          fit: fit,
          placeholder: (context, url) => Container(color: Colors.black12),
          errorWidget: (context, url, error) =>
              Icon(PhosphorIcons.image(), color: Colors.white));
    return Image.file(File(path),
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            Icon(PhosphorIcons.image(), color: Colors.white));
  }
}
