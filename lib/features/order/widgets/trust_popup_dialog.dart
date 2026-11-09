// lib/features/order/widgets/trust_popup_dialog.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class TrustPopupDialog extends StatelessWidget {
  final String shopName;
  final String ownerName;
  final String area;
  final int customerCount;
  final int satisfiedCustomerPercent;
  final int billCount;
  final int itemsCount;
  final bool isUrdu;

  const TrustPopupDialog({
    super.key,
    required this.shopName,
    required this.ownerName,
    required this.area,
    required this.customerCount,
    required this.satisfiedCustomerPercent,
    required this.billCount,
    required this.itemsCount,
    required this.isUrdu,
  });

  static Future<void> show({
    required BuildContext context,
    required String shopName,
    required String ownerName,
    required String area,
    required int customerCount,
    required int satisfiedCustomerPercent,
    required int billCount,
    required int itemsCount,
    required bool isUrdu,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.darkColor.withValues(alpha: 0.55),
      builder: (_) => TrustPopupDialog(
        shopName: shopName,
        ownerName: ownerName,
        area: area,
        customerCount: customerCount,
        satisfiedCustomerPercent: satisfiedCustomerPercent,
        billCount: billCount,
        itemsCount: itemsCount,
        isUrdu: isUrdu,
      ),
    );
  }

  String _fmt(int n) {
    if (isUrdu) {
      if (n >= 100000) {
        return '${(n / 100000).toStringAsFixed(1).replaceAll('.0', '')} لاکھ';
      }
      if (n >= 1000) {
        return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')} ہزار';
      }
      return '$n';
    } else {
      if (n >= 1000) {
        return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
      }
      return '$n';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final satisfactionPercent = satisfiedCustomerPercent.clamp(0, 100);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Directionality(
        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // ─── Header (Green gradient) ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: isUrdu ? null : 0,
                    left: isUrdu ? 0 : null,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIcons.x(PhosphorIconsStyle.bold),
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      right: isUrdu ? 0 : 36,
                      left: isUrdu ? 36 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: isUrdu
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          shopName,
                          textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(height: 3),
                        UrduAwareText(
                          '${isUrdu ? 'از' : 'by'} $ownerName · $area',
                          textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: isUrdu
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            UrduAwareText(
                              _fmt(customerCount),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: fontFamily,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            UrduAwareText(
                              isUrdu ? 'کل خریدار' : 'total buyers',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.92),
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Body ───
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: isUrdu
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      isUrdu ? 'مطمئن خریدار' : 'Satisfied buyers',
                      fontFamily,
                    ),
                    const SizedBox(height: 7),
                    Row(
                      textDirection:
                          isUrdu ? TextDirection.rtl : TextDirection.ltr,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: customerCount == 0
                                  ? 0
                                  : satisfactionPercent / 100,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        UrduAwareText(
                          customerCount == 0 ? '—' : '$satisfactionPercent%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF047857),
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle(
                        isUrdu ? 'کاروباری سرگرمی' : 'Business activity',
                        fontFamily),
                    const SizedBox(height: 7),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.4,
                      children: [
                        _statCard(_fmt(customerCount),
                            isUrdu ? 'کل خریدار' : 'Total buyers', fontFamily),
                        _statCard(
                            '$itemsCount',
                            isUrdu ? 'دستیاب اشیاء' : 'Items available',
                            fontFamily),
                        _statCard('$billCount',
                            isUrdu ? 'فوری بل' : 'Quick Bills', fontFamily),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _sectionTitle(String text, String? fontFamily) {
    return UrduAwareText(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.5,
        fontFamily: fontFamily,
      ),
    );
  }

  Widget _statCard(String num, String lbl, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Column(
        crossAxisAlignment:
            isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UrduAwareText(
            num,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          UrduAwareText(
            lbl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
