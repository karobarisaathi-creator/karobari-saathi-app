// lib/utils/helpers.dart
//
// Formatting (money, dates, phone, text size, parsing, initials, ...) lives in
// Formatters. This file keeps only validation, small UI helpers, IDs and
// date/colour utilities. The app uses whole numbers only (no decimals).
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class AppHelpers {
  // ═══════════════════════════════════════════════════════════
  // VALIDATION
  // (phone numbers: use Formatters.isValidPhoneNumber)
  // ═══════════════════════════════════════════════════════════

  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }

  static bool isValidUrl(String url) {
    final text = url.trim();
    if (text.isEmpty || text.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
  }

  /// Pakistan CNIC, with or without dashes: 12345-1234567-1 or 1234512345671.
  static bool isValidCnic(String cnic) {
    return RegExp(r'^\d{5}-?\d{7}-?\d$').hasMatch(cnic.trim());
  }

  /// Person or business name: letters of any language (Urdu included), digits,
  /// spaces and . - ' & ; at least 2 characters with at least one letter.
  static bool isValidName(String name) {
    final text = name.trim();
    if (text.length < 2) return false;
    final allowed = RegExp(
      r"^[\p{L}\p{M}0-9 .\-'’&\u200C]+$",
      unicode: true,
    );
    final hasLetter = RegExp(r'\p{L}', unicode: true);
    return allowed.hasMatch(text) && hasLetter.hasMatch(text);
  }

  /// A positive whole amount. Commas are allowed ("1,000"); decimals are not.
  static bool isValidAmount(String amount) {
    final value = int.tryParse(amount.trim().replaceAll(',', ''));
    return value != null && value > 0;
  }

  /// Digits only (commas allowed). No sign, no decimals, no exponent.
  static bool isNumeric(String str) {
    return RegExp(r'^\d+$').hasMatch(str.trim().replaceAll(',', ''));
  }

  // ═══════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (isError) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  /// [isDestructive] colours the confirm button red; pass false for
  /// harmless confirmations.
  static Future<bool> showConfirmationDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isUrdu = false,
    bool isDestructive = true,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: UrduAwareText(title),
            content: UrduAwareText(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: UrduAwareText(isUrdu ? 'منسوخ' : cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: UrduAwareText(
                  isUrdu ? 'تصدیق کریں' : confirmText,
                  style: isDestructive
                      ? const TextStyle(color: Colors.red)
                      : null,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ═══════════════════════════════════════════════════════════
  // IDs
  // ═══════════════════════════════════════════════════════════

  static int _idCounter = 0;
  static final Random _secureRandom = Random.secure();

  /// Unique within this app run (counter) and across devices (random salt),
  /// so many records created in the same millisecond can never collide.
  /// Safe as a Hive key and a Firestore document id.
  static String generateId() {
    _idCounter = (_idCounter + 1) & 0xFFFFF;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _secureRandom.nextInt(1 << 32).toRadixString(36);
    return '${timestamp}_${_idCounter}_$salt';
  }

  // ═══════════════════════════════════════════════════════════
  // NUMBERS
  // ═══════════════════════════════════════════════════════════

  /// Returns 0-100 (not 0-1). 0 when [whole] is 0.
  static double calculatePercentage(double part, double whole) {
    if (whole == 0) return 0.0;
    return (part / whole) * 100;
  }

  // ═══════════════════════════════════════════════════════════
  // TEXT
  // ═══════════════════════════════════════════════════════════

  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      final firstChar = String.fromCharCode(word.runes.first);
      return firstChar.toUpperCase() + word.substring(firstChar.length);
    }).join(' ');
  }

  /// Hides the middle of [data]. Short values never show more than a quarter
  /// of each side, so a 4-6 digit code is not exposed.
  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    if (data.isEmpty) return data;
    final visible =
        data.length <= visibleChars * 2 ? data.length ~/ 4 : visibleChars;
    final masked = '*' * (data.length - visible * 2);
    return '${data.substring(0, visible)}$masked'
        '${data.substring(data.length - visible)}';
  }

  // ═══════════════════════════════════════════════════════════
  // COLOURS
  // ═══════════════════════════════════════════════════════════

  static const List<Color> _palette = [
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

  /// Colour by plain income/expense type. For ledger entries prefer
  /// [getLedgerColor], which follows the debit/credit side.
  static Color getAmountColor(double amount, String type) {
    if (type == 'income') return AppTheme.incomeColor;
    if (type == 'expense') return AppTheme.expenseColor;
    return amount >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor;
  }

  /// Same side as the ledger and the receipt: debit (بنام) is red,
  /// credit (جمع) is green. A Quick Bill sale is therefore red, not green.
  static Color getLedgerColor(Transaction transaction) {
    final columns = AccountBalanceUtils.transactionColumns(transaction);
    return columns.debit > columns.credit
        ? AppTheme.expenseColor
        : AppTheme.incomeColor;
  }

  /// Different colour on every call. Do not call inside build().
  static Color getRandomColor() {
    return _palette[Random().nextInt(_palette.length)];
  }

  /// Same text always gives the same colour (stable across rebuilds).
  static Color colorFromText(String text) {
    var hash = 0;
    for (final unit in text.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  // ═══════════════════════════════════════════════════════════
  // DATES
  // ═══════════════════════════════════════════════════════════

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isYesterday(DateTime date) {
    final now = DateTime.now();
    // The DateTime constructor rolls day 0 back to the previous month, and a
    // calendar date never suffers from daylight-saving shifts.
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  /// Whole calendar days from [from] to [to] (time of day ignored).
  static int daysBetween(DateTime from, DateTime to) {
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }

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
}

// ═════════════════════════════════════════════════════════════
// TIMING
//
// Keep one instance per widget and dispose it:
//
//   final _search = Debouncer(const Duration(milliseconds: 300));
//   onChanged: (v) => _search.run(() {
//     if (mounted) setState(() => _query = v);
//   }),
//   @override
//   void dispose() { _search.dispose(); super.dispose(); }
// ═════════════════════════════════════════════════════════════

/// Runs the last [run] call only after [delay] without a newer call.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => cancel();
}

/// Lets one [run] call through per [interval]; calls inside it are ignored.
class Throttler {
  Throttler(this.interval);

  final Duration interval;
  Timer? _timer;

  void run(VoidCallback action) {
    if (_timer?.isActive ?? false) return;
    action();
    _timer = Timer(interval, () {});
  }

  void dispose() => _timer?.cancel();
}