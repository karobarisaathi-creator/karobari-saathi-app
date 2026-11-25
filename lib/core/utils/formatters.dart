// lib/core/utils/formatters.dart

import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:account_app/core/models/app_settings_model.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final bool allowDecimals;
  final int maxDecimalPlaces;

  const CurrencyInputFormatter({
    this.allowDecimals = false,
    this.maxDecimalPlaces = 2,
  }) : assert(maxDecimalPlaces >= 0);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final settings = Formatters.currentSettings;
    final selectionOffset =
        newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final beforeCursor = newValue.text.substring(0, selectionOffset);
    final digitsBeforeCursor =
        beforeCursor.replaceAll(RegExp(r'\D'), '').length;
    final decimalWasBeforeCursor = allowDecimals &&
        (beforeCursor.contains(settings.decimalSeparator) ||
            (settings.decimalSeparator != '.' && beforeCursor.contains('.')));
    final formattedText = _formatInput(
      newValue.text,
      settings.thousandSeparator,
      settings.decimalSeparator,
    );
    if (formattedText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    var cursor = 0;
    var digitsSeen = 0;
    while (cursor < formattedText.length && digitsSeen < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(formattedText[cursor])) digitsSeen++;
      cursor++;
    }
    if (decimalWasBeforeCursor) {
      final separatorIndex = formattedText.indexOf(settings.decimalSeparator);
      if (separatorIndex >= 0 && cursor <= separatorIndex) {
        cursor = separatorIndex + 1;
      }
    }
    cursor = cursor.clamp(0, formattedText.length);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  String _formatInput(String input, String grouping, String decimal) {
    var text = input.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (text.isEmpty) return '';

    final dotIndex = text.lastIndexOf('.');
    final commaIndex = text.lastIndexOf(',');
    String integerPart;
    String fractionPart = '';
    if (dotIndex >= 0 || commaIndex >= 0) {
      final decimalIndex = dotIndex > commaIndex ? dotIndex : commaIndex;
      final separator = text[decimalIndex];
      final isConfiguredGrouping = separator == grouping &&
          separator != decimal &&
          (dotIndex < 0 || commaIndex < 0);
      if (isConfiguredGrouping) {
        integerPart = text;
      } else {
        integerPart = text.substring(0, decimalIndex);
        if (allowDecimals && maxDecimalPlaces > 0) {
          final fractionDigits =
              text.substring(decimalIndex + 1).replaceAll(RegExp(r'\D'), '');
          fractionPart = fractionDigits.substring(
            0,
            fractionDigits.length.clamp(0, maxDecimalPlaces),
          );
        }
      }
    } else {
      integerPart = text;
    }

    final digits = integerPart.replaceAll(RegExp(r'\D'), '');
    final grouped = _groupDigits(digits, grouping);
    if (fractionPart.isEmpty) return grouped;
    return '$grouped$decimal$fractionPart';
  }

  String _groupDigits(String digits, String separator) {
    if (digits.length <= 3 || separator.isEmpty) return digits;
    final groups = <String>[];
    var end = digits.length;
    while (end > 3) {
      groups.insert(0, digits.substring(end - 3, end));
      end -= 3;
    }
    groups.insert(0, digits.substring(0, end));
    return groups.join(separator);
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
  static int get decimalPlaces => 0;

  // Legacy support
  static String get currency => _settings.currencySymbol;

  // ═══════════════════════════════════════════════════════════
  // CURRENCY — formats
  // ═══════════════════════════════════════════════════════════

  /// ⭐ صرف number (بغیر symbol) — legacy behavior
  /// استعمال: '${Formatters.formatAmountWithCurrency(x)}' — پرانا کوڈ کام کرے گا
  static String formatAmount(num amount) {
    if (!amount.isFinite) return '0';
    return _currencySettings.formatNumber(amount.roundToDouble());
  }

  /// ⭐ symbol کے ساتھ — "Rs 1,234" یا "$1,234.00"
  static String formatAmountWithCurrency(num amount) {
    return _currencySettings.formatAmount(amount.roundToDouble());
  }

  static String formatAmountWithoutCurrency(num amount) {
    return _currencySettings.formatNumber(amount.roundToDouble());
  }

  static AppSettings get _currencySettings =>
      _settings.copyWith(decimalPlaces: 0);

  static double? tryParseAmount(String value, {bool allowDecimals = false}) {
    var normalized = value.trim();
    if (_settings.currencySymbol.isNotEmpty) {
      normalized = normalized.replaceAll(_settings.currencySymbol, '');
    }
    normalized = normalized.replaceAll(RegExp(r'\s'), '');
    if (normalized.isEmpty ||
        !RegExp(r'^[+-]?[0-9.,]+$').hasMatch(normalized)) {
      return null;
    }

    var sign = '';
    if (normalized.startsWith('-') || normalized.startsWith('+')) {
      sign = normalized[0];
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) return null;

    final dotIndex = normalized.lastIndexOf('.');
    final commaIndex = normalized.lastIndexOf(',');
    String? decimalSeparator;
    String? groupingSeparator;
    if (dotIndex >= 0 && commaIndex >= 0) {
      decimalSeparator = dotIndex > commaIndex ? '.' : ',';
      groupingSeparator = decimalSeparator == '.' ? ',' : '.';
    } else if (dotIndex >= 0 || commaIndex >= 0) {
      final separator = dotIndex >= 0 ? '.' : ',';
      final occurrences = separator == '.'
          ? '.'.allMatches(normalized).length
          : ','.allMatches(normalized).length;
      final configuredDecimal = separator == _settings.decimalSeparator;
      final configuredGrouping = separator == _settings.thousandSeparator;
      final isValidGrouping = _isGroupedInteger(normalized, separator);

      if (configuredDecimal && occurrences == 1) {
        decimalSeparator = separator;
      } else if (configuredGrouping && isValidGrouping) {
        groupingSeparator = separator;
      } else if (occurrences == 1 &&
          _settings.decimalPlaces > 0 &&
          !isValidGrouping) {
        decimalSeparator = separator;
      } else if (isValidGrouping) {
        groupingSeparator = separator;
      } else {
        return null;
      }
    }

    if (groupingSeparator != null &&
        decimalSeparator != null &&
        normalized
            .substring(0, normalized.lastIndexOf(decimalSeparator))
            .contains(decimalSeparator)) {
      return null;
    }
    if (groupingSeparator != null) {
      final integerPart = decimalSeparator == null
          ? normalized
          : normalized.substring(0, normalized.lastIndexOf(decimalSeparator));
      if (integerPart.contains(groupingSeparator) &&
          !_isGroupedInteger(integerPart, groupingSeparator)) {
        return null;
      }
      normalized = normalized.replaceAll(groupingSeparator, '');
    }
    if (decimalSeparator != null) {
      final decimalIndex = normalized.lastIndexOf(decimalSeparator);
      if (decimalIndex < 0 ||
          normalized.indexOf(decimalSeparator) != decimalIndex) {
        return null;
      }
      normalized = normalized.replaceRange(decimalIndex, decimalIndex + 1, '.');
    }

    final amount = double.tryParse('$sign$normalized');
    if (amount == null || !amount.isFinite) return null;
    return allowDecimals ? amount : amount.roundToDouble();
  }

  static bool _isGroupedInteger(String value, String separator) {
    final escapedSeparator = RegExp.escape(separator);
    return RegExp('^[0-9]{1,3}(?:$escapedSeparator[0-9]{3})+\$')
        .hasMatch(value);
  }

  /// ⭐ Compact — "Rs 1.2K", "Rs 1.5M"
  static String formatCompact(double amount) {
    if (!amount.isFinite) return '0';

    final roundedAmount = amount.round();
    final absAmount = roundedAmount.abs();
    if (absAmount >= 1000000) {
      return _formatCompactCurrency(
        roundedAmount,
        (absAmount / 1000000).round(),
        'M',
      );
    }
    if (absAmount >= 1000) {
      return _formatCompactCurrency(
        roundedAmount,
        (absAmount / 1000).round(),
        'K',
      );
    }
    return formatAmountWithCurrency(roundedAmount);
  }

  static String _formatCompactCurrency(
    int amount,
    int compactValue,
    String suffix,
  ) {
    final sign = amount < 0 ? '-' : '';
    final value = '$compactValue$suffix';
    return _settings.currencyBefore
        ? '$sign${_settings.currencySymbol} $value'
        : '$sign$value ${_settings.currencySymbol}';
  }

  /// ⭐ پرانا formatCurrency — backward compatibility
  static String formatCurrency(double amount, {String? locale}) {
    return formatAmountWithCurrency(amount);
  }

  /// ⭐ پرانا formatCurrencyCompact
  static String formatCurrencyCompact(double amount, {String? locale}) {
    return formatCompact(amount);
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

  static String getMonthName(int month, {bool isUrdu = false}) {
    final urduMonths = [
      'جنوری',
      'فروری',
      'مارچ',
      'اپریل',
      'مئی',
      'جون',
      'جولائی',
      'اگست',
      'ستمبر',
      'اکتوبر',
      'نومبر',
      'دسمبر',
    ];

    final englishMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return isUrdu ? urduMonths[month - 1] : englishMonths[month - 1];
  }

  static String getDayName(int day, {bool isUrdu = false}) {
    final urduDays = ['اتوار', 'پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ'];

    final englishDays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    return isUrdu ? urduDays[day - 1] : englishDays[day - 1];
  }

  // ═══════════════════════════════════════════════════════════
  // RELATIVE TIME
  // ═══════════════════════════════════════════════════════════
  static String formatRelativeTime(DateTime date, {bool isUrdu = true}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return isUrdu ? 'ابھی' : 'Just now';
    } else if (difference.inMinutes < 60) {
      return isUrdu
          ? '${difference.inMinutes} منٹ پہلے'
          : '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return isUrdu
          ? '${difference.inHours} گھنٹے پہلے'
          : '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return isUrdu
          ? '${difference.inDays} دن پہلے'
          : '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return isUrdu ? '$weeks ہفتے پہلے' : '$weeks wk ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return isUrdu ? '$months مہینے پہلے' : '$months mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return isUrdu ? '$years سال پہلے' : '$years yr ago';
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

  /// صرف اسکرین پر دکھانے کے لیے، محفوظ یا موازنہ نہ کریں۔
  static String displayPhone(String phone) {
    final formatted = formatPhoneNumber(phone);
    return formatted.isEmpty ? '' : '\u2066$formatted\u2069';
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
    if (queryDigits.length < 3) return false;

    final candidates = <String>{queryDigits};
    if (queryDigits.startsWith('00') && queryDigits.length > 4) {
      candidates.add(queryDigits.substring(2));
    }
    if (queryDigits.startsWith('92') && queryDigits.length > 5) {
      candidates.add(queryDigits.substring(2));
    }
    if (queryDigits.startsWith('0') && queryDigits.length > 3) {
      candidates.add(queryDigits.substring(1));
    }

    final key = phoneComparisonKey(phone);
    final localDigits = formatPhoneNumber(phone).replaceAll(RegExp(r'\D'), '');
    return candidates.any(
      (candidate) =>
          candidate.length >= 3 &&
          (key.contains(candidate) || localDigits.contains(candidate)),
    );
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

  static PhoneNumber? _parsePhoneNumber(
    String phone, {
    String defaultCountryCode = '+92',
  }) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;

    PhoneNumber? tryParse(String value) {
      try {
        final parsed = PhoneNumber.parse(value);
        return parsed.isValidLength() ? parsed : null;
      } on PhoneNumberException {
        return null;
      }
    }

    var input = trimmed;
    if (input.startsWith('00')) {
      input = '+${input.substring(2)}';
    } else if (!input.startsWith('+')) {
      final digits = input.replaceAll(RegExp(r'\D'), '');
      final countryCode = defaultCountryCode.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith(countryCode) &&
          digits.length > countryCode.length) {
        input = '+$digits';
      } else if (digits.length > 10 && !digits.startsWith('0')) {
        final international = tryParse('+$digits');
        if (international != null) return international;
        input = '+$countryCode$digits';
      } else {
        final nationalDigits =
            digits.startsWith('0') ? digits.substring(1) : digits;
        input = '+$countryCode$nationalDigits';
      }
    }

    final parsed = tryParse(input);
    if (parsed != null) return parsed;
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
    return _parsePhoneNumber(
          phone,
          defaultCountryCode: defaultCountryCode,
        )?.international ??
        '';
  }

  static String? normalizePhoneNumber(String phone,
      {String defaultCountryCode = '+92'}) {
    return _parsePhoneNumber(
      phone,
      defaultCountryCode: defaultCountryCode,
    )?.international;
  }

  static bool isValidPhoneNumber(String phone,
      {String defaultCountryCode = '+92'}) {
    return normalizePhoneNumber(phone,
            defaultCountryCode: defaultCountryCode) !=
        null;
  }

  static String maskPhoneNumber(String phone) {
    final formatted = formatPhoneNumber(phone);
    if (formatted.length < 7) return '*******';
    return '\u2066${formatted.substring(0, 4)}*******\u2069';
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
    if (!value.isFinite) return '0.0%';
    return '${value.toStringAsFixed(1)}%';
  }

  // ═══════════════════════════════════════════════════════════
  // COMPACT NUMBERS
  // ═══════════════════════════════════════════════════════════
  static String formatNumberCompact(int number) {
    final absNumber = number.abs();
    if (absNumber < 1000) {
      return number.toString();
    } else if (absNumber < 999500) {
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
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first))
        .join();
    return initials.isEmpty ? '?' : initials.toUpperCase();
  }

  // ═══════════════════════════════════════════════════════════
  // SAFE PARSING
  // ═══════════════════════════════════════════════════════════
  static double safeParseDouble(String value) {
    return tryParseAmount(value, allowDecimals: true) ?? 0.0;
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
    final rounded = balance.roundToDouble();
    final sign = rounded < 0 ? '-' : '+';
    return '$sign${_currencySettings.formatAmount(rounded.abs())}';
  }

  static String formatPendingAmount(double amount, {bool isUrdu = true}) {
    final suffix = isUrdu ? 'بقایا' : 'pending';
    return '${formatAmountWithCurrency(amount)} $suffix';
  }

  // ═══════════════════════════════════════════════════════════
  // SANITIZATION
  // ═══════════════════════════════════════════════════════════
  static String sanitizeText(String text) {
    if (text.isEmpty) return text;

    var sanitized = text.replaceAll(
      RegExp(
        r'</?(?:script|style|iframe|object|embed|svg|math|html|body|div|span|p|br|a|img|b|i|u|strong|em|form|input|button|textarea|select|option|meta|link|title|head)(?:\s[^<>]*)?\s*/?>',
        caseSensitive: false,
      ),
      '',
    );
    sanitized =
        sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    sanitized = sanitized.replaceAll(RegExp(r'[\u200B\uFEFF]'), '');

    return sanitized.trim();
  }
}
