import 'package:hive/hive.dart';

part 'transaction_item_model.g.dart';

@HiveType(typeId: 20) // Using typeId 20 to avoid conflict with Category (typeId 2)
class TransactionItem extends HiveObject {
  @HiveField(0)
  final String description;

  @HiveField(1)
  final double quantity;

  @HiveField(2)
  final double rate;

  @HiveField(3)
  final double total;

  @HiveField(4)
  final String? unit;

  TransactionItem({
    required this.description,
    required this.quantity,
    required this.rate,
    required this.total,
    this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'rate': rate,
      'total': total,
      'unit': unit,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'],
    );
  }
}
