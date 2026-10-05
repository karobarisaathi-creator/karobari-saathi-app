// lib/core/widgets/app_toast.dart

import 'package:flutter/material.dart';

class AppToast {
  static void show(
    BuildContext context, {
    required String title,
    String subtitle = 'Karobari Saathi',
    required IconData icon,
    required List<Color> gradient,
  }) {
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
                    color: gradient.first.withValues(alpha: 0.3),
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
                    child: Icon(icon, color: gradient.first, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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
      icon: Icons.check_rounded,
      gradient: [const Color(0xFF00D68F), const Color(0xFF00C896)],
    );
  }

  static void info(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.info_outline_rounded,
      gradient: [const Color(0xFF1A9FB0), const Color(0xFF1790A5)],
    );
  }

  static void warning(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.priority_high_rounded,
      gradient: [const Color(0xFFF43F5E), const Color(0xFFEC4899)],
    );
  }

  static void error(BuildContext context, String title,
      {String subtitle = 'Karobari Saathi'}) {
    show(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.error_outline_rounded,
      gradient: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
    );
  }
}
