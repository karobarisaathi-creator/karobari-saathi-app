import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'job_post_model.g.dart';

@HiveType(typeId: 31)
class JobPost extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String customerId;

  @HiveField(2)
  final String customerName;

  @HiveField(3)
  final String customerPhone;

  @HiveField(4)
  final String title;

  @HiveField(5)
  final String description;

  @HiveField(6)
  final String location;

  @HiveField(7)
  final String category;

  @HiveField(8)
  final double? estimatedBudget;

  @HiveField(9)
  final DateTime deadline;

  @HiveField(10)
  final List<String> images;

  @HiveField(11)
  final String status;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final String? selectedBidId;

  @HiveField(14)
  final int bidCount;

  @HiveField(15)
  final String? customerPhotoUrl;

  JobPost({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerPhotoUrl,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    this.estimatedBudget,
    required this.deadline,
    this.images = const [],
    this.status = 'open',
    required this.createdAt,
    this.selectedBidId,
    this.bidCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerPhotoUrl': customerPhotoUrl,
      'title': title,
      'description': description,
      'location': location,
      'category': category,
      'estimatedBudget': estimatedBudget,
      'deadline': deadline.toIso8601String(),
      'images': images,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'selectedBidId': selectedBidId,
      'bidCount': bidCount,
    };
  }

  factory JobPost.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return JobPost(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerPhotoUrl: map['customerPhotoUrl'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      category: map['category'] ?? '',
      estimatedBudget: (map['estimatedBudget'] as num?)?.toDouble(),
      deadline: parseDate(map['deadline']),
      images: List<String>.from(map['images'] ?? []),
      status: map['status'] ?? 'open',
      createdAt: parseDate(map['createdAt']),
      selectedBidId: map['selectedBidId'],
      bidCount: (map['bidCount'] as num?)?.toInt() ?? 0,
    );
  }
}
