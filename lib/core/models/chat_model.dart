// chat_model.dart
import 'package:hive/hive.dart';

part 'chat_model.g.dart';

@HiveType(typeId: 8)
class Chat {
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
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final String? accountId;

  @HiveField(8)
  final String? accountName;

  Chat({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    required this.createdAt,
    required this.updatedAt,
    this.accountId,
    this.accountName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastSenderId': lastSenderId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'accountId': accountId,
      'accountName': accountName,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      participants: List<String>.from(map['participants']),
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.parse(map['lastMessageTime'])
          : null,
      lastSenderId: map['lastSenderId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      accountId: map['accountId'],
      accountName: map['accountName'],
    );
  }

  Chat copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastSenderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? accountId,
    String? accountName,
  }) {
    return Chat(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
    );
  }

  // Helper methods
  bool get hasUnreadMessages =>
      false; // This would be calculated based on actual messages

  String get displayName {
    if (accountName != null) return accountName!;
    return 'گروپ چیٹ';
  }

  String get lastMessagePreview {
    if (lastMessage == null) return 'کوئی پیغام نہیں';
    if (lastMessage!.length > 30) {
      return '${lastMessage!.substring(0, 30)}...';
    }
    return lastMessage!;
  }

  String get formattedLastMessageTime {
    if (lastMessageTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastMessageTime!);

    if (difference.inMinutes < 1) return 'ابھی';
    if (difference.inHours < 1) return '${difference.inMinutes} منٹ';
    if (difference.inDays < 1) return '${difference.inHours} گھنٹے';
    if (difference.inDays < 7) return '${difference.inDays} دن';

    return '${lastMessageTime!.day}/${lastMessageTime!.month}/${lastMessageTime!.year}';
  }
}

@HiveType(typeId: 9)
class ChatMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String chatId;

  @HiveField(2)
  final String senderId;

  @HiveField(3)
  final String message;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final bool isRead;

  @HiveField(6)
  final bool isEdited;

  @HiveField(7)
  final DateTime? updatedAt;

  @HiveField(8)
  final String? messageType; // text, image, document

  @HiveField(9)
  final String? fileUrl;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.isEdited = false,
    this.updatedAt,
    this.messageType = 'text',
    this.fileUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'isEdited': isEdited,
      'updatedAt': updatedAt?.toIso8601String(),
      'messageType': messageType,
      'fileUrl': fileUrl,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      chatId: map['chatId'],
      senderId: map['senderId'],
      message: map['message'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'],
      isEdited: map['isEdited'],
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
      messageType: map['messageType'],
      fileUrl: map['fileUrl'],
    );
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    bool? isEdited,
    DateTime? updatedAt,
    String? messageType,
    String? fileUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      updatedAt: updatedAt ?? this.updatedAt,
      messageType: messageType ?? this.messageType,
      fileUrl: fileUrl ?? this.fileUrl,
    );
  }

  // Helper methods
  bool get isTextMessage => messageType == 'text';
  bool get isImageMessage => messageType == 'image';
  bool get isDocumentMessage => messageType == 'document';

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String get displayMessage {
    if (isEdited) return '$message (ترمیم شدہ)';
    return message;
  }
}
