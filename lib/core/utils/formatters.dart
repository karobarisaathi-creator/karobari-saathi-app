// lib/core/utils/formatters.dart

import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:account_app/core/models/app_settings_model.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final bool allowDecimals;

  CurrencyInputFormatter({this.allowDecimals = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String text = newValue.text;

    if (allowDecimals && text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 2) {
        return oldValue;
      }

      String integerPart = parts[0].replaceAll(RegExp(r'\D'), '');
      String decimalPart = parts[1].replaceAll(RegExp(r'\D'), '');

      final number = int.tryParse(integerPart) ?? 0;
      final formatter = NumberFormat('#,##0', 'en_US');
      final formattedInteger =
          integerPart.isEmpty ? '' : formatter.format(number);

      final formattedText = '$formattedInteger.$decimalPart';

      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    }

    String cleanText = text.replaceAll(RegExp(r'\D'), '');

    if (cleanText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(cleanText) ?? 0;
    final formatter = NumberFormat('#,##0', 'en_US');
    final formattedText = formatter.format(number);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class Formatters {
  // ═══════════════════════════════════════════════════════════
  // ⭐ GLOBAL SETTINGS — main.dart سے set ہوتے ہیں
  // ═══════════════════════════════════════════════════════════
  static AppSettings _settings = const AppSettings();

  static void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  static AppSettings get currentSettings => _settings;

  static String get currencySymbol => _settings.currencySymbol;
  static String get currencyCode => _settings.currencyCode;
  static int get decimalPlaces => _settings.decimalPlaces;

  // Legacy support
  static String get currency => _settings.currencySymbol;

  // ═══════════════════════════════════════════════════════════
  // CURRENCY — formats
  // ═══════════════════════════════════════════════════════════

  /// ⭐ صرف number (بغیر symbol) — legacy behavior
  /// استعمال: '${Formatters.formatAmountWithCurrency(x)}' — پرانا کوڈ کام کرے گا
  static String formatAmount(num amount) {
    if (!amount.isFinite) return '0';

    // Aagar num int hai, seedha handle
    if (amount is int) {
      final formatter = NumberFormat(
        _settings.decimalPlaces > 0
            ? '#,##0.${'0' * _settings.decimalPlaces}'
            : '#,##0',
        'en_US',
      );
      return formatter.format(amount);
    }

    final formatter = NumberFormat(
      _settings.decimalPlaces > 0
          ? '#,##0.${'0' * _settings.decimalPlaces}'
          : '#,##0',
      'en_US',
    );
    return formatter.format(amount);
  }

  /// ⭐ symbol کے ساتھ — "Rs 1,234" یا "$1,234.00"
  static String formatAmountWithCurrency(num amount) {
    return _settings.formatAmount(amount.toDouble());
  }

  /// ⭐ Compact — "Rs 1.2K", "Rs 1.5M"
  static String formatCompact(double amount) {
    return _settings.formatCompact(amount);
  }

  /// ⭐ پرانا formatCurrency — backward compatibility
  static String formatCurrency(double amount, {String? locale}) {
    return _settings.formatAmount(amount);
  }

  /// ⭐ پرانا formatCurrencyCompact
  static String formatCurrencyCompact(double amount, {String? locale}) {
    return _settings.formatCompact(amount);
  }

  // ═══════════════════════════════════════════════════════════
  // DATE — formatting
  // ═══════════════════════════════════════════════════════════
  static String formatDate(DateTime? date, {String format = 'dd/MM/yyyy'}) {
    if (date == null) return '--/--/----';
    return DateFormat(format).format(date);
  }

  static String formatDateWithTime(DateTime date) {
    return DateFormat('dd/MM/yyyy hh:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  // ═══════════════════════════════════════════════════════════
  // RELATIVE TIME
  // ═══════════════════════════════════════════════════════════
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'ابھی';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} منٹ پہلے';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} گھنٹے پہلے';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} دن پہلے';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} ہفتے پہلے';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} مہینے پہلے';
    } else {
      return '${(difference.inDays / 365).floor()} سال پہلے';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PHONE
  // ═══════════════════════════════════════════════════════════
  static String formatPhoneNumber(String phone) {
    if (phone.trim().isEmpty) return '';
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (clean.startsWith('+')) {
      clean = clean.substring(1);
    }
    if (clean.startsWith('00')) {
      clean = clean.substring(2);
    }
    if (clean.startsWith('92') && clean.length >= 11) {
      clean = '0' + clean.substring(2);
    }
    if (clean.length == 10 && !clean.startsWith('0')) {
      clean = '0' + clean;
    }

    return clean.isNotEmpty ? clean : phone;
  }

  static String toE164(String phone, {String defaultCountryCode = '+92'}) {
    final trimmed = phone.trim();
    String clean = trimmed.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';

    if (clean.startsWith('00')) {
      clean = clean.substring(2);
    }

    if (trimmed.startsWith('+')) {
      return '+$clean';
    }

    if (clean.startsWith('0')) {
      return '$defaultCountryCode${clean.substring(1)}';
    }

    if (clean.startsWith('92') && clean.length >= 11) {
      return '+$clean';
    }

    return '$defaultCountryCode$clean';
  }

  static String? normalizePhoneNumber(String phone,
      {String defaultCountryCode = '+92'}) {
    if (phone.trim().isEmpty) return null;

    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (clean.startsWith('00')) {
      clean = '+' + clean.substring(2);
    } else if (clean.startsWith('0')) {
      clean = defaultCountryCode + clean.substring(1);
    }

    if (!clean.startsWith('+')) {
      if (clean.startsWith('92') && clean.length >= 12) {
        clean = '+' + clean;
      } else {
        clean = defaultCountryCode + clean;
      }
    }

    final e164Regex = RegExp(r'^\+[1-9]\d{10,14}$');
    return e164Regex.hasMatch(clean) ? clean : null;
  }

  static bool isValidPhoneNumber(String phone,
      {String defaultCountryCode = '+92'}) {
    return normalizePhoneNumber(phone,
            defaultCountryCode: defaultCountryCode) !=
        null;
  }

  static String maskPhoneNumber(String phone) {
    String formatted = formatPhoneNumber(phone);
    if (formatted.length < 7) return '*******';
    return '${formatted.substring(0, 4)}*******';
  }

  // ═══════════════════════════════════════════════════════════
  // FILE SIZE
  // ═══════════════════════════════════════════════════════════
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1048576) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PERCENTAGE
  // ═══════════════════════════════════════════════════════════
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  // ═══════════════════════════════════════════════════════════
  // COMPACT NUMBERS
  // ═══════════════════════════════════════════════════════════
  static String formatNumberCompact(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DURATION
  // ═══════════════════════════════════════════════════════════
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // TEXT
  // ═══════════════════════════════════════════════════════════
  static String truncateText(String text, {int maxLength = 50}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  // ═══════════════════════════════════════════════════════════
  // SAFE PARSING
  // ═══════════════════════════════════════════════════════════
  static double safeParseDouble(String value) {
    try {
      return double.parse(value);
    } catch (e) {
      return 0.0;
    }
  }

  static int safeParseInt(String value) {
    try {
      return int.parse(value);
    } catch (e) {
      return 0;
    }
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // ═══════════════════════════════════════════════════════════
  // BALANCE
  // ═══════════════════════════════════════════════════════════
  static String formatBalance(double balance) {
    final sign = balance >= 0 ? '+' : '';
    return '$sign${_settings.currencySymbol} ${formatAmount(balance.abs())}';
  }

  static String formatPendingAmount(double amount) {
    return '${_settings.currencySymbol} ${formatAmount(amount)} بقایا';
  }

  // ═══════════════════════════════════════════════════════════
  // SANITIZATION
  // ═══════════════════════════════════════════════════════════
  static String sanitizeText(String text) {
    if (text.isEmpty) return text;

    String sanitized = text.replaceAll(RegExp(r'<[^>]*>'), '');
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    sanitized = sanitized.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    return sanitized.trim();
  }

  static bool containsProhibitedContent(String text) {
    final prohibited = [
      'froad',
      'fraud',
      'جعلی',
      'froud',
      'ناجائز',
      'haram',
      'sharab',
      'drugs',
      'weapon',
      'aslaha',
      'bomb',
      'ہیروئن',
      'چرس',
      'شراب'
    ];
    final normalized = text.toLowerCase();

    return prohibited.any((word) {
      final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
      return pattern.hasMatch(normalized);
    });
  }
}
