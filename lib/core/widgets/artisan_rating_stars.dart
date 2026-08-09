// lib/features/artisans/widgets/artisan_rating_stars.dart
import 'package:flutter/material.dart';

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
    final starColor = color ?? Colors.amber;

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
            icon = Icons.star_rounded;
          } else if (isPartialStar) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
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