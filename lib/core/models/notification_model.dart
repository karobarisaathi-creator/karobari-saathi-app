import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 5)
class AppNotification {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String message;

  @HiveField(3)
  final NotificationType type;

  @HiveField(4)
  bool isRead;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final Map<String, dynamic>? data;

  @HiveField(7)
  final String? relatedAccountId;

  @HiveField(8)
  final String? relatedTransactionId;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.timestamp,
    this.data,
    this.relatedAccountId,
    this.relatedTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.toString(),
      'isRead': isRead,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'relatedAccountId': relatedAccountId,
      'relatedTransactionId': relatedTransactionId,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => NotificationType.general,
      ),
      isRead: map['isRead'],
      timestamp: DateTime.parse(map['timestamp']),
      data: map['data'],
      relatedAccountId: map['relatedAccountId'],
      relatedTransactionId: map['relatedTransactionId'],
    );
  }

  // Helper methods
  bool get isTransactionNotification => type == NotificationType.transaction;
  bool get isShareNotification => type == NotificationType.share;
  bool get isReminderNotification => type == NotificationType.reminder;

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'ابھی';
    if (difference.inHours < 1) return '${difference.inMinutes} منٹ پہلے';
    if (difference.inDays < 1) return '${difference.inHours} گھنٹے پہلے';
    if (difference.inDays < 7) return '${difference.inDays} دن پہلے';

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

@HiveType(typeId: 6)
enum NotificationType {
  @HiveField(0)
  transaction,

  @HiveField(1)
  share,

  @HiveField(2)
  reminder,

  @HiveField(3)
  report,

  @HiveField(4)
  general,

  @HiveField(5)
  system,

  @HiveField(6)
  price_drop,
}
