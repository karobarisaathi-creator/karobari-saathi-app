import 'package:flutter/material.dart';

class AppTheme {
  // آپ کے بتائے ہوئے رنگ
  static const Color themeColor = Color(0xFF1D6ED6); // ZALOOQ Account Theme Color
  static const Color darkColor = Color(0xFF123248);
  static const Color lightColor = Color(0xFFFFFFFF);
  static const Color goldColor = Color(0xFF607D8B); // سرمئی رنگ (Grey/BlueGrey)
  static const Color textSecondary = Color(0xFF757575);
  static const Color incomeColor = Color(0xFF515D11); // Green for Received (Olive Green)
  static const Color expenseColor = Color(0xFFC83120); // گہرا سرخ رنگ (Cinnabar Red)
  static const Color verifiedGold = Color(0xFFDAA520); // Richer Darker Gold
  static const Color scaffoldBackground = Color(0xFFFFFFFF);

  // Dark Mode Colors
  static const Color darkScaffoldBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: themeColor,
      scaffoldBackgroundColor: lightColor,
      splashColor: themeColor.withOpacity(0.1),
      highlightColor: Colors.transparent,
      hoverColor: themeColor.withOpacity(0.05),
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeColor,
        primary: themeColor,
        secondary: darkColor,
        surface: lightColor,
        onSurface: darkColor,
        surfaceTint: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: themeColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: themeColor,
      scaffoldBackgroundColor: darkScaffoldBackground,
      colorScheme: const ColorScheme.dark(
        primary: themeColor,
        secondary: themeColor,
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: themeColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
