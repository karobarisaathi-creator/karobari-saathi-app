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
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: gradient.last, size: 24),
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
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: fontFamily,
                          ),
                        ),
                        if (localizedSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          UrduAwareText(
                            localizedSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
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
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
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
      icon: PhosphorIcons.checkCircle(),
      gradient: [const Color(0xFF00966B), const Color(0xFF007A55)],
    );
  }

  static void info(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: PhosphorIcons.info(),
      gradient: [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
    );
  }

  static void warning(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: PhosphorIcons.warning(),
      gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
    );
  }

  static void error(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: PhosphorIcons.warningCircle(),
      gradient: [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
    );
  }
}
