import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'dispute_model.g.dart';

@HiveType(typeId: 28)
class Dispute extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String workOrderId;
  
  @HiveField(2)
  final String raisedBy; // customer or artisan
  
  @HiveField(3)
  final String reason;
  
  @HiveField(4)
  final String description;
  
  @HiveField(5)
  final String status; // open, under_review, resolved, rejected
  
  @HiveField(6)
  final DateTime createdAt;
  
  @HiveField(7)
  final DateTime? resolvedAt;
  
  @HiveField(8)
  final String? resolution;
  
  @HiveField(9)
  final List<DisputeMessage> messages;
  
  @HiveField(10)
  final List<String> attachments;

  Dispute({
    required this.id,
    required this.workOrderId,
    required this.raisedBy,
    required this.reason,
    required this.description,
    this.status = 'open',
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
    this.messages = const [],
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workOrderId': workOrderId,
      'raisedBy': raisedBy,
      'reason': reason,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolution': resolution,
      'messages': messages.map((m) => m.toMap()).toList(),
      'attachments': attachments,
    };
  }

  factory Dispute.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return Dispute(
      id: map['id']?.toString() ?? '',
      workOrderId: map['workOrderId']?.toString() ?? '',
      raisedBy: map['raisedBy']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? 'open',
      createdAt: parseDate(map['createdAt']),
      resolvedAt: map['resolvedAt'] != null ? parseDate(map['resolvedAt']) : null,
      resolution: map['resolution']?.toString(),
      messages: (map['messages'] as List? ?? [])
          .map((m) => DisputeMessage.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }
}

@HiveType(typeId: 29)
class DisputeMessage extends HiveObject {
  @HiveField(0)
  final String senderId;
  
  @HiveField(1)
  final String message;
  
  @HiveField(2)
  final DateTime timestamp;

  DisputeMessage({
    required this.senderId,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DisputeMessage.fromMap(Map<String, dynamic> map) {
    return DisputeMessage(
      senderId: map['senderId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
