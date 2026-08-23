import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/features/artisans/widgets/job_post_card.dart';
import 'package:account_app/features/artisans/job_detail_screen.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';

class JobsTab extends StatefulWidget {
  final String selectedCategory;
  final String searchQuery;
  const JobsTab({
    super.key,
    required this.selectedCategory,
    this.searchQuery = '',
  });

  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  final ScrollController _scrollController = ScrollController();
  List<JobPost> _jobs = [];
  DocumentSnapshot? _lastJobDocument;
  bool _isLoadingMoreJobs = false;
  bool _hasMoreJobs = true;
  bool _isInitialJobsLoading = true;
  String? _artisanProfession;
  double? _artisanLat;
  double? _artisanLng;
  final int _batchSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadArtisanProfile();
    _fetchJobs(isRefresh: true);
  }

  Future<void> _loadArtisanProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final profile = await ArtisanService().getProfile(userId);
    if (!mounted) return;
    setState(() {
      _artisanProfession =
          profile != null && profile.isActive ? profile.profession : null;
      _artisanLat = profile?.latitude;
      _artisanLng = profile?.longitude;
    });
  }

  @override
  void didUpdateWidget(JobsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _fetchJobs(isRefresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMoreJobs && !_isLoadingMoreJobs) {
        _fetchJobs();
      }
    }
  }

  Future<void> _fetchJobs({bool isRefresh = false}) async {
    if (_isLoadingMoreJobs) return;

    if (mounted) {
      setState(() {
        if (isRefresh) {
          _isInitialJobsLoading = true;
          _jobs = [];
          _lastJobDocument = null;
          _hasMoreJobs = true;
        }
        _isLoadingMoreJobs = true;
      });
    }

    try {
      final service = Provider.of<JobService>(context, listen: false);

      // 1. Fetch Local First
      final localJobs = service.getJobsLocal();
      if (localJobs.isNotEmpty && mounted && isRefresh) {
        setState(() {
          _isInitialJobsLoading = false;
        });
      }

      // 2. Sync from Cloud
      final snapshot = await service.getJobsBatch(
        limit: _batchSize,
        startAfter: _lastJobDocument,
        category: widget.selectedCategory,
      );

      if (snapshot.docs.isNotEmpty) {
        _lastJobDocument = snapshot.docs.last;
        final newJobs =
            snapshot.docs.map((doc) => JobPost.fromMap(doc.data())).toList();

        final now = DateTime.now();
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        final validJobs = newJobs
            .where((j) =>
                j.customerId == currentUserId ||
                j.deadline == null ||
                j.deadline!.isAfter(now))
            .toList();

        if (mounted) {
          setState(() {
            _hasMoreJobs = snapshot.docs.length == _batchSize;
          });
          // Update local cache manually if needed or let the service handle it
          for (var j in validJobs) {
            await service.jobsBox?.put(j.id, j);
          }
          service.notifyListeners();
        }
      } else {
        if (mounted) {
          setState(() => _hasMoreJobs = false);
        }
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitialJobsLoading = false;
          _isLoadingMoreJobs = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Consumer<JobService>(
      builder: (context, service, child) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final now = DateTime.now();

        // Filter jobs from local cache reactively
        var jobs = service.jobsBox?.values.where((j) {
              // If 'all' is selected, show everything (including own).
              // If a specific category is selected, hide own to focus on others' jobs.
              bool isNotMine = widget.selectedCategory == 'all' ||
                  j.customerId != currentUserId;
              bool matchesCategory = widget.selectedCategory == 'all' ||
                  j.categories.contains(widget.selectedCategory);
              bool isNotExpired = j.customerId == currentUserId ||
                  j.deadline == null ||
                  j.deadline!.isAfter(now);
              bool isOpen = j.status == 'open' || j.customerId == currentUserId;

              bool matchesSearch = true;
              if (widget.searchQuery.isNotEmpty) {
                final query = widget.searchQuery.toLowerCase();
                matchesSearch = j.title.toLowerCase().contains(query) ||
                    j.description.toLowerCase().contains(query) ||
                    j.location.toLowerCase().contains(query);
              }

              return isNotMine &&
                  matchesCategory &&
                  isNotExpired &&
                  isOpen &&
                  matchesSearch;
            }).toList() ??
            [];

        // Apply algorithm sorting
        final algorithm = JobAlgorithmService();
        jobs = algorithm.applySmartSort(
          jobs: jobs,
          artisanProfession: _artisanProfession,
          currentUserId: currentUserId,
          artisanLat: _artisanLat,
          artisanLng: _artisanLng,
        );

        return RefreshIndicator(
          onRefresh: () => _fetchJobs(isRefresh: true),
          color: AppTheme.themeColor,
          child: _isInitialJobsLoading && jobs.isEmpty
              ? _buildShimmerLoading()
              : jobs.isEmpty
                  ? _buildEmptyState(isUrdu, fontFamily)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: jobs.length + (_hasMoreJobs ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < jobs.length) {
                          final job = jobs[index];
                          return JobPostCard(
                            job: job,
                            isUrdu: isUrdu,
                            fontFamily: fontFamily,
                            currentUserId: currentUserId ?? '',
                            onBidTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          JobDetailScreen(job: job)));
                            },
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    AppTheme.themeColor.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        }
                      },
                    ),
        );
      },
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
      itemBuilder: (context, index) => SkeletonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonShimmer(width: 150, height: 18, borderRadius: 4),
            const SizedBox(height: 8),
            const SkeletonShimmer(width: 100, height: 12, borderRadius: 4),
            const SizedBox(height: 16),
            const SkeletonShimmer(
                width: double.infinity, height: 14, borderRadius: 4),
            const SizedBox(height: 8),
            const SkeletonShimmer(width: 200, height: 14, borderRadius: 4),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonShimmer(width: 80, height: 24, borderRadius: 12),
                const SkeletonShimmer(width: 80, height: 24, borderRadius: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
