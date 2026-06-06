import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'category_model.g.dart';

@HiveType(typeId: 2)
class Category {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final CategoryType type;

  @HiveField(3)
  final String? parentId;

  @HiveField(4)
  final String color;

  @HiveField(5)
  final String icon;

  @HiveField(6)
  final bool isActive;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    required this.color,
    required this.icon,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'parentId': parentId,
      'color': color,
      'icon': icon,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic dateVal) {
      if (dateVal == null) return DateTime.now();
      if (dateVal is Timestamp) return dateVal.toDate();
      if (dateVal is String) return DateTime.parse(dateVal);
      return DateTime.now();
    }

    return Category(
      id: map['id'],
      name: map['name'],
      type: CategoryType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => CategoryType.income,
      ),
      parentId: map['parentId'],
      color: map['color'],
      icon: map['icon'],
      isActive: map['isActive'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  bool get isIncome => type == CategoryType.income;
  bool get isExpense => type == CategoryType.expense;
}

@HiveType(typeId: 3)
enum CategoryType {
  @HiveField(0)
  income,

  @HiveField(1)
  expense,
}
