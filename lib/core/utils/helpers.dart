// lib/utils/helpers.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AppHelpers {
  // Phone validation - Improved regex for Pakistan numbers
  static bool isValidPhone(String phone) {
    final regex = RegExp(r'^(\+92|92|0)?3\d{9}$');
    return regex.hasMatch(phone);
  }

  // Email validation
  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  // Currency formatting
  static String formatCurrency(double amount, {String? locale}) {
    final format = NumberFormat.currency(
      locale: locale ?? 'ur_PK',
      symbol: 'RS ',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  // Compact currency formatting
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

  // Date with time formatting
  static String formatDateWithTime(DateTime date) {
    return DateFormat('dd/MM/yyyy hh:mm a').format(date);
  }

  // Time formatting
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  // Show snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Show confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isUrdu = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(isUrdu ? 'منسوخ' : cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  isUrdu ? 'تصدیق کریں' : confirmText,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Generate random ID
  static String generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${timestamp}_${random.nextInt(10000)}';
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  // Calculate percentage
  static double calculatePercentage(double part, double whole) {
    if (whole == 0) return 0.0;
    return (part / whole) * 100;
  }

  // Get initials from name
  static String getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Capitalize each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  // Format duration
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

  // Truncate text
  static String truncateText(String text, {int maxLength = 50}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Format balance with sign
  static String formatBalance(double balance) {
    final sign = balance >= 0 ? '+' : '';
    return '$sign RS ${balance.abs().toStringAsFixed(2)}';
  }

  // Format pending amount
  static String formatPendingAmount(double amount) {
    return 'RS ${amount.toStringAsFixed(2)} بقایا';
  }

  // Check if string contains numbers only
  static bool isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  // Get color based on amount and type
  static Color getAmountColor(double amount, String type) {
    if (type == 'income') return Colors.green;
    if (type == 'expense') return Colors.red;
    return amount >= 0 ? Colors.green : Colors.red;
  }

  // Validate URL
  static bool isValidUrl(String url) {
    final regex = RegExp(r'^(http|https):\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}');
    return regex.hasMatch(url);
  }

  // Format time ago
  static String formatTimeAgo(DateTime date) {
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

  // Get random color
  static Color getRandomColor() {
    final random = Random();
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[random.nextInt(colors.length)];
  }

  // Validate CNIC (Pakistan)
  static bool isValidCnic(String cnic) {
    final regex = RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$');
    return regex.hasMatch(cnic);
  }

  // Mask sensitive data
  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars * 2) return data;
    final firstPart = data.substring(0, visibleChars);
    final lastPart = data.substring(data.length - visibleChars);
    final masked = '*' * (data.length - visibleChars * 2);
    return '$firstPart$masked$lastPart';
  }

  // Format phone number for display
  static String formatPhoneNumber(String phone) {
    if (phone.startsWith('+92')) {
      return '+92 ${phone.substring(3, 6)} ${phone.substring(6, 9)} ${phone.substring(9)}';
    } else if (phone.startsWith('92')) {
      return '+92 ${phone.substring(2, 5)} ${phone.substring(5, 8)} ${phone.substring(8)}';
    } else if (phone.startsWith('0')) {
      return '+92 ${phone.substring(1, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}';
    }
    return phone;
  }

  // Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  // Calculate age from birth date
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // Get difference between two dates in days
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }

  // Validate name (only letters and spaces)
  static bool isValidName(String name) {
    final regex = RegExp(r'^[a-zA-Zآ-ی ]+$');
    return regex.hasMatch(name) && name.length >= 2;
  }

  // Validate amount (positive number)
  static bool isValidAmount(String amount) {
    final value = double.tryParse(amount);
    return value != null && value > 0;
  }

  // Get greeting based on time of day
  static String getGreeting({bool isUrdu = false}) {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return isUrdu ? 'صبح بخیر' : 'Good Morning';
    } else if (hour < 17) {
      return isUrdu ? 'دوپہر بخیر' : 'Good Afternoon';
    } else if (hour < 21) {
      return isUrdu ? 'شام بخیر' : 'Good Evening';
    } else {
      return isUrdu ? 'رات بخیر' : 'Good Night';
    }
  }

  // Debounce function
  static Function debounce(Function func, Duration delay) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(delay, () => func());
    };
  }

  // Throttle function
  static Function throttle(Function func, Duration delay) {
    Timer? timer;
    return () {
      if (timer == null) {
        func();
        timer = Timer(delay, () => timer = null);
      }
    };
  }
}
