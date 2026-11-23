import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceListing {
  final String id;
  final String ownerId;
  final String sellerName;
  final String phoneNumber;
  final bool phoneShared;
  final String title;
  final String description;
  final String category;
  final String condition;
  final String area;
  final double price;
  final bool isNegotiable;
  final List<String> imageUrls;
  final List<String> imagePaths;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MarketplaceListing({
    required this.id,
    required this.ownerId,
    required this.sellerName,
    required this.phoneNumber,
    required this.phoneShared,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.area,
    required this.price,
    required this.isNegotiable,
    required this.imageUrls,
    required this.imagePaths,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isSold => status == 'sold';

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'sellerName': sellerName,
        'phoneNumber': phoneNumber,
        'phoneShared': phoneShared,
        'title': title,
        'description': description,
        'category': category,
        'condition': condition,
        'area': area,
        'price': price,
        'isNegotiable': isNegotiable,
        'imageUrls': imageUrls,
        'imagePaths': imagePaths,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory MarketplaceListing.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> readStrings(dynamic value) {
      if (value is! Iterable) return const [];
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final now = DateTime.now();
    return MarketplaceListing(
      id: id,
      ownerId: map['ownerId']?.toString() ?? '',
      sellerName: map['sellerName']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      phoneShared: map['phoneShared'] == true,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? 'other',
      condition: map['condition']?.toString() ?? 'used',
      area: map['area']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      isNegotiable: map['isNegotiable'] == true,
      imageUrls: readStrings(map['imageUrls']),
      imagePaths: readStrings(map['imagePaths']),
      status: map['status']?.toString() ?? 'active',
      createdAt: readDate(map['createdAt'] ?? now),
      updatedAt: readDate(map['updatedAt'] ?? now),
    );
  }

  MarketplaceListing copyWith({
    String? id,
    String? ownerId,
    String? sellerName,
    String? phoneNumber,
    bool? phoneShared,
    String? title,
    String? description,
    String? category,
    String? condition,
    String? area,
    double? price,
    bool? isNegotiable,
    List<String>? imageUrls,
    List<String>? imagePaths,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MarketplaceListing(
        id: id ?? this.id,
        ownerId: ownerId ?? this.ownerId,
        sellerName: sellerName ?? this.sellerName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        phoneShared: phoneShared ?? this.phoneShared,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        condition: condition ?? this.condition,
        area: area ?? this.area,
        price: price ?? this.price,
        isNegotiable: isNegotiable ?? this.isNegotiable,
        imageUrls: imageUrls ?? this.imageUrls,
        imagePaths: imagePaths ?? this.imagePaths,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
