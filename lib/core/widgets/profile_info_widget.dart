import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/models/account_model.dart';
import 'category_chip.dart';

class ProfileInfoWidget extends StatefulWidget {
  final String name;
  final String phone;
  final String? profileImage;
  final String? category;
  final String? address;
  final DateTime? date;
  final bool showDate;
  final bool isLarge;
  final bool isCentered;
  final bool showText;
  final bool isVerticalCategory;
  final String? topLabel;
  final bool isStore;
  final Color? textColor;
  final Color? subtitleColor;
  final Color? categoryColor;
  final bool hasUpdate;
  final bool isVerified;
  final bool isFavorite;
  final Widget? suffix;
  final Widget? bottom;
  final Widget? categorySuffix;
  final double? customSize;
  final double? borderRadius;
  final double verticalSpacing;
  final String? reputationLabel;
  final Color? reputationColor;
  final Color? reputationBgColor;
  final bool isAddressBold;
  final Color? addressColor;

  const ProfileInfoWidget({
    super.key,
    required this.name,
    required this.phone,
    this.profileImage,
    this.category,
    this.address,
    this.date,
    this.showDate = false,
    this.isLarge = false,
    this.isCentered = false,
    this.showText = true,
    this.isVerticalCategory = false,
    this.topLabel,
    this.isStore = false,
    this.textColor,
    this.subtitleColor,
    this.categoryColor,
    this.hasUpdate = false,
    this.isVerified = false,
    this.isFavorite = false,
    this.suffix,
    this.bottom,
    this.categorySuffix,
    this.customSize,
    this.borderRadius,
    this.verticalSpacing = 4.0,
    this.reputationLabel,
    this.reputationColor,
    this.reputationBgColor,
    this.isAddressBold = false,
    this.addressColor,
  });

  @override
  State<ProfileInfoWidget> createState() => _ProfileInfoWidgetState();
}

class _ProfileInfoWidgetState extends State<ProfileInfoWidget> {
  String _getAvatarForName(String name) {
    if (name.isEmpty) return 'assets/avatars/avatar.svg';
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % 8;
    if (index == 0) return 'assets/avatars/avatar.svg';
    return 'assets/avatars/avatar ($index).svg';
  }

  String _getTranslatedCategory(String category, bool isUrdu) {
    if (!isUrdu) return category;

    final key = category.trim().toLowerCase();

    try {
      // صرف CategoryChip کی لسٹ سے میچ کرنے کی کوشش کریں
      final match = CategoryChip.partyCategories.firstWhere((c) =>
          c.id.toLowerCase() == key ||
          c.labelEn.toLowerCase() == key ||
          c.labelUr == category.trim());
      return match.labelUr;
    } catch (_) {
      // اگر لسٹ میں نہ ملے تو اصل ٹیکسٹ ہی واپس کر دیں (جو شاید پہلے سے ہی اردو ہو یا کوئی سسٹم کیٹگری ہو)
      return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    final effectiveTextColor = widget.textColor ?? AppTheme.darkColor;
    final effectiveSubtitleColor =
        widget.subtitleColor ?? AppTheme.textSecondary;

    final String displayCategory = widget.category != null
        ? _getTranslatedCategory(widget.category!, isUrdu)
        : '';

    // Default values
    String displayName = widget.name.trim().isEmpty
        ? (isUrdu ? 'نامعلوم' : 'Unknown')
        : widget.name;
    String? displayImage = widget.profileImage;

    final double size = widget.customSize ?? (widget.isLarge ? 50 : 36);
    final double radius = widget.borderRadius ?? 12.0; // Enforced 12 radius as requested

    // Check if the phone field actually contains Urdu text (like 'Verified Profile')
    bool phoneHasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(widget.phone);

    // Build the Image Widget
    Widget imagePart = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Main Image Container
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: AppTheme.darkColor.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: _buildCoreImage(displayImage, displayName, radius, size),
            ),
          ),

          // Small Update Badge
          if (widget.hasUpdate)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.themeColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Return only image if text is not needed to prevent Row overflow in tight spaces
    if (!widget.showText) return imagePart;

