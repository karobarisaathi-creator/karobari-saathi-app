import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/features/artisans/widgets/tabs/jobs_tab.dart';
import 'package:account_app/features/artisans/widgets/tabs/artisans_tab.dart';
import 'package:account_app/core/services/logging_service.dart';

class BrowseJobsScreen extends StatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  State<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends State<BrowseJobsScreen>
    with TickerProviderStateMixin {
  final _logger = LoggingService();
  late TabController _mainTabController;
  final TextEditingController _searchController = TextEditingController();
  final ArtisanService _artisanService = ArtisanService();

  String _selectedProfession = 'all';
  String _searchQuery = '';
  bool _isSearching = false;

  // Remove _tabViews variable
  
  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _selectRoleBasedTab();
  }

  // Remove _updateTabViews method

  Future<void> _selectRoleBasedTab() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final profile = await _artisanService.getProfile(userId);
      if (!mounted) return;

      setState(() {
        _mainTabController.index = profile != null && profile.isActive ? 0 : 1;
      });
    } catch (e, stack) {
      _logger.error("Select role tab error", e, stack);
    }
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'کام اور ماہرین' : 'Browse Services',
        showBackButton: false,
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('search_btn_fixed'),
            onPressed: _toggleSearch,
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isSearching ? 100 : 48),
          child: Column(
            children: [
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SearchSortBar(
                    controller: _searchController,
                    hintText: isUrdu
                        ? 'کام یا مقام تلاش کریں...'
                        : 'Search jobs or locations...',
                    showVoiceSearch: false,
                    onSearchChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              TabBar(
                controller: _mainTabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: isUrdu ? 'دستیاب کام' : 'Jobs'),
                  Tab(text: isUrdu ? 'ماہرین / کاریگر' : 'Artisans'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [
          JobsTab(
            key: ValueKey('jobs_$_searchQuery'),
            selectedCategory: 'all',
            searchQuery: _searchQuery,
          ),
          ArtisansTab(
            key: ValueKey('artisans_${_selectedProfession}_$_searchQuery'),
            selectedProfession: _selectedProfession,
            searchQuery: _searchQuery,
            onProfessionTap: () => _showGlobalProfessionPicker(isUrdu, fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionPickerButton(bool isUrdu, String fontFamily) {
    String name = isUrdu ? 'سب' : 'All';
    if (_selectedProfession != 'all') {
      final professions = ArtisanService.getProfessions();
      final found = professions.firstWhere(
            (p) => p['id'] == _selectedProfession,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        name = isUrdu ? found['name'] : found['id'];
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: InkWell(
          onTap: () => _showGlobalProfessionPicker(isUrdu, fontFamily),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGlobalProfessionPicker(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var p in professions) {
      final cat = isUrdu ? p['categoryUrdu'] : p['category'];
      if (!grouped.containsKey(cat)) grouped[cat] = [];
      grouped[cat]!.add(p);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isUrdu ? 'شعبہ منتخب کریں' : 'Select Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: fontFamily,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: grouped.keys.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildAllOptionCard(isUrdu, fontFamily),
                      );
                    }

                    final category = grouped.keys.elementAt(index - 1);
                    final items = grouped[category]!;
                    return _buildCategorySection(
                      category,
                      items,
                      isUrdu,
                      fontFamily,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllOptionCard(bool isUrdu, String fontFamily) {
    final isSelected = _selectedProfession == 'all';
    return InkWell(
      onTap: () {
        setState(() => _selectedProfession = 'all');
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.themeColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.themeColor : Colors.white,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppTheme.themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.circlesThree(),
                color: isSelected ? Colors.white : AppTheme.themeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              isUrdu ? 'تمام کام / شعبے' : 'All Jobs & Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
                color: isSelected ? Colors.white : AppTheme.darkColor,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
      String category,
      List<Map<String, dynamic>> items,
      bool isUrdu,
      String fontFamily,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.themeColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.75,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final p = items[idx];
              final isSelected = _selectedProfession == p['id'];
              return InkWell(
                onTap: () {
                  setState(() => _selectedProfession = p['id']!);
                  Navigator.pop(context);
                },
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.themeColor : AppTheme.backgroundColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.themeColor : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppTheme.themeColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ] : null,
                      ),
                      child: Icon(
                        p['icon'],
                        color: isSelected ? Colors.white : AppTheme.themeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        isUrdu ? p['name']! : p['id']!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontFamily: fontFamily,
                          color: isSelected ? AppTheme.themeColor : AppTheme.darkColor,
                          height: 1.1,
                        ),
                      ),
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
}