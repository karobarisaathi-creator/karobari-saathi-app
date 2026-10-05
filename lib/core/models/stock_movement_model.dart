// lib/core/models/stock_movement_model.dart

enum StockMovementType {
  purchase, // Stock In (+)
  sale, // Stock Out (-)
  adjustment, // Manual audit adjustment (+/-)
  customerReturn, // Customer return (+)
  supplierReturn, // Return to supplier (-)
}

class StockMovement {
  final String id;
  final String stockItemId;
  final String stockItemName;
  final StockMovementType type;
  final double quantity; // Positive value
  final double unitPrice; // Cost or Sale price per unit
  final String reason; // Purchase, Sale, Damage, Theft, Expiry, Discrepancy
  final String note; // Extra user notes
  final String partyId; // Related party/customer ID if applicable
  final String partyName; // Related party name if applicable
  final String transactionId;
  final DateTime timestamp;

  StockMovement({
    required this.id,
    required this.stockItemId,
    required this.stockItemName,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    this.reason = '',
    this.note = '',
    this.partyId = '',
    this.partyName = '',
    this.transactionId = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stockItemId': stockItemId,
      'stockItemName': stockItemName,
      'type': type.name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'reason': reason,
      'note': note,
      'partyId': partyId,
      'partyName': partyName,
      'transactionId': transactionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] ?? '',
      stockItemId: map['stockItemId'] ?? '',
      stockItemName: map['stockItemName'] ?? '',
      type: StockMovementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StockMovementType.adjustment,
      ),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] ?? '',
      note: map['note'] ?? '',
      partyId: map['partyId'] ?? '',
      partyName: map['partyName'] ?? '',
      transactionId: map['transactionId'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
