// screens/marketplace_screen.dart
// Professional Grade Marketplace Screen with Global Standards

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/app_filter_chip.dart';
import 'package:account_app/core/widgets/product_card.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';
import 'package:account_app/features/visual_finder/visual_finder_screen.dart';
import 'item_detail_screen.dart';
import 'add_inventory_item_screen.dart';
import 'seller_items_screen.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with TickerProviderStateMixin {
  // ==================== STATE MANAGEMENT ====================
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = "";
  String _locationFilter = "";
  SortOption _currentSort = SortOption.latest;
  ViewMode _viewMode = ViewMode.grid;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  List<InventoryItem> _allItems = [];
  List<InventoryItem> _displayedItems = [];
  List<InventoryItem> _featuredItems = [];
  List<InventoryItem> _recentlyViewed = [];
  List<String> _recentSearches = [];
  bool _isSearchFocused = false;
  Position? _userPosition;
  double _distanceFilter = 50.0; // 50km default
  bool _useDistanceFilter = false;

  void _showCategoryPicker(bool isUrdu, String fontFamily) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              isUrdu ? 'کیٹیگری منتخب کریں' : 'Select Category',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: AppFilterChip.productCategories.length,
                itemBuilder: (context, index) {
                  final cat = AppFilterChip.productCategories[index];
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddInventoryItemScreen(
                                initialCategory: cat.id)),
                      );
                      if (result == true) _loadData();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon,
                              color: AppTheme.themeColor, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isUrdu ? cat.labelUr : cat.labelEn,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: fontFamily),
                        ),
                      ],
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

  List<Account> _allAccounts = [];

  // Filters State
  Set<String> _selectedConditions = {'New', 'Used'};
  RangeValues _priceRange = const RangeValues(0, 500000);
  double _maxPriceFound = 500000;

  // Categories with Icons
  final List<AppCategory> _categories = [
    AppCategory(
        id: 'all',
        labelEn: 'All',
        labelUr: 'سب',
        icon: PhosphorIcons.gridFour()),
    AppCategory(
        id: 'for_you',
        labelEn: 'For You',
        labelUr: 'آپ کے لیے',
        icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill)),
    ...AppFilterChip.productCategories,
  ];

  Set<String> _interestKeywords = {};
  String _selectedCategory = "for_you"; // Default to For You

  String? _selectedCondition; // null = all, 'New', 'Used'

  // ==================== INITIALIZATION ====================
  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    _loadData();
    _loadSearchHistory();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty && _isSearchFocused == false) {
        setState(() => _isSearchFocused = true);
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches =
          prefs.getStringList('marketplace_recent_searches') ?? [];
    });
  }

  Future<void> _saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 5) _recentSearches.removeLast();
    await prefs.setStringList('marketplace_recent_searches', _recentSearches);
    setState(() {});
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final position = _scrollController.position;

      // Pagination - Load more when near bottom
      if (position.pixels >= position.maxScrollExtent - 200) {
        _loadMoreItems();
      }
    });
  }

  Future<void> _toggleFavorite(InventoryItem item) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    setState(() {
      item.isFavorite = !(item.isFavorite ?? false);
      if (item.isFavorite ?? false) {
        item.likes += 1;
      } else {
        item.likes = (item.likes > 0) ? item.likes - 1 : 0;
      }
    });
    await dbService.updateInventoryItem(item);
  }

  // ==================== DATA LOADING ====================
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
      _lastDocument = null;
      _allItems = [];
    });

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    try {
      // 0. Get User Location (for distance calculation)
      try {
        _userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        debugPrint("Could not get user position: $e");
      }

      // 1. Get Local Data (Accounts/Transactions) for Interest Extraction
      final localAccounts = dbService.getAccounts();
      final localTransactions = dbService.getAllTransactions();
      _extractUserInterests(localAccounts, localTransactions);

      // 2. Fetch Global Marketplace Items (Professional Pagination)
      late final List<InventoryItem> remoteItems;
      if (_searchQuery.trim().isNotEmpty && _searchQuery.trim().length > 2) {
        remoteItems = await dbService.searchGlobalMarketplaceItems(
          searchQuery: _searchQuery.trim(),
          limit: 80,
        );
        _lastDocument = null;
        _hasMore = false;
      } else {
        final result = await dbService.getGlobalMarketplaceItemsPaginated(
          limit: _pageSize,
          lastDocument: null,
        );

        remoteItems = result['items'] as List<InventoryItem>;
        _lastDocument = result['lastDocument'] as DocumentSnapshot?;
        _hasMore = result['hasMore'] as bool;
      }

      // 3. Get User's Own Local Items (Offline Support)
      final localItems = dbService.getInventoryItems();

      // 4. Get Recently Viewed Items
      final recentlyViewed = dbService.getRecentlyViewed();

      // Merge Items: Unique items prioritizing local copies if they exist
      final Map<String, InventoryItem> itemsMap = {};

      for (var item in remoteItems) {
        itemsMap[item.id] = item;
      }

      for (var item in localItems) {
        itemsMap[item.id] = item;
      }

      if (mounted) {
        setState(() {
          _allItems = itemsMap.values.toList();
          _featuredItems = _allItems.where((item) => item.isFeatured).toList();
          _recentlyViewed = recentlyViewed;
          _allAccounts = localAccounts;
          _isLoading = false;

          if (_allItems.isNotEmpty) {
            double highestItemPrice = _allItems
                .map((e) => e.defaultRate)
                .reduce((a, b) => a > b ? a : b);
            _maxPriceFound =
                highestItemPrice > 500000 ? highestItemPrice : 500000;
            _priceRange = RangeValues(0, _maxPriceFound);
          }
        });
      }

      _applyFiltersAndSort();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
            isUrdu
                ? 'مارکیٹ پلیس لوڈ کرنے میں غلطی: $e'
                : 'Error loading marketplace: $e',
            isError: true);
      }
    }
  }

  void _extractUserInterests(
      List<Account> accounts, List<model.Transaction> transactions) {
    Set<String> keywords = {};

    // 1. Scan Account Categories
    for (var account in accounts) {
      if (account.category.isNotEmpty) {
        keywords.add(account.category.toLowerCase().trim());
      }
    }

    // 2. Scan Transaction Item Names and Descriptions
    final recentTxs = transactions.take(50);
    for (var tx in recentTxs) {
      if (tx.description.length > 2) {
        keywords.addAll(_splitIntoKeywords(tx.description));
      }
      for (var item in tx.items) {
        keywords.addAll(_splitIntoKeywords(item.description));
      }
    }

    setState(() {
      _interestKeywords = keywords;
    });
  }

  List<String> _splitIntoKeywords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
        .split(' ')
        .where((w) => w.length > 2)
        .toList();
  }

  void _applyFiltersAndSort() {
    final now = DateTime.now();

    var filtered = _allItems.where((item) {
      // 0. Expiry Filter
      if (item.adExpiryDate != null && item.adExpiryDate!.isBefore(now)) {
        return false;
      }
      if (now.difference(item.createdAt).inDays > 90) {
        return false;
      }

      final query = _searchQuery.toLowerCase();
      final matchesSearch = item.name.toLowerCase().contains(query) ||
          (item.brand ?? "").toLowerCase().contains(query) ||
          (item.location ?? "").toLowerCase().contains(query) ||
          (item.description ?? "").toLowerCase().contains(query) ||
          (item.category ?? "").toLowerCase().contains(query) ||
          (item.sku ?? "").toLowerCase().contains(query);

      // 1. Category Filter
      bool matchesCategory = false;
      if (_selectedCategory == 'all') {
        matchesCategory = true;
      } else if (_selectedCategory == 'for_you') {
        final itemName = item.name.toLowerCase();
        final itemDesc = (item.description ?? "").toLowerCase();
        final itemCat = (item.category ?? "").toLowerCase();
        matchesCategory = _interestKeywords.any((k) =>
            itemName.contains(k) ||
            itemDesc.contains(k) ||
            itemCat.contains(k));
      } else {
        matchesCategory = item.category == _selectedCategory;
      }

      // 2. Condition Filter
      bool matchesCondition =
          _selectedConditions.contains(item.condition ?? 'New');

      // 3. Price Range Filter
      bool matchesPrice = item.defaultRate >= _priceRange.start &&
          item.defaultRate <= _priceRange.end;

      // 4. Location Filter
      bool matchesLocation = _locationFilter.isEmpty ||
          (item.location ?? "")
              .toLowerCase()
              .contains(_locationFilter.toLowerCase());

      // 5. Distance Filter
      bool matchesDistance = true;
      if (_useDistanceFilter &&
          _userPosition != null &&
          item.latitude != null &&
          item.longitude != null) {
        final double distance = Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              item.latitude!,
              item.longitude!,
            ) /
            1000; // to km
        matchesDistance = distance <= _distanceFilter;
      }

      return matchesSearch &&
          matchesCategory &&
          matchesCondition &&
          matchesPrice &&
          matchesLocation &&
          matchesDistance;
    }).toList();

    if (_selectedCategory == 'for_you' &&
        filtered.isEmpty &&
        _searchQuery.isEmpty) {
      filtered = List.from(_allItems);
    }

    switch (_currentSort) {
      case SortOption.latest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.priceLow:
        filtered.sort((a, b) => a.defaultRate.compareTo(b.defaultRate));
        break;
      case SortOption.priceHigh:
        filtered.sort((a, b) => b.defaultRate.compareTo(a.defaultRate));
        break;
      case SortOption.rating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.popular:
        filtered.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    setState(() {
      _displayedItems = filtered;
    });
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMore || _searchQuery.isNotEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    final dbService = Provider.of<DatabaseService>(context, listen: false);

    try {
      final result = await dbService.getGlobalMarketplaceItemsPaginated(
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      final newItems = result['items'] as List<InventoryItem>;
      _lastDocument = result['lastDocument'] as DocumentSnapshot?;
      _hasMore = result['hasMore'] as bool;

      if (mounted && newItems.isNotEmpty) {
        setState(() {
          final existingIds = _allItems.map((e) => e.id).toSet();
          for (var item in newItems) {
            if (!existingIds.contains(item.id)) {
              _allItems.add(item);
            }
          }
          _isLoadingMore = false;
          _applyFiltersAndSort();
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      debugPrint("Load more failed: $e");
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 0;
      _isSearchFocused = value.isEmpty;
    });

    if (value.trim().isEmpty) {
      _loadData();
    } else {
      _applyFiltersAndSort();
    }
  }

  void _onSearchSubmitted(String value) {
    if (value.isNotEmpty) {
      _saveSearchQuery(value);
      setState(() => _isSearchFocused = false);
      _loadData();
    }
  }

  void _onSortChanged(SortOption sort) {
    setState(() {
      _currentSort = sort;
      _currentPage = 0;
      _applyFiltersAndSort();
    });
  }

  void _onCategorySelected(String categoryId) {
    setState(() {
      _selectedCategory = categoryId;
      _currentPage = 0;
      _applyFiltersAndSort();
    });
  }

  void _navigateToDetail(InventoryItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
    );
    // Always refresh UI when coming back from detail screen to sync likes/favorites
    setState(() {
      _applyFiltersAndSort();
    });
  }

  void _navigateToSellerProfile(InventoryItem item) {
    if (item.accountId == null) return;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    try {
      final account = _allAccounts.firstWhere((a) => a.id == item.accountId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PartyDetailScreen(party: account, isReadOnly: true),
        ),
      );
    } catch (e) {
      _showSnackBar(isUrdu ? 'بیچنے والا نہیں ملا' : 'Seller not found',
          isError: true);
    }
  }

  String? _getSellerName(InventoryItem item) {
    if (item.accountId == null) return null;
    try {
      final account = _allAccounts.firstWhere((a) => a.id == item.accountId);
      return account.storeName?.isNotEmpty == true
          ? account.storeName
          : account.name;
    } catch (e) {
      return null;
    }
  }

  // ==================== UI HELPERS ====================
  void _showSnackBar(String message, {bool isError = false}) {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : null),
        ),
        backgroundColor: isError ? AppTheme.expenseColor : AppTheme.incomeColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== BUILD METHODS ====================
  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final currentUser =
        FirebaseAuth.instance.currentUser; // ignore: unused_local_variable

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: _buildAppBar(isUrdu, fontFamily),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.themeColor,
        child: Column(
          children: [
            _buildSearchAndFilterBar(isUrdu, fontFamily),
            _buildCategoriesRow(isUrdu, fontFamily),
            _buildSortAndViewBar(isUrdu, fontFamily),
            Expanded(
              child: _isLoading
                  ? _buildLoadingShimmer()
                  : _displayedItems.isEmpty
                      ? _buildEmptyState(isUrdu, fontFamily)
                      : _buildProductsGrid(isUrdu, fontFamily),
            ),
            if (_isLoadingMore) _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isUrdu, String fontFamily) {
    return CustomAppBar(
      title: isUrdu ? 'مارکیٹ پلیس' : 'Marketplace',
      showBackButton: false,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(PhosphorIcons.shoppingBag(), color: Colors.white),
        onPressed: () => _showCartDialog(isUrdu, fontFamily),
        tooltip: isUrdu ? 'میری پسندیدہ مصنوعات' : 'My Favorites',
      ),
      actions: [
        // "My Ads" Button
        IconButton(
          icon: Icon(PhosphorIcons.userList(), color: Colors.white),
          onPressed: () {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SellerItemsScreen(
                    sellerUid: user.uid,
                    sellerName: user.displayName ?? 'My Store',
                  ),
                ),
              );
            }
          },
          tooltip: isUrdu ? 'میرے اشتہارات' : 'My Ads',
        ),
        // "Sell Item" Button moved from FAB to AppBar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: ElevatedButton.icon(
            onPressed: () => _showCategoryPicker(isUrdu, fontFamily),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.add_shopping_cart,
                size: 14, color: Colors.white),
            label: Text(
              isUrdu ? 'کچھ بیچیں' : 'Sell Item',
              style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar(bool isUrdu, String fontFamily) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    setState(() => _isSearchFocused =
                        hasFocus && _searchController.text.isEmpty);
                  },
                  child: SearchSortBar(
                    controller: _searchController,
                    padding: EdgeInsets.zero,
                    showVoiceSearch: true,
                    showScanner: true,
                    onScannerTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const VisualFinderScreen())),
                    hintText:
                        isUrdu ? 'مصنوعات تلاش کریں...' : 'Search products...',
                    isAscending: _currentSort == SortOption.priceLow ||
                        _currentSort == SortOption.latest,
                    onSearchChanged: _onSearchChanged,
                    onSubmitted: _onSearchSubmitted,
                    onSortToggled: () {
                      setState(() {
                        if (_currentSort == SortOption.latest) {
                          _currentSort = SortOption.oldest;
                        } else if (_currentSort == SortOption.oldest) {
                          _currentSort = SortOption.latest;
                        } else if (_currentSort == SortOption.priceLow) {
                          _currentSort = SortOption.priceHigh;
                        } else {
                          _currentSort = SortOption.latest;
                        }
                        _applyFiltersAndSort();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _viewMode = _viewMode == ViewMode.grid
                        ? ViewMode.list
                        : ViewMode.grid;
                  });
                },
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppTheme.themeColor.withOpacity(0.2)),
                  ),
                  child: Icon(
                    _viewMode == ViewMode.grid
                        ? PhosphorIcons.list()
                        : PhosphorIcons.gridFour(),
                    color: AppTheme.themeColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isSearchFocused && _recentSearches.isNotEmpty)
          _buildRecentSearches(isUrdu, fontFamily),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRecentSearches(bool isUrdu, String fontFamily) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'حالیہ تلاشیں' : 'Recent Searches',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _recentSearches
                .map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        _searchController.text = s;
                        _onSearchChanged(s);
                        _onSearchSubmitted(s);
                      },
                      backgroundColor: Colors.grey[100],
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesRow(bool isUrdu, String fontFamily) {
    return Container(
      height: 40, // Further reduced height
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return AppFilterChip(
            labelEn: category.labelEn,
            labelUr: category.labelUr,
            icon: category.icon,
            isSelected: _selectedCategory == category.id,
            activeColor: AppTheme.goldColor,
            onTap: () => _onCategorySelected(category.id),
          );
        },
      ),
    );
  }

  Widget _buildSortAndViewBar(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // 1. Compact Filter Button
          InkWell(
            onTap: () => _showFilterBottomSheet(isUrdu, fontFamily),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.goldColor, // Changed to Gold
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.funnel(), size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    isUrdu ? 'فلٹر' : 'Filter',
                    style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 2. Scrollable Selected Filter Tags
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildMiniTag(
                      _getSortLabel(_currentSort, isUrdu), fontFamily),
                  _buildMiniTag(
                      '${NumberFormat.compact().format(_priceRange.start)}-${NumberFormat.compact().format(_priceRange.end)}',
                      ''),
                  if (_selectedConditions.length == 1)
                    _buildMiniTag(
                        _selectedConditions.first == 'New'
                            ? (isUrdu ? 'صرف نیا' : 'New Only')
                            : (isUrdu ? 'صرف پرانا' : 'Used Only'),
                        fontFamily),
                ],
              ),
            ),
          ),

          // 3. Count Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_displayedItems.length} ${isUrdu ? 'آئٹم' : 'items'}',
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String text, String fontFamily) {
    return Container(
      margin: const EdgeInsets.only(right: 6, left: 2),
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3), // Reduced vertical padding
      decoration: BoxDecoration(
        color: AppTheme.goldColor.withOpacity(0.05), // Light gold background
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppTheme.goldColor.withOpacity(0.2)), // Gold border
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 9,
            color: AppTheme.goldColor,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold), // Gold text, smaller font
      ),
    );
  }

  void _showFilterBottomSheet(bool isUrdu, String fontFamily) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isUrdu ? 'فلٹرز اور ترتیب' : 'Filter & Sort',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // 1. Price Range Section (Professional Slider)
              Text(
                isUrdu ? 'قیمت کی حد' : 'Price Range',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: fontFamily),
              ),
              const SizedBox(height: 8),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: _maxPriceFound,
                divisions: 100,
                activeColor: AppTheme.goldColor, // Changed to Gold
                labels: RangeLabels(
                  NumberFormat('#,###').format(_priceRange.start),
                  NumberFormat('#,###').format(_priceRange.end),
                ),
                onChanged: (values) {
                  // Ensure a minimum distance between start and end to prevent overlapping
                  if ((values.end - values.start).abs() <
                      (_maxPriceFound * 0.05)) return;

                  setModalState(() => _priceRange = values);
                  setState(() => _priceRange = values);
                  _applyFiltersAndSort();
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rs ${_priceRange.start.round()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Rs ${_priceRange.end.round()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 24),

              // 2. Distance / Nearby Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isUrdu ? 'میرے قریب (فاصلہ)' : 'Nearby (Distance)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: fontFamily),
                  ),
                  Switch(
                    value: _useDistanceFilter,
                    activeTrackColor: AppTheme.goldColor.withValues(alpha: 0.5),
                    activeColor: AppTheme.goldColor,
                    onChanged: (v) {
                      setModalState(() => _useDistanceFilter = v);
                      setState(() => _useDistanceFilter = v);
                      _applyFiltersAndSort();
                    },
                  ),
                ],
              ),
              if (_useDistanceFilter) ...[
                const SizedBox(height: 8),
                Slider(
                  value: _distanceFilter,
                  min: 1,
                  max: 500,
                  divisions: 50,
                  activeColor: AppTheme.goldColor,
                  label: '${_distanceFilter.round()} km',
                  onChanged: (v) {
                    setModalState(() => _distanceFilter = v);
                    setState(() => _distanceFilter = v);
                    _applyFiltersAndSort();
                  },
                ),
                Text(
                  isUrdu
                      ? '${_distanceFilter.round()} کلومیٹر کے اندر'
                      : 'Within ${_distanceFilter.round()} km',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              const SizedBox(height: 24),

              // 3. Condition Selection (Multiple Selection)
              Text(
                isUrdu ? 'آئٹم کی حالت' : 'Condition',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: fontFamily),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip(
                      'New', isUrdu ? 'نیا' : 'New', setModalState, fontFamily),
                  const SizedBox(width: 12),
                  _buildFilterChip('Used', isUrdu ? 'استعمال شدہ' : 'Used',
                      setModalState, fontFamily),
                ],
              ),

              const SizedBox(height: 24),

              // 3. Location Filter
              Text(
                isUrdu ? 'شہر / علاقہ' : 'Location',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: fontFamily),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) {
                  setModalState(() => _locationFilter = v);
                  setState(() => _locationFilter = v);
                  _applyFiltersAndSort();
                },
                decoration: InputDecoration(
                  hintText: isUrdu ? 'شہر تلاش کریں...' : 'Search city...',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Sorting Options
              Text(
                isUrdu ? 'ترتیب دیں' : 'Sort By',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: fontFamily),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SortOption.values
                    .where((opt) =>
                        opt != SortOption.conditionNew &&
                        opt != SortOption.conditionUsed)
                    .map((opt) => ChoiceChip(
                          label: Text(_getSortLabel(opt, isUrdu),
                              style: TextStyle(
                                  fontSize: 12, fontFamily: fontFamily)),
                          selected: _currentSort == opt,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => _currentSort = opt);
                              setState(() => _currentSort = opt);
                              _applyFiltersAndSort();
                            }
                          },
                          selectedColor: AppTheme.goldColor
                              .withOpacity(0.2), // Changed to Gold
                          labelStyle: TextStyle(
                              color: _currentSort == opt
                                  ? AppTheme.goldColor
                                  : Colors.black), // Changed to Gold
                        ))
                    .toList(),
              ),

              const SizedBox(height: 32),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isUrdu ? 'فلٹرز لگائیں' : 'Apply Filters',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String value, String label, Function setModalState, String fontFamily) {
    bool isSelected = _selectedConditions.contains(value);
    return FilterChip(
      label:
          Text(label, style: TextStyle(fontFamily: fontFamily, fontSize: 13)),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          if (selected) {
            _selectedConditions.add(value);
          } else {
            if (_selectedConditions.length > 1)
              _selectedConditions.remove(value);
          }
        });
        setState(() {}); // Sync main state
        _applyFiltersAndSort();
      },
      selectedColor: AppTheme.goldColor.withOpacity(0.2), // Changed to Gold
      checkmarkColor: AppTheme.goldColor, // Changed to Gold
    );
  }

  String _getSortLabel(SortOption option, bool isUrdu) {
    switch (option) {
      case SortOption.latest:
        return isUrdu ? 'نئی ترین' : 'Latest';
      case SortOption.oldest:
        return isUrdu ? 'پرانی' : 'Oldest';
      case SortOption.priceLow:
        return isUrdu ? 'قیمت: کم سے زیادہ' : 'Price: Low to High';
      case SortOption.priceHigh:
        return isUrdu ? 'قیمت: زیادہ سے کم' : 'Price: High to Low';
      case SortOption.rating:
        return isUrdu ? 'درجہ بندی' : 'Rating';
      case SortOption.popular:
        return isUrdu ? 'مقبول ترین' : 'Most Popular';
      case SortOption.conditionNew:
        return isUrdu ? 'صرف نیا' : 'New Only';
      case SortOption.conditionUsed:
        return isUrdu ? 'صرف پرانا/استعمال شدہ' : 'Used Only';
    }
  }

  Widget _buildProductsGrid(bool isUrdu, String fontFamily) {
    if (_selectedCategory == 'all' && _searchQuery.isEmpty) {
      return _buildSectionedView(isUrdu, fontFamily);
    }

    if (_viewMode == ViewMode.grid) {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _displayedItems.length,
        itemBuilder: (context, index) {
          final item = _displayedItems[index];
          return ProductCard(
            item: item,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            view: ProductCardView.grid,
            isFavorite: item.isFavorite ?? false,
            isMyItem: item.accountId == FirebaseAuth.instance.currentUser?.uid,
            sellerName: _getSellerName(item),
            userPosition: _userPosition,
            onTap: () => _navigateToDetail(item),
            onFavoriteToggle: () => _toggleFavorite(item),
            onSellerTap: () => _navigateToSellerProfile(item),
          );
        },
      );
    } else {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _displayedItems.length,
        itemBuilder: (context, index) {
          final item = _displayedItems[index];
          return ProductCard(
            item: item,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            view: ProductCardView.list,
            isFavorite: item.isFavorite ?? false,
            isMyItem: item.accountId == FirebaseAuth.instance.currentUser?.uid,
            sellerName: _getSellerName(item),
            userPosition: _userPosition,
            onTap: () => _navigateToDetail(item),
            onFavoriteToggle: () => _toggleFavorite(item),
            onSellerTap: () => _navigateToSellerProfile(item),
          );
        },
      );
    }
  }

  Widget _buildSectionedView(bool isUrdu, String fontFamily) {
    // 1. Group items by category
    final Map<String, List<InventoryItem>> categoryGroups = {};
    for (var item in _allItems) {
      final cat = item.category ?? 'other';
      if (!categoryGroups.containsKey(cat)) categoryGroups[cat] = [];
      categoryGroups[cat]!.add(item);
    }

    // 2. Identify "For You" items
    final forYouItems = _allItems.where((item) {
      final itemName = item.name.toLowerCase();
      final itemDesc = (item.description ?? "").toLowerCase();
      final itemCat = (item.category ?? "").toLowerCase();
      return _interestKeywords.any((k) =>
          itemName.contains(k) || itemDesc.contains(k) || itemCat.contains(k));
    }).toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Recently Viewed Section (If not searching)
        if (_recentlyViewed.isNotEmpty && _searchQuery.isEmpty)
          _buildRecentlyViewedSection(isUrdu, fontFamily),

        // Featured Section
        if (_featuredItems.isNotEmpty)
          _buildFeaturedSection(isUrdu, fontFamily),

        // For You Section
        if (forYouItems.isNotEmpty)
          _buildCategorySection(
            isUrdu ? 'آپ کے لیے خاص' : 'Recommended For You',
            forYouItems,
            isUrdu,
            fontFamily,
          ),

        // Latest Arrivals
        _buildCategorySection(
          isUrdu ? 'نئی اشیاء' : 'Latest Arrivals',
          _allItems.take(15).toList(), // Show first 15 newest items
          isUrdu,
          fontFamily,
        ),

        // Individual Category Sections
        ..._categories
            .where((c) => c.id != 'all' && c.id != 'for_you')
            .map((cat) {
          final items = categoryGroups[cat.id] ?? [];
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildCategorySection(
            isUrdu ? cat.labelUr : cat.labelEn,
            items,
            isUrdu,
            fontFamily,
            categoryId: cat.id,
          );
        }),

        const SizedBox(height: 80), // Space for bottom
      ],
    );
  }

  Widget _buildCategorySection(
      String title, List<InventoryItem> items, bool isUrdu, String fontFamily,
      {String? categoryId}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                ),
              ),
              if (categoryId != null)
                TextButton(
                  onPressed: () => _onCategorySelected(categoryId),
                  child: Text(
                    isUrdu ? 'مزید دیکھیں' : 'See All',
                    style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        color: AppTheme.themeColor),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 240, // Optimized height for horizontal cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 180, // Fixed width for horizontal items
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ProductCard(
                  item: item,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  view: ProductCardView.grid,
                  isFavorite: item.isFavorite ?? false,
                  isMyItem:
                      item.accountId == FirebaseAuth.instance.currentUser?.uid,
                  sellerName: _getSellerName(item),
                  userPosition: _userPosition,
                  onTap: () => _navigateToDetail(item),
                  onFavoriteToggle: () => _toggleFavorite(item),
                  onSellerTap: () => _navigateToProfile(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToProfile(InventoryItem item) {
    if (item.accountId == null) return;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final String sellerName = _getSellerName(item) ?? 'Seller';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerItemsScreen(
          sellerUid: item.accountId!,
          sellerName: sellerName,
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(bool isUrdu, String fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Icon(PhosphorIcons.crown(PhosphorIconsStyle.fill),
                  color: AppTheme.goldColor, size: 20),
              const SizedBox(width: 8),
              Text(
                isUrdu ? 'نمایاں اشتہارات' : 'Featured Ads',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _featuredItems.length,
            itemBuilder: (context, index) {
              final item = _featuredItems[index];
              return Container(
                width: 180,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Stack(
                  children: [
                    ProductCard(
                      item: item,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      view: ProductCardView.grid,
                      isFavorite: item.isFavorite ?? false,
                      isMyItem: item.accountId ==
                          FirebaseAuth.instance.currentUser?.uid,
                      sellerName: _getSellerName(item),
                      userPosition: _userPosition,
                      onTap: () => _navigateToDetail(item),
                      onFavoriteToggle: () => _toggleFavorite(item),
                      onSellerTap: () => _navigateToProfile(item),
                    ),
                    Positioned(
                      top: 10,
                      left: isUrdu ? null : 10,
                      right: isUrdu ? 10 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.goldColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              isUrdu ? 'نمایاں' : 'Featured',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyViewedSection(bool isUrdu, String fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.fill),
                  color: AppTheme.themeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                isUrdu ? 'حال ہی میں دیکھے گئے' : 'Recently Viewed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _recentlyViewed.length,
            itemBuilder: (context, index) {
              final item = _recentlyViewed[index];
              return GestureDetector(
                onTap: () => _navigateToDetail(item),
                child: Container(
                  width: 100,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4)
                    ],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: item.imagePaths.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: item.imagePaths.first,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : Container(
                                  color: Colors.grey[100],
                                  child: const Icon(Icons.image,
                                      color: Colors.grey)),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: fontFamily),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorIcons.package(),
                size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            isUrdu ? 'کوئی مصنوعات نہیں ملی' : 'No products found',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor,
                fontFamily: fontFamily),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu ? 'پہلی مصنوعات شامل کریں' : 'Add your first product',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: fontFamily),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddInventoryItemScreen()),
              );
              if (result == true) await _loadData();
            },
            icon: Icon(PhosphorIcons.plus(), size: 18),
            label: Text(isUrdu ? 'مصنوعات شامل کریں' : 'Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonShimmer(
                width: double.infinity, height: 140, borderRadius: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonShimmer(width: double.infinity, height: 14),
                    const SizedBox(height: 8),
                    const SkeletonShimmer(width: 80, height: 10),
                    const Spacer(),
                    const SkeletonShimmer(width: 100, height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          height: 32,
          width: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  void _showCartDialog(bool isUrdu, String fontFamily) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final favorites =
                _allItems.where((item) => item.isFavorite == true).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isUrdu ? 'پسندیدہ مصنوعات' : 'Favorite Products',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: favorites.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIcons.heart(),
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  isUrdu
                                      ? 'کوئی پسندیدہ مصنوعات نہیں'
                                      : 'No favorite products',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontFamily: fontFamily),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: favorites.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = favorites[index];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: item.imagePaths.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: item.imagePaths.first,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                                    color: Colors.grey[200]),
                                            errorWidget:
                                                (context, url, error) => Icon(
                                                    PhosphorIcons.image(),
                                                    size: 24),
                                          )
                                        : Icon(PhosphorIcons.package(),
                                            size: 24, color: Colors.grey[400]),
                                  ),
                                ),
                                title: Text(item.name,
                                    style: TextStyle(fontFamily: fontFamily)),
                                subtitle: Text('Rs ${item.defaultRate}',
                                    style: const TextStyle(
                                        fontFamily: '',
                                        fontWeight: FontWeight.bold)),
                                trailing: IconButton(
                                  icon: Icon(PhosphorIcons.trash(),
                                      color: AppTheme.expenseColor),
                                  onPressed: () async {
                                    await _toggleFavorite(item);
                                    setModalState(
                                        () {}); // Re-build the modal list
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _navigateToDetail(item);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ==================== ENUMS & MODELS ====================
enum SortOption {
  latest,
  oldest,
  priceLow,
  priceHigh,
  rating,
  popular,
  conditionNew,
  conditionUsed
}

enum ViewMode { grid, list }

class CategoryChip {
  final String id;
  final String labelEn;
  final String labelUr;
  final IconData icon;

  const CategoryChip({
    required this.id,
    required this.labelEn,
    required this.labelUr,
    required this.icon,
  });
}
