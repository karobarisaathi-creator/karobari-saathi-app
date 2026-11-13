// lib/features/accounts/widgets/party_trust_popup.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class PartyTrustPopup extends StatelessWidget {
  final double? trustScore;
  final bool isUrdu;
  final String? fontFamily;

  const PartyTrustPopup({
    super.key,
    required this.trustScore,
    required this.isUrdu,
    this.fontFamily,
  });

  static Future<void> show({
    required BuildContext context,
    required double? trustScore,
    required bool isUrdu,
    String? fontFamily,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.darkColor.withValues(alpha: 0.55),
      builder: (_) => PartyTrustPopup(
        trustScore: trustScore,
        isUrdu: isUrdu,
        fontFamily: fontFamily,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Color helpers
  // ═══════════════════════════════════════════════════════════
  String _getColorClass() {
    final score = trustScore;
    if (score == null) return 'grey';
    if (score >= 80) return 'green';
    if (score >= 60) return 'amber';
    if (score >= 40) return 'orange';
    return 'red';
  }

  Color _getBadgeColor() {
    switch (_getColorClass()) {
      case 'green':
        return const Color(0xFF16A34A);
      case 'amber':
        return const Color(0xFFD97706);
      case 'orange':
        return const Color(0xFFEA580C);
      case 'red':
        return const Color(0xFFDC2626);
      default:
        return AppTheme.textSecondary;
    }
  }

  // Background / border colors
  Color _getBgStart() {
    switch (_getColorClass()) {
      case 'green':
        return const Color(0xFFECFDF5);
      case 'amber':
        return const Color(0xFFFFFBEB);
      case 'orange':
        return const Color(0xFFFFF7ED);
      case 'red':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF9FAFB);
    }
  }

  Color _getBgEnd() {
    switch (_getColorClass()) {
      case 'green':
        return const Color(0xFFD1FAE5);
      case 'amber':
        return const Color(0xFFFEF3C7);
      case 'orange':
        return const Color(0xFFFFEDD5);
      case 'red':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getBorderColor() {
    switch (_getColorClass()) {
      case 'green':
        return const Color(0xFFA7F3D0);
      case 'amber':
        return const Color(0xFFFDE68A);
      case 'orange':
        return const Color(0xFFFDBA74);
      case 'red':
        return const Color(0xFFFECACA);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 5 Shields (Plain Shield without check)
  // ═══════════════════════════════════════════════════════════
  List<Widget> _buildShields() {
    final color = _getBadgeColor();

    final score = trustScore;
    final exactShields = score == null ? 0.0 : score / 20;
    final fullShields = exactShields.floor();
    final remainder = exactShields - fullShields;
    final hasHalf = remainder >= 0.5;

    Widget shieldAt(int index) {
      if (index < fullShields) {
        return _shieldWidget(
          color: color,
          isFilled: true,
        );
      } else if (index == fullShields && hasHalf) {
        return _shieldWidget(
          color: color,
          isHalf: true,
        );
      } else {
        return _shieldWidget(color: color, isEmpty: true);
      }
    }

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          shieldAt(0),
          const SizedBox(width: 8),
          shieldAt(1),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          shieldAt(2),
          const SizedBox(width: 8),
          shieldAt(3),
          const SizedBox(width: 8),
          shieldAt(4),
        ],
      ),
    ];
  }

  Widget _shieldWidget({
    required Color color,
    bool isFilled = false,
    bool isHalf = false,
    bool isEmpty = false,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0x1A000000),
                Color(0x1A000000),
              ],
            ).createShader(bounds),
            child: Icon(
              PhosphorIcons.shield(PhosphorIconsStyle.fill),
              size: 34,
              color: Colors.white,
            ),
          ),
          if (isFilled)
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.85),
                  color,
                ],
              ).createShader(bounds),
              child: Icon(
                PhosphorIcons.shield(PhosphorIconsStyle.fill),
                size: 34,
                color: Colors.white,
              ),
            ),
          if (isHalf)
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.5, 0.5],
                colors: [
                  color,
                  Colors.black.withValues(alpha: 0.10),
                ],
              ).createShader(bounds),
              child: Icon(
                PhosphorIcons.shield(PhosphorIconsStyle.fill),
                size: 34,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_getBgStart(), _getBgEnd()],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _getBorderColor(), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkColor.withValues(alpha: 0.25),
              blurRadius: 35,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UrduAwareText(
              isUrdu ? 'بھروسہ پوائنٹ' : 'Trust Point',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: badgeColor,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            // ═══ BIG NUMBER ═══
            UrduAwareText(
              trustScore == null ? '—' : '${trustScore!.round()}%',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: badgeColor,
                height: 1,
                letterSpacing: -1.5,
                fontFamily: null,
              ),
            ),
            const SizedBox(height: 12),

            // ═══ 5 SHIELDS ═══
            Column(children: _buildShields()),
          ],
        ),
      ),
    );
  }
}
