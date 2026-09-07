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
  final List<String> categories;

  @HiveField(8)
  final double? estimatedBudget;

  @HiveField(10)
  final List<String> images;

  @HiveField(11)
  final String status;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(15)
  final String? customerPhotoUrl;

  @HiveField(16)
  final List<String> clarifications;

  @HiveField(17)
  final String? detailedScope;

  @HiveField(18)
  final String? scopeOfWork;

  @HiveField(19)
  final String? exclusions;

  @HiveField(20)
  final bool? isComplex;

  @HiveField(21)
  final int? estimatedDays;

  @HiveField(28)
  final String? budgetUnit; // 'total', 'monthly', 'hourly'

  @HiveField(29)
  final String? durationUnit; // 'hours', 'days', 'weeks', 'months'

  @HiveField(22)
  final bool? requiresHeightWork;

  @HiveField(23)
  final bool? requiresSpecialTools;

  @HiveField(24)
  final double? latitude;

  @HiveField(25)
  final double? longitude;

  @HiveField(26)
  final String? timeIn;

  @HiveField(27)
  final String? timeOut;

  @HiveField(30)
  final String? website;

  @HiveField(31)
  final String? companyName;

  JobPost({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerPhotoUrl,
    required this.title,
    required this.description,
    required this.location,
    required this.categories,
    this.estimatedBudget,
    this.images = const [],
    this.status = 'open',
    required this.createdAt,
    this.clarifications = const [],
    this.detailedScope,
    this.scopeOfWork,
    this.exclusions,
    this.isComplex,
    this.estimatedDays,
    this.budgetUnit,
    this.durationUnit,
    this.requiresHeightWork,
    this.requiresSpecialTools,
    this.latitude,
    this.longitude,
    this.timeIn,
    this.timeOut,
    this.website,
    this.companyName,
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
      'categories': categories,
      'estimatedBudget': estimatedBudget,
      'images': images,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'clarifications': clarifications,
      'detailedScope': detailedScope,
      'scopeOfWork': scopeOfWork,
      'exclusions': exclusions,
      'isComplex': isComplex,
      'estimatedDays': estimatedDays,
      'budgetUnit': budgetUnit,
      'durationUnit': durationUnit,
      'requiresHeightWork': requiresHeightWork,
      'requiresSpecialTools': requiresSpecialTools,
      'latitude': latitude,
      'longitude': longitude,
      'timeIn': timeIn,
      'timeOut': timeOut,
      'website': website,
      'companyName': companyName,
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
      categories: map['categories'] != null
          ? List<String>.from(map['categories'])
          : (map['category'] != null ? [map['category']] : []),
      estimatedBudget: (map['estimatedBudget'] as num?)?.toDouble(),
      images: List<String>.from(map['images'] ?? []),
      status: map['status'] ?? 'open',
      createdAt: parseDate(map['createdAt']),
      clarifications: List<String>.from(map['clarifications'] ?? []),
      detailedScope: map['detailedScope'],
      scopeOfWork: map['scopeOfWork'],
      exclusions: map['exclusions'],
      isComplex: map['isComplex'],
      estimatedDays: (map['estimatedDays'] as num?)?.toInt(),
      budgetUnit: map['budgetUnit'],
      durationUnit: map['durationUnit'],
      requiresHeightWork: map['requiresHeightWork'],
      requiresSpecialTools: map['requiresSpecialTools'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      timeIn: map['timeIn'],
      timeOut: map['timeOut'],
      website: map['website'],
      companyName: map['companyName'],
    );
  }

  JobPost copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerPhotoUrl,
    String? title,
    String? description,
    String? location,
    List<String>? categories,
    double? estimatedBudget,
    List<String>? images,
    String? status,
    DateTime? createdAt,
    List<String>? clarifications,
    String? detailedScope,
    String? scopeOfWork,
    String? exclusions,
    bool? isComplex,
    int? estimatedDays,
    String? budgetUnit,
    String? durationUnit,
    bool? requiresHeightWork,
    bool? requiresSpecialTools,
    double? latitude,
    double? longitude,
    String? timeIn,
    String? timeOut,
    String? website,
    String? companyName,
  }) {
    return JobPost(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerPhotoUrl: customerPhotoUrl ?? this.customerPhotoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      categories: categories ?? this.categories,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      images: images ?? this.images,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      clarifications: clarifications ?? this.clarifications,
      detailedScope: detailedScope ?? this.detailedScope,
      scopeOfWork: scopeOfWork ?? this.scopeOfWork,
      exclusions: exclusions ?? this.exclusions,
      isComplex: isComplex ?? this.isComplex,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      budgetUnit: budgetUnit ?? this.budgetUnit,
      durationUnit: durationUnit ?? this.durationUnit,
      requiresHeightWork: requiresHeightWork ?? this.requiresHeightWork,
      requiresSpecialTools: requiresSpecialTools ?? this.requiresSpecialTools,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
      website: website ?? this.website,
      companyName: companyName ?? this.companyName,
    );
  }
}
