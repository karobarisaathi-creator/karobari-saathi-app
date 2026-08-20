import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/features/artisans/widgets/job_post_card.dart';
import 'package:account_app/features/artisans/job_detail_screen.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';

class JobsTab extends StatefulWidget {
  final String selectedCategory;
  const JobsTab({super.key, required this.selectedCategory});

  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  List<JobPost> _jobs = [];
  DocumentSnapshot? _lastJobDocument;
  bool _isLoadingMoreJobs = false;
  bool _hasMoreJobs = true;
  bool _isInitialJobsLoading = true;
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
    _fetchJobs(isRefresh: true);
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
    _shimmerController.dispose();
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
                j.customerId == currentUserId || j.deadline == null || j.deadline!.isAfter(now))
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
          bool isNotMine = widget.selectedCategory == 'all' || j.customerId != currentUserId;
          bool matchesCategory = widget.selectedCategory == 'all' || j.categories.contains(widget.selectedCategory);
          bool isNotExpired = j.customerId == currentUserId || j.deadline == null || j.deadline!.isAfter(now);
          
          return isNotMine && matchesCategory && isNotExpired;
        }).toList() ?? [];

        // Apply algorithm sorting
        final algorithm = JobAlgorithmService();
        jobs = algorithm.applySmartSort(jobs, widget.selectedCategory, currentUserId);

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

  Widget _shimmerBox(
      {required double width, required double height, double radius = 4}) {
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
