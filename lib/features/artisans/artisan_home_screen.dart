// lib/features/artisans/screens/artisan_home_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
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
import 'package:geolocator/geolocator.dart';
import 'artisan_profile_screen.dart';
import 'artisan_detail_screen.dart';
import 'customer_orders_screen.dart';

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
  StreamSubscription<ArtisanProfile?>? _artisanSub;
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtisans();
    _setupArtisanListener();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _artisanSub?.cancel();
    super.dispose();
  }

  void _setupArtisanListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final service = ArtisanService();
    _artisanSub = service.streamProfile(user.uid).listen((profile) {
      if (mounted) {
        setState(() {
          _myArtisanProfile = profile;
        });
      }
    });
  }

  Future<void> _toggleMyAvailability() async {
    if (_myArtisanProfile == null) return;
    
    final newStatus = _myArtisanProfile!.availability == 'available' ? 'busy' : 'available';
    final updated = _myArtisanProfile!.copyWith(
      availability: newStatus,
      updatedAt: DateTime.now(),
    );
    
    final service = ArtisanService();
    try {
      await service.saveProfile(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  double? _calculateDistance(double? lat, double? lng) {
    if (_currentPosition == null || lat == null || lng == null) return null;
    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
    return distanceInMeters / 1000; // Convert to KM
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

  void _showAllProfessionsPicker(bool isUrdu, String fontFamily) {
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
                  itemCount: groupedProfessions.keys.length + 1, // Added 1 for "All"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Special "All Professions" Option
                      final isSelected = _selectedProfession == 'all';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              _onProfessionSelected('all');
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.themeColor.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppTheme.themeColor : Colors.grey[200]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(PhosphorIcons.circlesThree(), color: isSelected ? AppTheme.themeColor : Colors.grey[700], size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    isUrdu ? 'تمام پیشے (All)' : 'All Professions',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: fontFamily,
                                      color: isSelected ? AppTheme.themeColor : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    }

                    final categoryIndex = index - 1;
                    final category = groupedProfessions.keys.elementAt(categoryIndex);
                    final categoryItems = groupedProfessions[category]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.themeColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemCount: categoryItems.length,
                          itemBuilder: (context, idx) {
                            final p = categoryItems[idx];
                            final isSelected = _selectedProfession == p['id'];
                            return InkWell(
                              onTap: () {
                                _onProfessionSelected(p['id']!);
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.themeColor.withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.themeColor : Colors.grey[200]!,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(p['icon'], color: isSelected ? AppTheme.themeColor : Colors.grey[700], size: 28),
                                    const SizedBox(height: 8),
                                    Text(
                                      isUrdu ? p['name']! : p['id']!,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontFamily: fontFamily,
                                        color: isSelected ? AppTheme.themeColor : Colors.black87,
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

  void _onProfessionSelected(String id) {
    setState(() => _selectedProfession = id);
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
          IconButton(
            icon: Icon(PhosphorIcons.clockCounterClockwise(), color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomerOrdersScreen()),
              );
            },
            tooltip: isUrdu ? 'تاریخچہ' : 'History',
          ),
          _buildAvailabilityToggle(isUrdu, fontFamily),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // سرچ بار
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SearchSortBar(
                    controller: _searchController,
                    padding: EdgeInsets.zero,
                    hintText: isUrdu ? 'کاریگر تلاش کریں...' : 'Search artisans...',
                    onSearchChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    showVoiceSearch: true,
                  ),
                ),
                const SizedBox(width: 8),
                _buildProfessionPickerButton(isUrdu, fontFamily),
              ],
            ),
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
            child: StreamBuilder<List<ArtisanProfile>>(
              stream: ArtisanService().streamAllArtisans(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      isUrdu ? 'ڈیٹا لوڈ کرنے میں غلطی ہوئی' : 'Error loading data',
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                  );
                }

                final allArtisans = snapshot.data ?? [];
                
                // Filtering logic
                var filtered = List<ArtisanProfile>.from(allArtisans);

                if (_selectedProfession != 'all') {
                  filtered = filtered.where((a) => a.profession == _selectedProfession).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filtered = filtered.where((a) {
                    return a.name.toLowerCase().contains(query) ||
                        a.profession.toLowerCase().contains(query) ||
                        a.description.toLowerCase().contains(query);
                  }).toList();
                }

                // Sorting logic
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

                // Ensure current user is at the top
                final myId = FirebaseAuth.instance.currentUser?.uid;
                if (myId != null) {
                  final myIndex = filtered.indexWhere((a) => a.id == myId);
                  if (myIndex != -1) {
                    final myProfile = filtered.removeAt(myIndex);
                    filtered.insert(0, myProfile);
                  }
                }

                if (filtered.isEmpty) {
                  return _buildEmptyState(isUrdu, fontFamily);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final artisan = filtered[index];
                    final distance = _calculateDistance(artisan.latitude, artisan.longitude);
                    final isMe = artisan.id == myId;

                    return Stack(
                      children: [
                        ArtisanCard(
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
                        ),
                        if (isMe)
                          Positioned.directional(
                            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                            top: 0,
                            end: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.themeColor,
                                borderRadius: BorderRadius.only(
                                  topRight: isUrdu ? Radius.zero : const Radius.circular(16),
                                  bottomLeft: isUrdu ? Radius.zero : const Radius.circular(16),
                                  topLeft: isUrdu ? const Radius.circular(16) : Radius.zero,
                                  bottomRight: isUrdu ? const Radius.circular(16) : Radius.zero,
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
                                ],
                              ),
                              child: Text(
                                isUrdu ? 'میرا پروفائل' : 'My Profile',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
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
    if (_myArtisanProfile == null) return const SizedBox.shrink();

    final isAvailable = _myArtisanProfile?.availability == 'available';
    final color = isAvailable ? Colors.greenAccent : AppTheme.expenseColor;
    final label = isAvailable 
        ? (isUrdu ? 'دستیاب' : 'Available') 
        : (isUrdu ? 'مصروف' : 'Busy');

    return Center(
      child: InkWell(
        onTap: _toggleMyAvailability,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.5), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
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

  Widget _buildProfessionPickerButton(bool isUrdu, String fontFamily) {
    String professionName = isUrdu ? 'سب' : 'All';
    if (_selectedProfession != 'all') {
      final professions = ArtisanService.getProfessions();
      final found = professions.firstWhere(
        (p) => p['id'] == _selectedProfession,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        professionName = isUrdu ? found['name'] : found['id'];
      }
    }

    return GestureDetector(
      onTap: () => _showAllProfessionsPicker(isUrdu, fontFamily),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.darkColor.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              professionName,
              style: TextStyle(
                color: AppTheme.themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(width: 4),
            Icon(PhosphorIcons.caretDown(), size: 14, color: AppTheme.themeColor),
          ],
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