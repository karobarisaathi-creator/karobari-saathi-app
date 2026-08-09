// lib/features/artisans/screens/artisan_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
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
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';
import 'artisan_work_orders_screen.dart';
import 'artisan_reviews_screen.dart';
import 'artisan_profile_screen.dart';
import 'package:account_app/features/inventory/chat_screen.dart';
import 'package:account_app/features/settings/verification_request_screen.dart';

class ArtisanDetailScreen extends StatefulWidget {
  final String artisanId;
  final ArtisanProfile? initialArtisan;
  final double? distanceKm;

  const ArtisanDetailScreen({super.key, required this.artisanId, this.initialArtisan, this.distanceKm});

  @override
  State<ArtisanDetailScreen> createState() => _ArtisanDetailScreenState();
}

class _ArtisanDetailScreenState extends State<ArtisanDetailScreen> {
  ArtisanProfile? _artisan;
  StreamSubscription<ArtisanProfile?>? _artisanSub;
  bool _isLoading = true;
  int _workCount = 0;
  bool _isSending = false;
  String? _requestStatus;

  bool get isOwner => FirebaseAuth.instance.currentUser?.uid == widget.artisanId;

  @override
  void initState() {
    super.initState();
    _checkRequestStatus();
    _setupArtisanListener();
    if (!widget.artisanId.startsWith('dummy')) {
      _loadExtraData();
    }
  }

  @override
  void dispose() {
    _artisanSub?.cancel();
    super.dispose();
  }

