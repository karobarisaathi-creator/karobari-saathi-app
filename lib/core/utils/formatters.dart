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
    
    // اگر 92 سے شروع ہو رہا ہے تو اسے 0 سے بدل دیں
    if (clean.startsWith('92') && clean.length == 12) {
      clean = '0' + clean.substring(2);
    }
    
    // اگر نمبر 10 ہندسوں کا ہے اور 0 نہیں ہے تو 0 لگا دیں
    if (clean.length == 10 && !clean.startsWith('0')) {
      clean = '0' + clean;
    }

    // نمبر کی درست ترتیب کے لیے (03xx xxxxxxx)
    if (clean.length == 11) {
      return clean; // اسپیس ختم کر دی تاکہ آپ کے بتائے ہوئے اسٹائل 03001234567 میں آئے
    }
    
    return clean.isNotEmpty ? clean : phone;
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
}
