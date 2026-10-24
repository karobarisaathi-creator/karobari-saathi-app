// lib/core/models/stock_item_model.dart

class StockItem {
  final String id;
  final String name;
  final String nameUrdu;
  final String barcode;
  final String categoryId;
  final String categoryName;
  final double purchasePrice;
  final double sellingPrice;
  final double wholesalePrice;
  final double initialQuantity;
  final double minStockAlert;
  final String unit; // Pieces, Kg, Meter, Liter, Box, Dozen etc.
  final String description;
  final String? imagePath;
  final String sku;
  final double mrp;
  final String brand;
  final String model;
  final String supplierName;
  final String batchNo;
  final int warranty;
  final bool featured;
  final bool trackStock;
  final bool allowReturn;
  final bool stopWhenOut;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  StockItem({
    required this.id,
    required this.name,
    this.nameUrdu = '',
    this.barcode = '',
    this.categoryId = '',
    this.categoryName = '',
    this.purchasePrice = 0.0,
    this.sellingPrice = 0.0,
    this.wholesalePrice = 0.0,
    this.initialQuantity = 0.0,
    this.minStockAlert = 5.0,
    this.unit = 'Pieces',
    this.description = '',
    this.imagePath,
    this.sku = '',
    this.mrp = 0.0,
    this.brand = '',
    this.model = '',
    this.supplierName = '',
    this.batchNo = '',
    this.warranty = 0,
    this.featured = false,
    this.trackStock = true,
    this.allowReturn = true,
    this.stopWhenOut = true,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get profitMargin => sellingPrice - purchasePrice;

  double get profitMarginPercent {
    if (purchasePrice <= 0) return 0.0;
    return ((sellingPrice - purchasePrice) / purchasePrice) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameUrdu': nameUrdu,
      'barcode': barcode,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'wholesalePrice': wholesalePrice,
      'initialQuantity': initialQuantity,
      'minStockAlert': minStockAlert,
      'unit': unit,
      'description': description,
      'imagePath': imagePath,
      'sku': sku,
      'mrp': mrp,
      'brand': brand,
      'model': model,
      'supplierName': supplierName,
      'batchNo': batchNo,
      'warranty': warranty,
      'featured': featured,
      'trackStock': trackStock,
      'allowReturn': allowReturn,
      'stopWhenOut': stopWhenOut,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StockItem.fromMap(Map<String, dynamic> map) {
    double readDouble(String key, [double fallback = 0.0]) {
      final value = map[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int readInt(String key, [int fallback = 0]) {
      final value = map[key];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = map[key];
      if (value is bool) return value;
      if (value is String) {
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
      }
      return fallback;
    }

    return StockItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameUrdu: map['nameUrdu'] ?? '',
      barcode: map['barcode'] ?? '',
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (map['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
      initialQuantity: (map['initialQuantity'] as num?)?.toDouble() ?? 0.0,
      minStockAlert: (map['minStockAlert'] as num?)?.toDouble() ?? 5.0,
      unit: map['unit'] ?? 'Pieces',
      description: map['description'] ?? '',
      imagePath: map['imagePath'],
      sku: map['sku']?.toString() ?? '',
      mrp: readDouble('mrp'),
      brand: map['brand']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      supplierName: map['supplierName']?.toString() ?? '',
      batchNo: map['batchNo']?.toString() ?? '',
      warranty: readInt('warranty'),
      featured: readBool('featured', false),
      trackStock: readBool('trackStock', true),
      allowReturn: readBool('allowReturn', true),
      stopWhenOut: readBool('stopWhenOut', true),
      isArchived: readBool('isArchived', false),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  StockItem copyWith({
    String? id,
    String? name,
    String? nameUrdu,
    String? barcode,
    String? categoryId,
    String? categoryName,
    double? purchasePrice,
    double? sellingPrice,
    double? wholesalePrice,
    double? initialQuantity,
    double? minStockAlert,
    String? unit,
    String? description,
    String? imagePath,
    bool clearImagePath = false,
    String? sku,
    double? mrp,
    String? brand,
    String? model,
    String? supplierName,
    String? batchNo,
    int? warranty,
    bool? featured,
    bool? trackStock,
    bool? allowReturn,
    bool? stopWhenOut,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockItem(
      id: id ?? this.id,
      name: name ?? this.name,
      nameUrdu: nameUrdu ?? this.nameUrdu,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      sku: sku ?? this.sku,
      mrp: mrp ?? this.mrp,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      supplierName: supplierName ?? this.supplierName,
      batchNo: batchNo ?? this.batchNo,
      warranty: warranty ?? this.warranty,
      featured: featured ?? this.featured,
      trackStock: trackStock ?? this.trackStock,
      allowReturn: allowReturn ?? this.allowReturn,
      stopWhenOut: stopWhenOut ?? this.stopWhenOut,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
