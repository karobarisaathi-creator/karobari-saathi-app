// lib/core/utils/formatters.dart

import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
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

  static String formatAmountWithoutCurrency(num amount) {
    return _settings.formatNumber(amount.toDouble());
  }

  static double? tryParseAmount(String value) {
    var normalized = value.trim();
    if (_settings.currencySymbol.isNotEmpty) {
      normalized = normalized.replaceAll(_settings.currencySymbol, '');
    }
    if (_settings.thousandSeparator.isNotEmpty) {
      normalized = normalized.replaceAll(_settings.thousandSeparator, '');
    }
    if (_settings.decimalSeparator != '.') {
      normalized = normalized.replaceAll(_settings.decimalSeparator, '.');
    }
    normalized = normalized.replaceAll(RegExp(r'\s'), '');
    return double.tryParse(normalized);
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
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    final parsed = _parsePhoneNumber(trimmed);
    if (parsed == null) return trimmed;

    final nationalFormat = parsed.formatNsn();
    if (parsed.isoCode == IsoCode.PK &&
        parsed.nsn.length == 10 &&
        parsed.nsn.startsWith('3')) {
      return nationalFormat.startsWith('0')
          ? nationalFormat
          : '0$nationalFormat';
    }
    return nationalFormat;
  }

  static String phoneComparisonKey(String phone) {
    final parsed = _parsePhoneNumber(phone);
    return (parsed?.international ?? phone).replaceAll(RegExp(r'\D'), '');
  }

  static bool phoneNumbersMatch(String first, String second) {
    final firstKey = phoneComparisonKey(first);
    final secondKey = phoneComparisonKey(second);
    if (firstKey.isEmpty || secondKey.isEmpty) return false;
    if (firstKey == secondKey) return true;

    final firstIsInternational = _isInternationalInput(first);
    final secondIsInternational = _isInternationalInput(second);
    if (firstIsInternational == secondIsInternational) {
      return false;
    }

    final internationalPhone = _parsePhoneNumber(
      firstIsInternational ? first : second,
    );
    if (internationalPhone == null) return false;

    final localNumber = firstIsInternational ? second : first;
    final localDigits = localNumber.replaceAll(RegExp(r'\D'), '');
    final localNsn = localDigits.startsWith('0')
        ? localDigits.substring(1)
        : _parsePhoneNumber(localNumber)?.nsn ?? localDigits;
    return internationalPhone.nsn == localNsn;
  }

  static bool phoneMatchesSearch(String phone, String query) {
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');
    if (queryDigits.isEmpty) return false;

    final candidates = <String>{queryDigits};
    if (queryDigits.startsWith('00')) candidates.add(queryDigits.substring(2));
    if (queryDigits.startsWith('92')) candidates.add(queryDigits.substring(2));
    if (queryDigits.startsWith('0')) candidates.add(queryDigits.substring(1));

    final key = phoneComparisonKey(phone);
    return candidates
        .any((candidate) => candidate.isNotEmpty && key.contains(candidate));
  }

  static List<String> phoneNumberLookupCandidates(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const [];

    final parsed = _parsePhoneNumber(trimmed);
    final localFormat = parsed == null ? null : formatPhoneNumber(trimmed);
    return <String>{
      trimmed,
      digits,
      if (parsed != null) parsed.international,
      if (parsed != null) parsed.international.replaceFirst('+', ''),
      if (parsed != null) '00${parsed.international.substring(1)}',
      if (parsed != null) parsed.nsn,
      if (parsed != null) parsed.formatNsn(),
      if (localFormat != null) localFormat,
      if (localFormat != null) localFormat.replaceAll(RegExp(r'\D'), ''),
    }.toList(growable: false);
  }

  static PhoneNumber? _parsePhoneNumber(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;

    var input = trimmed;
    if (input.startsWith('00')) {
      input = '+${input.substring(2)}';
    } else if (!input.startsWith('+')) {
      final digits = input.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('92') && digits.length == 12) {
        input = '+$digits';
      }
    }

    PhoneNumber? tryParse(String value) {
      try {
        final parsed = PhoneNumber.parse(value, callerCountry: IsoCode.PK);
        return parsed.isValidLength() ? parsed : null;
      } on PhoneNumberException {
        return null;
      }
    }

    final parsed = tryParse(input);
    if (parsed != null) return parsed;

    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (!input.startsWith('+') &&
        digits.length > 10 &&
        !digits.startsWith('0')) {
      return tryParse('+$digits');
    }
    return null;
  }

  static bool _isInternationalInput(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return trimmed.startsWith('+') ||
        trimmed.startsWith('00') ||
        (digits.startsWith('92') && digits.length == 12) ||
        (digits.length > 10 && !digits.startsWith('0'));
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
