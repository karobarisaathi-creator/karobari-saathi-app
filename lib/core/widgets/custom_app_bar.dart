// custom_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/theme_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title; // String یا Widget دونوں قبول کرے گا
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final Widget? leading;
  final bool? centerTitle;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 4,
    this.leading,
    this.centerTitle,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final isUrdu = languageService.isUrdu;

    return AppBar(
      title: title is Widget
        ? title
        : Text(
            title.toString(),
            style: TextStyle(
              fontFamily: isUrdu ? 'NooriNastaleeq' : null,
              fontSize: isUrdu ? 20 : 18,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
            ),
          ),
      leading:
          leading ??
          (showBackButton ? _buildBackButton(context, isUrdu) : null),
      automaticallyImplyLeading: false,
      actions: actions,
      backgroundColor:
          backgroundColor ??
          themeService.currentThemeData.appBarTheme.backgroundColor,
      foregroundColor:
          foregroundColor ??
          themeService.currentThemeData.appBarTheme.foregroundColor,
      elevation: elevation,
      centerTitle: centerTitle ?? (title is! Widget), // اگر ویجیٹ ہے تو سینٹر نہیں کرے گا
      bottom: bottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, bool isUrdu) {
    return IconButton(
      icon: Directionality(
          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          child: const Icon(Icons.arrow_back)),
      onPressed: onBackPressed ?? () => Navigator.pop(context),
      tooltip: isUrdu ? 'پیچھے جائیں' : 'Back',
    );
  }
}

class GradientAppBar extends CustomAppBar {
  final List<Color> gradientColors;

  const GradientAppBar({
    super.key,
    required super.title,
    super.actions,
    super.showBackButton = true,
    super.onBackPressed,
    this.gradientColors = const [Colors.green, Colors.lightGreen],
    super.elevation = 4,
    super.leading,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontFamily: isUrdu ? 'NooriNastaleeq' : null,
          fontSize: isUrdu ? 20 : 18,
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
          color: Colors.white,
        ),
      ),
      leading:
          leading ??
          (showBackButton ? _buildBackButton(context, isUrdu) : null),
      automaticallyImplyLeading: false,
      actions: actions,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      elevation: elevation,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    );
  }
}

