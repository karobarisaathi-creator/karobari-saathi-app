// lib/core/models/app_settings_model.dart

import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// AppSettings — ایپ کی عمومی سیٹنگز (کرنسی وغیرہ)
/// ═══════════════════════════════════════════════════════════════
class AppSettings {
  final String currencySymbol;      // 'Rs', '$', '£', '€', '﷼'
  final String currencyCode;        // 'PKR', 'USD', 'GBP', 'EUR', 'SAR'
  final int decimalPlaces;          // 0, 1, 2
  final String thousandSeparator;   // ',', '.', ' '
  final String decimalSeparator;    // '.', ','
  final bool currencyBefore;        // true = 'Rs 100', false = '100 Rs'

  const AppSettings({
    this.currencySymbol = 'Rs',
    this.currencyCode = 'PKR',
    this.decimalPlaces = 0,
    this.thousandSeparator = ',',
    this.decimalSeparator = '.',
    this.currencyBefore = true,
  });

  AppSettings copyWith({
    String? currencySymbol,
    String? currencyCode,
    int? decimalPlaces,
    String? thousandSeparator,
    String? decimalSeparator,
    bool? currencyBefore,
  }) {
    return AppSettings(
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      thousandSeparator: thousandSeparator ?? this.thousandSeparator,
      decimalSeparator: decimalSeparator ?? this.decimalSeparator,
      currencyBefore: currencyBefore ?? this.currencyBefore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currencySymbol': currencySymbol,
      'currencyCode': currencyCode,
      'decimalPlaces': decimalPlaces,
      'thousandSeparator': thousandSeparator,
      'decimalSeparator': decimalSeparator,
      'currencyBefore': currencyBefore,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      currencySymbol: (map['currencySymbol'] ?? 'Rs').toString(),
      currencyCode: (map['currencyCode'] ?? 'PKR').toString(),
      decimalPlaces: (map['decimalPlaces'] as num?)?.toInt() ?? 0,
      thousandSeparator: (map['thousandSeparator'] ?? ',').toString(),
      decimalSeparator: (map['decimalSeparator'] ?? '.').toString(),
      currencyBefore: map['currencyBefore'] != false,
    );
  }

  /// ⭐ رقم کو فارمیٹ کریں
  String formatAmount(double amount) {
    if (!amount.isFinite) return '0';

    final negative = amount < 0;
    final absAmount = amount.abs();

    // Decimal places کے مطابق rounding
    final multiplier = _pow10(decimalPlaces);
    final rounded = (absAmount * multiplier).round() / multiplier;

    // Integer aur fractional parts
    final parts = rounded.toStringAsFixed(decimalPlaces).split('.');
    final integerPart = parts[0];
    final fractionalPart = decimalPlaces > 0 ? parts[1] : '';

    // Thousand separator لگائیں
    final withSeparator = _addThousandSeparator(integerPart);

    // Compose
    final number = decimalPlaces > 0
        ? '$withSeparator$decimalSeparator$fractionalPart'
        : withSeparator;

    final sign = negative ? '-' : '';

    // Currency position
    if (currencyBefore) {
      return '$sign$currencySymbol $number';
    } else {
      return '$sign$number $currencySymbol';
    }
  }

  /// ⭐ صرف number (بغیر currency symbol) — جیسے input fields کے لیے
  String formatNumber(double amount) {
    if (!amount.isFinite) return '0';

    final negative = amount < 0;
    final absAmount = amount.abs();
    final multiplier = _pow10(decimalPlaces);
    final rounded = (absAmount * multiplier).round() / multiplier;

    final parts = rounded.toStringAsFixed(decimalPlaces).split('.');
    final integerPart = parts[0];
    final fractionalPart = decimalPlaces > 0 ? parts[1] : '';
    final withSeparator = _addThousandSeparator(integerPart);

    final number = decimalPlaces > 0
        ? '$withSeparator$decimalSeparator$fractionalPart'
        : withSeparator;

    return negative ? '-$number' : number;
  }

  /// ⭐ صرف symbol — جب صرف 'Rs' دکھانا ہو
  String get symbol => currencySymbol;

  /// ⭐ Compact format (K, M) — جیسے "Rs 1.2K"
  String formatCompact(double amount) {
    if (!amount.isFinite) return '0';
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (abs >= 1000000) {
      return '$sign$currencySymbol ${(abs / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      return '$sign$currencySymbol ${(abs / 1000).toStringAsFixed(1)}K';
    }
    return formatAmount(amount);
  }

  // ─── Helpers ───
  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  String _addThousandSeparator(String number) {
    if (number.length <= 3) return number;
    final buffer = StringBuffer();
    final start = number.length % 3;
    if (start > 0) {
      buffer.write(number.substring(0, start));
      if (number.length > start) buffer.write(thousandSeparator);
    }
    for (var i = start; i < number.length; i += 3) {
      buffer.write(number.substring(i, i + 3));
      if (i + 3 < number.length) buffer.write(thousandSeparator);
    }
    return buffer.toString();
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Predefined currencies — dropdown کے لیے
/// ═══════════════════════════════════════════════════════════════
class CurrencyOptions {
  static const List<Map<String, String>> list = [
    {'code': 'PKR', 'symbol': 'Rs', 'name': 'Pakistani Rupee', 'nameUrdu': 'پاکستانی روپیہ'},
    {'code': 'USD', 'symbol': r'$', 'name': 'US Dollar', 'nameUrdu': 'امریکی ڈالر'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound', 'nameUrdu': 'برطانوی پاؤنڈ'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'nameUrdu': 'یورو'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal', 'nameUrdu': 'سعودی ریال'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham', 'nameUrdu': 'اماراتی درہم'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee', 'nameUrdu': 'بھارتی روپیہ'},
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka', 'nameUrdu': 'بنگلہ دیشی ٹکا'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan', 'nameUrdu': 'چینی یوآن'},
    {'code': 'TRY', 'symbol': '₺', 'name': 'Turkish Lira', 'nameUrdu': 'ترکش لیرا'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit', 'nameUrdu': 'ملائیشین رنگٹ'},
    {'code': 'AFN', 'symbol': '؋', 'name': 'Afghan Afghani', 'nameUrdu': 'افغانی'},
    {'code': 'IRR', 'symbol': '﷼', 'name': 'Iranian Rial', 'nameUrdu': 'ایرانی ریال'},
  ];
}