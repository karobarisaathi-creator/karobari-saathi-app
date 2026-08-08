// lib/features/artisans/screens/artisan_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';
import 'artisan_work_orders_screen.dart';
import 'artisan_reviews_screen.dart';
import 'artisan_profile_screen.dart';
import 'package:account_app/features/settings/verification_request_screen.dart';

class ArtisanDetailScreen extends StatefulWidget {
  final String artisanId;
  final ArtisanProfile? initialArtisan;

  const ArtisanDetailScreen({super.key, required this.artisanId, this.initialArtisan});

  @override
  State<ArtisanDetailScreen> createState() => _ArtisanDetailScreenState();
}

class _ArtisanDetailScreenState extends State<ArtisanDetailScreen> {
  ArtisanProfile? _artisan;
  bool _isLoading = true;
  int _workCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialArtisan != null) {
      _artisan = widget.initialArtisan;
      _isLoading = false;
      // Still load work count if not dummy
      if (!widget.artisanId.startsWith('dummy')) {
        _loadExtraData();
      }
    } else {
      _loadData();
    }
  }

  Future<void> _loadExtraData() async {
    final workService = ArtisanWorkOrderService();
    final count = await workService.getWorkCount(widget.artisanId);
    if (mounted) {
      setState(() {
        _workCount = count;
      });
    }
  }

  Future<void> _loadData() async {
    // Prevent network call for dummy data
    if (widget.artisanId.startsWith('dummy')) {
      setState(() => _isLoading = false);
      return;
    }

    final service = ArtisanService();
    final workService = ArtisanWorkOrderService();

    try {
      final profile = await service.getProfile(widget.artisanId);
      final count = await workService.getWorkCount(widget.artisanId);

      if (mounted) {
        setState(() {
          _artisan = profile;
          _workCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading artisan detail: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _callArtisan() async {
    if (_artisan == null) return;
    final phone = Formatters.normalizePhoneNumber(_artisan!.phone);
    if (phone != null) {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _whatsappArtisan() async {
    if (_artisan == null) return;
    final phone = Formatters.normalizePhoneNumber(_artisan!.phone);
    if (phone != null) {
      final uri = Uri.parse(
        'https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(
          'Salam! I found your profile on Karobari Saathi. I need your services.'
        )}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _shareProfile() {
    if (_artisan == null) return;
    final message = '''
🛠️ ${_artisan!.name}
📋 ${_artisan!.professionUrdu}
📍 ${_artisan!.location}
⭐ ${_artisan!.rating} (${_artisan!.totalReviews} reviews)

Check out this artisan on Karobari Saathi!
''';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    if (_isLoading) {
      return Scaffold(
        appBar: CustomAppBar(title: ''),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_artisan == null) {
      return Scaffold(
        appBar: CustomAppBar(title: ''),
        body: Center(
          child: Text(
            isUrdu ? 'کاریگر نہیں ملا' : 'Artisan not found',
            style: TextStyle(fontFamily: fontFamily),
          ),
        ),
      );
    }

    final artisan = _artisan!;
    final isOwner = FirebaseAuth.instance.currentUser?.uid == artisan.id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: '',
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.shareNetwork(), color: Colors.white),
            onPressed: _shareProfile,
          ),
          if (isOwner)
            IconButton(
              icon: Icon(PhosphorIcons.pencilSimple(), color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ArtisanProfileScreen(),
                  ),
                ).then((_) => _loadData());
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ہیڈر سیکشن
            _buildHeader(artisan, isUrdu, fontFamily),

            // رابطہ بٹنز
            _buildContactButtons(isUrdu, fontFamily),

            // تفصیل
            _buildDescription(artisan, isUrdu, fontFamily),

            // کام کی تصاویر
            if (artisan.workImages.isNotEmpty)
              _buildWorkGallery(artisan, isUrdu, fontFamily),

            // اعداد و شمار
            _buildStats(artisan, isUrdu, fontFamily),

            // ریویوز
            _buildReviewsSection(artisan, isUrdu, fontFamily),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: isOwner
          ? _buildOwnerBottomBar(isUrdu, fontFamily)
          : _buildCustomerBottomBar(isUrdu, fontFamily),
    );
  }

  Widget _buildHeader(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkColor, AppTheme.darkColor.withOpacity(0.8)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // پروفائل تصویر
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: artisan.profileImage != null
                      ? CachedNetworkImage(
                          imageUrl: artisan.profileImage!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => Icon(
                            PhosphorIcons.user(),
                            size: 40,
                            color: Colors.grey,
                          ),
                        )
                      : Icon(
                          PhosphorIcons.user(),
                          size: 40,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            artisan.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (artisan.isVerified || artisan.verificationStatus == 'approved')
                          Icon(
                            PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                            size: 18,
                            color: AppTheme.verifiedGold,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          artisan.professionUrdu,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: artisan.availability == 'available'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: artisan.availability == 'available'
                                  ? Colors.green
                                  : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            artisan.availability == 'available'
                                ? (isUrdu ? 'دستیاب' : 'Available')
                                : (isUrdu ? 'مصروف' : 'Busy'),
                            style: TextStyle(
                              fontSize: 10,
                              color: artisan.availability == 'available'
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.mapPin(),
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          artisan.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ریٹنگ
          Row(
            children: [
              ArtisanRatingStars(rating: artisan.rating, size: 16),
              const SizedBox(width: 8),
              Text(
                '${artisan.rating}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${artisan.totalReviews} ${isUrdu ? 'ریویوز' : 'reviews'})',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactButtons(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _callArtisan,
              icon: Icon(PhosphorIcons.phone(PhosphorIconsStyle.fill)),
              label: Text(
                isUrdu ? 'کال کریں' : 'Call',
                style: TextStyle(fontFamily: fontFamily),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _whatsappArtisan,
              icon: Icon(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill)),
              label: Text(
                isUrdu ? 'واٹس ایپ' : 'WhatsApp',
                style: TextStyle(fontFamily: fontFamily),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'تعارف' : 'About',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            artisan.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontFamily: fontFamily,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkGallery(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'کام کی تصاویر' : 'Work Gallery',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: artisan.workImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(artisan.workImages[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '$_workCount',
            isUrdu ? 'کام' : 'Works',
            fontFamily,
          ),
          _buildStatItem(
            '${artisan.experience} ${isUrdu ? 'سال' : 'yrs'}',
            isUrdu ? 'تجربہ' : 'Experience',
            fontFamily,
          ),
          _buildStatItem(
            '${artisan.totalReviews}',
            isUrdu ? 'ریویوز' : 'Reviews',
            fontFamily,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, String fontFamily) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isUrdu ? 'حالیہ ریویوز' : 'Recent Reviews',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ArtisanReviewsScreen(artisanId: artisan.id),
                    ),
                  );
                },
                child: Text(
                  isUrdu ? 'مزید دیکھیں' : 'See All',
                  style: TextStyle(
                    color: AppTheme.themeColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
          // یہاں ریویوز کی لسٹ دکھائی جائے گی
          // (مختصر ورژن کے لیے)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.chatText(),
                  size: 24,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUrdu
                        ? 'ریویوز دیکھنے کے لیے "مزید دیکھیں" پر کلک کریں'
                        : 'Click "See All" to view reviews',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerBottomBar(bool isUrdu, String fontFamily) {
    final artisan = _artisan!;
    final needsVerification = !artisan.isVerified && artisan.verificationStatus != 'approved';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (needsVerification) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerificationRequestScreen(
                          isArtisanMode: true,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                  icon: Icon(PhosphorIcons.shieldCheck()),
                  label: Text(
                    isUrdu ? 'تصدیق کروائیں' : 'Verify Now',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verifiedGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ArtisanWorkOrdersScreen(artisanId: widget.artisanId),
                    ),
                  );
                },
                icon: Icon(PhosphorIcons.listBullets()),
                label: Text(
                  isUrdu ? 'میرے کام' : 'My Works',
                  style: TextStyle(fontFamily: fontFamily),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerBottomBar(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _callArtisan,
                icon: Icon(PhosphorIcons.phone(PhosphorIconsStyle.fill)),
                label: Text(
                  isUrdu ? 'رابطہ کریں' : 'Contact',
                  style: TextStyle(fontFamily: fontFamily),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}