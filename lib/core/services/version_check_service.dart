import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class VersionCheckService {
  static const String _lastDismissedKey = 'update_banner_dismissed_at';

  // یہ چیک کرے گا کہ کیا واقعی نیا ورژن دستیاب ہے اور یوزر نے حال ہی میں اسے ڈسمس نہیں کیا
  Future<Map<String, dynamic>?> getUpdateData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDismissedStr = prefs.getString(_lastDismissedKey);

      // اگر 48 گھنٹے سے کم وقت ہوا ہے تو بینر نہیں دکھائیں گے
      if (lastDismissedStr != null) {
        final lastDismissed = DateTime.parse(lastDismissedStr);
        if (DateTime.now().difference(lastDismissed).inHours < 48) {
          return null;
        }
      }

      final packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final versionDoc = await FirebaseFirestore.instance.collection('settings').doc('app_version').get();
      if (!versionDoc.exists) return null;

      final data = versionDoc.data();
      if (data == null) return null;

      String latestVersion = data['latest_version'] ?? currentVersion;
      
      if (_isNewVersionAvailable(currentVersion, latestVersion)) {
        return data;
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
    }
    return null;
  }

  // ڈسمس کا وقت محفوظ کرنا
  Future<void> dismissUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDismissedKey, DateTime.now().toIso8601String());
  }

  bool _isNewVersionAvailable(String current, String latest) {
    List<String> currentParts = current.split('.');
    List<String> latestParts = latest.split('.');

    for (int i = 0; i < latestParts.length; i++) {
      int latestPart = int.parse(latestParts[i]);
      int currentPart = i < currentParts.length ? int.parse(currentParts[i]) : 0;
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }
}
