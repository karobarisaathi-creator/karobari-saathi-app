// lib/features/artisans/screens/artisan_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/artisan_review_model.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';

class ArtisanReviewsScreen extends StatefulWidget {
  final String artisanId;

  const ArtisanReviewsScreen({super.key, required this.artisanId});

  @override
  State<ArtisanReviewsScreen> createState() => _ArtisanReviewsScreenState();
}

class _ArtisanReviewsScreenState extends State<ArtisanReviewsScreen> {
  final ArtisanService _service = ArtisanService();
  String _filter = 'all'; // all, 5, 4, 3, 2, 1

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'ریویوز' : 'Reviews',
      ),
      body: StreamBuilder<List<ArtisanReview>>(
        stream: _service.getReviews(widget.artisanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          var reviews = snapshot.data!;

          // فلٹر
          if (_filter != 'all') {
            final filterRating = double.parse(_filter);
            reviews = reviews.where((r) => r.rating == filterRating).toList();
          }

          return Column(
            children: [
              // فلٹر بار
              _buildFilterBar(isUrdu, fontFamily, reviews.length),

              // ریویوز کی لسٹ
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewCard(review, isUrdu, fontFamily);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(bool isUrdu, String fontFamily, int totalReviews) {
    final filters = [
      {'value': 'all', 'label': isUrdu ? 'سب' : 'All'},
      {'value': '5', 'label': '5 ★'},
      {'value': '4', 'label': '4 ★'},
      {'value': '3', 'label': '3 ★'},
      {'value': '2', 'label': '2 ★'},
      {'value': '1', 'label': '1 ★'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$totalReviews ${isUrdu ? 'ریویوز' : 'reviews'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) {
                  final isSelected = _filter == f['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f['value']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.themeColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.themeColor
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        f['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ArtisanReview review, bool isUrdu, String fontFamily) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.reviewerName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: fontFamily,
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(review.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ArtisanRatingStars(rating: review.rating, size: 16),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontFamily: fontFamily,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.chatText(), size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی ریویو نہیں ملا' : 'No reviews yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? 'ابھی تک کسی نے ریویو نہیں دیا'
                : 'Be the first to review this artisan',
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