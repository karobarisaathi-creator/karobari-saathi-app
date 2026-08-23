// lib/features/artisans/widgets/artisan_rating_stars.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';

class ArtisanRatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;

  const ArtisanRatingStars({
    super.key,
    required this.rating,
    this.size = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? AppTheme.darkColor;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starValue = index + 1;
          final isFullStar = rating >= starValue;
          final isPartialStar = rating > index && rating < starValue;

          IconData icon;
          if (isFullStar) {
            icon = PhosphorIcons.star(PhosphorIconsStyle.fill);
          } else if (isPartialStar) {
            icon = PhosphorIcons.starHalf(PhosphorIconsStyle.fill);
          } else {
            icon = PhosphorIcons.star();
          }

          return Icon(
            icon,
            size: size,
            color: starColor,
          );
        }),
      ),
    );
  }
}