import 'package:account_app/core/services/database_service.dart';

class BillNumbering {
  static const String nextNumberSettingKey = 'next_bill_number';
  static const String legacyQuickBillSettingKey =
      'quick_bill_next_bill_number';

  static String? loadNextNumber(DatabaseService databaseService) {
    final sharedNumber =
        databaseService.getSetting(nextNumberSettingKey)?.toString().trim();
    if (sharedNumber != null && sharedNumber.isNotEmpty) return sharedNumber;

    final legacyNumber = databaseService
        .getSetting(legacyQuickBillSettingKey)
        ?.toString()
        .trim();
    if (legacyNumber != null && legacyNumber.isNotEmpty) return legacyNumber;
    return null;
  }

  static String increment(String billNumber) {
    final trimmedNumber = billNumber.trim();
    final match = RegExp(r'^(.*?)(\d+)$').firstMatch(trimmedNumber);
    if (match == null) return '$trimmedNumber-1';

    final prefix = match.group(1)!;
    final digits = match.group(2)!;
    final number = int.tryParse(digits);
    if (number == null) return '$trimmedNumber-1';

    return '$prefix${(number + 1).toString().padLeft(digits.length, '0')}';
  }

  static Future<void> saveNextNumber(
    DatabaseService databaseService,
    String currentNumber,
  ) {
    return databaseService.saveSetting(
      nextNumberSettingKey,
      increment(currentNumber),
    );
  }
}
