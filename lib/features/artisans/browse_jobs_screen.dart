import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/features/artisans/widgets/job_post_card.dart';
import 'place_bid_screen.dart';
import 'post_job_screen.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';
import 'dart:ui' as ui;

class BrowseJobsScreen extends StatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  State<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends State<BrowseJobsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<JobPost> _jobs = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _selectedCategory = 'all';
  bool _isInitialLoading = true;
  
  late AnimationController _shimmerController;
  final int _batchSize = 10;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scrollController.addListener(_onScroll);
    _initData();
  }

  Future<void> _initData() async {
    await _setInitialCategory();
    await _fetchJobs(isRefresh: true);
  }

  Future<void> _setInitialCategory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = await ArtisanService().getProfile(user.uid);
    if (profile != null && mounted) {
      _selectedCategory = profile.profession;
    }
  }

  Future<void> _fetchJobs({bool isRefresh = false}) async {
    if (_isLoadingMore) return;

    if (mounted) {
      setState(() {
        if (isRefresh) {
          _isInitialLoading = true;
          _jobs = [];
          _lastDocument = null;
          _hasMore = true;
        }
        _isLoadingMore = true;
      });
    }

    try {
      final snapshot = await JobService().getJobsBatch(
        limit: _batchSize,
        startAfter: _lastDocument,
        category: _selectedCategory,
      );

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newJobs = snapshot.docs.map((doc) => JobPost.fromMap(doc.data())).toList();
        
        // Filter out expired jobs locally
        final now = DateTime.now();
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        
        final validJobs = newJobs.where((j) => j.customerId == currentUserId || j.deadline.isAfter(now)).toList();

        if (mounted) {
          setState(() {
            _jobs.addAll(validJobs);
            
            // 🔥 یہاں الگورتھم استعمال ہو رہا ہے
            // جیسے ہی نیا ڈیٹا آتا ہے، ہم پوری لسٹ کو دوبارہ "سمارٹ سورٹ" کرتے ہیں
            final algorithm = JobAlgorithmService();
            _jobs = algorithm.applySmartSort(_jobs, _selectedCategory, currentUserId);
            
            _hasMore = snapshot.docs.length == _batchSize;
          });
        }
      } else {
        if (mounted) {
          setState(() => _hasMore = false);
        }
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _fetchJobs();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _showCategoryPicker(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
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
                width: 40, height: 4,
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
                              _selectedCategory = 'all';
                              _fetchJobs(isRefresh: true);
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
                              _selectedCategory = p['id']!;
                              _fetchJobs(isRefresh: true);
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
      body: RefreshIndicator(
        onRefresh: () => _fetchJobs(isRefresh: true),
        color: AppTheme.themeColor,
        child: _isInitialLoading 
            ? _buildShimmerLoading() 
            : _jobs.isEmpty 
                ? _buildEmptyState(isUrdu, fontFamily)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _jobs.length) {
                        final job = _jobs[index];
                        return JobPostCard(
                          job: job,
                          isUrdu: isUrdu,
                          fontFamily: fontFamily,
                          currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          onBidTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceBidScreen(job: job)));
                          },
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.themeColor.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      }
                    },
                  ),
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
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
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _shimmerBox(width: 40, height: 40, radius: 10),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(width: 120, height: 12),
                      const SizedBox(height: 6),
                      _shimmerBox(width: 80, height: 10),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _shimmerBox(width: double.infinity, height: 16),
              const SizedBox(height: 8),
              _shimmerBox(width: double.infinity, height: 16),
              const SizedBox(height: 8),
              _shimmerBox(width: 150, height: 16),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBox(width: 100, height: 35, radius: 20),
                  _shimmerBox(width: 100, height: 35, radius: 20),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox({required double width, required double height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [
            _shimmerController.value - 0.3,
            _shimmerController.value,
            _shimmerController.value + 0.3,
          ],
          colors: [
            Colors.grey[200]!,
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
        ),
      ),
    );
  }
}
