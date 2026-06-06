// lib/core/models/profession_model.dart
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:account_app/l10n/app_localizations.dart';

part 'profession_model.g.dart';

// پیشے کی اقسام
@HiveType(typeId: 10)
enum ProfessionCategory {
  @HiveField(0)
  agriculture,      // زراعت
  @HiveField(1)
  manufacturing,    // مینوفیکچرنگ
  @HiveField(2)
  services,         // سروسز
  @HiveField(3)
  retail,           // رٹیل
  @HiveField(4)
  construction,     // تعمیرات
  @HiveField(5)
  education,        // تعلیم
  @HiveField(6)
  healthcare,       // صحت
  @HiveField(7)
  transportation,   // ٹرانسپورٹ
  @HiveField(8)
  technology,       // ٹیکنالوجی
  @HiveField(9)
  general,          // عام
}

@HiveType(typeId: 4)
class Profession {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> categories;

  @HiveField(3)
  final bool isActive;

  @HiveField(4)
  final double totalIncome;

  @HiveField(5)
  final double totalExpense;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  @HiveField(8)
  final String? description;

  @HiveField(9)
  final double totalProduction;

  @HiveField(10)
  String productionUnit; // mutable for flexibility

  @HiveField(11)
  final String season;

  // نیے فیلڈز
  @HiveField(12)
  final double targetProduction;

  @HiveField(13)
  final Map<String, double>? budgetLimits;

  @HiveField(14)
  final String seasonKey;

  @HiveField(15)
  final double benchmarkCostPerUnit;

  @HiveField(16)
  final ProfessionCategory categoryType;

  @HiveField(17)
  final Map<String, dynamic>? customMetrics;

  Profession({
    required this.id,
    required this.name,
    required this.categories,
    this.isActive = true,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.totalProduction = 0.0,
    this.productionUnit = 'unit',
    this.season = '',
    this.targetProduction = 0.0,
    this.budgetLimits,
    this.seasonKey = '',
    this.benchmarkCostPerUnit = 0.0,
    this.categoryType = ProfessionCategory.general,
    this.customMetrics,
  });

