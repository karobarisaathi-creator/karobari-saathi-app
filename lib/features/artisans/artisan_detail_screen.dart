// lib/features/artisans/screens/artisan_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/services/database/job_negotiation_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/image_gallery_viewer.dart';
import 'artisan_work_orders_screen.dart';

import '../settings/master_profile_screen.dart';
import '../dashboard/main_navigation_screen.dart';
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
  bool _isLoading = true;
  int _workCount = 0;
  bool _isSending = false;
  int _activeIndex = 0; // 0: about, 1: gallery, 2: reviews
  late PageController _pageController;

  bool get isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.artisanId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _setupArtisanListener();
    if (!widget.artisanId.startsWith('dummy')) {
      _loadExtraData();
    }
  }

  @override
  void dispose() {
    _artisanSub?.cancel();
    _pageController.dispose();
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

  void _sendWorkRequest(bool isUrdu) async {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final String inquiryMessage = isUrdu
        ? 'السلام علیکم! میں آپ کی خدمات حاصل کرنا چاہتا ہوں۔ کیا آپ اس وقت کام کے لیے دستیاب ہیں؟'
        : 'Salam! I am interested in your services. Are you currently available for work?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUrdu ? 'رابطہ کریں' : 'Contact Artisan',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUrdu
              ? 'کیا آپ اس کاریگر کے ساتھ کام کے بارے میں بات چیت شروع کرنا چاہتے ہیں؟'
              : 'Do you want to start a negotiation with this artisan?',
          style: TextStyle(
              fontSize: 14, color: Colors.grey[700], fontFamily: fontFamily),
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
            text: isUrdu ? 'پیغام بھیجیں' : 'Send Message',
            color: AppTheme.themeColor,
            variant: AppButtonVariant.primary,
            onPressed: () async {
              Navigator.pop(context);
              _openNegotiation(isUrdu, inquiryMessage);
            },
          ),
        ],
      ),
    );
  }

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
        errorText:
            controller.text.isNotEmpty && controller.text.length < minLength
                ? (isUrdu
                    ? 'کم از کم $minLength حروف درکار ہیں'
                    : 'Min $minLength characters required')
                : null,
        filled: true,
        fillColor: const Color(0xFFF5F7F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _openNegotiation(bool isUrdu, String workDescription) async {
    setState(() => _isSending = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isSending = false);
      return;
    }

    try {
      final existingOrders = await FirebaseFirestore.instance
          .collection('artisans')
          .doc(widget.artisanId)
          .collection('work_orders')
          .where('customerId', isEqualTo: user.uid)
          .where('status', whereIn: ['negotiating', 'quoted'])
          .limit(1)
          .get();

      ArtisanWorkOrder order;
      if (existingOrders.docs.isNotEmpty) {
        order = ArtisanWorkOrder.fromMap(existingOrders.docs.first.data());
      } else {
        // 🆕 اسمارٹ عنوان: اگر پہلا پیغام مختصر ہے تو اسے عنوان بنا دیں، ورنہ پیشہ استعمال کریں
        String smartTitle = workDescription.trim();
        if (smartTitle.length > 40) {
          smartTitle = smartTitle.substring(0, 37) + "...";
        }
        // اگر پیغام بہت ہی چھوٹا ہے (مثلاً صرف سلام)، تو پیشہ ہی رہنے دیں
        if (smartTitle.length < 5) {
          smartTitle = isUrdu 
            ? '${_artisan?.professionUrdu ?? 'کاریگر'} کی خدمات' 
            : '${_artisan?.profession ?? 'Artisan'} Service';
        }

        order = ArtisanWorkOrder(
          id: 'artisan_chat_${DateTime.now().millisecondsSinceEpoch}',
          artisanId: widget.artisanId,
          artisanName: _artisan?.name,
          title: smartTitle, // اسمارٹ عنوان یہاں سیو ہوگا
          customerId: user.uid,
          customerName:
              user.displayName ?? (isUrdu ? 'ایک گاہک' : 'A Customer'),
          customerPhone: user.phoneNumber ?? '',
          workDescription: workDescription,
          status: 'negotiating',
          createdAt: DateTime.now(),
        );
        await FirebaseFirestore.instance
            .collection('artisans')
            .doc(widget.artisanId)
            .collection('work_orders')
            .doc(order.id)
            .set(order.toMap());
      }

      await JobNegotiationService().sendNegotiationMessage(
        jobId: order.id,
        artisanId: widget.artisanId,
        message: workDescription,
        isDirect: true,
      );

      if (mounted) {
        setState(() {
          _isSending = false;
        });

        // Set the target tab and expansion
        final notificationService =
            Provider.of<NotificationService>(context, listen: false);
        notificationService.setNotificationsTabIndex(1);
        notificationService.setTargetExpandOrderId(order.id);

        // Change tab and THEN pop
        MainNavigationScreen.switchTab(4);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isUrdu ? 'رابطہ شروع کر دیا گیا ہے۔' : 'Contact started.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isUrdu
                  ? 'رابطہ شروع نہیں ہو سکا'
                  : 'Unable to start contact')),
        );
      }
    }
  }

  void _showAddReviewDialog(bool isUrdu, String fontFamily) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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
              onPressed: () => Navigator.pop(dialogContext),
            ),
            const SizedBox(width: 8),
            AppButton(
              text: isUrdu ? 'جمع کریں' : 'Submit',
              color: AppTheme.themeColor,
              variant: AppButtonVariant.primary,
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : () async {
                final comment = commentController.text.trim();
                if (comment.length < 20) return;

                setDialogState(() => isSubmitting = true);

                try {
                  final artisanService = ArtisanService();
                  await artisanService.addReview(
                    artisanId: widget.artisanId,
                    rating: selectedRating,
                    comment: comment,
                  );

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _loadData();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(isUrdu
                            ? 'آپ کا ریویو جمع ہوگیا ہے!'
                            : 'Review submitted!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkRequestButton(bool isUrdu, String fontFamily) {
    Color btnColor = AppTheme.themeColor;
    final btnText = isUrdu ? 'رابطہ کریں' : 'Contact';
    final icon = PhosphorIcons.chatCircleDots();

    return AppButton(
      text: btnText,
      icon: icon,
      color: btnColor,
      size: AppButtonSize.large,
      isLoading: _isSending,
      onPressed: _isSending ? null : () => _sendWorkRequest(isUrdu),
    );
  }

  void _shareProfile() {
    if (_artisan == null) return;
    final message = '''
🛠️ ${_artisan!.name}
📋 ${_artisan!.profession} | ${_artisan!.professionUrdu}
📍 ${_artisan!.location}
⭐ ${_artisan!.rating} (${_artisan!.totalReviews} reviews)

Check out this artisan on Karobari Saathi!
کاریگر کی تفصیلات دیکھنے کے لیے کاروباری ساتھی ایپ ڈاؤن لوڈ کریں۔
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

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
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
            _buildHeader(artisan, isUrdu, fontFamily),
            _buildLocationStrip(artisan, isUrdu, fontFamily),
            _buildSelectionBar(isUrdu, fontFamily),
            const SizedBox(height: 16),
            _buildTabContent(artisan, isUrdu, fontFamily),
          ],
        ),
      ),
      bottomNavigationBar: isOwner
          ? _buildOwnerBottomBar(isUrdu, fontFamily)
          : _buildCustomerBottomBar(isUrdu, fontFamily),
    );
  }

  Widget _buildTabContent(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    switch (_activeIndex) {
      case 0:
        return _AboutTab(
            artisan: artisan, isUrdu: isUrdu, fontFamily: fontFamily);
      case 1:
        return _GalleryTab(
            artisan: artisan, isUrdu: isUrdu, fontFamily: fontFamily);
      case 2:
        return _ReviewsTab(
          artisanId: widget.artisanId,
          isUrdu: isUrdu,
          fontFamily: fontFamily,
          requestStatus: null,
          isOwner: isOwner,
          onAddReview: () => _showAddReviewDialog(isUrdu, fontFamily),
        );
      default:
        return const SizedBox.shrink();
    }
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
        color: AppTheme.darkColor,
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
                category: isUrdu ? artisan.professionUrdu : artisan.profession,
                address: isUrdu
                    ? '${artisan.experience} سال کا تجربہ'
                    : '${artisan.experience} years experience',
                isVerified: artisan.isVerified ||
                    artisan.verificationStatus == 'approved',
                isLarge: true,
                isVerticalCategory: true,
                isFavorite: isFav,
                textColor: Colors.white,
                subtitleColor: Colors.white70,
                categoryColor: Colors.white,
                customSize: 85,
                verticalSpacing: 6.0,
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
                        const Spacer(),
                        Text(
                          '${isUrdu ? 'مکمل کام' : 'Jobs Done'}: ${artisan.workCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily,
                          ),
                        ),
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

  Widget _buildAvailabilityBadge(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
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

  Widget _buildLocationStrip(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.lightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
              size: 20, color: AppTheme.themeColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUrdu ? 'مقام' : 'Location',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: fontFamily),
                ),
                Text(
                  artisan.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStripItem(
      String label, String value, IconData icon, String fontFamily) {
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
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: fontFamily),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor),
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
                  icon: isPending
                      ? PhosphorIcons.clock()
                      : PhosphorIcons.shieldCheck(),
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
                if (_artisan!.availability == 'available') ...[
                  Expanded(
                    child: _buildWorkRequestButton(isUrdu, fontFamily),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getUnitUr(String? unit) {
    switch (unit) {
      case 'hour':
        return 'فی گھنٹہ';
      case 'day':
        return 'فی دیہاڑی';
      case 'month':
        return 'فی مہینہ';
      case 'fixed':
        return 'کل رقم';
      case 'contract':
        return 'ٹھیکہ';
      case 'item':
      case 'per_item':
        return 'فی آئٹم';
      case 'sqft':
        return 'فی مربع فٹ';
      case 'visit':
        return 'فی وزٹ';
      case 'km':
        return 'فی کلومیٹر';
      case 'kg':
        return 'فی کلو';
      default:
        return 'کام';
    }
  }

  String _getUnitEn(String? unit) {
    switch (unit) {
      case 'hour':
        return 'Hr';
      case 'day':
        return 'Day';
      case 'month':
        return 'Mo';
      case 'fixed':
        return 'Total';
      case 'contract':
        return 'Contract';
      case 'item':
      case 'per_item':
        return 'Item';
      case 'sqft':
        return 'Sqft';
      case 'visit':
        return 'Visit';
      case 'km':
        return 'KM';
      case 'kg':
        return 'KG';
      default:
        return 'Job';
    }
  }

  Widget _buildSelectionBar(bool isUrdu, String fontFamily) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: AlignmentDirectional(
              _activeIndex == 0 ? -1.0 : (_activeIndex == 1 ? 0.0 : 1.0),
              0.0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _buildSelectionItem(
                  0, 'about', isUrdu ? 'تعارف' : 'About', isUrdu, fontFamily),
              _buildSelectionItem(1, 'gallery', isUrdu ? 'گیلری' : 'Gallery',
                  isUrdu, fontFamily),
              _buildSelectionItem(2, 'reviews', isUrdu ? 'ریویوز' : 'Reviews',
                  isUrdu, fontFamily),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionItem(
      int index, String id, String label, bool isUrdu, String fontFamily) {
    final bool isActive = _activeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
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

  Widget _buildBadge(String text, Color bgColor, Color textColor,
      String fontFamily, bool isUrdu) {
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
            Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                size: 12, color: textColor),
          if (text == 'GREAT VALUE' || text == 'بہترین سروس')
            Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                size: 12, color: textColor),
          if (text == 'ELITE' ||
              text == 'تصدیق شدہ' ||
              text == 'GREAT VALUE' ||
              text == 'بہترین سروس')
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

class _AboutTab extends StatefulWidget {
  final ArtisanProfile artisan;
  final bool isUrdu;
  final String fontFamily;
  const _AboutTab(
      {required this.artisan, required this.isUrdu, required this.fontFamily});

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDescription(widget.artisan, widget.isUrdu, widget.fontFamily),
          if (widget.artisan.qualification != null && widget.artisan.qualification!.isNotEmpty)
            _buildQualificationSection(widget.artisan, widget.isUrdu, widget.fontFamily),
          if (widget.artisan.website != null && widget.artisan.website!.isNotEmpty)
            _buildWebsiteSection(widget.artisan, widget.isUrdu, widget.fontFamily),
          if (widget.artisan.skills.isNotEmpty)
            _buildSkillsSection(
                widget.artisan, widget.isUrdu, widget.fontFamily),
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
                fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          Text(
            artisan.description,
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                fontFamily: fontFamily,
                height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildQualificationSection(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'تعلیمی قابلیت' : 'Qualification',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          Text(
            artisan.qualification!,
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                fontFamily: fontFamily,
                height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteSection(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'ویب سائٹ' : 'Website',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              // وپ سائٹ کھولنے کی لاجک یہاں آ سکتی ہے
            },
            child: Row(
              children: [
                Icon(PhosphorIcons.globe(), size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    artisan.website!,
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(
      ArtisanProfile artisan, bool isUrdu, String fontFamily) {
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
                fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (isUrdu && artisan.skillsUrdu.isNotEmpty
                    ? artisan.skillsUrdu
                    : artisan.skills)
                .map((skill) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _GalleryTab extends StatefulWidget {
  final ArtisanProfile artisan;
  final bool isUrdu;
  final String fontFamily;
  const _GalleryTab(
      {required this.artisan, required this.isUrdu, required this.fontFamily});

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        if (widget.artisan.workImages.isNotEmpty)
          _buildWorkGallery(widget.artisan, widget.isUrdu, widget.fontFamily)
        else
          _buildEmptyGallery(widget.isUrdu, widget.fontFamily),
      ],
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
                fontFamily: fontFamily),
          ),
        ),
        ImageGalleryViewer(
          imagePaths: artisan.workImages,
          isVerticalGrid: false,
          isReadOnly: true,
          height: 150,
        ),
      ],
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
            Text(isUrdu ? 'کوئی تصویر موجود نہیں' : 'No images available',
                style: TextStyle(color: Colors.grey, fontFamily: fontFamily)),
          ],
        ),
      ),
    );
  }
}

class _ReviewsTab extends StatefulWidget {
  final String artisanId;
  final bool isUrdu;
  final String fontFamily;
  final String? requestStatus;
  final bool isOwner;
  final VoidCallback onAddReview;

  const _ReviewsTab({
    required this.artisanId,
    required this.isUrdu,
    required this.fontFamily,
    this.requestStatus,
    required this.isOwner,
    required this.onAddReview,
  });

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab>
    with AutomaticKeepAliveClientMixin {
  late Stream<List<ArtisanReview>> _reviewsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reviewsStream = ArtisanService().getReviews(widget.artisanId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.requestStatus == 'accepted' && !widget.isOwner)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: AppButton(
                text: widget.isUrdu ? 'اپنی رائے دیں' : 'Write a Review',
                onPressed: widget.onAddReview,
                icon: PhosphorIcons.pencilLine(),
                color: AppTheme.themeColor,
                isFullWidth: true,
                size: AppButtonSize.large,
              ),
            ),
          StreamBuilder<List<ArtisanReview>>(
            stream: _reviewsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final reviews = snapshot.data ?? [];
              if (reviews.isEmpty)
                return _buildEmptyReviewsState(
                    widget.isUrdu, widget.fontFamily);

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
                          Text(review.reviewerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(Formatters.formatDate(review.timestamp),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ArtisanRatingStars(rating: review.rating, size: 14),
                      const SizedBox(height: 8),
                      Text(review.comment,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.5,
                              fontFamily: widget.fontFamily)),
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
            Text(isUrdu ? 'ابھی تک کوئی ریویو موجود نہیں' : 'No reviews yet',
                style: TextStyle(color: Colors.grey, fontFamily: fontFamily)),
          ],
        ),
      ),
    );
  }
}
