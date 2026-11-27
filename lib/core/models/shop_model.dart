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
  final bool showItemsCount;
  final bool showTags;

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
    this.showItemsCount = true,
    this.showTags = true,
  });

  int get availableItemCount => itemCount ?? items.length;

  Shop copyWith({
    List<ShopItem>? items,
    int? itemCount,
  }) =>
      Shop(
        id: id,
        name: name,
        logoEmoji: logoEmoji,
        bannerImageUrl: bannerImageUrl,
        profileImageUrl: profileImageUrl,
        owner: owner,
        area: area,
        distance: distance,
        distanceVal: distanceVal,
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
        showItemsCount: showItemsCount,
        showTags: showTags,
      );
}

class ShopItem {
  final String id;
  final String name;
  final String? description;
  final String? brand;
  final String? model;
  final bool allowReturn;
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
  final List<String> images;
  final String stockItemId;
  double quantity;

  ShopItem({
    required this.id,
    required this.name,
    this.description,
    this.brand,
    this.model,
    this.allowReturn = false,
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
    this.images = const [],
    this.stockItemId = '',
    this.quantity = 0,
  });

  List<String> get allImages {
    final list = <String>[];
    for (final img in images) {
      final trimmed = img.trim();
      if (trimmed.isNotEmpty && trimmed.length > 4 && !list.contains(trimmed)) {
        list.add(trimmed);
      }
    }
    if (imageUrl != null) {
      final trimmed = imageUrl!.trim();
      if (trimmed.isNotEmpty && trimmed.length > 4 && !list.contains(trimmed)) {
        list.insert(0, trimmed);
      }
    }
    return list;
  }

  double get total => rate * quantity;
  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= 10;
  bool get hasDiscount => oldRate != null && oldRate! > rate;
  int get discountPercent =>
      hasDiscount ? (((oldRate! - rate) / oldRate!) * 100).round() : 0;
}
