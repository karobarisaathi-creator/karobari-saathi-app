import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/features/artisans/widgets/job_post_card.dart';
import 'place_bid_screen.dart';
import 'post_job_screen.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';

class BrowseJobsScreen extends StatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  State<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends State<BrowseJobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _setInitialCategory();
  }

  Future<void> _setInitialCategory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = await ArtisanService().getProfile(user.uid);
    if (profile != null && mounted) {
      setState(() {
        _selectedCategory = profile.profession;
        _isFirstLoad = false;
      });
    } else if (mounted) {
      setState(() => _isFirstLoad = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCategoryPicker(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
    
    // Group professions by category
    final Map<String, List<Map<String, dynamic>>> groupedProfessions = {};
    for (var p in professions) {
      final cat = isUrdu ? p['categoryUrdu'] : p['category'];
      if (!groupedProfessions.containsKey(cat)) {
        groupedProfessions[cat] = [];
      }
      groupedProfessions[cat]!.add(p);
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
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                isUrdu ? 'تمام شعبہ جات' : 'All Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedProfessions.keys.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = _selectedCategory == 'all';
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(PhosphorIcons.circlesThree(), color: isSelected ? AppTheme.themeColor : Colors.grey),
                            title: Text(isUrdu ? 'تمام کام' : 'All Jobs', style: TextStyle(fontFamily: fontFamily, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            onTap: () {
                              setState(() => _selectedCategory = 'all');
                              Navigator.pop(context);
                            },
                          ),
                          const Divider(),
                        ],
                      );
                    }
                    final category = groupedProfessions.keys.elementAt(index - 1);
                    final items = groupedProfessions[category]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Text(category, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.themeColor, fontFamily: fontFamily)),
                        ),
                        ...items.map((p) {
                          final isSelected = _selectedCategory == p['id'];
                          return ListTile(
                            leading: Icon(p['icon'], color: isSelected ? AppTheme.themeColor : Colors.grey),
                            title: Text(isUrdu ? p['name'] : p['id'], style: TextStyle(fontFamily: fontFamily, fontSize: 13)),
                            onTap: () {
                              setState(() => _selectedCategory = p['id']!);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
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

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: isUrdu ? 'دستیاب کام' : 'Available Jobs',
        showBackButton: false,
        actions: [
          _buildCategoryPickerButton(isUrdu, fontFamily),
          IconButton(
            icon: Icon(PhosphorIcons.plusCircle(), color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PostJobScreen()),
              );
            },
            tooltip: isUrdu ? 'نیا کام' : 'Post Job',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isFirstLoad 
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: StreamBuilder<List<JobPost>>(
              stream: JobService().getOpenJobs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var jobs = snapshot.data ?? [];
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                final algorithm = JobAlgorithmService();
                
                // 1. میعاد ختم ہونے والی جابز چھپائیں (صرف دوسروں کی)
                final now = DateTime.now();
                jobs = jobs.where((j) => j.customerId == currentUserId || j.deadline.isAfter(now)).toList();

                // 2. کیٹیگری فلٹر (Client side)
                if (_selectedCategory != 'all') {
                  jobs = jobs.where((j) => j.category == _selectedCategory).toList();
                }

                // 3. سمارٹ سورٹنگ (AI Logic)
                // ہم چیک کرتے ہیں کہ کیا صارف کاریگر ہے تاکہ اس کے پیشے کے مطابق ڈیٹا دکھائیں
                String? artisanProfession;
                if (_selectedCategory != 'all') {
                  artisanProfession = _selectedCategory;
                }

                jobs = algorithm.applySmartSort(jobs, artisanProfession, currentUserId);

                if (jobs.isEmpty) return _buildEmptyState(isUrdu, fontFamily);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return JobPostCard(
                      job: job,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      onBidTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceBidScreen(job: job)));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPickerButton(bool isUrdu, String fontFamily) {
    String name = isUrdu ? 'سب' : 'All';
    if (_selectedCategory != 'all') {
      final p = ArtisanService.getProfessions().firstWhere((p) => p['id'] == _selectedCategory, orElse: () => {});
      if (p.isNotEmpty) name = isUrdu ? p['name'] : p['id'];
    }

    return Center(
      child: InkWell(
        onTap: () => _showCategoryPicker(isUrdu, fontFamily),
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
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.megaphone(), size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(isUrdu ? 'کوئی کام دستیاب نہیں' : 'No jobs available',
              style: TextStyle(
                  fontSize: 18, color: Colors.grey, fontFamily: fontFamily)),
        ],
      ),
    );
  }
}
