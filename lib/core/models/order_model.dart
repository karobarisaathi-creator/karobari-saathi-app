import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }

class OrderModel {
  final String id;
  final String itemId;
  final String itemName;
  final String? itemImage;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String sellerId;
  final double price;
  final double quantity;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deliveryAddress;
  final String? note;

  OrderModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    this.itemImage,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.sellerId,
    required this.price,
    this.quantity = 1,
    this.status = OrderStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryAddress,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'itemImage': itemImage,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'sellerId': sellerId,
      'price': price,
      'quantity': quantity,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deliveryAddress': deliveryAddress,
      'note': note,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      itemImage: map['itemImage'],
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      buyerPhone: map['buyerPhone'] ?? '',
      sellerId: map['sellerId'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      status: OrderStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => OrderStatus.pending),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
      deliveryAddress: map['deliveryAddress'],
      note: map['note'],
    );
  }
}
