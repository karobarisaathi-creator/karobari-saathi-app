// lib/features/artisans/widgets/artisan_card.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'artisan_rating_stars.dart';

import 'package:account_app/core/widgets/profile_info_widget.dart';

class ArtisanCard extends StatelessWidget {
  final ArtisanProfile artisan;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onTap;

  const ArtisanCard({
    super.key,
    required this.artisan,
    required this.isUrdu,
    required this.fontFamily,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.themeColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            ProfileInfoWidget(
              name: artisan.name,
              phone: '', // Phone removed from card as requested
              profileImage: artisan.profileImage,
              category: artisan.professionUrdu,
              address: artisan.location,
              isVerified: artisan.isVerified || artisan.verificationStatus == 'approved',
              customSize: 70,
              isVerticalCategory: true, // Shows profession clearly under name
              suffix: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: artisan.availability == 'available'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: artisan.availability == 'available'
                        ? Colors.green
                        : Colors.red,
                    width: 1,
                  ),
                ),
                child: Text(
                  artisan.availability == 'available'
                      ? (isUrdu ? 'دستیاب' : 'Available')
                      : (isUrdu ? 'مصروف' : 'Busy'),
                  style: TextStyle(
                    fontSize: 10,
                    color: artisan.availability == 'available'
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ),
            const Divider(height: 16, thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ArtisanRatingStars(
                      rating: artisan.rating,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${artisan.rating}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${artisan.totalReviews} ${isUrdu ? 'ریویوز' : 'Reviews'})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
                Icon(PhosphorIcons.caretRight(), size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
