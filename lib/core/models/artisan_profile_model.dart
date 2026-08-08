// lib/features/artisans/models/artisan_profile_model.dart
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'artisan_profile_model.g.dart';

@HiveType(typeId: 26)
class ArtisanProfile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String profession;

  @HiveField(3)
  final String professionUrdu;

  @HiveField(4)
  final String location;

  @HiveField(5)
  final double? latitude;

  @HiveField(6)
  final double? longitude;

  @HiveField(7)
  final int experience;

  @HiveField(8)
  final String? rate;

  @HiveField(9)
  final String availability;

  @HiveField(10)
  final String phone;

  @HiveField(11)
  final bool showPhone;

  @HiveField(12)
  final String description;

  @HiveField(13)
  final String? profileImage;

  @HiveField(14)
  final List<String> workImages;

  @HiveField(15)
  final double rating;

  @HiveField(16)
  final int totalReviews;

  @HiveField(17)
  final bool isVerified;

  @HiveField(18)
  final String verificationStatus; // 'none', 'pending', 'approved', 'rejected'

  @HiveField(19)
  final bool isActive;

  @HiveField(20)
  final DateTime createdAt;

  @HiveField(21)
  final DateTime updatedAt;

  ArtisanProfile({
    required this.id,
    required this.name,
    required this.profession,
    required this.professionUrdu,
    required this.location,
    this.latitude,
    this.longitude,
    this.experience = 0,
    this.rate,
    this.availability = 'available',
    required this.phone,
    this.showPhone = true,
    required this.description,
    this.profileImage,
    this.workImages = const [],
    this.rating = 0.0,
    this.totalReviews = 0,
    this.isVerified = false,
    this.verificationStatus = 'none',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'profession': profession,
      'professionUrdu': professionUrdu,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'experience': experience,
      'rate': rate,
      'availability': availability,
      'phone': phone,
      'showPhone': showPhone,
      'description': description,
      'profileImage': profileImage,
      'workImages': workImages,
      'rating': rating,
      'totalReviews': totalReviews,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ArtisanProfile.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return ArtisanProfile(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      profession: map['profession']?.toString() ?? '',
      professionUrdu: map['professionUrdu']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      experience: (map['experience'] as num?)?.toInt() ?? 0,
      rate: map['rate']?.toString(),
      availability: map['availability']?.toString() ?? 'available',
      phone: map['phone']?.toString() ?? '',
      showPhone: map['showPhone'] ?? true,
      description: map['description']?.toString() ?? '',
      profileImage: map['profileImage']?.toString(),
      workImages: List<String>.from(map['workImages'] ?? []),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      isVerified: map['isVerified'] ?? false,
      verificationStatus: map['verificationStatus']?.toString() ?? (map['isVerified'] == true ? 'approved' : 'none'),
      isActive: map['isActive'] ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  ArtisanProfile copyWith({
    String? name,
    String? profession,
    String? professionUrdu,
    String? location,
    double? latitude,
    double? longitude,
    int? experience,
    String? rate,
    String? availability,
    String? phone,
    bool? showPhone,
    String? description,
    String? profileImage,
    List<String>? workImages,
    double? rating,
    int? totalReviews,
    bool? isVerified,
    String? verificationStatus,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return ArtisanProfile(
      id: id,
      name: name ?? this.name,
      profession: profession ?? this.profession,
      professionUrdu: professionUrdu ?? this.professionUrdu,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      experience: experience ?? this.experience,
      rate: rate ?? this.rate,
      availability: availability ?? this.availability,
      phone: phone ?? this.phone,
      showPhone: showPhone ?? this.showPhone,
      description: description ?? this.description,
      profileImage: profileImage ?? this.profileImage,
      workImages: workImages ?? this.workImages,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