  void _setupArtisanListener() {
    final service = ArtisanService();
    _artisanSub = service.streamProfile(widget.artisanId).listen((profile) {
      if (mounted) {
        setState(() {
          _artisan = profile;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _toggleAvailability() async {
    if (_artisan == null || !isOwner) return;

    final service = ArtisanService();
    final newStatus = _artisan!.availability == 'available' ? 'busy' : 'available';
    
    final updatedProfile = _artisan!.copyWith(
      availability: newStatus,
      updatedAt: DateTime.now(),
    );

    try {
      await service.saveProfile(updatedProfile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
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

  Future<void> _checkRequestStatus() async {
    final nService = Provider.of<NotificationService>(context, listen: false);
    final status = await nService.getArtisanRequestStatus(widget.artisanId);
    if (mounted) {
      setState(() {
        _requestStatus = status;
      });
    }
  }

  void _sendWorkRequest(bool isUrdu) async {
    setState(() => _isSending = true);
    final nService = Provider.of<NotificationService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    
    try {
      await nService.sendArtisanWorkRequest(
        artisanUid: widget.artisanId,
        customerName: user?.displayName ?? (isUrdu ? 'ایک گاہک' : 'A Customer'),
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          _requestStatus = 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'درخواست کامیابی سے بھیج دی گئی!' : 'Request sent successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showAddReviewDialog(bool isUrdu, String fontFamily) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isUrdu ? 'اپنی رائے دیں' : 'Write a Review',
            style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu ? 'کاریگر کا کام کیسا رہا؟' : 'How was your experience?',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: fontFamily),
              ),
              const SizedBox(height: 20),
              // Star Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setDialogState(() => selectedRating = index + 1.0),
                    icon: Icon(
                      index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isUrdu ? 'اپنا تجربہ لکھیں...' : 'Write your comment here...',
                  hintStyle: TextStyle(fontSize: 13, fontFamily: fontFamily),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'کینسل' : 'Cancel', style: TextStyle(fontFamily: fontFamily)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (commentController.text.trim().isEmpty) return;
                
                final artisanService = ArtisanService();
                // Passing a dummy work order ID since we are in simple mode
                await artisanService.addReview(
                  artisanId: widget.artisanId,
                  workOrderId: 'simple_${DateTime.now().millisecondsSinceEpoch}', 
                  rating: selectedRating,
                  comment: commentController.text.trim(),
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadData(); // Refresh to see new rating
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isUrdu ? 'آپ کا ریویو جمع ہوگیا ہے!' : 'Review submitted!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.themeColor),
              child: Text(isUrdu ? 'جمع کریں' : 'Submit', style: TextStyle(fontFamily: fontFamily, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openInAppChat() {
    if (_artisan == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: _artisan!.id,
          otherUserName: _artisan!.name,
          otherUserImage: _artisan!.profileImage,
        ),
      ),
    );
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
    final bool isAccepted = _requestStatus == 'accepted';

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, // Allow header to go behind app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
            // Unified Header Section
            _buildHeader(artisan, isUrdu, fontFamily),

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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 50,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkColor, // Solid Dark Color (No opacity)
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          ProfileInfoWidget(
            name: artisan.name,
            phone: '', 
            profileImage: artisan.profileImage,
            category: artisan.professionUrdu,
            address: '${artisan.location} \u200E(${widget.distanceKm?.toStringAsFixed(1) ?? "0.0"} km)', 
            isVerified: artisan.isVerified || artisan.verificationStatus == 'approved',
            isLarge: true,
            isVerticalCategory: true,
            textColor: Colors.white,
            subtitleColor: Colors.white70,
            categoryColor: Colors.white, // Profession in white as requested
            customSize: 85,
            suffix: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                InkWell(
                  onTap: isOwner ? _toggleAvailability : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: artisan.availability == 'available'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
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
                        fontSize: 11,
                        color: artisan.availability == 'available'
                            ? Colors.green[300]
                            : Colors.red[300],
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Ratings and Reviews
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ArtisanRatingStars(
                  rating: artisan.rating, 
                  size: 18,
                  color: Colors.white, // White stars as requested
                ),
                const SizedBox(width: 10),
                Text(
                  '${artisan.rating}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${artisan.totalReviews} ${isUrdu ? 'ریویوز' : 'reviews'})',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
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
              fontSize: 16, // Increased from 14 to 16
              color: Colors.grey[800],
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
          // Add Review Button (Only if interacted/accepted)
          if (_requestStatus == 'accepted' && !isOwner)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddReviewDialog(isUrdu, fontFamily),
                  icon: Icon(PhosphorIcons.pencilLine(), size: 18),
                  label: Text(
                    isUrdu ? 'اپنی رائے دیں' : 'Write a Review',
                    style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.themeColor,
                    side: BorderSide(color: AppTheme.themeColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
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
    final bool isVerified = artisan.isVerified || artisan.verificationStatus == 'approved';
    final bool isPending = artisan.verificationStatus == 'pending';

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
            if (!isVerified) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isPending
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VerificationRequestScreen(
                                isArtisanMode: true,
                              ),
                            ),
                          ).then((_) => _loadData());
                        },
                  icon: Icon(isPending ? PhosphorIcons.clock() : PhosphorIcons.shieldCheck()),
                  label: Text(
                    isPending
                        ? (isUrdu ? 'تصدیق جاری ہے...' : 'Verifying...')
                        : (isUrdu ? 'تصدیق کروائیں' : 'Verify Now'),
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPending ? Colors.grey[400] : AppTheme.verifiedGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
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
    final bool isPending = _requestStatus == 'pending';
    final bool isAccepted = _requestStatus == 'accepted';
    final bool isRejected = _requestStatus == 'rejected';

    Color btnColor = AppTheme.themeColor;
    String btnText = isUrdu ? 'کیا آپ کام کریں گے؟' : 'Available for work?';
    IconData? icon;

    if (isPending) {
      btnColor = Colors.orange.shade700;
      btnText = isUrdu ? 'جواب کا انتظار' : 'Waiting...';
      icon = PhosphorIcons.clock();
    } else if (isAccepted) {
      btnColor = Colors.green.shade700;
      btnText = isUrdu ? 'منظور شدہ' : 'Accepted';
      icon = PhosphorIcons.checkCircle();
    } else if (isRejected) {
      btnColor = Colors.red.shade700;
      btnText = isUrdu ? 'دوبارہ پوچھیں' : 'Ask Again';
      icon = PhosphorIcons.arrowClockwise();
    }

    final artisan = _artisan!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Work Request Button
                if (artisan.availability == 'available') ...[
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: (_isSending || isPending || isAccepted) ? null : () => _sendWorkRequest(isUrdu),
                      icon: _isSending 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(icon ?? PhosphorIcons.question(), size: 20),
                      label: Text(
                        btnText,
                        style: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // In-App Chat Button (Always visible for customers)
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _openInAppChat,
                    icon: Icon(PhosphorIcons.chatCircleDots(PhosphorIconsStyle.fill), size: 20),
                    label: Text(
                      isUrdu ? 'چیٹ' : 'Chat',
                      style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            if (isAccepted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _whatsappArtisan,
                  icon: Icon(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), size: 22),
                  label: Text(
                    isUrdu ? 'واٹس ایپ پر رابطہ کریں' : 'Contact on WhatsApp',
                    style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}