    // Centered Vertical Layout (New Support)
    if (widget.isCentered) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          imagePart,
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.isLarge ? 20 : 16,
                    fontWeight: fontWeight,
                    color: effectiveTextColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
          if (widget.phone.isNotEmpty)
            Text(
              Formatters.formatPhoneNumber(widget.phone),
              style: TextStyle(
                fontSize: 12,
                color: effectiveSubtitleColor,
                fontFamily: phoneHasUrdu ? fontFamily : '',
              ),
            ),
        ],
      );
    }

    // Default Row Layout
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        imagePart,
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Allow to grow if needed
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.topLabel != null && widget.topLabel!.isNotEmpty)
                    Text(
                      widget.topLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: effectiveSubtitleColor.withOpacity(0.7),
                        fontFamily: fontFamily,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: widget.isLarge ? 20 : 16,
                                  fontWeight: fontWeight,
                                  color: effectiveTextColor,
                                  fontFamily: fontFamily,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            if (widget.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                                size: widget.isLarge ? 18 : 14,
                                color: AppTheme.verifiedGold,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.suffix != null) ...[
                        const SizedBox(width: 8),
                        widget.suffix!,
                      ],
                    ],
                  ),
                ],
              ),
              if (widget.isVerticalCategory && displayCategory.isNotEmpty) ...[
                SizedBox(height: widget.verticalSpacing),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayCategory,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.categoryColor ?? AppTheme.themeColor,
                          fontFamily: fontFamily,
                          fontWeight: fontWeight,
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.categorySuffix != null) ...[
                      const SizedBox(width: 8),
                      widget.categorySuffix!,
                    ],
                  ],
                ),
              ],
              if (widget.phone.isNotEmpty) ...[
                SizedBox(height: widget.verticalSpacing),
                Text(
                  Formatters.formatPhoneNumber(widget.phone),
                  style: TextStyle(
                    fontSize: 13,
                    color: effectiveSubtitleColor,
                    fontFamily: phoneHasUrdu ? fontFamily : '',
                  ),
                ),
              ],
              if (widget.address != null && widget.address!.isNotEmpty) ...[
                SizedBox(height: widget.verticalSpacing),
                Text(
                  widget.address!,
                  style: TextStyle(
                      fontSize: 13,
                      color: widget.addressColor ?? effectiveSubtitleColor,
                      fontFamily: fontFamily,
                      fontWeight: widget.isAddressBold ? FontWeight.w900 : fontWeight,
                      height: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (widget.bottom != null) ...[
                SizedBox(height: widget.verticalSpacing),
                widget.bottom!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoreImage(String? displayImage, String displayName, double radius, double size) {
    if (displayImage == null || displayImage.isEmpty) {
      return _buildPlaceholderImage(displayName, radius, size);
    }

    if (displayImage.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: displayImage,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppTheme.darkColor.withOpacity(0.05),
        ),
        errorWidget: (context, url, error) => _buildPlaceholderImage(displayName, radius, size),
      );
    }

    if (displayImage.startsWith('assets/')) {
      return SvgPicture.asset(displayImage, fit: BoxFit.cover);
    }

    if (File(displayImage).existsSync()) {
      return Image.file(File(displayImage), fit: BoxFit.cover);
    }

    return _buildPlaceholderImage(displayName, radius, size);
  }

  Widget _buildPlaceholderImage(String name, double radius, double size) {
    final assetPath = _getAvatarForName(name);
    return SvgPicture.asset(
      assetPath,
      fit: BoxFit.cover,
      placeholderBuilder: (context) => Container(
        color: AppTheme.darkColor.withOpacity(0.05),
      ),
    );
  }

  Widget _buildInitials(String name, bool isLarge, Color color, double size,
      {bool isStore = false}) {
    return Center(
      child: Icon(
        isStore ? PhosphorIcons.storefront() : PhosphorIcons.user(),
        size: isLarge ? size * 0.5 : size * 0.6, // Relative to container size
        color: color.withOpacity(0.4),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;
  final double radius;

  _GradientBorderPainter({
    required this.gradient,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return true;
  }
}
