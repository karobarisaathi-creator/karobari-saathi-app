// lib/features/order/widgets/shop_card_widget.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/location_chip_widget.dart';
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
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover (Banner)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox(
                      height: 85,
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
                    top: 8,
                    left: 10,
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
                            shop.isOpen
                                ? (isUrdu ? 'کھلی ہے' : 'Open')
                                : (isUrdu ? 'بند ہے' : 'Closed'),
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
                ],
              ),

              // Body with Expanded to pin footer at absolute bottom
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top details (Name, Location, Delivery)
                      Column(
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
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.darkColor,
                                      fontFamily: fontFamily,
                                      letterSpacing: -0.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (shop.showRating && shop.reviews > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7E6),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            PhosphorIcons.star(
                                                PhosphorIconsStyle.fill),
                                            size: 10,
                                            color: AppTheme.verifiedGold),
                                        const SizedBox(width: 3),
                                        UrduAwareText('${shop.rating}',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFB45309))),
                                      ]),
                                ),
                              ],
                            ],
                          ),
                          if (shop.area.isNotEmpty || shop.latitude != null) ...[
                            const SizedBox(height: 4),
                            LocationChipWidget(
                              latitude: shop.latitude,
                              longitude: shop.longitude,
                              address: shop.area,
                              isUrdu: isUrdu,
                              isChip: false,
                              showAddress: shop.showArea,
                              showTime: true,
                              color: AppTheme.themeColor,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.themeColor,
                              ),
                            ),
                          ],
                          if (shop.showDeliveryInfo &&
                              (shop.deliveryTime.isNotEmpty ||
                                  shop.deliveryFee.isNotEmpty ||
                                  shop.minOrder.isNotEmpty)) ...[
                            const SizedBox(height: 6),
                            Wrap(spacing: 5, runSpacing: 5, children: [
                              if (shop.deliveryTime.isNotEmpty)
                                _buildInfoPill(
                                  PhosphorIcons.clock(),
                                  isUrdu
                                      ? 'ڈیلیوری: ${shop.deliveryTime}'
                                      : 'Delivery: ${shop.deliveryTime}',
                                  fontFamily: fontFamily,
                                ),
                              if (shop.deliveryFee.isNotEmpty)
                                _buildInfoPill(
                                  PhosphorIcons.truck(),
                                  isUrdu
                                      ? 'فیس: ${shop.deliveryFee}'
                                      : 'Fee: ${shop.deliveryFee}',
                                  green: shop.deliveryFee == '???',
                                  fontFamily: fontFamily,
                                ),
                            ]),
                          ],
                        ],
                      ),

                      // Footer anchored at absolute bottom (Fixed at bottom: Avatar + Owner Name + Items Count)
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.backgroundColor, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.darkColor.withValues(alpha: 0.1),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6.5),
                              child: ProfileInfoWidget(
                                name: shop.owner.isNotEmpty
                                    ? shop.owner
                                    : shop.name,
                                phone: '',
                                profileImage: shop.profileImageUrl,
                                showText: false,
                                customSize: 24,
                                borderRadius: 6.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (shop.showOwnerName && shop.owner.isNotEmpty)
                            Expanded(
                              child: UrduAwareText(
                                shop.owner,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.darkColor,
                                  fontFamily: fontFamily,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            const Spacer(),

                          if (shop.showItemsCount) ...[
                            if (shop.showOwnerName && shop.owner.isNotEmpty)
                              const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.themeColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UrduAwareText(
                                    '${shop.availableItemCount}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.themeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  UrduAwareText(
                                    isUrdu ? 'اشیاء دستیاب' : 'items available',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.themeColor,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
          size: 26,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: txtColor),
          const SizedBox(width: 3),
          _buildMixedText(
            text,
            baseStyle: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: txtColor,
            ),
            urduFontFamily: fontFamily,
          ),
        ],
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
