// lib/core/widgets/profile_info_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'category_chip.dart';

class ProfileInfoWidget extends StatelessWidget {
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
      final match = CategoryChip.partyCategories.firstWhere(
        (c) =>
            c.id.toLowerCase() == key ||
            c.labelEn.toLowerCase() == key ||
            c.labelUr == category.trim(),
      );
      return match.labelUr;
    } catch (_) {
      return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    final effectiveTextColor = textColor ?? AppTheme.darkColor;
    final effectiveSubtitleColor = subtitleColor ?? AppTheme.textSecondary;

    final displayCategory = category != null
        ? _getTranslatedCategory(category!, isUrdu)
        : '';

    final displayName = name.trim().isEmpty
        ? (isUrdu ? 'نامعلوم' : 'Unknown')
        : name;

    final size = customSize ?? (isLarge ? 50 : 36);
    final radius = borderRadius ?? 12.0;

    final phoneHasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(phone);

    final imagePart = _buildImagePart(
      displayName,
      size,
      radius,
    );

    if (!showText) return imagePart;

    if (isCentered) {
      return _buildCenteredLayout(
        imagePart,
        displayName,
        phone,
        phoneHasUrdu,
        displayCategory,
        isUrdu,
        fontFamily,
        fontWeight,
        effectiveTextColor,
        effectiveSubtitleColor,
      );
    }

    return _buildRowLayout(
      imagePart,
      displayName,
      phone,
      phoneHasUrdu,
      displayCategory,
      isUrdu,
      fontFamily,
      fontWeight,
      effectiveTextColor,
      effectiveSubtitleColor,
      size,
    );
  }

  Widget _buildImagePart(String displayName, double size, double radius) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: AppTheme.darkColor.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: _buildCoreImage(profileImage, displayName, size),
            ),
          ),
          if (hasUpdate)
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
  }

  Widget _buildCoreImage(String? imagePath, String displayName, double size) {
    if (imagePath == null || imagePath.isEmpty) {
      return _buildPlaceholderImage(displayName);
    }

    if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppTheme.darkColor.withValues(alpha: 0.05),
        ),
        errorWidget: (context, url, error) => _buildPlaceholderImage(displayName),
      );
    }

    if (imagePath.startsWith('assets/')) {
      return SvgPicture.asset(imagePath, fit: BoxFit.cover);
    }

    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }

    return _buildPlaceholderImage(displayName);
  }

  Widget _buildPlaceholderImage(String name) {
    final assetPath = _getAvatarForName(name);
    return SvgPicture.asset(
      assetPath,
      fit: BoxFit.cover,
      placeholderBuilder: (context) => Container(
        color: AppTheme.darkColor.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildCenteredLayout(
    Widget imagePart,
    String displayName,
    String phone,
    bool phoneHasUrdu,
    String displayCategory,
    bool isUrdu,
    String fontFamily,
    FontWeight fontWeight,
    Color effectiveTextColor,
    Color effectiveSubtitleColor,
  ) {
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
                  fontSize: isLarge ? 22 : 16,
                  fontWeight: fontWeight,
                  color: effectiveTextColor,
                  fontFamily: fontFamily,
                ),
              ),
            ),
          ],
        ),
        if (displayCategory.isNotEmpty) ...[
          SizedBox(height: verticalSpacing),
          Text(
            displayCategory,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: categoryColor ?? AppTheme.themeColor,
              fontFamily: fontFamily,
            ),
          ),
        ],
        if (phone.isNotEmpty) ...[
          SizedBox(height: verticalSpacing),
          Text(
            phone,
            style: TextStyle(
              fontSize: 13,
              color: effectiveSubtitleColor,
              fontFamily: phoneHasUrdu ? fontFamily : '',
            ),
          ),
        ],
        if (suffix != null) ...[
          SizedBox(height: verticalSpacing * 2),
          suffix!,
        ],
        if (bottom != null) ...[
          SizedBox(height: verticalSpacing),
          bottom!,
        ],
      ],
    );
  }

  Widget _buildRowLayout(
    Widget imagePart,
    String displayName,
    String phone,
    bool phoneHasUrdu,
    String displayCategory,
    bool isUrdu,
    String fontFamily,
    FontWeight fontWeight,
    Color effectiveTextColor,
    Color effectiveSubtitleColor,
    double size,
  ) {
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (topLabel != null && topLabel!.isNotEmpty)
                    Text(
                      topLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: effectiveSubtitleColor.withValues(alpha: 0.7),
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
                                  fontSize: isLarge ? 20 : 16,
                                  fontWeight: fontWeight,
                                  color: effectiveTextColor,
                                  fontFamily: fontFamily,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (suffix != null) ...[
                        const SizedBox(width: 8),
                        suffix!,
                      ],
                    ],
                  ),
                ],
              ),
              if (isVerticalCategory && displayCategory.isNotEmpty) ...[
                SizedBox(height: verticalSpacing),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayCategory,
                        style: TextStyle(
                          fontSize: 14,
                          color: categoryColor ?? AppTheme.themeColor,
                          fontFamily: fontFamily,
                          fontWeight: fontWeight,
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (categorySuffix != null) ...[
                      const SizedBox(width: 8),
                      categorySuffix!,
                    ],
                  ],
                ),
              ],
              if (phone.isNotEmpty) ...[
                SizedBox(height: verticalSpacing),
                Text(
                  Formatters.formatPhoneNumber(phone),
                  style: TextStyle(
                    fontSize: 13,
                    color: effectiveSubtitleColor,
                    fontFamily: phoneHasUrdu ? fontFamily : '',
                  ),
                ),
              ],
              if (address != null && address!.isNotEmpty) ...[
                SizedBox(height: verticalSpacing),
                Text(
                  address!,
                  style: TextStyle(
                    fontSize: 13,
                    color: addressColor ?? effectiveSubtitleColor,
                    fontFamily: fontFamily,
                    fontWeight: isAddressBold ? FontWeight.w900 : fontWeight,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (showDate && date != null) ...[
                SizedBox(height: verticalSpacing),
                Text(
                  Formatters.formatDate(date!),
                  style: TextStyle(
                    fontSize: 12,
                    color: effectiveSubtitleColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
              if (bottom != null) ...[
                SizedBox(height: verticalSpacing),
                bottom!,
              ],
              if (reputationLabel != null) ...[
                SizedBox(height: verticalSpacing),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: reputationBgColor ?? AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reputationLabel!,
                    style: TextStyle(
                      fontSize: 10,
                      color: reputationColor ?? AppTheme.themeColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
