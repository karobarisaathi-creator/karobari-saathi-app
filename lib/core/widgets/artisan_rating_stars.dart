// lib/features/artisans/widgets/artisan_rating_stars.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';

class ArtisanRatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;
  final bool showRatingValue;
  final int? totalReviews;

  const ArtisanRatingStars({
    super.key,
    required this.rating,
    this.size = 14,
    this.color,
    this.showRatingValue = false,
    this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? AppTheme.darkColor;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final icon = _getStarIcon(starValue);
              return Icon(
                icon,
                size: size,
                color: starColor,
              );
            }),
          ),
          if (showRatingValue) ...[
            const SizedBox(width: 6),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: starColor,
              ),
            ),
            if (totalReviews != null) ...[
              const SizedBox(width: 2),
              Text(
                '($totalReviews)',
                style: TextStyle(
                  fontSize: size - 2,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getStarIcon(int starValue) {
    if (rating >= starValue) {
      return PhosphorIcons.star(PhosphorIconsStyle.fill);
    } else if (rating >= starValue - 0.5) {
      // Half star for values like 4.5
      return PhosphorIcons.starHalf(PhosphorIconsStyle.fill);
    } else {
      return PhosphorIcons.star();
    }
  }
}
