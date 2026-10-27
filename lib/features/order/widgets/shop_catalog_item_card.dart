// lib/features/order/widgets/shop_catalog_item_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class ShopCatalogItemCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback? onTap;

  const ShopCatalogItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  static const Map<String, String> _categoryNamesUrdu = {
    'General': 'عمومی',
    'Grocery': 'کریانہ',
    'Food': 'خوراک',
    'Beverages': 'مشروبات',
    'Clothing': 'kپڑے',
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

    final isOut = item.stock <= 0;
    final isLow = !isOut && item.stock <= 5;
    final hasDiscount = item.oldRate != null && item.oldRate! > item.rate;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.backgroundColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ بڑی تصویر ═══
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 110,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isOut
                              ? Colors.grey.shade300
                              : AppTheme.themeColor.withValues(alpha: 0.25),
                        ),
                        child: _buildImage(item, isOut),
                      ),

                    // ⭐ سٹاک بیج (اوپر دائیں)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOut
                              ? AppTheme.expenseColor.withValues(alpha: 0.95)
                              : isLow
                                  ? const Color(0xFFD97706)
                                      .withValues(alpha: 0.95)
                                  : const Color(0xFF6B7A1F)
                                      .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOut
                                  ? PhosphorIcons.xCircle()
                                  : isLow
                                      ? PhosphorIcons.warning()
                                      : PhosphorIcons.checkCircle(),
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            UrduAwareText(
                              isOut
                                  ? (isUrdu ? 'اسٹاک ختم ہے' : 'Out of stock')
                                  : isLow
                                      ? (isUrdu ? 'اسٹاک کم ہے' : 'Low stock')
                                      : (isUrdu
                                          ? 'اسٹاک موجود ہے'
                                          : 'In stock'),
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ⭐ ڈسکاؤنٹ بیج (اوپر بائیں)
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.expenseColor.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: UrduAwareText(
                            '-${item.discountPercent}%',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

              // ═══ تفصیل ═══
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // نام
                          UrduAwareText(
                            item.name,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isOut
                                  ? AppTheme.textSecondary
                                  : AppTheme.darkColor,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // قیمت + اکائی
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    UrduAwareText(
                                      Formatters.formatAmountWithCurrency(
                                          item.rate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: isOut
                                            ? AppTheme.textSecondary
                                            : AppTheme.goldColor,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    if (hasDiscount) ...[
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: UrduAwareText(
                                          Formatters.formatAmountWithCurrency(
                                              item.oldRate!),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textSecondary,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (item.unit.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: UrduAwareText(
                                    item.unit,
                                    style: TextStyle(
                                      fontFamily: fontFamily,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Category and description
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.category.isNotEmpty)
                            UrduAwareText(
                              _formatCategory(item.category, isUrdu),
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            UrduAwareText(
                              item.description!,
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 9,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

  Widget _buildImage(ShopItem item, bool isOut) {
    final path = item.imageUrl?.trim();
    final fallback = Center(
      child: Icon(
        PhosphorIcons.package(),
        size: 45,
        color: isOut
            ? Colors.grey.shade400
            : AppTheme.themeColor.withValues(alpha: 0.6),
      ),
    );

    if (path == null ||
        path.isEmpty ||
        path == '?' ||
        path == '؟' ||
        path.length < 5) {
      return fallback;
    }

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    final image = isRemote
        ? Image.network(
            path,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : Image.file(
            File(path),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
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