  // Map میں تبدیل
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categories': categories,
      'isActive': isActive,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'totalProduction': totalProduction,
      'productionUnit': productionUnit,
      'season': season,
      'targetProduction': targetProduction,
      'budgetLimits': budgetLimits,
      'seasonKey': seasonKey,
      'benchmarkCostPerUnit': benchmarkCostPerUnit,
      'categoryType': categoryType.name,
      'customMetrics': customMetrics,
    };
  }

  // Map سے Profession بنانا
  factory Profession.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic dateVal) {
      if (dateVal == null) return DateTime.now();
      if (dateVal is Timestamp) return dateVal.toDate();
      if (dateVal is String) return DateTime.parse(dateVal);
      return DateTime.now();
    }

    ProfessionCategory parseCategory(String? cat) {
      if (cat == null) return ProfessionCategory.general;
      return ProfessionCategory.values.firstWhere(
            (e) => e.name == cat,
        orElse: () => ProfessionCategory.general,
      );
    }

    return Profession(
      id: map['id'],
      name: map['name'],
      categories: List<String>.from(map['categories'] ?? []),
      isActive: map['isActive'] ?? true,
      totalIncome: (map['totalIncome'] ?? 0.0).toDouble(),
      totalExpense: (map['totalExpense'] ?? 0.0).toDouble(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      description: map['description'],
      totalProduction: (map['totalProduction'] ?? 0.0).toDouble(),
      productionUnit: map['productionUnit'] ?? 'unit',
      season: map['season'] ?? '',
      targetProduction: (map['targetProduction'] ?? 0.0).toDouble(),
      budgetLimits: map['budgetLimits'] != null
          ? Map<String, double>.from(map['budgetLimits'])
          : null,
      seasonKey: map['seasonKey'] ?? '',
      benchmarkCostPerUnit: (map['benchmarkCostPerUnit'] ?? 0.0).toDouble(),
      categoryType: parseCategory(map['categoryType']),
      customMetrics: map['customMetrics'] != null
          ? Map<String, dynamic>.from(map['customMetrics'])
          : null,
    );
  }

  // کاپی بنانا
  Profession copyWith({
    String? id,
    String? name,
    List<String>? categories,
    bool? isActive,
    double? totalIncome,
    double? totalExpense,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    double? totalProduction,
    String? productionUnit,
    String? season,
    double? targetProduction,
    Map<String, double>? budgetLimits,
    String? seasonKey,
    double? benchmarkCostPerUnit,
    ProfessionCategory? categoryType,
    Map<String, dynamic>? customMetrics,
  }) {
    return Profession(
      id: id ?? this.id,
      name: name ?? this.name,
      categories: categories ?? this.categories,
      isActive: isActive ?? this.isActive,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      description: description ?? this.description,
      totalProduction: totalProduction ?? this.totalProduction,
      productionUnit: productionUnit ?? this.productionUnit,
      season: season ?? this.season,
      targetProduction: targetProduction ?? this.targetProduction,
      budgetLimits: budgetLimits ?? this.budgetLimits,
      seasonKey: seasonKey ?? this.seasonKey,
      benchmarkCostPerUnit: benchmarkCostPerUnit ?? this.benchmarkCostPerUnit,
      categoryType: categoryType ?? this.categoryType,
      customMetrics: customMetrics ?? this.customMetrics,
    );
  }

  // 🔥 حساب کتاب کے getters

  // خالص منافع
  double get netProfit => totalIncome - totalExpense;

  // منافع بخش ہے؟
  bool get isProfitable => netProfit > 0;

  // فی اکائی لاگت
  double get costPerUnit {
    if (totalProduction > 0) {
      return totalExpense / totalProduction;
    }
    return 0.0;
  }

  // فی اکائی منافع
  double get profitPerUnit {
    if (totalProduction > 0) {
      return netProfit / totalProduction;
    }
    return 0.0;
  }

  // ہدف کا فیصد
  double get productionProgress {
    if (targetProduction > 0) {
      return (totalProduction / targetProduction) * 100;
    }
    return 0.0;
  }

  // 🔥 پیشے کی قسم کے مطابق ڈسپلے نام
  String get displayUnit {
    switch (categoryType) {
      case ProfessionCategory.agriculture:
        // اگر "unit" ہے تو "کلو" دکھائیں، ورنہ جو محفوظ ہے وہی دکھائیں
        return productionUnit == 'unit' ? 'کلو' : productionUnit;
      case ProfessionCategory.manufacturing:
        return productionUnit == 'unit' ? 'ٹکڑا' : productionUnit;
      case ProfessionCategory.services:
        return productionUnit == 'unit' ? 'سروس' : productionUnit;
      case ProfessionCategory.retail:
        return productionUnit == 'unit' ? 'آئٹم' : productionUnit;
      case ProfessionCategory.construction:
        return productionUnit == 'unit' ? 'پروجیکٹ' : productionUnit;
      case ProfessionCategory.education:
        return productionUnit == 'unit' ? 'طلبہ' : productionUnit;
      case ProfessionCategory.healthcare:
        return productionUnit == 'unit' ? 'مریض' : productionUnit;
      case ProfessionCategory.transportation:
        return productionUnit == 'unit' ? 'سفر' : productionUnit;
      case ProfessionCategory.technology:
        return productionUnit == 'unit' ? 'پروجیکٹ' : productionUnit;
      default:
        return productionUnit;
    }
  }

  // 🔥 پیشے کی قسم کے مطابق اصطلاحات
  Map<String, String> get terminology {
    switch (categoryType) {
      case ProfessionCategory.agriculture:
        return {
          'production': 'پیداوار',
          'unit': productionUnit == 'unit' ? 'کلو' : productionUnit,
          'cost_per_unit': 'فی کلو لاگت',
          'season': 'سیزن',
          'target': 'ہدف',
        };
      case ProfessionCategory.manufacturing:
        return {
          'production': 'تیاری',
          'unit': 'ٹکڑا',
          'cost_per_unit': 'فی یونٹ لاگت',
          'season': 'مہینہ',
          'target': 'ہدف',
        };
      default:
        return {
          'production': 'پیداوار',
          'unit': productionUnit,
          'cost_per_unit': 'فی یونٹ لاگت',
          'season': 'مدت',
          'target': 'ہدف',
        };
    }
  }

  // 🔥 کارکردگی اسکور (0-100)
  double get performanceScore {
    double score = 0.0;

    // 1. منافع کی شرح (40 پوائنٹس)
    if (totalIncome > 0) {
      final profitMargin = (netProfit / totalIncome) * 100;
      if (profitMargin > 0) {
        score += (profitMargin.clamp(0, 50) / 50) * 40;
      }
    }

    // 2. لاگت کنٹرول (30 پوائنٹس)
    if (benchmarkCostPerUnit > 0 && costPerUnit > 0) {
      final costRatio = benchmarkCostPerUnit / costPerUnit;
      score += costRatio.clamp(0, 2) * 15;
    }

    // 3. پیداوار کا ہدف (30 پوائنٹس)
    if (targetProduction > 0 && totalProduction > 0) {
      final productionRatio = totalProduction / targetProduction;
      score += productionRatio.clamp(0, 1.5) * 30;
    } else if (totalProduction > 0) {
      score += 15; // پیداوار ہے مگر ہدف نہیں
    }

    return score.clamp(0, 100);
  }

  // 🔥 پیشے کی قسم کا نام
  String categoryName(AppLocalizations l10n) {
    switch (categoryType) {
      case ProfessionCategory.agriculture:
        return l10n.agriculture;
      case ProfessionCategory.manufacturing:
        return l10n.manufacturing;
      case ProfessionCategory.services:
        return l10n.services;
      case ProfessionCategory.retail:
        return l10n.retail;
      case ProfessionCategory.construction:
        return l10n.construction;
      case ProfessionCategory.education:
        return l10n.education;
      case ProfessionCategory.healthcare:
        return l10n.healthcare;
      case ProfessionCategory.transportation:
        return l10n.transportation;
      case ProfessionCategory.technology:
        return l10n.tech;
      default:
        return l10n.general;
    }
  }

  // 🔥 سیزن کا خلاصہ
  String getSeasonSummary(AppLocalizations l10n) {
    if (season.isEmpty) return '';

    return '${l10n.seasonYear}: $season\n'
        '${l10n.costPerUnit}: ${costPerUnit.toStringAsFixed(2)}\n'
        '${l10n.profit}: ${netProfit.toStringAsFixed(0)}';
  }

  // 🔥 پیشے کی صحت کی کیفیت
  ProfessionHealth get healthStatus {
    final score = performanceScore;
    if (score >= 80) return ProfessionHealth.excellent;
    if (score >= 60) return ProfessionHealth.good;
    if (score >= 40) return ProfessionHealth.fair;
    return ProfessionHealth.poor;
  }

  // 🔥 رنگ صحت کے لحاظ سے
  Color get healthColor {
    switch (healthStatus) {
      case ProfessionHealth.excellent:
        return Colors.green;
      case ProfessionHealth.good:
        return Colors.greenAccent;
      case ProfessionHealth.fair:
        return Colors.orange;
      case ProfessionHealth.poor:
        return Colors.red;
    }
  }
}

// پیشے کی صحت کی درجہ بندی
enum ProfessionHealth {
  excellent, // بہترین
  good,      // اچھا
  fair,      // مناسب
  poor,      // خراب
}
