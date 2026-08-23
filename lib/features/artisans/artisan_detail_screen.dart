// lib/features/artisans/screens/artisan_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:account_app/core/utils/artisan_validators.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/image_gallery_viewer.dart';
import 'artisan_work_orders_screen.dart';
import 'artisan_reviews_screen.dart';
import '../settings/master_profile_screen.dart';
import 'package:account_app/features/settings/verification_request_screen.dart';

class ArtisanDetailScreen extends StatefulWidget {
  final String artisanId;
  final ArtisanProfile? initialArtisan;
  final double? distanceKm;

  const ArtisanDetailScreen(
      {super.key,
      required this.artisanId,
      this.initialArtisan,
      this.distanceKm});

  @override
  State<ArtisanDetailScreen> createState() => _ArtisanDetailScreenState();
}

class _ArtisanDetailScreenState extends State<ArtisanDetailScreen> {
  ArtisanProfile? _artisan;
  StreamSubscription<ArtisanProfile?>? _artisanSub;
  StreamSubscription<String?>? _requestStatusSub;
  bool _isLoading = true;
  int _workCount = 0;
  bool _isSending = false;
  String? _requestStatus;
  String _activeSection = 'about'; // 'about', 'gallery', 'reviews'

  bool get isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.artisanId;

  @override
  void initState() {
    super.initState();
    _checkRequestStatus();
    _listenRequestStatus();
    _setupArtisanListener();
    if (!widget.artisanId.startsWith('dummy')) {
      _loadExtraData();
    }
  }

