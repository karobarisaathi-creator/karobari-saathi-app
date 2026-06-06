// date_utils.dart
import 'package:intl/intl.dart';

class DateUtils {
  // Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  // Get start of week
  static DateTime startOfWeek(DateTime date) {
    final weekDay = date.weekday;
    return date.subtract(Duration(days: weekDay - 1));
  }

  // Get end of week
  static DateTime endOfWeek(DateTime date) {
    final weekDay = date.weekday;
    return date.add(Duration(days: DateTime.daysPerWeek - weekDay));
  }

  // Get start of month
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // Get end of month
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }

  // Get start of year
  static DateTime startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  // Get end of year
  static DateTime endOfYear(DateTime date) {
    return DateTime(date.year, 12, 31, 23, 59, 59, 999);
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

  // Check if date is this week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final start = startOfWeek(now);
    final end = endOfWeek(now);
    return date.isAfter(start) && date.isBefore(end);
  }

  // Check if date is this month
  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  // Check if date is this year
  static bool isThisYear(DateTime date) {
    return date.year == DateTime.now().year;
  }

  // Get days in month
  static int daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  // Get week number
  static int getWeekNumber(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final days = date.difference(firstDay).inDays;
    return ((days + firstDay.weekday - 1) / 7).floor() + 1;
  }

  // Format date for display
  static String formatForDisplay(DateTime date) {
    if (isToday(date)) {
      return 'آج';
    } else if (isYesterday(date)) {
      return 'کل';
    } else if (isThisWeek(date)) {
      return DateFormat('EEEE').format(date);
    } else if (isThisYear(date)) {
      return DateFormat('dd MMM').format(date);
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  // Get month name
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

  // Get day name
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

  // Calculate age
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // Add business days
  static DateTime addBusinessDays(DateTime date, int days) {
    DateTime result = date;
    int addedDays = 0;

    while (addedDays < days) {
      result = result.add(Duration(days: 1));

      // Skip weekends (Saturday = 6, Sunday = 7)
      if (result.weekday != 6 && result.weekday != 7) {
        addedDays++;
      }
    }

    return result;
  }

  // Get business days between two dates
  static int businessDaysBetween(DateTime from, DateTime to) {
    int businessDays = 0;
    DateTime current = from;

    while (current.isBefore(to)) {
      if (current.weekday != 6 && current.weekday != 7) {
        businessDays++;
      }
      current = current.add(Duration(days: 1));
    }

    return businessDays;
  }

  // Is holiday (Pakistan holidays)
  static bool isHoliday(DateTime date) {
    // Major Pakistan holidays
    final holidays = [
      DateTime(date.year, 3, 23), // Pakistan Day
      DateTime(date.year, 5, 1), // Labour Day
      DateTime(date.year, 8, 14), // Independence Day
      DateTime(date.year, 9, 6), // Defence Day
      DateTime(date.year, 12, 25), // Quaid-e-Azam Day
    ];

    return holidays.any(
      (holiday) =>
          holiday.year == date.year &&
          holiday.month == date.month &&
          holiday.day == date.day,
    );
  }

  // Get next business day
  static DateTime nextBusinessDay(DateTime date) {
    DateTime nextDay = date.add(Duration(days: 1));

    while (nextDay.weekday == 6 || nextDay.weekday == 7 || isHoliday(nextDay)) {
      nextDay = nextDay.add(Duration(days: 1));
    }

    return nextDay;
  }

  // Format duration between dates
  static String formatDurationBetween(DateTime from, DateTime to) {
    final difference = to.difference(from);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years سال';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months مہینے';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ہفتے';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} دن';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} گھنٹے';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} منٹ';
    } else {
      return '${difference.inSeconds} سیکنڈ';
    }
  }
}
