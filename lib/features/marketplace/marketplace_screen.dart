import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/features/marketplace/marketplace_listing_detail_screen.dart';
import 'package:account_app/features/marketplace/marketplace_listing_form_screen.dart';
import 'package:account_app/features/marketplace/models/marketplace_categories.dart';
import 'package:account_app/features/marketplace/models/marketplace_listing.dart';
import 'package:account_app/features/marketplace/services/marketplace_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MarketplaceScreen extends StatefulWidget {
  final MarketplaceService? service;

  const MarketplaceScreen({super.key, this.service});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late final MarketplaceService _service;
  late final Stream<List<MarketplaceListing>> _activeListingsStream;
  late final Stream<List<MarketplaceListing>> _myListingsStream;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MarketplaceService();
    _activeListingsStream = _service.watchActiveListings();
    _myListingsStream = _service.watchMyListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      if (mounted) {
        AppToast.success(
          context,
          status == 'sold'
              ? (isUrdu ? 'چیز فروخت شدہ ہوگئی' : 'Marked as sold')
              : status == 'hidden'
                  ? (isUrdu ? 'اشتہار چھپا دیا گیا' : 'Listing hidden')
                  : (isUrdu
                      ? 'اشتہار دوبارہ دستیاب ہے'
                      : 'Listing is available'),
        );
      }
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
        title: Text(isUrdu ? 'اشتہار حذف کریں؟' : 'Delete listing?'),
        content: Text(
          isUrdu
              ? 'یہ اشتہار مستقل طور پر حذف ہوجائے گا۔'
              : 'This listing will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isUrdu ? 'حذف کریں' : 'Delete'),
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

  Widget _buildListingTile(
    MarketplaceListing listing,
    bool isUrdu, {
    bool isMine = false,
  }) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final statusLabel = switch (listing.status) {
      'sold' => isUrdu ? 'فروخت ہوگئی' : 'Sold',
      'hidden' => isUrdu ? 'چھپایا گیا' : 'Hidden',
      _ => isUrdu ? 'دستیاب' : 'Available',
    };
    final price = listing.price == 0
        ? (isUrdu ? 'مفت' : 'Free')
        : 'Rs. ${Formatters.formatAmountWithCurrency(listing.price)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  width: 90,
                  height: 90,
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
              const SizedBox(width: 12),
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: TextStyle(
                        color: AppTheme.themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.mapPin(),
                          size: 15,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: UrduAwareText(
                            listing.area,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isMine)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: listing.isActive
                                ? AppTheme.themeColor
                                : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isMine)
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
                      child: Text(isUrdu ? 'ترمیم' : 'Edit'),
                    ),
                    if (!listing.isSold)
                      PopupMenuItem(
                        value: 'sold',
                        child: Text(isUrdu ? 'فروخت شدہ کریں' : 'Mark as sold'),
                      ),
                    if (!listing.isActive)
                      PopupMenuItem(
                        value: 'active',
                        child:
                            Text(isUrdu ? 'دوبارہ دستیاب کریں' : 'Reactivate'),
                      ),
                    PopupMenuItem(
                      value: 'hide',
                      child: Text(isUrdu ? 'چھپائیں' : 'Hide listing'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(isUrdu ? 'حذف کریں' : 'Delete'),
                    ),
                  ],
                )
              else
                Icon(PhosphorIcons.caretRight(), color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  List<MarketplaceListing> _filterListings(
    List<MarketplaceListing> listings,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    return listings.where((listing) {
      final matchesCategory =
          _selectedCategory == 'all' || listing.category == _selectedCategory;
      final searchable =
          '${listing.title} ${listing.description} ${listing.area}'
              .toLowerCase();
      return matchesCategory && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  Widget _buildSearchAndCategories(bool isUrdu) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
              hintText:
                  isUrdu ? 'چیز یا علاقہ تلاش کریں' : 'Search items or area',
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: Icon(PhosphorIcons.x()),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              ChoiceChip(
                label: Text(isUrdu ? 'سب' : 'All'),
                selected: _selectedCategory == 'all',
                onSelected: (_) => setState(() => _selectedCategory = 'all'),
              ),
              ...marketplaceCategories.map(
                (category) => Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: ChoiceChip(
                    label: Text(category.label(isUrdu)),
                    selected: _selectedCategory == category.id,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListingStream(
    Stream<List<MarketplaceListing>> stream,
    bool isUrdu, {
    bool isMine = false,
    Widget? beforeList,
  }) {
    return StreamBuilder<List<MarketplaceListing>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                isUrdu
                    ? 'اشتہارات لوڈ نہیں ہوسکے، کنکشن چیک کریں'
                    : 'Could not load listings. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allListings = snapshot.data ?? const <MarketplaceListing>[];
        final listings = isMine ? allListings : _filterListings(allListings);
        if (listings.isEmpty) {
          return Column(
            children: [
              if (beforeList != null) beforeList,
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: UrduAwareText(
                      isMine
                          ? (isUrdu
                              ? 'آپ نے ابھی کوئی اشتہار نہیں دیا'
                              : 'You have not listed anything yet.')
                          : (allListings.isEmpty
                              ? (isUrdu
                                  ? 'ابھی کوئی چیز فروخت کے لیے موجود نہیں'
                                  : 'No items are listed yet.')
                              : (isUrdu
                                  ? 'اس تلاش سے کوئی چیز نہیں ملی'
                                  : 'No items match your search.')),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            if (beforeList != null) beforeList,
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 88),
                itemCount: listings.length,
                itemBuilder: (context, index) => _buildListingTile(
                  listings[index],
                  isUrdu,
                  isMine: isMine,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.watch<LanguageService>().isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: ScreenAppBar(
          title: isUrdu ? 'مارکیٹ پلیس' : 'Marketplace',
          isUrdu: isUrdu,
          actions: [
            IconButton(
              tooltip: isUrdu ? 'چیز فروخت کریں' : 'Sell an item',
              onPressed: () => _openForm(),
              icon: Icon(PhosphorIcons.plusCircle()),
            ),
          ],
        ),
        body: Column(
          children: [
            TabBar(
              labelColor: AppTheme.themeColor,
              unselectedLabelColor: Colors.grey.shade700,
              indicatorColor: AppTheme.themeColor,
              labelStyle: TextStyle(fontFamily: fontFamily),
              tabs: [
                Tab(text: isUrdu ? 'خریدیں' : 'Browse'),
                Tab(text: isUrdu ? 'میرے اشتہارات' : 'My listings'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildListingStream(
                    _activeListingsStream,
                    isUrdu,
                    beforeList: _buildSearchAndCategories(isUrdu),
                  ),
                  _buildListingStream(
                    _myListingsStream,
                    isUrdu,
                    isMine: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: Text(isUrdu ? 'چیز فروخت کریں' : 'Sell an item'),
        ),
      ),
    );
  }
}
