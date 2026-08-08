import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final bool hasUpdate;
  final bool isVerified;
  final Widget? suffix;
  final double? customSize;
  final String? reputationLabel;
  final Color? reputationColor;
  final Color? reputationBgColor;

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
    this.hasUpdate = false,
    this.isVerified = false,
    this.suffix,
    this.customSize,
    this.reputationLabel,
    this.reputationColor,
    this.reputationBgColor,
  });

  @override
  State<ProfileInfoWidget> createState() => _ProfileInfoWidgetState();
}

class _ProfileInfoWidgetState extends State<ProfileInfoWidget> {
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
    final double radius = widget.customSize != null ? 12.0 : 6.0; // Larger radius for larger images

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
              child: displayImage != null && displayImage.isNotEmpty
                  ? (displayImage.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: displayImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.darkColor.withOpacity(0.05),
                          ),
                          errorWidget: (context, url, error) => _buildInitials(
                              displayName, widget.isLarge, AppTheme.darkColor),
                        )
                      : (File(displayImage).existsSync()
                          ? Image.file(File(displayImage), fit: BoxFit.cover)
                          : _buildInitials(
                              displayName, widget.isLarge, AppTheme.darkColor)))
                  : _buildInitials(
                      displayName, widget.isLarge, AppTheme.darkColor,
                      isStore: widget.isStore),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.suffix != null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        imagePart,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
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
                children: [
                  Expanded(
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
                              height: 1.2,
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
                        if (widget.reputationLabel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.reputationBgColor ?? Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: widget.reputationColor?.withOpacity(0.2) ?? Colors.blue.withOpacity(0.2)),
                            ),
                            child: Text(
                              widget.reputationLabel!,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: widget.reputationColor ?? Colors.blue[700],
                                fontFamily: fontFamily,
                              ),
                            ),
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
              const SizedBox(height: 2),
              if (widget.isVerticalCategory) ...[
                Text(
                  Formatters.formatPhoneNumber(widget.phone),
                  style: TextStyle(
                    fontSize: widget.isLarge ? 14 : 12,
                    color: AppTheme.textSecondary,
                    fontFamily: phoneHasUrdu ? fontFamily : '',
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (displayCategory.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    displayCategory,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.themeColor,
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ] else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        Formatters.formatPhoneNumber(widget.phone),
                        style: TextStyle(
                          fontSize: widget.isLarge ? 14 : 12,
                          color: AppTheme.textSecondary,
                          fontFamily: phoneHasUrdu ? fontFamily : '',
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (displayCategory.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          displayCategory,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.themeColor,
                            fontFamily: fontFamily,
                            fontWeight: fontWeight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              if (widget.address != null && widget.address!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.address!,
                  style: TextStyle(
                      fontSize: 11,
                      color: effectiveSubtitleColor,
                      fontFamily: fontFamily,
                      fontWeight: fontWeight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (widget.showDate && widget.date != null) ...[
                const SizedBox(height: 2),
                Text(
                  Formatters.formatDate(widget.date!),
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontFamily: '',
                      fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInitials(String name, bool isLarge, Color color,
      {bool isStore = false}) {
    if (name.trim().isEmpty || name == 'Unknown' || name == 'نامعلوم') {
      return Center(
        child: Icon(
          isStore ? PhosphorIcons.storefront() : PhosphorIcons.user(),
          size: isLarge ? 24 : 18,
          color: color.withOpacity(0.5),
        ),
      );
    }

    try {
      return Center(
        child: Text(
          Formatters.getInitials(name),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isLarge ? 20 : 14,
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Icon(
          isStore ? PhosphorIcons.storefront() : PhosphorIcons.user(),
          size: isLarge ? 24 : 18,
          color: color.withOpacity(0.5),
        ),
      );
    }
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
