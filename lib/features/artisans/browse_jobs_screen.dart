import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/features/artisans/post_job_screen.dart';
import 'package:account_app/features/artisans/widgets/tabs/jobs_tab.dart';
import 'package:account_app/features/artisans/widgets/tabs/artisans_tab.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';

class BrowseJobsScreen extends StatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  State<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends State<BrowseJobsScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedProfession = 'all';
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _selectRoleBasedTab();
  }

  Future<void> _selectRoleBasedTab() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final profile = await ArtisanService().getProfile(userId);
    if (!mounted) return;
    _mainTabController.index = profile != null && profile.isActive ? 0 : 1;
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF0), // Even darker for better contrast
      appBar: CustomAppBar(
        title: isUrdu ? 'کمیونٹی مرکز' : 'Community Hub',
        showBackButton: false,
        leading: _buildProfessionPickerButton(isUrdu, fontFamily),
        leadingWidth: 120, // Increased to avoid overflow
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('search_btn_fixed'),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
          ),
          IconButton(
            key: const ValueKey('add_job_btn_fixed'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PostJobScreen()),
              );
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
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
                    hintText: isUrdu ? 'تلاش کریں...' : 'Search...',
                    showVoiceSearch: false,
                    onSearchChanged: (val) {
                      setState(() => _searchQuery = val);
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
                    fontSize: 13),
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
            selectedCategory: _selectedProfession,
            searchQuery: _searchQuery,
          ),
          ArtisansTab(
            selectedProfession: _selectedProfession,
            searchQuery: _searchQuery,
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
        padding: const EdgeInsets.only(left: 12, right: 8), // کنارے سے فاصلہ
        child: InkWell(
          onTap: () => _showGlobalProfessionPicker(isUrdu, fontFamily),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
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
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
                isUrdu ? 'شعبہ منتخب کریں' : 'Select Category',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.keys.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = _selectedProfession == 'all';
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(PhosphorIcons.circlesThree(),
                                color: isSelected
                                    ? AppTheme.themeColor
                                    : Colors.grey),
                            title: Text(isUrdu ? 'تمام کام' : 'All Jobs',
                                style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            selected: isSelected,
                            onTap: () {
                              setState(() => _selectedProfession = 'all');
                              Navigator.pop(context);
                            },
                          ),
                          const Divider(),
                        ],
                      );
                    }
                    final category = grouped.keys.elementAt(index - 1);
                    final items = grouped[category]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          child: Text(
                            category,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.themeColor,
                                fontFamily: fontFamily),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
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
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.themeColor.withOpacity(0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: isSelected
                                          ? AppTheme.themeColor
                                          : Colors.grey[200]!,
                                      width: 1.5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(p['icon'],
                                        color: isSelected
                                            ? AppTheme.themeColor
                                            : Colors.grey[700],
                                        size: 28),
                                    const SizedBox(height: 8),
                                    Text(
                                      isUrdu ? p['name']! : p['id']!,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontFamily: fontFamily,
                                        color: isSelected
                                            ? AppTheme.themeColor
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                      ],
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
}
