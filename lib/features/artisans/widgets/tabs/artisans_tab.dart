import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/widgets/artisan_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/features/artisans/artisan_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';

class ArtisansTab extends StatefulWidget {
  final String selectedProfession;
  final String searchQuery;
  const ArtisansTab({
    super.key,
    required this.selectedProfession,
    this.searchQuery = '',
  });

  @override
  State<ArtisansTab> createState() => _ArtisansTabState();
}

class _ArtisansTabState extends State<ArtisansTab> {
  String _artisanSortBy = 'rating';
  Position? _currentPosition;
  int _currentArtisanPage = 1;
  static const int _artisanPageSize = 20;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint("Error getting location: $e");
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

  int _calculateArtisanScore(ArtisanProfile artisan) {
    int score = 0;

    // 1. Available: +30 points
    if (artisan.availability == 'available') {
      score += 30;
    }

    // 2. Distance < 5km: +25 points
    final distance = _calculateDistance(artisan.latitude, artisan.longitude);
    if (distance != null && distance < 5.0) {
      score += 25;
    }

    // 3. Verified: +20 points
    if (artisan.isVerified) {
      score += 20;
    }

    // 4. Rating 4.5+: +15 points
    if (artisan.rating >= 4.5) {
      score += 15;
    }

    // 5. Experience 5+ years: +10 points
    if (artisan.experience >= 5) {
      score += 10;
    }

    return score;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                isUrdu ? 'ترتیب:' : 'Sort By:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 8),
              _buildArtisanSortChip(
                  'rating', isUrdu ? 'ریٹنگ' : 'Rating', fontFamily),
              _buildArtisanSortChip(
                  'distance', isUrdu ? 'قریب' : 'Nearby', fontFamily),
              _buildArtisanSortChip(
                  'experience', isUrdu ? 'تجربہ' : 'Experience', fontFamily),
              _buildArtisanSortChip(
                  'reviews', isUrdu ? 'ریویوز' : 'Reviews', fontFamily),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ArtisanProfile>>(
            stream: ArtisanService().streamArtisansPaginated(
                limit: _currentArtisanPage * _artisanPageSize),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerLoading();
              }

              final allArtisans = snapshot.data ?? [];
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;

              // Always hide the current user's own profile from the Artisans list
              var filtered = allArtisans
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
                  final matchesSkills = a.skills.any((s) => s.toLowerCase().contains(query));
                  return a.name.toLowerCase().contains(query) ||
                      a.profession.toLowerCase().contains(query) ||
                      a.description.toLowerCase().contains(query) ||
                      matchesSkills;
                }).toList();
              }

              filtered.sort((a, b) {
                final scoreA = _calculateArtisanScore(a);
                final scoreB = _calculateArtisanScore(b);

                if (scoreA != scoreB) {
                  return scoreB.compareTo(scoreA); // Higher score first
                }

                // Tie-breaker: Use the user selected sort criteria
                if (_artisanSortBy == 'distance') {
                  final distA =
                      _calculateDistance(a.latitude, a.longitude) ?? 9999.0;
                  final distB =
                      _calculateDistance(b.latitude, b.longitude) ?? 9999.0;
                  return distA.compareTo(distB);
                }

                switch (_artisanSortBy) {
                  case 'experience':
                    return b.experience.compareTo(a.experience);
                  case 'reviews':
                    return b.totalReviews.compareTo(a.totalReviews);
                  case 'rating':
                  default:
                    return b.rating.compareTo(a.rating);
                }
              });

              if (filtered.isEmpty) {
                return _buildArtisanEmptyState(isUrdu, fontFamily);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length +
                    (filtered.length >= _currentArtisanPage * _artisanPageSize
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  if (index == filtered.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentArtisanPage++;
                            });
                          },
                          icon: Icon(PhosphorIcons.plus(), size: 18),
                          label: Text(
                            isUrdu ? 'مزید لوڈ کریں' : 'Load More',
                            style: TextStyle(
                                fontFamily: fontFamily,
                                fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.themeColor,
                            backgroundColor:
                                AppTheme.themeColor.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    );
                  }

                  final artisan = filtered[index];
                  final distance =
                      _calculateDistance(artisan.latitude, artisan.longitude);

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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtisanSortChip(String value, String label, String fontFamily) {
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

  Widget _buildArtisanEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.magnifyingGlass(),
              size: 64, color: Colors.grey[300]),
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
