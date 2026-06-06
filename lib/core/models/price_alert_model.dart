class PriceAlert {
  final String id;
  final String userId;
  final String productName;
  final String productId; // Added for matching with reports
  final double targetPrice;
  final double currentPrice;
  final bool isActive;
  final DateTime createdAt;

  PriceAlert({
    required this.id,
    required this.userId,
    required this.productName,
    required this.productId,
    required this.targetPrice,
    required this.currentPrice,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'productName': productName,
      'productId': productId,
      'targetPrice': targetPrice,
      'currentPrice': currentPrice,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PriceAlert.fromMap(Map<String, dynamic> map) {
    return PriceAlert(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      productName: map['productName'] ?? '',
      productId: map['productId'] ?? '',
      targetPrice: (map['targetPrice'] ?? 0).toDouble(),
      currentPrice: (map['currentPrice'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
