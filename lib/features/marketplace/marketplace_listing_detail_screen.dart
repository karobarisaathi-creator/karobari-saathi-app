// lib/features/marketplace/marketplace_listing_detail_screen.dart

import 'package:account_app/core/services/database/profile_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/features/marketplace/models/marketplace_categories.dart';
import 'package:account_app/features/marketplace/models/marketplace_listing.dart';
import 'package:account_app/features/marketplace/services/marketplace_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════
// رنگ — AppTheme کے مطابق (ہلکا پس منظر)
// ═══════════════════════════════════════════════════════════════
class _C {
  static const accent = AppTheme.themeColor;
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const textPrimary = AppTheme.darkColor;
  static const textSecondary = AppTheme.textSecondary;
  static const textMuted = Color(0xFF94A3B8);
  static const success = AppTheme.incomeColor;
  static const danger = AppTheme.expenseColor;
  static const warning = Color(0xFFF59E0B);
}

class MarketplaceListingDetailScreen extends StatefulWidget {
  final String listingId;
  final MarketplaceService? service;

  const MarketplaceListingDetailScreen({
    super.key,
    required this.listingId,
    this.service,
  });

  @override
  State<MarketplaceListingDetailScreen> createState() =>
      _MarketplaceListingDetailScreenState();
}

