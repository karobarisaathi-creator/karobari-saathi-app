import 'dart:async';

import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/features/marketplace/marketplace_listing_detail_screen.dart';
import 'package:account_app/features/marketplace/marketplace_listing_form_screen.dart';
import 'package:account_app/features/marketplace/models/marketplace_categories.dart';
import 'package:account_app/features/marketplace/models/marketplace_listing.dart';
import 'package:account_app/features/marketplace/services/marketplace_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MarketplaceScreen extends StatefulWidget {
  final MarketplaceService? service;

  const MarketplaceScreen({super.key, this.service});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const double _prefetchExtent = 500;

  late final MarketplaceService _service;
  ScrollController? _listScrollController;
  StreamSubscription<MarketplaceListingPage>? _firstPageSubscription;
  final _searchController = UrduAwareTextEditingController();
  final List<MarketplaceListing> _loadedListings = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  Object? _initialLoadError;
  Object? _loadMoreError;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasFetchedMore = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MarketplaceService();
    _subscribeToFirstPage();
  }

  ScrollController _getListScrollController() {
    return _listScrollController ??= ScrollController()
      ..addListener(_onListScroll);
  }

  void _subscribeToFirstPage() {
    _firstPageSubscription = _service.watchFirstActiveListingsPage().listen(
      _applyFirstPage,
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'marketplace listings',
            context: ErrorDescription('while watching the latest listings'),
          ),
        );
        if (!mounted) return;
        setState(() {
          _initialLoadError = error;
          _isInitialLoading = false;
        });
      },
    );
  }

  void _applyFirstPage(MarketplaceListingPage page) {
    if (!mounted) return;
    setState(() {
      if (!_hasFetchedMore) {
        _loadedListings
          ..clear()
          ..addAll(page.listings);
        _lastDocument = page.lastDocument;
      } else {
        final firstPageIds = page.listings.map((item) => item.id).toSet();
        final olderListings = _loadedListings
            .where((item) => !firstPageIds.contains(item.id))
            .toList();
        _loadedListings
          ..clear()
          ..addAll(page.listings)
          ..addAll(olderListings);
      }
      if (!_hasFetchedMore) _hasMore = page.hasMore;
      _isInitialLoading = false;
      _initialLoadError = null;
    });
  }

  void _onListScroll() {
    final controller = _listScrollController;
    if (controller == null ||
        !controller.hasClients ||
        controller.position.extentAfter > _prefetchExtent) {
      return;
    }
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    final cursor = _lastDocument;
    if (_isLoadingMore || !_hasMore || cursor == null) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await _service.fetchNextActiveListingsPage(after: cursor);
      if (!mounted) return;
      setState(() {
        final existingIds = _loadedListings.map((item) => item.id).toSet();
        _loadedListings.addAll(
          page.listings.where((item) => existingIds.add(item.id)),
        );
        _lastDocument = page.lastDocument ?? _lastDocument;
        _hasMore = page.hasMore;
        _hasFetchedMore = true;
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'marketplace listings',
          context: ErrorDescription('while loading another listings page'),
        ),
      );
      if (mounted) setState(() => _loadMoreError = error);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _firstPageSubscription?.cancel();
    _listScrollController?.removeListener(_onListScroll);
    _listScrollController?.dispose();
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

  Widget _buildListingTile(MarketplaceListing listing, bool isUrdu) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final price = listing.price == 0
        ? (isUrdu ? 'مفت' : 'Free')
        : 'Rs. ${Formatters.formatAmountWithCurrency(listing.price)}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    UrduAwareText(
                      price,
                      style: TextStyle(
                        fontFamily: fontFamily,
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
                  ],
                ),
              ),
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
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: SearchSortBar(
            controller: _searchController,
            hintText:
                isUrdu ? 'چیز یا علاقہ تلاش کریں' : 'Search items or area',
            onSearchChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              ChoiceChip(
                label: UrduAwareText(isUrdu ? 'سب' : 'All'),
                selected: _selectedCategory == 'all',
                onSelected: (_) => setState(() => _selectedCategory = 'all'),
              ),
              ...marketplaceCategories.map(
                (category) => Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: ChoiceChip(
                    label: UrduAwareText(category.label(isUrdu)),
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

  Widget _buildListingStream(bool isUrdu) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initialLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UrduAwareText(
                isUrdu
                    ? 'اشتہارات لوڈ نہیں ہوسکے، کنکشن چیک کریں'
                    : 'Could not load listings. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isInitialLoading = true;
                    _initialLoadError = null;
                  });
                  _subscribeToFirstPage();
                },
                child: UrduAwareText(isUrdu ? 'دوبارہ کوشش' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final listings = _filterListings(_loadedListings);
    if (_loadedListings.isEmpty && !_hasMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: UrduAwareText(
            isUrdu
                ? 'ابھی کوئی چیز فروخت کے لیے موجود نہیں'
                : 'No items are listed yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _getListScrollController(),
      padding: const EdgeInsets.only(top: 4, bottom: 88),
      itemCount: listings.length + 1,
      itemBuilder: (context, index) {
        if (index < listings.length) {
          return _buildListingTile(listings[index], isUrdu);
        }
        if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_loadMoreError != null) {
          return Center(
            child: TextButton(
              onPressed: _loadNextPage,
              child: UrduAwareText(
                isUrdu
                    ? 'مزید اشتہارات لوڈ نہیں ہوسکے، دوبارہ کوشش کریں'
                    : 'Could not load more listings. Tap to retry.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (_hasMore) {
          return Center(
            child: TextButton(
              onPressed: _loadNextPage,
              child: UrduAwareText(
                listings.isEmpty
                    ? (isUrdu
                        ? 'مزید اشتہارات میں تلاش جاری رکھیں'
                        : 'Search older listings')
                    : (isUrdu
                        ? 'مزید اشتہارات لوڈ کریں'
                        : 'Load more listings'),
              ),
            ),
          );
        }
        if (listings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: UrduAwareText(
              isUrdu
                  ? 'اس تلاش سے کوئی چیز نہیں ملی'
                  : 'No items match your search.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return const SizedBox(height: 16);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.watch<LanguageService>().isUrdu;

    return Scaffold(
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
          _buildSearchAndCategories(isUrdu),
          Expanded(child: _buildListingStream(isUrdu)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: UrduAwareText(isUrdu ? 'چیز فروخت کریں' : 'Sell an item'),
      ),
    );
  }
}
