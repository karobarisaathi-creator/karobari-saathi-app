import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'shared_account_model.g.dart';

@HiveType(typeId: 7)
class SharedAccount {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String accountId;

  @HiveField(2)
  final String ownerId;

  @HiveField(3)
  final String sharedWith;

  @HiveField(4)
  final String sharedWithPhone;

  @HiveField(5)
  final List<String> permissions;

  @HiveField(6)
  final DateTime sharedAt;

  @HiveField(7)
  final bool isActive;

  @HiveField(8)
  final String? accountName;

  @HiveField(9)
  final double? currentBalance;

  @HiveField(10)
  final DateTime? lastViewedAt; // New field for seen status

  @HiveField(11)
  final String? photoUrl;

  SharedAccount({
    required this.id,
    required this.accountId,
    required this.ownerId,
    required this.sharedWith,
    required this.sharedWithPhone,
    required this.permissions,
    required this.sharedAt,
    required this.isActive,
    this.accountName,
    this.currentBalance,
    this.lastViewedAt,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'ownerId': ownerId,
      'sharedWith': sharedWith,
      'sharedWithPhone': sharedWithPhone,
      'permissions': permissions,
      'sharedAt': Timestamp.fromDate(sharedAt), // Use Timestamp
      'isActive': isActive,
      'accountName': accountName,
      'currentBalance': currentBalance,
      'lastViewedAt': lastViewedAt != null ? Timestamp.fromDate(lastViewedAt!) : null,
      'photoUrl': photoUrl,
    };
  }

  factory SharedAccount.fromMap(Map<String, dynamic> map) {
    return SharedAccount(
      id: map['id'],
      accountId: map['accountId'],
      ownerId: map['ownerId'],
      sharedWith: map['sharedWith'],
      sharedWithPhone: map['sharedWithPhone'],
      permissions: List<String>.from(map['permissions']),
      sharedAt: _parseTimestamp(map['sharedAt']),
      isActive: map['isActive'],
      accountName: map['accountName'],
      currentBalance: map['currentBalance'],
      lastViewedAt: _parseTimestampNullable(map['lastViewedAt']),
      photoUrl: map['photoUrl'],
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now(); // Fallback
  }

  static DateTime? _parseTimestampNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  SharedAccount copyWith({
    String? id,
    String? accountId,
    String? ownerId,
    String? sharedWith,
    String? sharedWithPhone,
    List<String>? permissions,
    DateTime? sharedAt,
    bool? isActive,
    String? accountName,
    double? currentBalance,
    DateTime? lastViewedAt,
    String? photoUrl,
  }) {
    return SharedAccount(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      ownerId: ownerId ?? this.ownerId,
      sharedWith: sharedWith ?? this.sharedWith,
      sharedWithPhone: sharedWithPhone ?? this.sharedWithPhone,
      permissions: permissions ?? this.permissions,
      sharedAt: sharedAt ?? this.sharedAt,
      isActive: isActive ?? this.isActive,
      accountName: accountName ?? this.accountName,
      currentBalance: currentBalance ?? this.currentBalance,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  // Helper methods
  bool get canView => permissions.contains('view');
  bool get canEdit => permissions.contains('edit');
  bool get canDelete => permissions.contains('delete');
  bool get canChat => permissions.contains('chat');

  String getPermissionText(bool isUrdu) {
    if (permissions.contains('edit')) return isUrdu ? 'مکمل رسائی' : 'Full Access';
    if (permissions.contains('view')) return isUrdu ? 'صرف دیکھیں' : 'View Only';
    return isUrdu ? 'محدود رسائی' : 'Limited Access';
  }

  String getStatusText(bool isUrdu) => isActive 
      ? (isUrdu ? 'فعال' : 'Active') 
      : (isUrdu ? 'منقطع' : 'Disconnected');

  String getFormattedSharedDate(bool isUrdu) {
    final now = DateTime.now();
    final difference = now.difference(sharedAt);

    if (difference.inDays < 1) return isUrdu ? 'آج' : 'Today';
    if (difference.inDays < 7) {
      return isUrdu 
          ? '${difference.inDays} دن پہلے' 
          : '${difference.inDays}d ago';
    }
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return isUrdu 
          ? '$weeks ہفتے پہلے' 
          : '${weeks}w ago';
    }
    final months = (difference.inDays / 30).floor();
    return isUrdu 
        ? '$months مہینے پہلے' 
        : '${months}mo ago';
  }
}
