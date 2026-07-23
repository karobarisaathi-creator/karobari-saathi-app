import 'package:cloud_firestore/cloud_firestore.dart';

class AdReport {
  final String id;
  final String itemId;
  final String itemOwnerId;
  final String reporterId;
  final String reason;
  final String? additionalDetails;
  final DateTime reportedAt;

  AdReport({
    required this.id,
    required this.itemId,
    required this.itemOwnerId,
    required this.reporterId,
    required this.reason,
    this.additionalDetails,
    required this.reportedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'itemOwnerId': itemOwnerId,
      'reporterId': reporterId,
      'reason': reason,
      'additionalDetails': additionalDetails,
      'reportedAt': reportedAt, // Firestore will convert this to Timestamp
    };
  }

  factory AdReport.fromMap(Map<String, dynamic> map) {
    return AdReport(
      id: map['id'] ?? '',
      itemId: map['itemId'] ?? '',
      itemOwnerId: map['itemOwnerId'] ?? '',
      reporterId: map['reporterId'] ?? '',
      reason: map['reason'] ?? '',
      additionalDetails: map['additionalDetails'],
      reportedAt: (map['reportedAt'] as Timestamp).toDate(),
    );
  }
}
