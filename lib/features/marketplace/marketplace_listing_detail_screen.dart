import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_toast.dart';
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

  Future<void> _contactSeller(
    MarketplaceListing listing, {
    required bool useWhatsApp,
    required bool isUrdu,
  }) async {
    final phone = listing.phoneNumber.trim();
    final normalizedPhone = Formatters.formatPhoneNumber(phone);
    final whatsappNumber = (normalizedPhone.isEmpty ? phone : normalizedPhone)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final uri = useWhatsApp
        ? Uri.parse('https://wa.me/$whatsappNumber')
        : Uri(scheme: 'tel', path: phone);
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
          context: ErrorDescription('while opening seller contact'),
        ),
      );
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'رابطہ ایپ نہیں کھل سکی' : 'Could not open the contact app.',
        );
      }
    }
  }

  Future<void> _reportListing(
    MarketplaceListing listing,
    bool isUrdu,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
        return AlertDialog(
          title: Text(isUrdu ? 'اشتہار کی رپورٹ کریں' : 'Report listing'),
          content: TextField(
            controller: reasonController,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isUrdu
                  ? 'رپورٹ کی وجہ لکھیں'
                  : 'Tell us why this listing should be reviewed',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: Text(
                isUrdu ? 'رپورٹ بھیجیں' : 'Submit report',
                style: TextStyle(fontFamily: fontFamily),
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

  Widget _statusChip(MarketplaceListing listing, bool isUrdu) {
    final label = switch (listing.status) {
      'sold' => isUrdu ? 'فروخت ہوگئی' : 'Sold',
      'hidden' => isUrdu ? 'چھپایا گیا' : 'Hidden',
      _ => isUrdu ? 'دستیاب' : 'Available',
    };
    final color = listing.isSold ? Colors.grey : AppTheme.themeColor;
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      side: BorderSide.none,
    );
  }

  Widget _imageGallery(MarketplaceListing listing) {
    if (listing.imageUrls.isEmpty) {
      return Container(
        height: 280,
        color: Colors.grey.shade200,
        child: Center(child: Icon(PhosphorIcons.image())),
      );
    }
    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: listing.imageUrls.length,
        itemBuilder: (context, index) => CachedNetworkImage(
          imageUrl: listing.imageUrls[index],
          fit: BoxFit.cover,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) =>  Center(
            child: Icon(PhosphorIcons.image(), size: 40),
          ),
        ),
      ),
    );
  }

  Widget _informationRow(
    IconData icon,
    String label,
    String value,
    String? fontFamily,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.themeColor),
          const SizedBox(width: 10),
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          UrduAwareText(
            value,
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingContent(MarketplaceListing listing, bool isUrdu) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = userId == listing.ownerId;
    final matchingCategories =
        marketplaceCategories.where((item) => item.id == listing.category);
    final category =
        matchingCategories.isEmpty ? null : matchingCategories.first;
    final formattedPhone = Formatters.formatPhoneNumber(listing.phoneNumber);
    final conditionLabel = listing.condition == 'new'
        ? (isUrdu ? 'نئی' : 'New')
        : (isUrdu ? 'استعمال شدہ' : 'Used');

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _imageGallery(listing),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.title,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                      ),
                    ),
                  ),
                  _statusChip(listing, isUrdu),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                listing.price == 0
                    ? (isUrdu ? 'مفت' : 'Free')
                    : 'Rs. ${Formatters.formatAmountWithCurrency(listing.price)}',
                style: TextStyle(
                  color: AppTheme.themeColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (listing.isNegotiable)
                UrduAwareText(
                  isUrdu ? 'قیمت پر بات ہوسکتی ہے' : 'Price is negotiable',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: Colors.grey.shade700,
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _informationRow(
                        PhosphorIcons.squaresFour(),
                        isUrdu ? 'قسم' : 'Category',
                        category?.label(isUrdu) ?? (isUrdu ? 'دیگر' : 'Other'),
                        fontFamily,
                      ),
                      _informationRow(
                        PhosphorIcons.package(),
                        isUrdu ? 'حالت' : 'Condition',
                        conditionLabel,
                        fontFamily,
                      ),
                      _informationRow(
                        PhosphorIcons.mapPin(),
                        isUrdu ? 'علاقہ' : 'Area',
                        listing.area,
                        fontFamily,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (listing.description.trim().isNotEmpty) ...[
                UrduAwareText(
                  isUrdu ? 'تفصیل' : 'Description',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                UrduAwareText(
                  listing.description,
                  style: TextStyle(fontFamily: fontFamily, fontSize: 15),
                ),
                const SizedBox(height: 18),
              ],
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.themeColor.withValues(alpha: 0.1),
                    child:
                        Icon(PhosphorIcons.user(), color: AppTheme.themeColor),
                  ),
                  title: Text(listing.sellerName),
                  subtitle: Text(
                    listing.phoneShared
                        ? (formattedPhone.isEmpty
                            ? listing.phoneNumber
                            : formattedPhone)
                        : (isUrdu
                            ? 'رابطہ نمبر شیئر نہیں کیا گیا'
                            : 'Contact number is not shared'),
                  ),
                ),
              ),
              if (!isOwner && listing.isActive && listing.phoneShared) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _contactSeller(
                          listing,
                          useWhatsApp: false,
                          isUrdu: isUrdu,
                        ),
                        icon: Icon(PhosphorIcons.phone()),
                        label: Text(isUrdu ? 'کال کریں' : 'Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _contactSeller(
                          listing,
                          useWhatsApp: true,
                          isUrdu: isUrdu,
                        ),
                        icon: Icon(PhosphorIcons.chatCircleText()),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _reportListing(listing, isUrdu),
                    icon: Icon(PhosphorIcons.flag(), size: 18),
                    label:
                        Text(isUrdu ? 'اشتہار رپورٹ کریں' : 'Report listing'),
                  ),
                ),
              ],
              if (!isOwner && listing.isSold)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: UrduAwareText(
                      isUrdu
                          ? 'یہ چیز پہلے ہی فروخت ہوچکی ہے'
                          : 'This item has already been sold.',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: Colors.grey.shade700,
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
              child: Text(
                isUrdu
                    ? 'اشتہار لوڈ نہیں ہوسکا'
                    : 'Could not load this listing.',
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final listing = snapshot.data;
          if (listing == null) {
            return Center(
              child: Text(isUrdu ? 'اشتہار موجود نہیں' : 'Listing not found.'),
            );
          }
          return _listingContent(listing, isUrdu);
        },
      ),
    );
  }
}
