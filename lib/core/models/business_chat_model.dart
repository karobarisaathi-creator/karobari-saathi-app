import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'business_chat_model.g.dart';

@HiveType(typeId: 35)
class BusinessChatMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderId;

  @HiveField(2)
  final String receiverId;

  @HiveField(3)
  final String message;

  @HiveField(4)
  final String messageType; // text, image, file, order_link

  @HiveField(5)
  final String? fileUrl;

  @HiveField(6)
  final String? fileName;

  @HiveField(7)
  final String? fileSize;

  @HiveField(8)
  final bool isRead;

  @HiveField(9)
  final bool isDelivered;

  @HiveField(10)
  final DateTime timestamp;

  @HiveField(11)
  final DateTime? editedAt;

  @HiveField(12)
  final String? orderId; 

  BusinessChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.messageType = 'text',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isRead = false,
    this.isDelivered = false,
    required this.timestamp,
    this.editedAt,
    this.orderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'messageType': messageType,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'timestamp': timestamp.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'orderId': orderId,
    };
  }

  factory BusinessChatMessage.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return BusinessChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      messageType: map['messageType']?.toString() ?? 'text',
      fileUrl: map['fileUrl']?.toString(),
      fileName: map['fileName']?.toString(),
      fileSize: map['fileSize']?.toString(),
      isRead: map['isRead'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      timestamp: parseDate(map['timestamp']),
      editedAt: map['editedAt'] != null ? parseDate(map['editedAt']) : null,
      orderId: map['orderId']?.toString(),
    );
  }
}

@HiveType(typeId: 36)
class BusinessChatRoom {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<String> participants;

  @HiveField(2)
  final String? lastMessage;

  @HiveField(3)
  final DateTime? lastMessageTime;

  @HiveField(4)
  final String? lastSenderId;

  @HiveField(5)
  final int unreadCount;

  @HiveField(6)
  final bool isActive;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  BusinessChatRoom({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCount = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BusinessChatRoom.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return BusinessChatRoom(
      id: map['id']?.toString() ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage']?.toString(),
      lastMessageTime: map['lastMessageTime'] != null
          ? parseDate(map['lastMessageTime'])
          : null,
      lastSenderId: map['lastSenderId']?.toString(),
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