class _MarketplaceListingDetailScreenState
    extends State<MarketplaceListingDetailScreen> {
  late final MarketplaceService _service;
  late final Stream<MarketplaceListing?> _listingStream;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MarketplaceService();
    _listingStream = _service.watchListing(widget.listingId);
  }

  // ═══════════════════════════════════════════════════════════
  // واٹس ایپ رابطہ
  // ═══════════════════════════════════════════════════════════
  Future<void> _contactWhatsApp(MarketplaceListing listing, bool isUrdu) async {
    final phone = listing.phoneNumber.trim();
    if (phone.isEmpty) {
      AppToast.error(
        context,
        isUrdu ? 'رابطہ نمبر دستیاب نہیں ہے' : 'Contact number is not available.',
      );
      return;
    }
    final normalizedPhone = Formatters.formatPhoneNumber(phone);
    final whatsappNumber = (normalizedPhone.isEmpty ? phone : normalizedPhone)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$whatsappNumber');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw PlatformException(
          code: 'contact_unavailable',
          message: 'No app can handle this contact action.',
        );
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'marketplace contact',
          context: ErrorDescription('while opening WhatsApp seller contact'),
        ),
      );
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'واٹس ایپ نہیں کھل سکا' : 'Could not open WhatsApp.',
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // رپورٹ
  // ═══════════════════════════════════════════════════════════
  Future<void> _reportListing(
      MarketplaceListing listing,
      bool isUrdu,
      ) async {
    final reasonController = UrduAwareTextEditingController(isUrdu: isUrdu);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
        return AlertDialog(
          backgroundColor: _C.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: UrduAwareText(
            isUrdu ? 'اشتہار کی رپورٹ کریں' : 'Report listing',
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
            ),
          ),
          content: TextField(
            controller: reasonController,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(fontFamily: fontFamily, color: _C.textPrimary),
            decoration: InputDecoration(
              hintText: isUrdu
                  ? 'رپورٹ کی وجہ لکھیں'
                  : 'Tell us why this listing should be reviewed',
              hintStyle: TextStyle(
                fontFamily: fontFamily,
                color: _C.textMuted,
                fontSize: 12.5,
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              counterStyle: const TextStyle(color: _C.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.accent, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: UrduAwareText(
                isUrdu ? 'منسوخ' : 'Cancel',
                style: const TextStyle(color: _C.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: UrduAwareText(
                isUrdu ? 'رپورٹ بھیجیں' : 'Submit report',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    try {
      await _service.reportListing(
        listingId: listing.id,
        reason: reason,
      );
      if (mounted) {
        AppToast.success(
          context,
          isUrdu ? 'رپورٹ بھیج دی گئی' : 'Report submitted',
        );
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'marketplace report',
          context: ErrorDescription('while reporting a listing'),
        ),
      );
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'رپورٹ نہیں بھیجی جاسکی'
              : 'Could not submit report. You may have already reported it.',
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // اسٹیٹس بیج
  // ═══════════════════════════════════════════════════════════
  Widget _statusBadge(MarketplaceListing listing, bool isUrdu) {
    final sold = listing.isSold;
    final hidden = listing.status == 'hidden';

    final label = sold
        ? (isUrdu ? 'فروخت ہوگئی' : 'Sold')
        : hidden
        ? (isUrdu ? 'چھپایا گیا' : 'Hidden')
        : (isUrdu ? 'دستیاب' : 'Available');

    final color = sold || hidden ? _C.textSecondary : _C.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: UrduAwareText(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // تصویر گیلری
  // ═══════════════════════════════════════════════════════════
  Widget _imageGallery(MarketplaceListing listing, bool isUrdu) {
    if (listing.imageUrls.isEmpty) {
      return Container(
        height: 260,
        color: AppTheme.backgroundColor,
        child: Center(
          child: Icon(PhosphorIcons.image(), size: 50, color: _C.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: listing.imageUrls.length,
            itemBuilder: (context, index) => CachedNetworkImage(
              imageUrl: listing.imageUrls[index],
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                color: AppTheme.backgroundColor,
                child: const Center(
                  child: CircularProgressIndicator(color: _C.accent),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.backgroundColor,
                child: Center(
                  child: Icon(PhosphorIcons.image(),
                      size: 40, color: _C.textMuted),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _statusBadge(listing, isUrdu),
          ),
          if (listing.imageUrls.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  listing.imageUrls.length,
                      (i) => Container(
                    width: i == 0 ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // معلوماتی قطار
  // ═══════════════════════════════════════════════════════════
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required String? fontFamily,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: (iconColor ?? _C.accent).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor ?? _C.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: UrduAwareText(
              label,
              style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          UrduAwareText(
            value,
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: _C.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // مواد
  // ═══════════════════════════════════════════════════════════
  Widget _listingContent(MarketplaceListing listing, bool isUrdu) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = userId == listing.ownerId;
    final matchingCategories =
    marketplaceCategories.where((item) => item.id == listing.category);
    final category =
    matchingCategories.isEmpty ? null : matchingCategories.first;
    final conditionLabel = listing.condition == 'new'
        ? (isUrdu ? 'نئی' : 'New')
        : (isUrdu ? 'استعمال شدہ' : 'Used');

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _imageGallery(listing, isUrdu),

        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ عنوان + اسٹیٹس + قیمت ═══
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          listing.title,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _C.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _statusBadge(listing, isUrdu),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      UrduAwareText(
                        listing.price == 0
                            ? (isUrdu ? 'مفت' : 'Free')
                            : Formatters.formatAmountWithCurrency(listing.price),
                        style: const TextStyle(
                          color: _C.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (listing.isNegotiable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: UrduAwareText(
                            isUrdu ? 'قیمت پر بات ہو سکتی ہے' : ' Negotiable',
                            style: const TextStyle(
                                color: AppTheme.darkColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ═══ معلومات کارڈ ═══
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      icon: PhosphorIcons.squaresFour(),
                      label: isUrdu ? 'قسم' : 'Category',
                      value: category?.label(isUrdu) ??
                          (isUrdu ? 'دیگر' : 'Other'),
                      fontFamily: fontFamily,
                    ),
                    Divider(height: 1, color: _C.border),
                    _infoRow(
                      icon: PhosphorIcons.package(),
                      label: isUrdu ? 'حالت' : 'Condition',
                      value: conditionLabel,
                      fontFamily: fontFamily,
                      iconColor: _C.warning,
                    ),
                    Divider(height: 1, color: _C.border),
                    _infoRow(
                      icon: PhosphorIcons.mapPin(),
                      label: isUrdu ? 'علاقہ' : 'Area',
                      value: listing.area,
                      fontFamily: fontFamily,
                      iconColor: _C.success,
                    ),
                    Divider(height: 1, color: _C.border),
                    _infoRow(
                      icon: PhosphorIcons.calendar(),
                      label: isUrdu ? 'تاریخ اشاعت' : 'Date',
                      value: Formatters.formatDate(listing.createdAt),
                      fontFamily: fontFamily,
                      iconColor: AppTheme.themeColor,
                    ),
                  ],
                ),
              ),

              // ═══ تفصیل ═══
              if (listing.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                UrduAwareText(
                  isUrdu ? 'تفصیل' : 'Description',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.border),
                  ),
                  child: UrduAwareText(
                    listing.description,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 14,
                      color: AppTheme.darkColor,
                      height: 1.7,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],

              // ═══ بیچنے والا ═══
              const SizedBox(height: 8),
              UrduAwareText(
                isUrdu ? 'بیچنے والا' : 'Seller',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, String>?>(
                future: listing.ownerId.isNotEmpty
                    ? ProfileService().findPublicProfileByUid(listing.ownerId)
                    : Future.value(null),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final sellerName = (profile?['name']?.isNotEmpty == true)
                      ? profile!['name']!
                      : listing.sellerName;
                  final profileImage = profile?['photoUrl'];
                  final categoryName = (profile?['profession']?.isNotEmpty == true)
                      ? profile!['profession']!
                      : listing.category;

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _C.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border),
                    ),
                    child: ProfileInfoWidget(
                      name: sellerName,
                      phone: '',
                      profileImage: profileImage,
                      category: categoryName,
                      address: null,
                      isLarge: false,
                      isVerticalCategory: true,
                      customSize: 46,
                      borderRadius: 14,
                    ),
                  );
                },
              ),

              // ═══ فروخت شدہ نوٹس ═══
              if (!isOwner && listing.isSold)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _C.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _C.danger.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.xCircle(),
                            color: _C.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: UrduAwareText(
                            isUrdu
                                ? 'یہ چیز پہلے ہی فروخت ہوچکی ہے'
                                : 'This item has already been sold.',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              color: _C.danger,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ═══ رپورٹ بٹن ═══
              if (!isOwner && listing.isActive && listing.phoneShared)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => _reportListing(listing, isUrdu),
                      style: TextButton.styleFrom(
                        foregroundColor: _C.textSecondary,
                      ),
                      icon: Icon(PhosphorIcons.flag(), size: 15),
                      label: UrduAwareText(
                        isUrdu ? 'اشتہار رپورٹ کریں' : 'Report listing',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = context.watch<LanguageService>().isUrdu;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ScreenAppBar(
        title: isUrdu ? 'چیز کی تفصیل' : 'Listing details',
        isUrdu: isUrdu,
      ),
      body: StreamBuilder<MarketplaceListing?>(
        stream: _listingStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: UrduAwareText(
                isUrdu
                    ? 'اشتہار لوڈ نہیں ہوسکا'
                    : 'Could not load this listing.',
                style: const TextStyle(color: _C.textSecondary),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _C.accent),
            );
          }
          final listing = snapshot.data;
          if (listing == null) {
            return Center(
              child: UrduAwareText(
                isUrdu ? 'اشتہار موجود نہیں' : 'Listing not found.',
                style: const TextStyle(color: _C.textSecondary),
              ),
            );
          }

          return Stack(
            children: [
              _listingContent(listing, isUrdu),

              // ═══ نیچے WhatsApp بٹن ═══
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.backgroundColor.withValues(alpha: 0),
                        AppTheme.backgroundColor,
                      ],
                    ),
                  ),
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _contactWhatsApp(listing, isUrdu),
                      icon: Icon(PhosphorIcons.chatCircleText(),
                          size: 18, color: _C.success),
                      label: UrduAwareText(
                        isUrdu ? 'واٹس ایپ رابطہ' : 'WhatsApp Contact',
                        style: TextStyle(
                          fontFamily: isUrdu ? 'NooriNastaleeq' : null,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _C.success,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _C.success.withValues(alpha: 0.08),
                        foregroundColor: _C.success,
                        side: BorderSide(
                          color: _C.success.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}