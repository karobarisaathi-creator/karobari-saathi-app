import 'package:flutter/material.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';

enum AppButtonVariant { primary, outlined, ghost }
enum AppButtonSize { small, large, mini }

class AppButton extends StatelessWidget {
  final String text;
  final String? loadingText;
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
    this.loadingText,
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
      height = 54.0;
      borderRadius = 12.0;
      fontSize = 16.0;
      horizontalPadding = 24.0;
    } else if (size == AppButtonSize.small) {
      height = 42.0;
      borderRadius = 20.0;
      fontSize = 13.0;
      horizontalPadding = 16.0;
    } else {
      // Mini
      height = 34.0;
      borderRadius = 17.0;
      fontSize = 11.0;
      horizontalPadding = 12.0;
    }

    final displayText = isLoading ? (loadingText ?? text) : text;

    Widget buttonContent = Stack(
      alignment: Alignment.center,
      children: [
        // Main Content (Icon + Animated Text sliding from top to bottom)
        Padding(
          padding: const EdgeInsets.only(bottom: 3.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLoading && icon != null) ...[
                Icon(icon, size: size == AppButtonSize.small ? 16 : (size == AppButtonSize.mini ? 14 : 20)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0.0, -1.0), // Slide from top to bottom
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
                    return SlideTransition(
                      position: slideAnimation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: UrduAwareText(
                    displayText,
                    key: ValueKey<String>(displayText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Bottom Progress Line (runs continuously until loading finishes)
        if (isLoading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(borderRadius)),
              child: SizedBox(
                height: 3.5,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: variant == AppButtonVariant.primary ? Colors.white70 : themeColor,
                ),
              ),
            ),
          ),
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
        child: buttonContent,
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
        child: buttonContent,
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
      child: buttonContent,
    );
  }
}
