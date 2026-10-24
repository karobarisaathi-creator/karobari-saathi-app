// lib/core/models/shop_model.dart

class Shop {
  final String id;
  final String name;
  final String logoEmoji;
  final String? bannerImageUrl;
  final String? profileImageUrl;
  final String owner;
  final String area;
  final String distance;
  final double distanceVal;
  final double rating;
  final int reviews;
  final String deliveryTime;
  final int timeVal;
  final String minOrder;
  final String deliveryFee;
  final bool isOpen;
  final List<String> tags;
  final List<ShopItem> items;
  final int? itemCount;
  final bool showOwnerName;
  final bool showArea;
  final bool showDistance;
  final bool showDeliveryInfo;
  final bool showRating;
  final bool showItemsCount;
  final bool showTags;
  final double? latitude;
  final double? longitude;

  const Shop({
    required this.id,
    required this.name,
    required this.logoEmoji,
    this.bannerImageUrl,
    this.profileImageUrl,
    required this.owner,
    required this.area,
    required this.distance,
    required this.distanceVal,
    required this.rating,
    required this.reviews,
    required this.deliveryTime,
    required this.timeVal,
    required this.minOrder,
    required this.deliveryFee,
    required this.isOpen,
    required this.tags,
    required this.items,
    this.itemCount,
    this.showOwnerName = true,
    this.showArea = true,
    this.showDistance = true,
    this.showDeliveryInfo = true,
    this.showRating = true,
    this.showItemsCount = true,
    this.showTags = true,
    this.latitude,
    this.longitude,
  });

  int get availableItemCount => itemCount ?? items.length;

  Shop copyWith({List<ShopItem>? items, int? itemCount}) => Shop(
        id: id,
        name: name,
        logoEmoji: logoEmoji,
        bannerImageUrl: bannerImageUrl,
        profileImageUrl: profileImageUrl,
        owner: owner,
        area: area,
        distance: distance,
        distanceVal: distanceVal,
        rating: rating,
        reviews: reviews,
        deliveryTime: deliveryTime,
        timeVal: timeVal,
        minOrder: minOrder,
        deliveryFee: deliveryFee,
        isOpen: isOpen,
        tags: tags,
        items: items ?? this.items,
        itemCount: itemCount ?? this.itemCount,
        showOwnerName: showOwnerName,
        showArea: showArea,
        showDistance: showDistance,
        showDeliveryInfo: showDeliveryInfo,
        showRating: showRating,
        showItemsCount: showItemsCount,
        showTags: showTags,
        latitude: latitude,
        longitude: longitude,
      );
}

class ShopItem {
  final String id;
  final String name;
  final String? description;
  final double rate;
  final double? oldRate;
  final String unit;
  final String emoji;
  final String category;
  final String? badge;
  final double stock;
  final double rating;
  final List<String> highlights;
  final String nameUrdu;
  final String? imageUrl;
  final String stockItemId;
  double quantity;

  ShopItem({
    required this.id,
    required this.name,
    this.description,
    required this.rate,
    this.oldRate,
    required this.unit,
    required this.emoji,
    required this.category,
    this.badge,
    required this.stock,
    this.rating = 4.5,
    this.highlights = const [],
    this.nameUrdu = '',
    this.imageUrl,
    this.stockItemId = '',
    this.quantity = 0,
  });

  double get total => rate * quantity;
  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= 10;
  bool get hasDiscount => oldRate != null && oldRate! > rate;
  int get discountPercent =>
      hasDiscount ? (((oldRate! - rate) / oldRate!) * 100).round() : 0;
}
