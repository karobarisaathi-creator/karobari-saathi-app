import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';

class AppCategory {
  final String id;
  final String labelEn;
  final String labelUr;
  final IconData icon;
  final Color? color;

  const AppCategory({
    required this.id,
    required this.labelEn,
    required this.labelUr,
    required this.icon,
    this.color,
  });
}

class AppFilterChip extends StatelessWidget {
  final String? labelEn;
  final String? labelUr;
  final IconData? icon;
  final AppCategory? categoryData; // New: Pass entire category object
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;
  final bool transparentBackground; // New: Option for transparent background

  const AppFilterChip({
    super.key,
    this.labelEn,
    this.labelUr,
    this.icon,
    this.categoryData,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
    this.transparentBackground = false, // Default to false
  });

  // --- Centralized Product Categories ---
  static final List<AppCategory> productCategories = [
    AppCategory(id: 'general', labelEn: 'General', labelUr: 'عام', icon: PhosphorIcons.cube()),
    AppCategory(id: 'mobiles', labelEn: 'Mobiles', labelUr: 'موبائل', icon: PhosphorIcons.deviceMobile()),
    AppCategory(id: 'electronics', labelEn: 'Electronics', labelUr: 'الیکٹرانکس', icon: PhosphorIcons.cpu()),
    AppCategory(id: 'vehicles', labelEn: 'Vehicles', labelUr: 'گاڑیاں', icon: PhosphorIcons.car()),
    AppCategory(id: 'real_estate', labelEn: 'Real Estate', labelUr: 'رئیل اسٹیٹ', icon: PhosphorIcons.house()),
    AppCategory(id: 'agriculture', labelEn: 'Agriculture', labelUr: 'زراعت', icon: PhosphorIcons.leaf()),
    AppCategory(id: 'livestock', labelEn: 'Livestock', labelUr: 'مویشی', icon: PhosphorIcons.cow()),
    AppCategory(id: 'clothing', labelEn: 'Clothing', labelUr: 'کپڑے', icon: PhosphorIcons.shoppingCart()),
    AppCategory(id: 'furniture', labelEn: 'Furniture', labelUr: 'فرنیچر', icon: PhosphorIcons.couch()),
    AppCategory(id: 'food', labelEn: 'Food', labelUr: 'خوراک', icon: PhosphorIcons.cookingPot()),
    AppCategory(id: 'medical', labelEn: 'Medical', labelUr: 'ادویات', icon: PhosphorIcons.firstAid()),
    AppCategory(id: 'stationery', labelEn: 'Stationery', labelUr: 'سٹیشنری', icon: PhosphorIcons.book()),
    AppCategory(id: 'hardware', labelEn: 'Hardware', labelUr: 'ہارڈ ویئر', icon: PhosphorIcons.wrench()),
    AppCategory(id: 'construction', labelEn: 'Construction', labelUr: 'تعمیرات', icon: PhosphorIcons.hammer()),
    AppCategory(id: 'services', labelEn: 'Services', labelUr: 'خدمات', icon: PhosphorIcons.handshake()),
    AppCategory(id: 'transport', labelEn: 'Transport', labelUr: 'ٹرانسپورٹ', icon: PhosphorIcons.truck()),
    AppCategory(id: 'raw_material', labelEn: 'Raw Material', labelUr: 'خام مال', icon: PhosphorIcons.factory()),
    AppCategory(id: 'assets', labelEn: 'Assets', labelUr: 'اثاثہ جات', icon: PhosphorIcons.bank()),
    AppCategory(id: 'other', labelEn: 'Other', labelUr: 'دیگر', icon: PhosphorIcons.dotsThreeCircle()),
  ];

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    
    // Determine labels and icon
    final String label = categoryData != null 
        ? (isUrdu ? categoryData!.labelUr : categoryData!.labelEn)
        : (isUrdu ? (labelUr ?? '') : (labelEn ?? ''));
    
    final IconData displayIcon = categoryData?.icon ?? icon ?? PhosphorIcons.tag();
    final themeColor = categoryData?.color ?? activeColor ?? AppTheme.themeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), // Reduced padding
            decoration: BoxDecoration(
              color: transparentBackground 
                  ? Colors.transparent 
                  : (isSelected ? themeColor : Colors.white),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: transparentBackground 
                    ? Colors.grey[300]! 
                    : (isSelected ? themeColor : Colors.grey[300]!),
                width: 1,
              ),
              boxShadow: (isSelected && !transparentBackground) ? [
                BoxShadow(
                  color: themeColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  displayIcon,
                  size: 16,
                  color: (isSelected && !transparentBackground) ? Colors.white : AppTheme.darkColor,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: (isSelected && !transparentBackground) ? Colors.white : AppTheme.darkColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontFamily: fontFamily,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
