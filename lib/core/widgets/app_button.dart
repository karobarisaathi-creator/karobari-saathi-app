import 'package:flutter/material.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';

enum AppButtonVariant { primary, outlined, ghost }
enum AppButtonSize { small, large, mini }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Color? color;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.small,
    this.color,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    
    final themeColor = color ?? AppTheme.themeColor;
    
    double height;
    double borderRadius;
    double fontSize;
    double horizontalPadding;

    if (size == AppButtonSize.large) {
      height = 52.0;
      borderRadius = 12.0;
      fontSize = 16.0;
      horizontalPadding = 24.0;
    } else if (size == AppButtonSize.small) {
      height = 38.0;
      borderRadius = 20.0;
      fontSize = 13.0;
      horizontalPadding = 16.0;
    } else {
      // Mini
      height = 30.0;
      borderRadius = 15.0;
      fontSize = 11.0;
      horizontalPadding = 12.0;
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary ? Colors.white : themeColor,
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: size == AppButtonSize.small ? 16 : 20),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ],
    );

    if (variant == AppButtonVariant.outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: themeColor,
          side: BorderSide(color: themeColor.withOpacity(onPressed == null ? 0.3 : 1.0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        ),
        child: content,
      );
    }

    if (variant == AppButtonVariant.ghost) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: themeColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        ),
        child: content,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        minimumSize: Size(isFullWidth ? double.infinity : 0, height),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      ),
      child: content,
    );
  }
}
