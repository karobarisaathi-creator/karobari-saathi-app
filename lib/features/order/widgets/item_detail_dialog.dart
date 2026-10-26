// lib/features/order/widgets/item_detail_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/app_button.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Fallback
            if (item.imageUrl != null &&
                item.imageUrl!.trim().isNotEmpty &&
                item.imageUrl!.length > 4)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: _buildNetworkOrFileImage(item.imageUrl!),
                ),
              )
            else
              _buildPopupFallback(),

            const SizedBox(height: 14),

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
    ),
  );
}

Widget _buildPopupFallback() {
  return Container(
    height: 150,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppTheme.themeColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: Icon(
        PhosphorIcons.package(),
        size: 50,
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
    return Image.network(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPopupFallback(),
    );
  } else {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPopupFallback(),
    );
  }
}
