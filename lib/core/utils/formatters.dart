// formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  // Currency formatting
  static String formatCurrency(double amount, {String? locale}) {
    final format = NumberFormat.currency(
      locale: locale ?? 'ur_PK',
      symbol: 'RS ',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  static String formatCurrencyCompact(double amount, {String? locale}) {
    final format = NumberFormat.compactCurrency(
      locale: locale ?? 'ur_PK',
      symbol: 'RS ',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  // Date formatting
  static String formatDate(DateTime date, {String format = 'dd/MM/yyyy'}) {
    return DateFormat(format).format(date);
  }

  static String formatDateWithTime(DateTime date) {
    return DateFormat('dd/MM/yyyy hh:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  // Relative time formatting
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

  // Phone number formatting to local format (03xx xxxxxxx)
  static String formatPhoneNumber(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');

    // E.164 conversion for international consistency
    if (clean.startsWith('92') && clean.length == 12) {
      return '0${clean.substring(2)}';
    }

    if (clean.length == 10 && !clean.startsWith('0')) {
      return '0$clean';
    }

    return clean.isNotEmpty ? clean : phone;
  }

  /// Converts any phone number to E.164 format (e.g. +923001234567)
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

  /// Robust International Phone Normalization (E.164)
  static String? normalizePhoneNumber(String phone, {String defaultCountryCode = '+92'}) {
    if (phone.trim().isEmpty) return null;
    
    // Remove all non-digits except a leading plus
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Handle leading zeros (common in Pakistan/UK etc.)
    if (clean.startsWith('00')) {
      clean = '+' + clean.substring(2);
    } else if (clean.startsWith('0')) {
      clean = defaultCountryCode + clean.substring(1);
    }
    
    // Ensure leading plus
    if (!clean.startsWith('+')) {
      // If it starts with a country code but no plus (e.g. 92300...)
      if (clean.startsWith('92') && clean.length >= 12) {
        clean = '+' + clean;
      } else {
        clean = defaultCountryCode + clean;
      }
    }
    
    // Final E.164 Validation: +[1-9][0-9]{10,14}
    final e164Regex = RegExp(r'^\+[1-9]\d{10,14}$');
    return e164Regex.hasMatch(clean) ? clean : null;
  }

  /// Validates a phone number for E.164 compatibility.
  static bool isValidPhoneNumber(String phone,
      {String defaultCountryCode = '+92'}) {
    return normalizePhoneNumber(phone,
            defaultCountryCode: defaultCountryCode) !=
        null;
  }

  /// Masks a phone number for privacy (e.g. 0300*******)
  static String maskPhoneNumber(String phone) {
    String formatted = formatPhoneNumber(phone);
    if (formatted.length < 7) return '*******';
    return '${formatted.substring(0, 4)}*******';
  }

  // File size formatting
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

  // Percentage formatting
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  // Number compact formatting
  static String formatNumberCompact(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
  }

  // Duration formatting
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

  // Text truncation
  static String truncateText(String text, {int maxLength = 50}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Initials from name
  static String getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  // Safe parse double
  static double safeParseDouble(String value) {
    try {
      return double.parse(value);
    } catch (e) {
      return 0.0;
    }
  }

  // Safe parse int
  static int safeParseInt(String value) {
    try {
      return int.parse(value);
    } catch (e) {
      return 0;
    }
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Format balance with sign
  static String formatBalance(double balance) {
    final sign = balance >= 0 ? '+' : '';
    return '${sign}RS ${balance.abs().toStringAsFixed(2)}';
  }

  // Format pending amount
  static String formatPendingAmount(double amount) {
    return 'RS ${amount.toStringAsFixed(2)} بقایا';
  }

  /// Enterprise-grade text sanitization
  /// Removes HTML tags, control characters, and suspicious unicode patterns.
  static String sanitizeText(String text) {
    if (text.isEmpty) return text;
    
    // 1. Remove HTML tags
    String sanitized = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // 2. Remove non-printable control characters (ASCII 0-31 and 127)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    // 3. Remove suspicious zero-width unicode characters used in exploits
    sanitized = sanitized.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    
    return sanitized.trim();
  }

  /// Checks for prohibited keywords (fraud, banned items, etc.) with variations
  static bool containsProhibitedContent(String text) {
    final prohibited = [
      'froad', 'fraud', 'جعلی', 'froud', 'ناجائز', 'haram', 'sharab', 'drugs', 
      'weapon', 'aslaha', 'bomb', 'ہیروئن', 'چرس', 'شراب'
    ];
    final normalized = text.toLowerCase();
    
    // Check for exact words and common obfuscations
    return prohibited.any((word) {
      final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
      return pattern.hasMatch(normalized);
    });
  }
}
