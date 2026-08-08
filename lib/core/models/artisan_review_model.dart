// lib/features/artisans/models/artisan_review_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ArtisanReview {
  final String id;
  final String artisanId;
  final String reviewerId;
  final String reviewerName;
  final double rating;
  final String comment;
  final DateTime timestamp;

  ArtisanReview({
    required this.id,
    required this.artisanId,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artisanId': artisanId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ArtisanReview.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return ArtisanReview(
      id: map['id']?.toString() ?? '',
      artisanId: map['artisanId']?.toString() ?? '',
      reviewerId: map['reviewerId']?.toString() ?? '',
      reviewerName: map['reviewerName']?.toString() ?? 'Anonymous',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment']?.toString() ?? '',
      timestamp: parseDate(map['timestamp']),
    );
  }
}