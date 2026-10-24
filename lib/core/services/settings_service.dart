// lib/core/services/settings_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:account_app/core/models/app_settings_model.dart';
import 'package:account_app/core/utils/formatters.dart';

/// ═══════════════════════════════════════════════════════════════
/// SettingsService — ایپ کی سیٹنگز کو محفوظ اور لوڈ کرتا ہے
/// SharedPreferences (local) + Firestore (cloud sync)
/// ═══════════════════════════════════════════════════════════════
class SettingsService extends ChangeNotifier {
  static const String _prefsKey = 'app_settings_v1';

  AppSettings _settings = const AppSettings();
  bool _isLoading = false;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  /// ═══ Load from local on startup ═══
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _settings = AppSettings.fromMap(map);
        Formatters.updateSettings(_settings);
      }
    } catch (e) {
      debugPrint('SettingsService.loadSettings error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ═══ Save locally + cloud ═══
  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    Formatters.updateSettings(_settings);
    notifyListeners();

    // Local save
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(newSettings.toMap()));
    } catch (e) {
      debugPrint('SettingsService.save local error: $e');
    }

    // Cloud save (silent failure)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'appSettings': newSettings.toMap(),
          'appSettingsUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('SettingsService.save cloud error: $e');
    }
  }

  /// ═══ Load from cloud (on login) ═══
  Future<void> syncFromCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      final cloudSettings = data['appSettings'];
      if (cloudSettings is Map<String, dynamic>) {
        final loaded = AppSettings.fromMap(cloudSettings);
        _settings = loaded;
        Formatters.updateSettings(_settings);
        notifyListeners();

        // Local save too
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(loaded.toMap()));
      }
    } catch (e) {
      debugPrint('SettingsService.syncFromCloud error: $e');
    }
  }

  /// ═══ Convenience getters ═══
  String get currencySymbol => _settings.currencySymbol;
  String get currencyCode => _settings.currencyCode;
  int get decimalPlaces => _settings.decimalPlaces;

  /// ═══ Reset to default ═══
  Future<void> resetToDefaults() async {
    await updateSettings(const AppSettings());
  }
}