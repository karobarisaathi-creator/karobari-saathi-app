// lib/features/order/widgets/item_detail_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/image_gallery_viewer.dart';

void showItemDetailDialog(BuildContext context, ShopItem item,
    {String? shopName}) {
  final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
  final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

  final categoryNamesUrdu = {
    'General': 'عمومی',
    'Grocery': 'کریانہ',
    'Food': 'خوراک',
    'Beverages': 'مشروبات',
    'Clothing': 'کپڑے',
    'Electronics': 'الیکٹرانکس',
    'Household': 'گھریلو سامان',
    'Personal Care': 'ذاتی استعمال',
    'Medicine': 'ادویات',
    'Other': 'دیگر',
    'عام': 'عام',
  };

  String formatCategory(String cat) {
    if (isUrdu) {
      return categoryNamesUrdu[cat] ?? cat;
    }
    return cat;
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Wide Image Slider (Photography Aspect Ratio)
            _ItemPopupGallery(
              images: item.allImages,
              fontFamily: fontFamily,
              isUrdu: isUrdu,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

            // Name + Category
            Row(
              children: [
                Expanded(
                  child: UrduAwareText(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: UrduAwareText(
                    formatCategory(item.category),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.themeColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Price + Stock Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    UrduAwareText(
                      Formatters.formatAmountWithCurrency(item.rate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.goldColor,
                      ),
                    ),
                    if (item.hasDiscount) ...[
                      const SizedBox(width: 8),
                      UrduAwareText(
                        Formatters.formatAmountWithCurrency(item.oldRate!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isOutOfStock
                        ? AppTheme.expenseColor.withValues(alpha: 0.1)
                        : item.isLowStock
                            ? const Color(0xFFD97706).withValues(alpha: 0.1)
                            : AppTheme.incomeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: UrduAwareText(
                    item.isOutOfStock
                        ? (isUrdu ? 'اسٹاک ختم ہے' : 'Out of stock')
                        : item.isLowStock
                            ? (isUrdu ? 'اسٹاک کم ہے' : 'Low stock')
                            : (isUrdu ? 'اسٹاک موجود ہے' : 'In stock'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: item.isOutOfStock
                          ? AppTheme.expenseColor
                          : item.isLowStock
                              ? const Color(0xFFD97706)
                              : AppTheme.incomeColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            ),

            // Brand, Model & Returnable Badges
            if ((item.brand != null && item.brand!.isNotEmpty) ||
                (item.model != null && item.model!.isNotEmpty) ||
                item.allowReturn) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.brand != null && item.brand!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.themeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.themeColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.factory(),
                            size: 12,
                            color: AppTheme.themeColor,
                          ),
                          const SizedBox(width: 4),
                          UrduAwareText(
                            isUrdu
                                ? 'برانڈ: ${item.brand}'
                                : 'Brand: ${item.brand}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.themeColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.model != null && item.model!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.darkColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.darkColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.wrench(),
                            size: 12,
                            color: AppTheme.darkColor,
                          ),
                          const SizedBox(width: 4),
                          UrduAwareText(
                            isUrdu
                                ? 'ماڈل: ${item.model}'
                                : 'Model: ${item.model}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.allowReturn)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFBBF7D0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.arrowsCounterClockwise(),
                            size: 12,
                            color: AppTheme.incomeColor,
                          ),
                          const SizedBox(width: 4),
                          UrduAwareText(
                            isUrdu ? 'قابلِ واپسی' : 'Returnable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.incomeColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // Description
            if (item.description != null &&
                item.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              UrduAwareText(
                isUrdu ? 'تفصیل:' : 'Description:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(height: 3),
              UrduAwareText(
                item.description!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                  height: 1.3,
                ),
              ),
            ],

            // Highlights
            if (item.highlights.isNotEmpty) ...[
              const SizedBox(height: 12),
              UrduAwareText(
                isUrdu ? 'خصوصیات:' : 'Highlights:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.highlights
                    .map((h) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.check(),
                                size: 10,
                                color: AppTheme.incomeColor,
                              ),
                              const SizedBox(width: 4),
                              UrduAwareText(
                                h,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.incomeColor,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 20),

            // Buttons Row (Side by side, unequal width & size)
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: AppButton(
                    text: isUrdu ? 'بند کریں' : 'Close',
                    variant: AppButtonVariant.outlined,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    text: isUrdu
                        ? 'واٹس ایپ پر رابطہ کریں'
                        : 'Inquire on WhatsApp',
                    icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                    color: const Color(0xFF25D366),
                    size: AppButtonSize.small,
                    onPressed: () async {
                      final imageUrlText = (item.imageUrl != null &&
                              item.imageUrl!.startsWith('http'))
                          ? '\n🖼️ تصویر: ${item.imageUrl}'
                          : '';
                      final message = Uri.encodeComponent(
                        isUrdu
                            ? 'السلام علیکم! میں آپ کی دکان سے یہ آئٹم خریدنا چاہتا ہوں:\n\n📦 نام: ${item.name}\n💰 قیمت: ${Formatters.formatAmountWithCurrency(item.rate)}$imageUrlText'
                            : 'Hello! I want to inquire about this item:\n\n📦 Name: ${item.name}\n💰 Price: ${Formatters.formatAmountWithCurrency(item.rate)}$imageUrlText',
                      );
                      final uri = Uri.parse('https://wa.me/?text=$message');
                      try {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
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

Widget _buildPopupFallback() {
  return Container(
    height: 230,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppTheme.themeColor.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Center(
      child: Icon(
        PhosphorIcons.package(),
        size: 56,
        color: AppTheme.themeColor.withValues(alpha: 0.6),
      ),
    ),
  );
}

Widget _buildNetworkOrFileImage(String path) {
  final uri = Uri.tryParse(path);
  final isRemote =
      uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

  if (isRemote) {
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _buildPopupFallback(),
    );
  } else {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPopupFallback(),
      );
    }
    return _buildPopupFallback();
  }
}

class _ItemPopupGallery extends StatefulWidget {
  final List<String> images;
  final String? fontFamily;
  final bool isUrdu;

  const _ItemPopupGallery({
    required this.images,
    this.fontFamily,
    required this.isUrdu,
  });

  @override
  State<_ItemPopupGallery> createState() => _ItemPopupGalleryState();
}

class _ItemPopupGalleryState extends State<_ItemPopupGallery> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return _buildPopupFallback();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Image Slider / Carousel with Tap to Zoom
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            height: 230,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final path = widget.images[index];
                    return GestureDetector(
                      onTap: () => openFullScreenImageGallery(
                        context,
                        widget.images,
                        initialIndex: index,
                      ),
                      child: _buildNetworkOrFileImage(path),
                    );
                  },
                ),

                // Top-right: Fullscreen zoom button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => openFullScreenImageGallery(
                      context,
                      widget.images,
                      initialIndex: _currentIndex,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.arrowsOutSimple(),
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.isUrdu ? 'بڑا کریں' : 'Zoom',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontFamily: widget.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom-right: Image counter (if multiple)
                if (widget.images.length > 1)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Left Arrow (if > 1 image and index > 0)
                if (widget.images.length > 1 && _currentIndex > 0)
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Right Arrow (if > 1 image and index < length - 1)
                if (widget.images.length > 1 &&
                    _currentIndex < widget.images.length - 1)
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Thumbnail strip (if multiple images)
        if (widget.images.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final isSelected = idx == _currentIndex;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.themeColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildNetworkOrFileImage(widget.images[idx]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
