import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'job_bid_model.g.dart';

@HiveType(typeId: 32)
class JobBid extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String jobId;

  @HiveField(2)
  final String artisanId;

  @HiveField(3)
  final String artisanName;

  @HiveField(4)
  final String artisanPhone;

  @HiveField(5)
  final double amount;

  @HiveField(6)
  final String message;

  @HiveField(7)
  final int estimatedDays;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final String status;

  @HiveField(10)
  final double artisanRating;

  @HiveField(11)
  final int artisanExperience;

  @HiveField(12)
  final String? proposedScope;

  @HiveField(13)
  final String? artisanPhotoUrl;

  JobBid({
    required this.id,
    required this.jobId,
    required this.artisanId,
    required this.artisanName,
    required this.artisanPhone,
    required this.amount,
    required this.message,
    required this.estimatedDays,
    required this.createdAt,
    this.status = 'pending',
    this.artisanRating = 0.0,
    this.artisanExperience = 0,
    this.proposedScope,
    this.artisanPhotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'artisanId': artisanId,
      'artisanName': artisanName,
      'artisanPhone': artisanPhone,
      'amount': amount,
      'message': message,
      'estimatedDays': estimatedDays,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'artisanRating': artisanRating,
      'artisanExperience': artisanExperience,
      'proposedScope': proposedScope,
      'artisanPhotoUrl': artisanPhotoUrl,
    };
  }

  factory JobBid.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return JobBid(
      id: map['id'] ?? '',
      jobId: map['jobId'] ?? '',
      artisanId: map['artisanId'] ?? '',
      artisanName: map['artisanName'] ?? '',
      artisanPhone: map['artisanPhone'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      message: map['message'] ?? '',
      estimatedDays: (map['estimatedDays'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['createdAt']),
      status: map['status'] ?? 'pending',
      artisanRating: (map['artisanRating'] as num?)?.toDouble() ?? 0.0,
      artisanExperience: (map['artisanExperience'] as num?)?.toInt() ?? 0,
      proposedScope: map['proposedScope'],
      artisanPhotoUrl: map['artisanPhotoUrl'],
    );
  }

  JobBid copyWith({
    String? id,
    String? jobId,
    String? artisanId,
    String? artisanName,
    String? artisanPhone,
    double? amount,
    String? message,
    int? estimatedDays,
    DateTime? createdAt,
    String? status,
    double? artisanRating,
    int? artisanExperience,
    String? proposedScope,
    String? artisanPhotoUrl,
  }) {
    return JobBid(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      artisanId: artisanId ?? this.artisanId,
      artisanName: artisanName ?? this.artisanName,
      artisanPhone: artisanPhone ?? this.artisanPhone,
      amount: amount ?? this.amount,
      message: message ?? this.message,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      artisanRating: artisanRating ?? this.artisanRating,
      artisanExperience: artisanExperience ?? this.artisanExperience,
      proposedScope: proposedScope ?? this.proposedScope,
      artisanPhotoUrl: artisanPhotoUrl ?? this.artisanPhotoUrl,
    );
  }
}
