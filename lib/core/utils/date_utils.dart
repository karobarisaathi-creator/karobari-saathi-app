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

  // Whole calendar days between two dates, ignoring the time of day.
  static int daysBetween(DateTime from, DateTime to) {
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }

  // Get week number
  static int getWeekNumber(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final days = date.difference(firstDay).inDays;
    return ((days + firstDay.weekday - 1) / 7).floor() + 1;
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
}
