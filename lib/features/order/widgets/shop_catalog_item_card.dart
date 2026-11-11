// lib/features/order/widgets/shop_catalog_item_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class ShopCatalogItemCard extends StatefulWidget {
  final ShopItem item;
  final VoidCallback? onTap;

  const ShopCatalogItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<ShopCatalogItemCard> createState() => _ShopCatalogItemCardState();
}

class _ShopCatalogItemCardState extends State<ShopCatalogItemCard> {
  late PageController _pageController;
  int _currentImageIndex = 0;

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

  static const Map<String, String> _categoryNamesUrdu = {
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

  String _formatCategory(String cat, bool isUrdu) {
    if (isUrdu) {
      return _categoryNamesUrdu[cat] ?? cat;
    }
    return cat;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final item = widget.item;
    final images = item.allImages;
    final isOut = item.stock <= 0;
    final hasDiscount = item.oldRate != null && item.oldRate! > item.rate;

    // ═══════════════════════════════════════════════════════
    // کارڈ — سائز باہر سے آیا ہوا (grid جو دے)
    // ═══════════════════════════════════════════════════════
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ═══════════════════════════════════════
              // 1. FULL-BLEED IMAGE (پوری جگہ)
              // ═══════════════════════════════════════
              Container(
                color: isOut
                    ? Colors.grey.shade300
                    : AppTheme.themeColor.withValues(alpha: 0.15),
                child: images.isEmpty
                    ? _buildFallbackImage(isOut)
                    : PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (i) {
                    setState(() => _currentImageIndex = i);
                  },
                  itemBuilder: (context, idx) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTap,
                      child: _buildSingleImage(images[idx], isOut),
                    );
                  },
                ),
              ),

              // ═══════════════════════════════════════
              // 2. BOTTOM GRADIENT OVERLAY
              // ═══════════════════════════════════════
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 100,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.darkColor.withValues(alpha: 0.30),
                          AppTheme.darkColor.withValues(alpha: 0.85),
                          AppTheme.darkColor.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.35, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // 3. PAGE INDICATORS (dots)
              // ═══════════════════════════════════════
              if (images.length > 1)
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                          (idx) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: _currentImageIndex == idx ? 10 : 4,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _currentImageIndex == idx
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),

              // ═══════════════════════════════════════
              // 4. DISCOUNT TAG (صرف discount پر)
              // ═══════════════════════════════════════
              if (hasDiscount)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: UrduAwareText(
                      '-${item.discountPercent}%',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // ═══════════════════════════════════════
              // 5. BOTTOM CONTENT
              //    (نام، category/unit، اسٹاک، قیمت)
              // ═══════════════════════════════════════
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Item name ───
                      UrduAwareText(
                        item.name,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.25,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                              color:
                              AppTheme.darkColor.withValues(alpha: 0.4),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // ─── Category & Stock status row (Always shown) ───
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.category.isNotEmpty) ...[
                            Flexible(
                              child: _buildGlassChip(
                                text: _formatCategory(item.category, isUrdu),
                                fontFamily: fontFamily,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          _buildStockTag(
                            isOut: isOut,
                            isLow: item.isLowStock,
                            isUrdu: isUrdu,
                            fontFamily: fontFamily,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // ─── Price row (ریٹ + اکائی + پرانی قیمت) ───
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: UrduAwareText(
                              Formatters.formatAmountWithCurrency(item.rate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                                shadows: [
                                  Shadow(
                                    color: AppTheme.darkColor
                                        .withValues(alpha: 0.4),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ─── اکائی (unit) ───
                          if (item.unit.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            UrduAwareText(
                              '/ ${item.unit}',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                          if (hasDiscount) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: UrduAwareText(
                                Formatters.formatAmountWithCurrency(
                                    item.oldRate!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  decoration: TextDecoration.lineThrough,
                                ),
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

  // ═════════════════════════════════════════════
  // Glass Chip — تصویر پر شفاف
  // ═════════════════════════════════════════════
  Widget _buildGlassChip({
    required String text,
    String? fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: UrduAwareText(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Stock Tag (موجود، کم، ختم - بغیر تعداد کے)
  // ═════════════════════════════════════════════
  Widget _buildStockTag({
    required bool isOut,
    required bool isLow,
    required bool isUrdu,
    String? fontFamily,
  }) {
    final Color tagColor;
    final String label;
    final IconData iconData;

    if (isOut) {
      tagColor = AppTheme.expenseColor; // سرخ (ختم)
      label = isUrdu ? 'ختم' : 'Out';
      iconData = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
    } else if (isLow) {
      tagColor = AppTheme.verifiedGold; // پیلا/نارنجی (کم) - تھیم سے
      label = isUrdu ? 'کم' : 'Low';
      iconData = PhosphorIcons.warning(PhosphorIconsStyle.fill);
    } else {
      tagColor = AppTheme.greenColor; // سبز (موجود) - تھیم سے
      label = isUrdu ? 'موجود' : 'In Stock';
      iconData = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.35), // ہلکا بیک گراؤنڈ
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: tagColor.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 8,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          UrduAwareText(
            label,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Fallback Image
  // ═════════════════════════════════════════════
  Widget _buildFallbackImage(bool isOut) {
    return Center(
      child: Icon(
        PhosphorIcons.package(),
        size: 45,
        color: isOut
            ? Colors.grey.shade400
            : AppTheme.themeColor.withValues(alpha: 0.6),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Single Image
  // ═════════════════════════════════════════════
  Widget _buildSingleImage(String rawPath, bool isOut) {
    final path = rawPath.trim();
    if (path.isEmpty || path == '?' || path == '؟' || path.length < 5) {
      return _buildFallbackImage(isOut);
    }

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    final image = isRemote
        ? CachedNetworkImage(
      imageUrl: path,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _buildFallbackImage(isOut),
    )
        : Image.file(
      File(path),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackImage(isOut),
    );

    return isOut
        ? ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.grey.shade400.withValues(alpha: 0.5),
        BlendMode.saturation,
      ),
      child: image,
    )
        : image;
  }
}