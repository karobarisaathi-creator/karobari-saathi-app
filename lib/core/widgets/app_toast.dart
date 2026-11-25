// lib/core/widgets/app_toast.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';

class AppToast {
  static void show(
    BuildContext context, {
    required String title,
    String subtitle = 'Karobari Saathi',
    required IconData icon,
    required List<Color> gradient,
    required Color textColor,
    required Color iconColor,
  }) {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final localizedSubtitle = subtitle == 'Karobari Saathi'
        ? (isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi')
        : subtitle;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 12,
                16,
                14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.zero,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UrduAwareText(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: fontFamily,
                          ),
                        ),
                        if (localizedSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          UrduAwareText(
                            localizedSubtitle,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      if (overlayEntry.mounted) {
                        overlayEntry.remove();
                      }
                    },
                    child: Icon(Icons.close_rounded,
                        color: textColor.withValues(alpha: 0.7), size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static void success(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
      gradient: [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
      textColor: const Color(0xFF1B5E20),
      iconColor: const Color(0xFF2E7D32),
    );
  }

  static void info(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: PhosphorIcons.info(PhosphorIconsStyle.fill),
      gradient: [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
      textColor: const Color(0xFF0D47A1),
      iconColor: const Color(0xFF1565C0),
    );
  }

  static void warning(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: PhosphorIcons.warning(PhosphorIconsStyle.fill),
      gradient: [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
      textColor: const Color(0xFFF57F17),
      iconColor: const Color(0xFFFBC02D),
    );
  }

  static void error(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
      gradient: [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)],
      textColor: const Color(0xFFB71C1C),
      iconColor: const Color(0xFFC62828),
    );
  }
}
