class AppConstants {
  // App Info
  static const String appName = 'کھاتہ ایپ';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  
  // Database Constants
  static const String accountsBox = 'accounts';
  static const String transactionsBox = 'transactions';
  static const String categoriesBox = 'categories';
  static const String professionsBox = 'professions';
  static const String settingsBox = 'settings';
  
  // Date Formats
  static const String displayDateFormat = 'dd/MM/yyyy';
  static const String displayTimeFormat = 'hh:mm a';
  
  // Currency
  static const String currencySymbol = 'RS';
  static const String currencyCode = 'PKR';
  
  // Default Categories
  static const List<String> defaultIncomeCategories = [
    'فروخت',
    'خدمات', 
    'سرمایہ کاری',
    'تحفہ',
    'دیگر'
  ];
  
  static const List<String> defaultExpenseCategories = [
    'خریداری',
    'بلز',
    'ٹرانسپورٹ',
    'خوراک',
    'تفریح',
    'صحت',
    'دیگر'
  ];
}

class RouteConstants {
  static const String dashboard = '/dashboard';
  static const String login = '/login';
  static const String reports = '/reports';
  static const String parties = '/parties';
  static const String addParty = '/addParty';
  static const String shareAccount = '/shareAccount';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String professions = '/professions';
  static const String addTransaction = '/addTransaction';
  static const String profileSetup = '/profileSetup';
}