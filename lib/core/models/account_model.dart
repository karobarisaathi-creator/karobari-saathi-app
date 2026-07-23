import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'account_model.g.dart';

@HiveType(typeId: 0)
class Account {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String? address;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final double initialBalance;

  @HiveField(6)
  final String balanceType;

  @HiveField(7)
  final double balance;

  @HiveField(8, defaultValue: false)
  final bool isShared;

  @HiveField(9)
  final List<String> sharedWith;

  @HiveField(10)
  final String? profileImage;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  @HiveField(13, defaultValue: true)
  final bool isActive;

  @HiveField(14, defaultValue: false)
  final bool isVerified;

  @HiveField(15)
  final String? storeName;

  @HiveField(16)
  final String? storeImage;

  Account({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    required this.category,
    required this.initialBalance,
    required this.balanceType,
    required this.balance,
    this.isShared = false,
    this.sharedWith = const [],
    this.profileImage,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.isVerified = false,
    this.storeName,
    this.storeImage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'category': category,
      'initialBalance': initialBalance,
      'balanceType': balanceType,
      'balance': balance,
      'isShared': isShared,
      'sharedWith': sharedWith,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'isVerified': isVerified,
      'storeName': storeName,
      'storeImage': storeImage,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    // Helper to parse date from either String or Timestamp
    DateTime parseDate(dynamic dateVal) {
      if (dateVal == null) return DateTime.now();
      if (dateVal is Timestamp) return dateVal.toDate();
      if (dateVal is String) return DateTime.tryParse(dateVal) ?? DateTime.now();
      return DateTime.now();
    }

    return Account(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString(),
      category: map['category']?.toString() ?? 'Other',
      initialBalance: (map['initialBalance'] is num) ? (map['initialBalance'] as num).toDouble() : 0.0,
      balanceType: map['balanceType']?.toString() ?? 'Receivable',
      balance: (map['balance'] is num) ? (map['balance'] as num).toDouble() : 0.0,
      isShared: map['isShared'] ?? false,
      sharedWith: List<String>.from(map['sharedWith'] ?? []),
      profileImage: map['profileImage']?.toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      isVerified: map['isVerified'] ?? false,
      storeName: map['storeName']?.toString(),
      storeImage: map['storeImage']?.toString(),
    );
  }

  Account copyWith({
    String? name,
    String? phone,
    String? address,
    String? category,
    double? initialBalance,
    String? balanceType,
    double? balance,
    bool? isShared,
    List<String>? sharedWith,
    String? profileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isVerified,
    String? storeName,
    String? storeImage,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      category: category ?? this.category,
      initialBalance: initialBalance ?? this.initialBalance,
      balanceType: balanceType ?? this.balanceType,
      balance: balance ?? this.balance,
      isShared: isShared ?? this.isShared,
      sharedWith: sharedWith ?? this.sharedWith,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      storeName: storeName ?? this.storeName,
      storeImage: storeImage ?? this.storeImage,
    );
  }
}
