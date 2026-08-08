// lib/features/artisans/screens/artisan_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/widgets/artisan_card.dart';
import 'package:account_app/core/widgets/artisan_filter_bar.dart';
import 'artisan_profile_screen.dart';
import 'artisan_detail_screen.dart';

class ArtisanHomeScreen extends StatefulWidget {
  const ArtisanHomeScreen({super.key});

  @override
  State<ArtisanHomeScreen> createState() => _ArtisanHomeScreenState();
}

class _ArtisanHomeScreenState extends State<ArtisanHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedProfession = 'all';
  String _sortBy = 'rating';
  List<ArtisanProfile> _artisans = [];
  ArtisanProfile? _myArtisanProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtisans();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final service = ArtisanService();
    final profile = await service.getProfile(user.uid);
    if (mounted) {
      setState(() {
        _myArtisanProfile = profile;
      });
    }
  }

  Future<void> _toggleMyAvailability(String status) async {
    if (_myArtisanProfile == null) return;
    final updated = _myArtisanProfile!.copyWith(availability: status);
    final service = ArtisanService();
    await service.saveProfile(updated);
    setState(() {
      _myArtisanProfile = updated;
    });
  }

  Future<void> _loadArtisans() async {
    setState(() => _isLoading = true);
    try {
      final service = ArtisanService();
      final all = await service.getAllArtisans();
      if (mounted) {
        setState(() {
          _artisans = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading artisans: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ArtisanProfile> get _filteredArtisans {
    // Start with dummy data so something is always visible
    var filtered = [
      ArtisanProfile(
        id: 'dummy_1',
        name: 'محمد زکریا',
        profession: 'electrician',
        professionUrdu: 'الیکٹریشن',
        location: 'لاہور، پاکستان',
        experience: 5,
        rate: '800/گھنٹہ',
        availability: 'available',
        phone: '03001234567',
        profileImage: 'https://img.freepik.com/free-photo/portrait-handsome-young-man-with-crossed-arms_176420-15569.jpg',
      description: 'گھر اور دکان کی وائرنگ کا ماہر۔ ہر قسم کے بجلی کے کام کے لیے رابطہ کریں۔',
        rating: 4.8,
        totalReviews: 24,
        isVerified: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];

    // Add real artisans from database
    filtered.addAll(_artisans);

    // پیشے کے حساب سے فلٹر
    if (_selectedProfession != 'all') {
      filtered = filtered
          .where((a) => a.profession == _selectedProfession)
          .toList();
    }

    // سرچ کے حساب سے فلٹر
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        return a.name.toLowerCase().contains(query) ||
            a.profession.toLowerCase().contains(query) ||
            a.description.toLowerCase().contains(query);
      }).toList();
    }

    // ترتیب
    switch (_sortBy) {
      case 'rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'experience':
        filtered.sort((a, b) => b.experience.compareTo(a.experience));
        break;
      case 'reviews':
        filtered.sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'ماہرین کی فہرست' : 'Experts Directory',
        showBackButton: false,
        actions: [
          _buildAvailabilityToggle(isUrdu, fontFamily),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // سرچ بار
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchSortBar(
              controller: _searchController,
              hintText: isUrdu ? 'کاریگر تلاش کریں...' : 'Search artisans...',
              onSearchChanged: (value) {
                setState(() => _searchQuery = value);
              },
              showVoiceSearch: true,
            ),
          ),

          // فلٹر بار
          ArtisanFilterBar(
            selectedProfession: _selectedProfession,
            onProfessionSelected: (profession) {
              setState(() => _selectedProfession = profession);
            },
            isUrdu: isUrdu,
            fontFamily: fontFamily,
          ),

          // سورٹ آپشنز
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
                _buildSortChip('rating', isUrdu ? 'ریٹنگ' : 'Rating', fontFamily),
                _buildSortChip('experience', isUrdu ? 'تجربہ' : 'Experience', fontFamily),
                _buildSortChip('reviews', isUrdu ? 'ریویوز' : 'Reviews', fontFamily),
              ],
            ),
          ),

          // نتائج
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredArtisans.isEmpty
                    ? _buildEmptyState(isUrdu, fontFamily)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredArtisans.length,
                        itemBuilder: (context, index) {
                          final artisan = _filteredArtisans[index];
                          return ArtisanCard(
                            artisan: artisan,
                            isUrdu: isUrdu,
                            fontFamily: fontFamily,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ArtisanDetailScreen(
                                        artisanId: artisan.id,
                                        initialArtisan: artisan,
                                      ),
                                ),
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

  Widget _buildAvailabilityToggle(bool isUrdu, String fontFamily) {
    // If not an artisan, don't show the toggle or show a "Become Expert" hint
    if (_myArtisanProfile == null) return const SizedBox.shrink();

    final isAvailable = _myArtisanProfile?.availability == 'available';
    return Center(
      child: InkWell(
        onTap: () {
          _toggleMyAvailability(isAvailable ? 'busy' : 'available');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isAvailable ? Colors.green : Colors.red, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isAvailable ? (isUrdu ? 'دستیاب' : 'Available') : (isUrdu ? 'مصروف' : 'Busy'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String value, String label, String fontFamily) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
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

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
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
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? 'اپنی تلاش کی شرائط تبدیل کریں'
                : 'Try changing your search criteria',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}