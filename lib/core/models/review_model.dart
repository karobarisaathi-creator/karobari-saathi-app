import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String itemId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime timestamp;

  Review({
    required this.id,
    required this.itemId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      return DateTime.tryParse(d?.toString() ?? '') ?? DateTime.now();
    }
    
    return Review(
      id: map['id']?.toString() ?? '',
      itemId: map['itemId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? 'Anonymous',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment']?.toString() ?? '',
      timestamp: parseDate(map['timestamp']),
    );
  }
}
