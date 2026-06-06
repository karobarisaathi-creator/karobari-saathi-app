// lib/core/services/usage_limit_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsageLimitService {
  static const String _dailySearchesKey = 'daily_searches';
  static const String _lastResetDateKey = 'last_reset_date';
  static const String _monthlySearchesKey = 'monthly_searches';
  static const String _lastMonthResetKey = 'last_month_reset';
  static const String _dailyScansKey = 'daily_scans';

  // Free user limits
  final int freeDailyLimit = 5;
  final int freeMonthlyLimit = 50;
  final int freeScanLimit = 3;

  // ==================== PREMIUM CHECK ====================
  
  /// Check if user has premium
  Future<bool> _isPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    try {
      // Check Firestore for premium status
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      return doc.data()?['isPremium'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // ==================== RESET COUNTERS ====================
  
  /// Reset daily counters if needed
  Future<void> _resetDailyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastReset = prefs.getString(_lastResetDateKey) ?? '';

    if (lastReset != today) {
      await prefs.setInt(_dailySearchesKey, 0);
      await prefs.setInt(_dailyScansKey, 0);
      await prefs.setString(_lastResetDateKey, today);
    }
  }

  /// Reset monthly counters if needed
  Future<void> _resetMonthlyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final lastMonthReset = prefs.getString(_lastMonthResetKey) ?? '';

    if (lastMonthReset != currentMonth) {
      await prefs.setInt(_monthlySearchesKey, 0);
      await prefs.setString(_lastMonthResetKey, currentMonth);
    }
  }

  // ==================== CHECK FUNCTIONS ====================
  
  /// Check if user can search
  Future<Map<String, dynamic>> canSearch() async {
    if (await _isPremium()) {
      return {'allowed': true};
    }

    await _resetDailyIfNeeded();
    await _resetMonthlyIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    final dailySearches = prefs.getInt(_dailySearchesKey) ?? 0;
    final monthlySearches = prefs.getInt(_monthlySearchesKey) ?? 0;

    if (dailySearches >= freeDailyLimit) {
      return {
        'allowed': false,
        'reason': 'daily_limit',
        'message': 'آپ آج کی 5 سرچ کی حد پار کر چکے ہیں۔ کل دوبارہ کوشش کریں۔',
        'limit': freeDailyLimit,
        'used': dailySearches,
        'remaining': 0,
      };
    }

    if (monthlySearches >= freeMonthlyLimit) {
      return {
        'allowed': false,
        'reason': 'monthly_limit',
        'message': 'آپ اس ماہ کی 50 سرچ کی حد پار کر چکے ہیں۔ اگلے مہینے دوبارہ کوشش کریں۔',
        'limit': freeMonthlyLimit,
        'used': monthlySearches,
        'remaining': 0,
      };
    }

    return {
      'allowed': true,
      'remaining': freeDailyLimit - dailySearches,
      'dailyUsed': dailySearches,
      'monthlyUsed': monthlySearches,
    };
  }

  /// Check if user can scan image
  Future<Map<String, dynamic>> canScan() async {
    if (await _isPremium()) {
      return {'allowed': true};
    }

    await _resetDailyIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    final dailyScans = prefs.getInt(_dailyScansKey) ?? 0;

    if (dailyScans >= freeScanLimit) {
      return {
        'allowed': false,
        'reason': 'scan_limit',
        'message': 'آپ آج کی 3 تصویر اسکین کی حد پار کر چکے ہیں۔ کل دوبارہ کوشش کریں۔',
        'limit': freeScanLimit,
        'used': dailyScans,
        'remaining': 0,
      };
    }

    return {
      'allowed': true,
      'remaining': freeScanLimit - dailyScans,
      'used': dailyScans,
    };
  }

  // ==================== INCREMENT FUNCTIONS ====================
  
  /// Increment search count
  Future<void> incrementSearch() async {
    if (await _isPremium()) return;

    final prefs = await SharedPreferences.getInstance();
    final dailySearches = (prefs.getInt(_dailySearchesKey) ?? 0) + 1;
    final monthlySearches = (prefs.getInt(_monthlySearchesKey) ?? 0) + 1;

    await prefs.setInt(_dailySearchesKey, dailySearches);
    await prefs.setInt(_monthlySearchesKey, monthlySearches);
  }

  /// Increment scan count
  Future<void> incrementScan() async {
    if (await _isPremium()) return;

    final prefs = await SharedPreferences.getInstance();
    final dailyScans = (prefs.getInt(_dailyScansKey) ?? 0) + 1;
    await prefs.setInt(_dailyScansKey, dailyScans);
  }

  // ==================== GET REMAINING LIMITS ====================
  
  /// Get remaining limits for display
  Future<Map<String, dynamic>> getRemainingLimits() async {
    if (await _isPremium()) {
      return {
        'isPremium': true,
        'dailyRemaining': 'Unlimited',
        'monthlyRemaining': 'Unlimited',
        'scansRemaining': 'Unlimited',
      };
    }

    await _resetDailyIfNeeded();
    await _resetMonthlyIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    final dailySearches = prefs.getInt(_dailySearchesKey) ?? 0;
    final monthlySearches = prefs.getInt(_monthlySearchesKey) ?? 0;
    final dailyScans = prefs.getInt(_dailyScansKey) ?? 0;

    return {
      'isPremium': false,
      'dailyRemaining': freeDailyLimit - dailySearches,
      'monthlyRemaining': freeMonthlyLimit - monthlySearches,
      'scansRemaining': freeScanLimit - dailyScans,
      'dailyUsed': dailySearches,
      'monthlyUsed': monthlySearches,
      'scansUsed': dailyScans,
      'dailyLimit': freeDailyLimit,
      'monthlyLimit': freeMonthlyLimit,
      'scanLimit': freeScanLimit,
    };
  }
}
