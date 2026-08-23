import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'artisan_detail_screen.dart';

class FavoriteArtisansScreen extends StatelessWidget {
  const FavoriteArtisansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final artisanService = ArtisanService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'پسندیدہ کاریگر' : 'Favorite Artisans',
      ),
      body: StreamBuilder<List<String>>(
        stream: artisanService.getFavoriteArtisanIds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final favoriteIds = snapshot.data ?? [];

          if (favoriteIds.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favoriteIds.length,
            itemBuilder: (context, index) {
              return FutureBuilder<ArtisanProfile?>(
                future: artisanService.getProfile(favoriteIds[index]),
                builder: (context, artisanSnapshot) {
                  if (!artisanSnapshot.hasData) return const SizedBox.shrink();
                  final artisan = artisanSnapshot.data!;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArtisanDetailScreen(
                              artisanId: artisan.id,
                              initialArtisan: artisan,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: ProfileInfoWidget(
                                name: artisan.name,
                                phone: '',
                                profileImage: artisan.profileImage,
                                category: artisan.professionUrdu,
                                isVerticalCategory: true,
                                isVerified: artisan.isVerified,
                                isFavorite: true,
                                customSize: 50,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.heartBreak(),
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی پسندیدہ کاریگر نہیں ملا' : 'No favorite artisans found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? 'بہترین کاریگروں کو اپنی لسٹ میں شامل کریں'
                : 'Save your favorite artisans here',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
