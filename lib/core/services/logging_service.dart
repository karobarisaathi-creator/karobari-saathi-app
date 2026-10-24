import 'package:flutter/foundation.dart';

/// ایپ کے لاگز (Logs) کو منظم کرنے کے لیے سروس
/// یہ سروس ڈیبگنگ کے دوران مختلف پیغامات کو آئیکونز کے ساتھ دکھانے میں مدد دیتی ہے
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();

  factory LoggingService() {
    return _instance;
  }

  LoggingService._internal();

  /// عام معلومات فراہم کرنے کے لیے (مثلاً: سروس شروع ہو گئی)
  void info(String message) {
    debugPrint('ℹ️ INFO: $message');
  }

  /// ممکنہ خطرے یا انتباہ کے لیے (مثلاً: ڈیٹا موجود نہیں ہے)
  void warning(String message) {
    debugPrint('⚠️ WARNING: $message');
  }

  /// کسی خرابی یا ایرر کی صورت میں (بشمول ایرر کی تفصیل اور اسٹیک ٹریس)
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('❌ ERROR: $message');
    if (error != null) debugPrint('   Details: $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  /// صرف ڈیبگ موڈ میں تفصیلی معلومات دکھانے کے لیے
  void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 DEBUG: $message');
    }
  }
}
