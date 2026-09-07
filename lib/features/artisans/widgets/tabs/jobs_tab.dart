import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
import 'package:account_app/core/services/logging_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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
  final _logger = LoggingService();
  final ScrollController _scrollController = ScrollController();
  final JobService _jobService = JobService();
  final ArtisanService _artisanService = ArtisanService();
  final JobAlgorithmService _algorithmService = JobAlgorithmService();

  List<JobPost> _jobs = [];
  DocumentSnapshot? _lastJobDocument;

  bool _isLoadingMore = false;
  bool _hasMoreJobs = true;
  bool _isInitialLoading = true;

  String? _artisanProfession;
  double? _artisanRating;
  double? _artisanLat;
  double? _artisanLng;

  final int _batchSize = 10;
  StreamSubscription? _jobsSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadArtisanProfile();
    _fetchJobs(isRefresh: true);
    _subscribeToLiveJobs();

    // لوکل ڈیٹا میں تبدیلیوں پر نظر رکھنے کے لیے
    _jobService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {
        // جب بھی لوکل ڈیٹا بدلے گا (مثلاً نئی جاب پوسٹ ہوگی)، لسٹ اپ ڈیٹ ہوگی
        _syncLocalJobs();
      });
    }
  }

  void _syncLocalJobs() {
    final localJobs = _jobService.getJobsLocal();
    if (localJobs.isNotEmpty) {
      setState(() {
        for (var updatedJob in localJobs) {
          final index = _jobs.indexWhere((j) => j.id == updatedJob.id);
          if (index != -1) {
            // اگر جاب پہلے سے موجود ہے تو اسے اپ ڈیٹ کریں
            _jobs[index] = updatedJob;
          } else {
            // اگر نئی جاب ہے تو اسے شروع میں شامل کریں
            _jobs.insert(0, updatedJob);
          }
        }
      });
    }
  }

  void _subscribeToLiveJobs() {
    _jobsSubscription = _jobService.getOpenJobs().listen(
      (liveJobs) {
        if (!mounted) return;

        final liveJobsById = {
          for (final job in liveJobs) job.id: job,
        };
        setState(() {
          for (final liveJob in liveJobs) {
            final index = _jobs.indexWhere((job) => job.id == liveJob.id);
            if (index == -1) {
              _jobs.add(liveJob);
            } else {
              _jobs[index] = liveJob;
            }
          }
          _jobs.removeWhere(
            (job) => job.status == 'open' && !liveJobsById.containsKey(job.id),
          );
          _isInitialLoading = false;
        });
      },
      onError: (error, stackTrace) {
        _logger.error('Live jobs stream error', error, stackTrace);
      },
    );
  }

  @override
  void didUpdateWidget(JobsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.searchQuery != widget.searchQuery) {
      _fetchJobs(isRefresh: true);
    }
  }

  @override
  void dispose() {
    _jobService.removeListener(_onServiceChanged);
    _scrollController.dispose();
    _jobsSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMoreJobs && !_isLoadingMore) {
        _fetchJobs();
      }
    }
  }

  Future<void> _loadArtisanProfile() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final profile = await _artisanService.getProfile(userId);
      if (!mounted) return;

      setState(() {
        _artisanProfession =
            profile != null && profile.isActive ? profile.profession : null;
        _artisanRating = profile?.rating;
        _artisanLat = profile?.latitude;
        _artisanLng = profile?.longitude;
      });
    } catch (e, stack) {
      _logger.error("Load artisan profile error", e, stack);
    }
  }

  Future<void> _fetchJobs({bool isRefresh = false}) async {
    if (_isLoadingMore) return;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
        if (isRefresh) {
          _isInitialLoading = true;
          _jobs = []; // پرانا ڈیٹا صاف کریں
          _lastJobDocument = null;
          _hasMoreJobs = true;
        }
      });
    }

    try {
      final snapshot = await _jobService.getJobsBatch(
        limit: _batchSize,
        startAfter: _lastJobDocument,
        category: widget.selectedCategory,
      );

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        _lastJobDocument = snapshot.docs.last;
        final newJobs =
            snapshot.docs.map((doc) => JobPost.fromMap(doc.data())).toList();

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final validJobs = newJobs;

        setState(() {
          if (isRefresh) {
            _jobs = validJobs;
          } else {
            // Avoid duplicates
            final existingIds = _jobs.map((j) => j.id).toSet();
            _jobs.addAll(validJobs.where((j) => !existingIds.contains(j.id)));
          }
          _hasMoreJobs = snapshot.docs.length == _batchSize;
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _hasMoreJobs = false;
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e, stack) {
      _logger.error("Fetch jobs error", e, stack);
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<JobPost> _filterAndSortJobs() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    var jobs = _jobs.where((job) {
      bool isNotMine = job.customerId != currentUserId;
      bool matchesCategory = widget.selectedCategory == 'all' ||
          job.categories.contains(widget.selectedCategory);
      bool isOpen = job.status == 'open' || job.customerId == currentUserId;

      bool matchesSearch = true;
      if (widget.searchQuery.isNotEmpty) {
        final query = widget.searchQuery.toLowerCase();
        matchesSearch = job.title.toLowerCase().contains(query) ||
            job.description.toLowerCase().contains(query) ||
            job.location.toLowerCase().contains(query);
      }

      return isNotMine && matchesCategory && isOpen && matchesSearch;
    }).toList();

    return _algorithmService.applySmartSort(
      jobs: jobs,
      artisanProfession: _artisanProfession,
      currentUserId: currentUserId,
      artisanLat: _artisanLat,
      artisanLng: _artisanLng,
      artisanRating: _artisanRating,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return RefreshIndicator(
      onRefresh: () => _fetchJobs(isRefresh: true),
      color: AppTheme.themeColor,
      child: _buildBody(isUrdu, fontFamily),
    );
  }

  Widget _buildBody(bool isUrdu, String fontFamily) {
    if (_isInitialLoading && _jobs.isEmpty) {
      return _buildShimmerLoading();
    }

    final filteredJobs = _filterAndSortJobs();

    if (filteredJobs.isEmpty) {
      return _buildEmptyState(isUrdu, fontFamily);
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: filteredJobs.length + (_hasMoreJobs ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredJobs.length) {
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

        final job = filteredJobs[index];
        return JobPostCard(
          job: job,
          isUrdu: isUrdu,
          fontFamily: fontFamily,
          currentUserId: currentUserId,
          onDeleted: () {
            setState(() {
              _jobs.removeWhere((j) => j.id == job.id);
            });
          },
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JobDetailScreen(job: job),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.7,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.megaphone(),
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                isUrdu ? 'کوئی کام دستیاب نہیں' : 'No jobs available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 5,
      itemBuilder: (context, index) => SkeletonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonShimmer(width: 140, height: 18, borderRadius: 4),
                const SkeletonShimmer(width: 60, height: 22, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 8),
            const SkeletonShimmer(width: 80, height: 12, borderRadius: 4),
            const SizedBox(height: 16),
            // Description
            const SkeletonShimmer(width: double.infinity, height: 12, borderRadius: 4),
            const SizedBox(height: 8),
            const SkeletonShimmer(width: 200, height: 12, borderRadius: 4),
            const SizedBox(height: 16),
            // Chips
            Row(
              children: [
                const SkeletonShimmer(width: 90, height: 24, borderRadius: 8),
                const SizedBox(width: 8),
                const SkeletonShimmer(width: 70, height: 24, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 16),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonShimmer(width: 100, height: 14, borderRadius: 4),
                const SkeletonShimmer(width: 80, height: 16, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
