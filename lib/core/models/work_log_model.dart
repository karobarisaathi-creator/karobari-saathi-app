import 'package:hive/hive.dart';

part 'work_log_model.g.dart';

@HiveType(typeId: 25)
class WorkLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String accountId;

  @HiveField(2)
  final String? professionId;

  @HiveField(3)
  final String description; // Raw text or AI summary

  @HiveField(4)
  final double quantity; // e.g., 2.5 (Acres/Hours)

  @HiveField(5)
  final int multiplier; // e.g., 2 (rounds/days)

  @HiveField(6)
  final double rate; // Rate per unit

  @HiveField(7)
  final double totalAmount; // Final calculated amount

  @HiveField(8)
  final DateTime date;

  @HiveField(9)
  final String unitName; // e.g., 'Acre', 'Hour', 'Suit'

  @HiveField(10)
  final String? accountName; // Cached name for quick display

  WorkLog({
    required this.id,
    required this.accountId,
    this.professionId,
    required this.description,
    this.quantity = 1.0,
    this.multiplier = 1,
    this.rate = 0.0,
    this.totalAmount = 0.0,
    required this.date,
    this.unitName = 'unit',
    this.accountName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'professionId': professionId,
      'description': description,
      'quantity': quantity,
      'multiplier': multiplier,
      'rate': rate,
      'totalAmount': totalAmount,
      'date': date.toIso8601String(),
      'unitName': unitName,
      'accountName': accountName,
    };
  }

  factory WorkLog.fromMap(Map<String, dynamic> map) {
    return WorkLog(
      id: map['id'] ?? '',
      accountId: map['accountId'] ?? '',
      professionId: map['professionId'],
      description: map['description'] ?? '',
      quantity: (map['quantity'] ?? 1.0).toDouble(),
      multiplier: (map['multiplier'] ?? 1).toInt(),
      rate: (map['rate'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      unitName: map['unitName'] ?? 'unit',
      accountName: map['accountName'],
    );
  }
}
