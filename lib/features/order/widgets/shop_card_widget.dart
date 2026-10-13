// lib/features/order/widgets/shop_card_widget.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/models/shop_model.dart';

class ShopCardWidget extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;

  const ShopCardWidget({
    super.key,
    required this.shop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              // Cover
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox(
                      height: 92,
                      width: double.infinity,
                      child: shop.bannerImageUrl?.trim().isNotEmpty == true
                          ? Image.network(
                              shop.bannerImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildBannerFallback(),
                            )
                          : _buildBannerFallback(),
                    ),
                  ),

                  // Open/Closed badge
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: shop.isOpen
                                  ? AppTheme.incomeColor
                                  : AppTheme.expenseColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          UrduAwareText(
                            shop.isOpen ? 'کھلی ہے' : 'بند ہے',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: shop.isOpen
                                  ? AppTheme.incomeColor
                                  : AppTheme.expenseColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Profile image overlay
                  Positioned(
                    bottom: -26,
                    right: 14,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.darkColor.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: ProfileInfoWidget(
                              name: shop.owner.isNotEmpty
                                  ? shop.owner
                                  : shop.name,
                              phone: '',
                              profileImage: shop.profileImageUrl,
                              showText: false,
                              customSize: 50,
                              borderRadius: 13,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          left: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.verifiedGold,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: Icon(
                              PhosphorIcons.checkCircle(
                                  PhosphorIconsStyle.fill),
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 34, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Rating
                    Row(
                      children: [
                        Expanded(
                          child: UrduAwareText(
                            shop.name,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                                color: AppTheme.darkColor, fontFamily: fontFamily,
                                letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (shop.showRating && shop.reviews > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFFFF7E6),
                                borderRadius: BorderRadius.circular(7)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                                  size: 11, color: AppTheme.verifiedGold),
                              const SizedBox(width: 3),
                              UrduAwareText('${shop.rating}',
                                  style: const TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFB45309))),
                            ]),
                          ),
                        ],
                      ],
                    ),
                    if (shop.showOwnerName && shop.owner.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(PhosphorIcons.user(), size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(child: UrduAwareText(shop.owner,
                            textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary, fontFamily: fontFamily),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                    if ((shop.showArea && shop.area.isNotEmpty) ||
                        (shop.showDistance && shop.distance.isNotEmpty)) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        if (shop.showArea && shop.area.isNotEmpty) ...[
                          Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                              size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(child: UrduAwareText(shop.area,
                              textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary, fontFamily: fontFamily),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                        if (shop.showDistance && shop.distance.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
                              size: 12, color: AppTheme.themeColor),
                          const SizedBox(width: 3),
                          UrduAwareText(shop.distance,
                              style: const TextStyle(fontSize: 10.5,
                                  fontWeight: FontWeight.w800, color: AppTheme.themeColor)),
                        ],
                      ]),
                    ],
                    if (shop.showDeliveryInfo &&
                        (shop.deliveryTime.isNotEmpty || shop.deliveryFee.isNotEmpty ||
                            shop.minOrder.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (shop.deliveryTime.isNotEmpty)
                          _buildInfoPill(PhosphorIcons.clock(), shop.deliveryTime,
                              fontFamily: fontFamily),
                        if (shop.deliveryFee.isNotEmpty)
                          _buildInfoPill(PhosphorIcons.truck(), shop.deliveryFee,
                              green: shop.deliveryFee == '???', fontFamily: fontFamily),
                        if (shop.minOrder.isNotEmpty)
                          _buildInfoPill(PhosphorIcons.money(), shop.minOrder,
                              blue: true, fontFamily: fontFamily),
                      ]),
                    ],
                    if (shop.showTags && shop.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 5, runSpacing: 5,
                          children: shop.tags.map((tag) => _buildTag(tag,
                              fontFamily: fontFamily)).toList()),
                    ],
                    const SizedBox(height: 12),

                    // Footer
                    Row(
                      children: [
                        if (shop.showItemsCount) Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UrduAwareText(
                                '${shop.availableItemCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.themeColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              UrduAwareText(
                                'آئٹمز دستیاب',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.themeColor,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UrduAwareText(
                                'دکان دیکھیں',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamily: fontFamily,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                PhosphorIcons.caretLeft(),
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF334155), Color(0xFF64748B)],
        ),
      ),
      child: Center(
        child: Icon(
          PhosphorIcons.storefront(),
          size: 30,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _buildInfoPill(
    IconData icon,
    String text, {
    bool green = false,
    bool blue = false,
    String? fontFamily,
  }) {
    final bgColor = green
        ? const Color(0xFFF0FDF4)
        : (blue ? const Color(0xFFEFF6FF) : const Color(0xFFF5F7FA));
    final txtColor = green
        ? AppTheme.incomeColor
        : (blue ? AppTheme.themeColor : AppTheme.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: txtColor),
          const SizedBox(width: 4),
          _buildMixedText(
            text,
            baseStyle: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: txtColor,
            ),
            urduFontFamily: fontFamily,
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, {String? fontFamily}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.themeColor.withValues(alpha: 0.08),
            AppTheme.themeColor.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: AppTheme.themeColor.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: UrduAwareText(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppTheme.themeColor,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildMixedText(
    String text, {
    required TextStyle baseStyle,
    required String? urduFontFamily,
  }) {
    final latinOrNumber = RegExp(
      r'[0-9]+(?:[.,][0-9]+)*(?:-[0-9]+(?:[.,][0-9]+)*)?|[A-Za-z]+',
    );
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in latinOrNumber.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(fontFamily: urduFontFamily),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(fontFamily: null),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(fontFamily: urduFontFamily),
        ),
      );
    }

    return UrduAwareText.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }
}
