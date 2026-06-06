import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService with ChangeNotifier {
  Locale _currentLocale = const Locale('ur', 'PK');
  TextDirection _textDirection = TextDirection.rtl;

  Locale get currentLocale => _currentLocale;
  TextDirection get textDirection => _textDirection;
  bool get isUrdu => _currentLocale.languageCode == 'ur';
  bool get isEnglish => _currentLocale.languageCode == 'en';

  LanguageService() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language') ?? 'ur';
    _currentLocale = Locale(languageCode, languageCode == 'ur' ? 'PK' : 'US');
    _textDirection = languageCode == 'ur' ? TextDirection.rtl : TextDirection.ltr;
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;

    _currentLocale = Locale(languageCode, languageCode == 'ur' ? 'PK' : 'US');
    _textDirection = languageCode == 'ur' ? TextDirection.rtl : TextDirection.ltr;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);

    notifyListeners();
  }

  String getFontFamily(String text) {
    if (_currentLocale.languageCode == 'ur') {
      final urduRegex = RegExp(r'[\u0600-\u06FF]');
      return urduRegex.hasMatch(text) ? 'NooriNastaleeq' : ''; // Default system font for English
    }
    return ''; // Default system font
  }

  TextDirection getTextDirection(String text) {
    if (_currentLocale.languageCode == 'ur') {
      final urduRegex = RegExp(r'[\u0600-\u06FF]');
      final englishRegex = RegExp(r'[a-zA-Z]');

      bool hasUrdu = urduRegex.hasMatch(text);
      bool hasEnglish = englishRegex.hasMatch(text);

      if (hasUrdu && !hasEnglish) return TextDirection.rtl;
      if (!hasUrdu && hasEnglish) return TextDirection.ltr;
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }
}
