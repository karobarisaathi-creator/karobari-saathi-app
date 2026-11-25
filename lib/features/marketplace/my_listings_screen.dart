import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/features/marketplace/marketplace_listing_detail_screen.dart';
import 'package:account_app/features/marketplace/marketplace_listing_form_screen.dart';
import 'package:account_app/features/marketplace/models/marketplace_listing.dart';
import 'package:account_app/features/marketplace/services/marketplace_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyListingsScreen extends StatefulWidget {
  final MarketplaceService? service;

  const MyListingsScreen({super.key, this.service});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  late final MarketplaceService _service;
  late final Stream<List<MarketplaceListing>> _listingsStream;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MarketplaceService();
    _listingsStream = _service.watchMyListings();
  }

  Future<void> _openForm({MarketplaceListing? listing}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MarketplaceListingFormScreen(
          listing: listing,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    MarketplaceListing listing,
    String status,
    bool isUrdu,
  ) async {
    try {
      await _service.updateStatus(listing.id, status);
      if (!mounted) return;
      AppToast.success(
        context,
        status == 'sold'
            ? (isUrdu ? 'چیز فروخت شدہ ہوگئی' : 'Marked as sold')
            : status == 'hidden'
                ? (isUrdu ? 'اشتہار چھپا دیا گیا' : 'Listing hidden')
                : (isUrdu ? 'اشتہار دوبارہ دستیاب ہے' : 'Listing is available'),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'marketplace management',
          context: ErrorDescription('while changing listing status'),
        ),
      );
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'اشتہار کی حالت تبدیل نہیں ہوسکی'
              : 'Could not change listing status.',
        );
      }
    }
  }

  Future<void> _deleteListing(
    MarketplaceListing listing,
    bool isUrdu,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: UrduAwareText(isUrdu ? 'اشتہار حذف کریں؟' : 'Delete listing?'),
        content: UrduAwareText(
          isUrdu
              ? 'یہ اشتہار مستقل طور پر حذف ہوجائے گا۔'
              : 'This listing will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: UrduAwareText(isUrdu ? 'حذف کریں' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteListing(listing);
      if (mounted) {
        AppToast.success(
          context,
          isUrdu ? 'اشتہار حذف ہوگیا' : 'Listing deleted',
        );
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'marketplace management',
          context: ErrorDescription('while deleting a listing'),
        ),
      );
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'اشتہار حذف نہیں ہوسکا' : 'Could not delete the listing.',
        );
      }
    }
  }

  String _statusLabel(MarketplaceListing listing, bool isUrdu) {
    return switch (listing.status) {
      'sold' => isUrdu ? 'فروخت ہوگئی' : 'Sold',
      'hidden' => isUrdu ? 'چھپایا گیا' : 'Hidden',
      _ => isUrdu ? 'دستیاب' : 'Available',
    };
  }

  Widget _buildListingTile(MarketplaceListing listing, bool isUrdu) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final price = listing.price == 0
        ? (isUrdu ? 'مفت' : 'Free')
        : 'Rs. ${Formatters.formatAmountWithCurrency(listing.price)}';
    final statusColor = listing.isActive
        ? AppTheme.themeColor
        : listing.isSold
            ? Colors.grey
            : AppTheme.verifiedGold;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarketplaceListingDetailScreen(
              listingId: listing.id,
              service: _service,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: listing.imageUrls.isEmpty
                      ? Container(
                          color: Colors.grey.shade200,
                          child: Icon(PhosphorIcons.image()),
                        )
                      : CachedNetworkImage(
                          imageUrl: listing.imageUrls.first,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              Icon(PhosphorIcons.image()),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UrduAwareText(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    UrduAwareText(
                      price,
                      style: const TextStyle(
                        color: AppTheme.themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    UrduAwareText(
                      listing.area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    UrduAwareText(
                      _statusLabel(listing, isUrdu),
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: isUrdu ? 'اشتہار کے اختیارات' : 'Listing options',
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _openForm(listing: listing);
                      break;
                    case 'sold':
                      _changeStatus(listing, 'sold', isUrdu);
                      break;
                    case 'active':
                      _changeStatus(listing, 'active', isUrdu);
                      break;
                    case 'hide':
                      _changeStatus(listing, 'hidden', isUrdu);
                      break;
                    case 'delete':
                      _deleteListing(listing, isUrdu);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: UrduAwareText(isUrdu ? 'ترمیم' : 'Edit'),
                  ),
                  if (!listing.isSold)
                    PopupMenuItem(
                      value: 'sold',
                      child: UrduAwareText(
                          isUrdu ? 'فروخت شدہ کریں' : 'Mark as sold'),
                    ),
                  if (!listing.isActive)
                    PopupMenuItem(
                      value: 'active',
                      child: UrduAwareText(
                          isUrdu ? 'دوبارہ دستیاب کریں' : 'Reactivate'),
                    ),
                  PopupMenuItem(
                    value: 'hide',
                    child: UrduAwareText(isUrdu ? 'چھپائیں' : 'Hide listing'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: UrduAwareText(isUrdu ? 'حذف کریں' : 'Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.watch<LanguageService>().isUrdu;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ScreenAppBar(
        title: isUrdu ? 'میرے اشتہارات' : 'My listings',
        isUrdu: isUrdu,
      ),
      body: StreamBuilder<List<MarketplaceListing>>(
        stream: _listingsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: UrduAwareText(
                  isUrdu
                      ? 'اشتہارات لوڈ نہیں ہوسکے، کنکشن چیک کریں'
                      : 'Could not load your listings. Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = snapshot.data ?? const <MarketplaceListing>[];
          if (listings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: UrduAwareText(
                  isUrdu
                      ? 'آپ نے ابھی کوئی اشتہار نہیں دیا'
                      : 'You have not listed anything yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 88),
            itemCount: listings.length,
            itemBuilder: (context, index) =>
                _buildListingTile(listings[index], isUrdu),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: Icon(PhosphorIcons.plus()),
        label: UrduAwareText(isUrdu ? 'نیا اشتہار' : 'Add listing'),
      ),
    );
  }
}