  @override
  void dispose() {
    _artisanSub?.cancel();
    _requestStatusSub?.cancel();
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
    final newStatus =
        _artisan!.availability == 'available' ? 'busy' : 'available';

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
    if (_artisan != null) {
      setState(() {
        _workCount = _artisan!.workCount;
      });
    }

    // اگر اپنا پروفائل ہے تو تازہ ترین تعداد حاصل کریں
    if (isOwner) {
      final workService = ArtisanWorkOrderService();
      final count = await workService.getWorkCount(widget.artisanId);
      if (mounted) {
        setState(() {
          _workCount = count;
        });
      }
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

  void _listenRequestStatus() {
    final nService = Provider.of<NotificationService>(context, listen: false);
    _requestStatusSub =
        nService.artisanRequestStatusStream(widget.artisanId).listen((status) {
      if (mounted) {
        setState(() {
          _requestStatus = status;
        });
      }
    });
  }

  void _sendWorkRequest(bool isUrdu) async {
    final descriptionController = TextEditingController();
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUrdu ? 'کام کی بات چیت شروع کریں' : 'Start Work Discussion',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUrdu 
                ? 'بتائیں کہ آپ کو کیا کام کروانا ہے تاکہ کاریگر آپ سے رابطہ کر سکے۔' 
                : 'Describe what you need so the artisan can contact you.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: fontFamily),
            ),
            const SizedBox(height: 16),
            _buildValidatedTextField(
              controller: descriptionController,
              label: isUrdu ? 'کام کی مختصر تفصیل' : 'Short description of work',
              minLength: 5,
              maxLength: 100,
              isUrdu: isUrdu,
              onChanged: (val) => (context as Element).markNeedsBuild(),
            ),
          ],
        ),
        actions: [
          AppButton(
            text: isUrdu ? 'کینسل' : 'Cancel',
            variant: AppButtonVariant.ghost,
            color: Colors.grey[600],
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          AppButton(
            text: isUrdu ? 'رابطہ کریں' : 'Connect',
            color: AppTheme.themeColor,
            variant: AppButtonVariant.primary,
            onPressed: () async {
              final desc = descriptionController.text.trim();
              if (desc.length < 5) return;

              Navigator.pop(context);
              _processSendRequest(isUrdu, desc);
            },
          ),
        ],
      ),
    );
  }

  /// کام کی تفصیلات کے لیے ویلیڈیٹڈ ٹیکسٹ فیلڈ
  Widget _buildValidatedTextField({
    required TextEditingController controller,
    required String label,
    required int minLength,
    required int maxLength,
    required bool isUrdu,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: 3,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        counterText: '${controller.text.length}/$maxLength',
        // اگر حروف کم ہوں تو اردو یا انگریزی میں ایرر دکھائیں
        errorText: controller.text.isNotEmpty && controller.text.length < minLength
            ? (isUrdu ? 'کم از کم $minLength حروف درکار ہیں' : 'Min $minLength characters required')
            : null,
        filled: true,
        fillColor: const Color(0xFFF5F7F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  /// بجٹ کی تصدیق کے لیے ویلیڈیٹڈ فیلڈ
  Widget _buildValidatedBudgetField({
    required TextEditingController controller,
    required String label,
    required bool isUrdu,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly], // صرف نمبرز کی اجازت
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        // اگر رقم 0 یا اس سے کم ہو تو ایرر دکھائیں
        errorText: controller.text.isNotEmpty && (double.tryParse(controller.text) ?? 0) <= 0
            ? (isUrdu ? 'برائے مہربانی درست رقم درج کریں' : 'Please enter a valid amount')
            : null,
        filled: true,
        fillColor: const Color(0xFFF5F7F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool isNumber = false,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        color: AppTheme.darkColor,
        fontFamily: isNumber ? '' : fontFamily,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: isUrdu ? 'NooriNastaleeq' : '',
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: const Color(0xFFF5F7F9),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)
        ),
      ),
    );
  }

  void _processSendRequest(bool isUrdu, String workDescription) async {
    setState(() => _isSending = true);
    final nService = Provider.of<NotificationService>(context, listen: false);
    final workOrderService = ArtisanWorkOrderService();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      // 1. Create a Work Order in 'negotiating' status
      final String orderId = "wo_${user.uid}_${widget.artisanId}_${DateTime.now().millisecondsSinceEpoch}";
      final newOrder = ArtisanWorkOrder(
        id: orderId,
        artisanId: widget.artisanId,
        customerId: user.uid,
        customerName: user.displayName ?? (isUrdu ? 'ایک گاہک' : 'A Customer'),
        customerPhone: user.phoneNumber ?? '',
        workDescription: workDescription,
        status: 'negotiating',
        createdAt: DateTime.now(),
      );

      await workOrderService.addWorkOrder(newOrder);

      // 2. Send Notification
      await nService.sendArtisanWorkRequest(
        artisanUid: widget.artisanId,
        customerName: user.displayName ?? (isUrdu ? 'ایک گاہک' : 'A Customer'),
        workDescription: workDescription,
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          _requestStatus = 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu
                ? 'رابطے کی درخواست بھیج دی گئی! اب آپ "میرے کام" میں بات چیت کر سکتے ہیں۔'
                : 'Inquiry sent! You can now negotiate in "My Works".'),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isUrdu ? 'اپنی رائے دیں' : 'Write a Review',
            style:
                TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu ? 'کاریگر کا کام کیسا رہا؟' : 'How was your experience?',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: fontFamily),
              ),
              const SizedBox(height: 20),
              // Star Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1.0),
                    icon: Icon(
                      index < selectedRating
                          ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                          : PhosphorIcons.star(),
                      color: AppTheme.darkColor,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              _buildValidatedTextField(
                controller: commentController,
                label: isUrdu ? 'اپنا تجربہ لکھیں' : 'Write your experience',
                minLength: 20,
                maxLength: 200,
                isUrdu: isUrdu,
                onChanged: (val) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            AppButton(
              text: isUrdu ? 'کینسل' : 'Cancel',
              variant: AppButtonVariant.ghost,
              color: Colors.grey[600],
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            AppButton(
              text: isUrdu ? 'جمع کریں' : 'Submit',
              color: AppTheme.themeColor,
              variant: AppButtonVariant.primary,
              onPressed: () async {
                if (commentController.text.trim().length < 20) return;

                final artisanService = ArtisanService();
                await artisanService.addReview(
                  artisanId: widget.artisanId,
                  rating: selectedRating,
                  comment: commentController.text.trim(),
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadData(); // Refresh to see new rating
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isUrdu
                          ? 'آپ کا ریویو جمع ہوگیا ہے!'
                          : 'Review submitted!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkRequestButton(bool isUrdu, String fontFamily) {
    final bool isPending = _requestStatus == 'pending';
    final bool isAccepted = _requestStatus == 'accepted';
    final bool isRejected = _requestStatus == 'rejected';

    Color btnColor = AppTheme.themeColor;
    String btnText = isUrdu ? 'کیا کام کریں گے؟' : 'Available?';
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

    return AppButton(
      text: btnText,
      icon: icon,
      color: btnColor,
      size: AppButtonSize.large,
      onPressed: (_isSending || isPending || isAccepted)
          ? null
          : () => _sendWorkRequest(isUrdu),
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
        'https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent('Salam! I found your profile on Karobari Saathi. I need your services.')}',
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
          icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildAvailabilityBadge(artisan, isUrdu, fontFamily),
          if (!isOwner)
            StreamBuilder<bool>(
              stream: ArtisanService().isFavorite(widget.artisanId),
              builder: (context, snapshot) {
                final isFav = snapshot.data ?? false;
                return IconButton(
                  icon: Icon(
                    isFav
                        ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                        : PhosphorIcons.heart(),
                    color: isFav ? Colors.red : Colors.white,
                  ),
                  onPressed: () =>
                      ArtisanService().toggleFavorite(widget.artisanId),
                );
              },
            ),
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
                    builder: (context) => const MasterProfileScreen(),
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

            // لوکیشن اور کام کی معلومات (Location & Tasks Strip)
            _buildLocationAndTasksStrip(artisan, isUrdu, fontFamily),

            // نیویگیشن پٹی (Modern Selection Bar)
            _buildSelectionBar(isUrdu, fontFamily),

            const SizedBox(height: 16),

            // متحرک مواد (Dynamic Content based on selection)
            if (_activeSection == 'about') ...[
              _buildDescription(artisan, isUrdu, fontFamily),
              if (artisan.skills.isNotEmpty)
                _buildSkillsSection(artisan, isUrdu, fontFamily),
            ] else if (_activeSection == 'gallery') ...[
              if (artisan.workImages.isNotEmpty)
                _buildWorkGallery(artisan, isUrdu, fontFamily)
              else
                _buildEmptyGallery(isUrdu, fontFamily),
            ] else if (_activeSection == 'reviews') ...[
              _buildReviewsTabContent(artisan, isUrdu, fontFamily),
            ],

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
    final String rateText = artisan.rate != null && artisan.rate!.isNotEmpty
        ? (isUrdu
            ? 'Rs. ${artisan.rate} / ${_getUnitUr(artisan.rateUnit)}'
            : 'Rs. ${artisan.rate} / ${_getUnitEn(artisan.rateUnit)}')
        : (isUrdu ? 'ریٹ دستیاب نہیں' : 'N/A');

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 50,
        bottom: 32,
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
          StreamBuilder<bool>(
            stream: ArtisanService().isFavorite(artisan.id),
            builder: (context, favSnapshot) {
              final isFav = favSnapshot.data ?? false;
              return ProfileInfoWidget(
                name: artisan.name,
                phone: '',
                profileImage: artisan.profileImage,
                category: artisan.professionUrdu,
                address: isUrdu ? '${artisan.experience} سال کا تجربہ' : '${artisan.experience} years experience',
                isVerified:
                    artisan.isVerified || artisan.verificationStatus == 'approved',
                isLarge: true,
                isVerticalCategory: true,
                isFavorite: isFav,
                textColor: Colors.white,
                subtitleColor: Colors.white70,
                categoryColor: Colors.white, // Profession in white as requested
                customSize: 85,
                suffix: Text(
                  rateText,
                  style: TextStyle(
                    fontSize: isUrdu ? 14 : 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: isUrdu ? fontFamily : null,
                  ),
                ),
                bottom: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${artisan.rating} (${artisan.totalReviews} ${isUrdu ? 'ریٹنگز' : 'ratings'})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: isUrdu ? fontFamily : null,
                          ),
                        ),
                        if (artisan.rating >= 4.5) ...[
                          const SizedBox(width: 8),
                          _buildBadge(
                            isUrdu ? 'بہترین سروس' : 'GREAT VALUE',
                            AppTheme.incomeColor.withOpacity(0.15),
                            AppTheme.incomeColor,
                            fontFamily,
                            isUrdu,
                          ),
                        ],
                        if (isFav) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.themeColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PhosphorIcons.heart(PhosphorIconsStyle.fill),
                              size: 12,
                              color: AppTheme.themeColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityBadge(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Center(
      child: InkWell(
        onTap: isOwner ? _toggleAvailability : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: artisan.availability == 'available'
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
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
              fontSize: 10,
              color: artisan.availability == 'available'
                  ? Colors.green[300]
                  : Colors.red[300],
              fontWeight: FontWeight.bold,
              fontFamily: fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactButtons(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              onPressed: _callArtisan,
              icon: PhosphorIcons.phone(PhosphorIconsStyle.fill),
              text: isUrdu ? 'کال کریں' : 'Call',
              color: Colors.green,
              size: AppButtonSize.large,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              onPressed: _whatsappArtisan,
              icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
              text: isUrdu ? 'واٹس ایپ' : 'WhatsApp',
              color: const Color(0xFF25D366),
              size: AppButtonSize.large,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
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

  Widget _buildSkillsSection(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'مہارتیں' : 'Skills',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: artisan.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.themeColor.withOpacity(0.3)),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.themeColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkGallery(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            isUrdu ? 'کام کی تصاویر' : 'Work Gallery',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
        ),
        ImageGalleryViewer(
          imagePaths: artisan.workImages,
          isVerticalGrid: false, // افقی سلائیڈر کے لیے
          isReadOnly: true,
          height: 150, // سلائیڈر کی اونچائی
        ),
      ],
    );
  }

  Widget _buildLocationAndTasksStrip(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.lightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStripItem(
            isUrdu ? 'مقام' : 'Location',
            artisan.location,
            PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
            fontFamily,
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          _buildStripItem(
            isUrdu ? 'مکمل کام' : 'Jobs Done',
            '$_workCount',
            PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
            fontFamily,
          ),
        ],
      ),
    );
  }

  Widget _buildStripItem(String label, String value, IconData icon, String fontFamily) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppTheme.themeColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: fontFamily),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTabContent(ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_requestStatus == 'accepted' && !isOwner)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: AppButton(
                text: isUrdu ? 'اپنی رائے دیں' : 'Write a Review',
                onPressed: () => _showAddReviewDialog(isUrdu, fontFamily),
                icon: PhosphorIcons.pencilLine(),
                color: AppTheme.themeColor,
                isFullWidth: true,
                size: AppButtonSize.large,
              ),
            ),
          StreamBuilder<List<ArtisanReview>>(
            stream: ArtisanService().getReviews(widget.artisanId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reviews = snapshot.data ?? [];

              if (reviews.isEmpty) {
                return _buildEmptyReviewsState(isUrdu, fontFamily);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            review.reviewerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            Formatters.formatDate(review.timestamp),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ArtisanRatingStars(rating: review.rating, size: 14),
                      const SizedBox(height: 8),
                      Text(
                        review.comment,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5, fontFamily: fontFamily),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReviewsState(bool isUrdu, String fontFamily) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(PhosphorIcons.chatText(), size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isUrdu ? 'ابھی تک کوئی ریویو موجود نہیں' : 'No reviews yet',
              style: TextStyle(color: Colors.grey, fontFamily: fontFamily),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerBottomBar(bool isUrdu, String fontFamily) {
    final artisan = _artisan!;
    final bool isVerified =
        artisan.isVerified || artisan.verificationStatus == 'approved';
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
                child: AppButton(
                  text: isPending
                      ? (isUrdu ? 'تصدیق جاری ہے...' : 'Verifying...')
                      : (isUrdu ? 'تصدیق کروائیں' : 'Verify Now'),
                  icon: isPending ? PhosphorIcons.clock() : PhosphorIcons.shieldCheck(),
                  color: isPending ? Colors.grey : AppTheme.verifiedGold,
                  size: AppButtonSize.large,
                  onPressed: isPending
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const VerificationRequestScreen(
                                isArtisanMode: true,
                              ),
                            ),
                          ).then((_) => _loadData());
                        },
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: AppButton(
                text: isUrdu ? 'میرے کام' : 'My Works',
                icon: PhosphorIcons.listBullets(),
                size: AppButtonSize.large,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ArtisanWorkOrdersScreen(artisanId: widget.artisanId),
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
                    child: _buildWorkRequestButton(isUrdu, fontFamily),
                  ),
                  const SizedBox(width: 10),
                ],
                // In-App WhatsApp Button (Replaced Chat)
                if (artisan.showWhatsApp)
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      text: isUrdu ? 'واٹس ایپ' : 'WhatsApp',
                      icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                      color: const Color(0xFF25D366),
                      size: AppButtonSize.large,
                      onPressed: _whatsappArtisan,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getUnitUr(String? unit) {
    switch (unit) {
      case 'hour': return 'فی گھنٹہ';
      case 'day': return 'فی دیہاڑی';
      case 'month': return 'فی مہینہ';
      case 'fixed': return 'مکمل کام';
      default: return 'کام';
    }
  }

  String _getUnitEn(String? unit) {
    switch (unit) {
      case 'hour': return 'Hr';
      case 'day': return 'Day';
      case 'month': return 'Mo';
      case 'fixed': return 'Fixed';
      default: return 'Job';
    }
  }

  Widget _buildSelectionBar(bool isUrdu, String fontFamily) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildSelectionItem('about', isUrdu ? 'تعارف' : 'About', isUrdu, fontFamily),
          _buildSelectionItem('gallery', isUrdu ? 'گیلری' : 'Gallery', isUrdu, fontFamily),
          _buildSelectionItem('reviews', isUrdu ? 'ریویوز' : 'Reviews', isUrdu, fontFamily),
        ],
      ),
    );
  }

  Widget _buildSelectionItem(String id, String label, bool isUrdu, String fontFamily) {
    final bool isActive = _activeSection == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSection = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
              color: isActive ? AppTheme.themeColor : Colors.grey[600],
              fontFamily: fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGallery(bool isUrdu, String fontFamily) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(PhosphorIcons.image(), size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isUrdu ? 'کوئی تصویر موجود نہیں' : 'No images available',
              style: TextStyle(color: Colors.grey, fontFamily: fontFamily),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor, String fontFamily, bool isUrdu) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text == 'ELITE' || text == 'تصدیق شدہ')
             Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), size: 12, color: textColor),
          if (text == 'GREAT VALUE' || text == 'بہترین سروس')
             Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 12, color: textColor),
          if (text == 'ELITE' || text == 'تصدیق شدہ' || text == 'GREAT VALUE' || text == 'بہترین سروس')
             const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: textColor,
              fontFamily: isUrdu ? fontFamily : null,
            ),
          ),
        ],
      ),
    );
  }
}
