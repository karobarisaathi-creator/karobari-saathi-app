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

class ArtisansTab extends StatefulWidget {
  final String selectedProfession;
  const ArtisansTab({super.key, required this.selectedProfession});

  @override
  State<ArtisansTab> createState() => _ArtisansTabState();
}

class _ArtisansTabState extends State<ArtisansTab> {
  final TextEditingController _artisanSearchController =
      TextEditingController();
  String _artisanSearchQuery = '';
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
    _artisanSearchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchSortBar(
            controller: _artisanSearchController,
            padding: EdgeInsets.zero,
            hintText: isUrdu ? 'کاریگر تلاش کریں...' : 'Search artisans...',
            onSearchChanged: (value) {
              setState(() => _artisanSearchQuery = value);
            },
            showVoiceSearch: true,
          ),
        ),
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
                return const Center(child: CircularProgressIndicator());
              }

              final allArtisans = snapshot.data ?? [];
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              
              // Always hide the current user's own profile from the Artisans list
              var filtered = allArtisans.where((a) => a.id != currentUserId).toList();

              if (widget.selectedProfession != 'all') {
                filtered = filtered
                    .where((a) => a.profession == widget.selectedProfession)
                    .toList();
              }

              if (_artisanSearchQuery.isNotEmpty) {
                final query = _artisanSearchQuery.toLowerCase();
                filtered = filtered.where((a) {
                  return a.name.toLowerCase().contains(query) ||
                      a.profession.toLowerCase().contains(query) ||
                      a.description.toLowerCase().contains(query);
                }).toList();
              }

              switch (_artisanSortBy) {
                case 'rating':
                  filtered.sort((a, b) => b.rating.compareTo(a.rating));
                  break;
                case 'experience':
                  filtered.sort((a, b) => b.experience.compareTo(a.experience));
                  break;
                case 'reviews':
                  filtered
                      .sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
                  break;
              }

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
}
