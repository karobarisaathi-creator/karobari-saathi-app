// lib/features/artisans/models/artisan_work_order_model.dart
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'artisan_work_order_model.g.dart';

@HiveType(typeId: 27)
class ArtisanWorkOrder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String artisanId;

  @HiveField(2)
  final String customerId;

  @HiveField(3)
  final String customerName;

  @HiveField(4)
  final String customerPhone;

  @HiveField(5)
  final String workDescription;

  @HiveField(6)
  final String? workImages;

  @HiveField(7)
  final String status;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime? completedAt;

  @HiveField(10)
  final DateTime? ratedAt;

  @HiveField(11)
  final double? rating;

  @HiveField(12)
  final String? review;

  @HiveField(13)
  final double? amount;

  @HiveField(14)
  final String? location;

  @HiveField(15)
  final bool isRated;

  @HiveField(16)
  final bool customerAgreed;

  @HiveField(17)
  final bool artisanAgreed;

  @HiveField(18)
  final DateTime? agreedAt;

  @HiveField(19)
  final String? contractTerms;

  @HiveField(20)
  final String? paymentTerms;

  @HiveField(21)
  final String? cancellationPolicy;

  @HiveField(22)
  final bool customerAcceptedTerms;

  @HiveField(23)
  final bool artisanAcceptedTerms;

  @HiveField(24)
  final String? disputeStatus;

  ArtisanWorkOrder({
    required this.id,
    required this.artisanId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.workDescription,
    this.workImages,
    this.status = 'pending',
    required this.createdAt,
    this.completedAt,
    this.ratedAt,
    this.rating,
    this.review,
    this.amount,
    this.location,
    this.isRated = false,
    this.customerAgreed = false,
    this.artisanAgreed = false,
    this.agreedAt,
    this.contractTerms,
    this.paymentTerms,
    this.cancellationPolicy,
    this.customerAcceptedTerms = false,
    this.artisanAcceptedTerms = false,
    this.disputeStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artisanId': artisanId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'workDescription': workDescription,
      'workImages': workImages,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'ratedAt': ratedAt?.toIso8601String(),
      'rating': rating,
      'review': review,
      'amount': amount,
      'location': location,
      'isRated': isRated,
      'customerAgreed': customerAgreed,
      'artisanAgreed': artisanAgreed,
      'agreedAt': agreedAt?.toIso8601String(),
      'contractTerms': contractTerms,
      'paymentTerms': paymentTerms,
      'cancellationPolicy': cancellationPolicy,
      'customerAcceptedTerms': customerAcceptedTerms,
      'artisanAcceptedTerms': artisanAcceptedTerms,
      'disputeStatus': disputeStatus,
    };
  }

  factory ArtisanWorkOrder.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return ArtisanWorkOrder(
      id: map['id']?.toString() ?? '',
      artisanId: map['artisanId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerPhone: map['customerPhone']?.toString() ?? '',
      workDescription: map['workDescription']?.toString() ?? '',
      workImages: map['workImages']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      createdAt: parseDate(map['createdAt']),
      completedAt: map['completedAt'] != null ? parseDate(map['completedAt']) : null,
      ratedAt: map['ratedAt'] != null ? parseDate(map['ratedAt']) : null,
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review']?.toString(),
      amount: (map['amount'] as num?)?.toDouble(),
      location: map['location']?.toString(),
      isRated: map['isRated'] ?? false,
      customerAgreed: map['customerAgreed'] ?? false,
      artisanAgreed: map['artisanAgreed'] ?? false,
      agreedAt: map['agreedAt'] != null ? parseDate(map['agreedAt']) : null,
      contractTerms: map['contractTerms'],
      paymentTerms: map['paymentTerms'],
      cancellationPolicy: map['cancellationPolicy'],
      customerAcceptedTerms: map['customerAcceptedTerms'] ?? false,
      artisanAcceptedTerms: map['artisanAcceptedTerms'] ?? false,
      disputeStatus: map['disputeStatus'],
    );
  }
}