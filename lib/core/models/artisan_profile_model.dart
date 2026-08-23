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

  @HiveField(26)
  final String? rateUnit; // 'hour', 'day', 'fixed', 'month'

  @HiveField(9)
  final String availability;

  @HiveField(27)
  final String? qualification;

  @HiveField(10)
  final String phone;

  @HiveField(11)
  final bool showPhone;

  @HiveField(22)
  final bool showWhatsApp;

  @HiveField(23)
  final int workCount;

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

  @HiveField(24)
  final List<String> skills;

  @HiveField(25)
  final List<String> skillsUrdu;

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
    this.rateUnit,
    this.availability = 'available',
    this.qualification,
    required this.phone,
    this.showPhone = true,
    this.showWhatsApp = true,
    this.workCount = 0,
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
    this.skills = const [],
    this.skillsUrdu = const [],
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
      'rateUnit': rateUnit,
      'availability': availability,
      'qualification': qualification,
      'phone': phone,
      'showPhone': showPhone,
      'showWhatsApp': showWhatsApp,
      'workCount': workCount,
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
      'skills': skills,
      'skillsUrdu': skillsUrdu,
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
      rateUnit: map['rateUnit']?.toString(),
      availability: map['availability']?.toString() ?? 'available',
      qualification: map['qualification']?.toString(),
      phone: map['phone']?.toString() ?? '',
      showPhone: map['showPhone'] ?? true,
      showWhatsApp: map['showWhatsApp'] ?? true,
      workCount: (map['workCount'] as num?)?.toInt() ?? 0,
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
      skills: List<String>.from(map['skills'] ?? []),
      skillsUrdu: List<String>.from(map['skillsUrdu'] ?? []),
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
    String? rateUnit,
    String? availability,
    String? qualification,
    String? phone,
    bool? showPhone,
    bool? showWhatsApp,
    int? workCount,
    String? description,
    String? profileImage,
    List<String>? workImages,
    double? rating,
    int? totalReviews,
    bool? isVerified,
    String? verificationStatus,
    bool? isActive,
    DateTime? updatedAt,
    List<String>? skills,
    List<String>? skillsUrdu,
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
      rateUnit: rateUnit ?? this.rateUnit,
      availability: availability ?? this.availability,
      qualification: qualification ?? this.qualification,
      phone: phone ?? this.phone,
      showPhone: showPhone ?? this.showPhone,
      showWhatsApp: showWhatsApp ?? this.showWhatsApp,
      workCount: workCount ?? this.workCount,
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
      skills: skills ?? this.skills,
      skillsUrdu: skillsUrdu ?? this.skillsUrdu,
    );
  }
}
