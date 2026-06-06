import 'package:cloud_firestore/cloud_firestore.dart';

class PriceReport {
  final String id;
  final String productId;
  final String productName; // Added field
  final double price;
  final String shopName;
  final String locationName;
  final GeoPoint coordinates;
  final String reporterId;
  final bool isVerified;
  final DateTime reportedAt;

  PriceReport({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.shopName,
    required this.locationName,
    required this.coordinates,
    required this.reporterId,
    this.isVerified = false,
    required this.reportedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'price': price,
      'shopName': shopName,
      'locationName': locationName,
      'coordinates': coordinates,
      'reporterId': reporterId,
      'isVerified': isVerified,
      'reportedAt': reportedAt,
    };
  }

  factory PriceReport.fromMap(Map<String, dynamic> map) {
    return PriceReport(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      shopName: map['shopName'] ?? '',
      locationName: map['locationName'] ?? '',
      coordinates: map['coordinates'] as GeoPoint,
      reporterId: map['reporterId'] ?? '',
      isVerified: map['isVerified'] ?? false,
      reportedAt: (map['reportedAt'] as Timestamp).toDate(),
    );
  }
}
