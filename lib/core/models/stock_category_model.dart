// lib/core/models/stock_category_model.dart

class StockCategory {
  final String id;
  final String name;
  final String nameUrdu;
  final String description;

  StockCategory({
    required this.id,
    required this.name,
    this.nameUrdu = '',
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameUrdu': nameUrdu,
      'description': description,
    };
  }

  factory StockCategory.fromMap(Map<String, dynamic> map) {
    return StockCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameUrdu: map['nameUrdu'] ?? '',
      description: map['description'] ?? '',
    );
  }
}
