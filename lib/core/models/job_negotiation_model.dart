import 'package:cloud_firestore/cloud_firestore.dart';

class NegotiationMessage {
  final String id;
  final String senderId;
  final String message;
  final double? proposedAmount;
  final DateTime timestamp;
  final bool isRead;

  NegotiationMessage({
    required this.id,
    required this.senderId,
    required this.message,
    this.proposedAmount,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'message': message,
      'proposedAmount': proposedAmount,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory NegotiationMessage.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return NegotiationMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      message: map['message'] ?? '',
      proposedAmount: (map['proposedAmount'] as num?)?.toDouble(),
      timestamp: parseDate(map['timestamp']),
      isRead: map['isRead'] ?? false,
    );
  }
}
