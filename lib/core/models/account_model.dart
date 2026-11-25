import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'account_model.g.dart';

@HiveType(typeId: 0)
class Account {
  static const Set<String> _workerAccountTypes = {
    'worker',
    'technician',
    'employee',
    'مزدور',
    'کاریگر/مستری',
    'ملازم',
  };

  static const Set<String> _knownAccountTypes = {
    ..._workerAccountTypes,
    'general',
    'عام',
    'customer',
    'گاہک',
    'supplier',
    'سپلائر',
    'wholesaler',
    'ہول سیلر',
    'retailer',
    'پرچون فروش',
    'farmer',
    'کاشتکار',
    'agent',
    'ایجنٹ/آڑھتی',
    'transport',
    'ٹرانسپورٹ',
    'investor',
    'سرمایہ کار',
    'business',
    'کاروباری',
    'friend',
    'دوست',
    'family',
    'فیملی',
    'other',
    'دیگر',
    'partner',
  };

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String? address;

  @HiveField(4)
  final String accountType;

  @HiveField(5)
  final double initialBalance;

  @HiveField(6)
  final String balanceType;

  @HiveField(7)
  final double balance;

  @HiveField(8, defaultValue: <String, String>{})
  final Map<String, String>? settlementNotes;

  @HiveField(10)
  final String? profileImage;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  @HiveField(13, defaultValue: true)
  final bool isActive;

  @HiveField(15)
  final String? storeName;

  @HiveField(16)
  final String? storeImage;

  @HiveField(17)
  final String? profession;

  String get category => accountType;

  bool get isWorkerAccount => isWorkerAccountType(accountType);

  static bool isWorkerAccountType(String value) =>
      _workerAccountTypes.contains(value.trim().toLowerCase());

  static bool isKnownAccountType(String value) =>
      _knownAccountTypes.contains(value.trim().toLowerCase());

  Account({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    String? category,
    String? accountType,
    required this.initialBalance,
    required this.balanceType,
    required this.balance,
    this.profileImage,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.storeName,
    this.storeImage,
    this.profession,
    this.settlementNotes = const {},
  }) : accountType = accountType ?? category ?? 'Other';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'category': accountType,
      'accountType': accountType,
      'profession': profession,
      'initialBalance': initialBalance,
      'balanceType': balanceType,
      'balance': balance,
      'settlementNotes': settlementNotes ?? const <String, String>{},
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'storeName': storeName,
      'storeImage': storeImage,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    // Helper to parse date from either String or Timestamp
    DateTime parseDate(dynamic dateVal) {
      if (dateVal == null) return DateTime.now();
      if (dateVal is Timestamp) return dateVal.toDate();
      if (dateVal is String)
        return DateTime.tryParse(dateVal) ?? DateTime.now();
      return DateTime.now();
    }

    return Account(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString(),
      accountType: map['accountType']?.toString() ??
          map['category']?.toString() ??
          'Other',
      profession: map['profession']?.toString(),
      initialBalance: (map['initialBalance'] is num)
          ? (map['initialBalance'] as num).toDouble()
          : 0.0,
      balanceType: map['balanceType']?.toString() ?? 'Receivable',
      balance:
          (map['balance'] is num) ? (map['balance'] as num).toDouble() : 0.0,
      settlementNotes: (map['settlementNotes'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString())) ??
          const {},
      profileImage: map['profileImage']?.toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      storeName: map['storeName']?.toString(),
      storeImage: map['storeImage']?.toString(),
    );
  }

  Account copyWith({
    String? name,
    String? phone,
    String? address,
    String? category,
    String? accountType,
    double? initialBalance,
    String? balanceType,
    double? balance,
    String? profileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? storeName,
    String? storeImage,
    String? profession,
    bool clearProfession = false,
    Map<String, String>? settlementNotes,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      accountType: accountType ?? category ?? this.accountType,
      initialBalance: initialBalance ?? this.initialBalance,
      balanceType: balanceType ?? this.balanceType,
      balance: balance ?? this.balance,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      storeName: storeName ?? this.storeName,
      storeImage: storeImage ?? this.storeImage,
      profession: clearProfession ? null : profession ?? this.profession,
      settlementNotes:
          settlementNotes ?? this.settlementNotes ?? const <String, String>{},
    );
  }
}
