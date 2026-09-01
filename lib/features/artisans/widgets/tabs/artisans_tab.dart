import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/widgets/artisan_card.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';
import 'package:account_app/features/artisans/artisan_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ArtisansTab extends StatefulWidget {
  final String selectedProfession;
  final String searchQuery;
  final VoidCallback? onProfessionTap;
  
  const ArtisansTab({
    super.key,
    required this.selectedProfession,
    this.searchQuery = '',
    this.onProfessionTap,
  });

  @override
  State<ArtisansTab> createState() => _ArtisansTabState();
}

class _ArtisansTabState extends State<ArtisansTab> {
  final ArtisanService _artisanService = ArtisanService();
  final ScrollController _scrollController = ScrollController();
  
  String _artisanSortBy = 'rating';
  Position? _currentPosition;
  
  List<ArtisanProfile> _allArtisans = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 20;
  
  DocumentSnapshot? _lastDocument;
  StreamSubscription? _artisanSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadArtisans();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ArtisansTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // اگر پیشہ یا سرچ کیوری بدل جائے تو دوبارہ لوڈ کریں
    if (oldWidget.selectedProfession != widget.selectedProfession ||
        oldWidget.searchQuery != widget.searchQuery) {
      _loadArtisans();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _artisanSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreArtisans();
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _loadArtisans() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _allArtisans = []; // پرانی لسٹ صاف کریں
    });
    
    try {
      _artisanSubscription?.cancel();
      
      _artisanSubscription = _artisanService
          .streamArtisansPaginated(limit: _pageSize)
          .listen(
        (artisans) {
          if (mounted) {
            setState(() {
              _allArtisans = artisans;
              _isLoading = false;
              _hasMore = artisans.length >= _pageSize;
              // Note: We need to handle _lastDocument for pagination if we use stream for the first batch
              // and Future for the rest. Or just use Future for all.
              // For simplicity, let's keep the stream for the first batch and manual load for more.
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreArtisans() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final moreArtisans = await _artisanService.getArtisansBatch(
        limit: _pageSize,
        startAfter: _lastDocument,
      );
      
      if (mounted) {
        setState(() {
          _allArtisans.addAll(moreArtisans);
          _hasMore = moreArtisans.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  double? _calculateDistance(double? lat, double? lng) {
    if (_currentPosition == null || lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        ) /
        1000;
  }

  int _calculateArtisanScore(ArtisanProfile artisan, double? distance) {
    int score = 0;
    if (artisan.availability == 'available') score += 30;
    if (distance != null && distance < 5.0) score += 25;
    if (artisan.isVerified) score += 20;
    if (artisan.rating >= 4.5) score += 15;
    if (artisan.experience >= 5) score += 10;
    return score;
  }

  List<ArtisanProfile> _filterAndSortArtisans() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    var filtered = _allArtisans
        .where((a) => a.id != currentUserId && a.isActive)
        .toList();

    if (widget.selectedProfession != 'all') {
      filtered = filtered
          .where((a) => a.profession == widget.selectedProfession)
          .toList();
    }

    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        final matchesSkills = a.skills.any(
          (s) => s.toLowerCase().contains(query),
        );
        return a.name.toLowerCase().contains(query) ||
            a.profession.toLowerCase().contains(query) ||
            a.description.toLowerCase().contains(query) ||
            matchesSkills;
      }).toList();
    }

    // Pre-calculate distances
    final distances = <String, double?>{};
    for (var artisan in filtered) {
      distances[artisan.id] = _calculateDistance(
        artisan.latitude,
        artisan.longitude,
      );
    }

    filtered.sort((a, b) {
      final scoreA = _calculateArtisanScore(a, distances[a.id]);
      final scoreB = _calculateArtisanScore(b, distances[b.id]);

      if (scoreA != scoreB) return scoreB.compareTo(scoreA);

      switch (_artisanSortBy) {
        case 'distance':
          final distA = distances[a.id] ?? 9999.0;
          final distB = distances[b.id] ?? 9999.0;
          return distA.compareTo(distB);
        case 'experience':
          return b.experience.compareTo(a.experience);
        case 'reviews':
          return b.totalReviews.compareTo(a.totalReviews);
        case 'rating':
        default:
          return b.rating.compareTo(a.rating);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Column(
      children: [
        _buildSortBar(isUrdu, fontFamily),
        Expanded(
          child: _isLoading
              ? _buildShimmerLoading()
              : _buildArtisanList(isUrdu, fontFamily),
        ),
      ],
    );
  }

  Widget _buildSortBar(bool isUrdu, String fontFamily) {
    String professionName = isUrdu ? 'پیشہ' : 'Profession';
    if (widget.selectedProfession != 'all') {
      final professions = ArtisanService.getProfessions();
      final found = professions.firstWhere(
        (p) => p['id'] == widget.selectedProfession,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        professionName = isUrdu ? found['name'] : found['id'];
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Profession Filter
            GestureDetector(
              onTap: widget.onProfessionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: widget.selectedProfession != 'all' 
                      ? AppTheme.themeColor.withValues(alpha: 0.1) 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.selectedProfession != 'all' 
                        ? AppTheme.themeColor 
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.briefcase(),
                      size: 14,
                      color: widget.selectedProfession != 'all' 
                          ? AppTheme.themeColor 
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      professionName,
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.selectedProfession != 'all' 
                            ? AppTheme.themeColor 
                            : Colors.grey[600],
                        fontFamily: fontFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: widget.selectedProfession != 'all' 
                          ? AppTheme.themeColor 
                          : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 4),
            Container(width: 1, height: 16, color: Colors.grey[300]),
            const SizedBox(width: 8),

            Text(
              isUrdu ? 'ترتیب:' : 'Sort By:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(width: 8),
            _buildSortChip('rating', isUrdu ? 'ریٹنگ' : 'Rating', fontFamily),
            _buildSortChip('distance', isUrdu ? 'قریب' : 'Nearby', fontFamily),
            _buildSortChip('experience', isUrdu ? 'تجربہ' : 'Experience', fontFamily),
            _buildSortChip('reviews', isUrdu ? 'ریویوز' : 'Reviews', fontFamily),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String value, String label, String fontFamily) {
    final isSelected = _artisanSortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _artisanSortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.themeColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.themeColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.grey[600],
            fontFamily: fontFamily,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildArtisanList(bool isUrdu, String fontFamily) {
    final filteredArtisans = _filterAndSortArtisans();

    if (filteredArtisans.isEmpty) {
      return _buildEmptyState(isUrdu, fontFamily);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredArtisans.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredArtisans.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : TextButton(
                      onPressed: _loadMoreArtisans,
                      child: Text(
                        isUrdu ? 'مزید لوڈ کریں' : 'Load More',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          );
        }

        final artisan = filteredArtisans[index];
        final distance = _calculateDistance(
          artisan.latitude,
          artisan.longitude,
        );

        return ArtisanCard(
          artisan: artisan,
          isUrdu: isUrdu,
          fontFamily: fontFamily,
          distanceKm: distance,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArtisanDetailScreen(
                  artisanId: artisan.id,
                  initialArtisan: artisan,
                  distanceKm: distance,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.magnifyingGlass(),
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی کاریگر نہیں ملا' : 'No artisans found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => SkeletonCard(
        child: Row(
          children: [
            const SkeletonShimmer(width: 70, height: 70, borderRadius: 12),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonShimmer(width: 120, height: 16, borderRadius: 4),
                  const SizedBox(height: 8),
                  const SkeletonShimmer(width: 80, height: 12, borderRadius: 4),
                  const SizedBox(height: 8),
                  const SkeletonShimmer(width: 150, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
