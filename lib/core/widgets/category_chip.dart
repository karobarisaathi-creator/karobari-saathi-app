import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'app_filter_chip.dart'; // Import to use AppCategory and theme consistency

class CategoryChip extends StatelessWidget {
  final String? category;
  final AppCategory? categoryData;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showIcon;

  const CategoryChip({
    super.key,
    this.category,
    this.categoryData,
    this.isSelected = false,
    this.onTap,
    this.showIcon = true,
  });

  // --- Centralized Party Categories (Product categories moved to AppFilterChip) ---
  
  static final List<AppCategory> partyCategories = [
    AppCategory(id: 'general', labelEn: 'General', labelUr: 'عام', icon: PhosphorIcons.user()),
    AppCategory(id: 'customer', labelEn: 'Customer', labelUr: 'گاہک', icon: PhosphorIcons.shoppingCart()),
    AppCategory(id: 'supplier', labelEn: 'Supplier', labelUr: 'سپلائر', icon: PhosphorIcons.package()),
    AppCategory(id: 'wholesaler', labelEn: 'Wholesaler', labelUr: 'ہول سیلر', icon: PhosphorIcons.buildings()),
    AppCategory(id: 'retailer', labelEn: 'Retailer', labelUr: 'پرچون فروش', icon: PhosphorIcons.storefront()),
    AppCategory(id: 'farmer', labelEn: 'Farmer', labelUr: 'کاشتکار', icon: PhosphorIcons.leaf()),
    AppCategory(id: 'agent', labelEn: 'Agent', labelUr: 'ایجنٹ/آڑھتی', icon: PhosphorIcons.handshake()),
    AppCategory(id: 'technician', labelEn: 'Technician', labelUr: 'کاریگر/مستری', icon: PhosphorIcons.wrench()),
    AppCategory(id: 'transport', labelEn: 'Transport', labelUr: 'ٹرانسپورٹ', icon: PhosphorIcons.truck()),
    AppCategory(id: 'employee', labelEn: 'Employee', labelUr: 'ملازم', icon: PhosphorIcons.identificationCard()),
    AppCategory(id: 'investor', labelEn: 'Investor', labelUr: 'سرمایہ کار', icon: PhosphorIcons.coins()),
    AppCategory(id: 'business', labelEn: 'Business', labelUr: 'کاروباری', icon: PhosphorIcons.briefcase()),
    AppCategory(id: 'friend', labelEn: 'Friend', labelUr: 'دوست', icon: PhosphorIcons.users()),
    AppCategory(id: 'family', labelEn: 'Family', labelUr: 'فیملی', icon: PhosphorIcons.house()),
    AppCategory(id: 'other', labelEn: 'Other', labelUr: 'دیگر', icon: PhosphorIcons.dotsThreeCircle()),
  ];

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;

    final String displayLabel = categoryData != null 
        ? (isUrdu ? categoryData!.labelUr : categoryData!.labelEn)
        : (category ?? '');
    
    final IconData icon = categoryData?.icon ?? _getCategoryIcon(category ?? '');
    final Color chipColor = categoryData?.color ?? _getCategoryColor(category ?? '');
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withOpacity(0.05),
          border: Border.all(
            color: chipColor.withOpacity(isSelected ? 1.0 : 0.4), 
            width: 1.5
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected ? [
            BoxShadow(
              color: chipColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : chipColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : AppTheme.darkColor.withOpacity(0.8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // Fallback logic for simple string categories if needed
    // First, try to match from productCategories in AppFilterChip
    try {
      final match = AppFilterChip.productCategories.firstWhere(
        (c) => c.labelEn == category || c.labelUr == category || c.id == category
      );
      return match.color ?? AppTheme.themeColor;
    } catch (_) {
      return AppTheme.themeColor;
    }
  }

  IconData _getCategoryIcon(String category) {
    try {
      final match = AppFilterChip.productCategories.firstWhere(
        (c) => c.labelEn == category || c.labelUr == category || c.id == category
      );
      return match.icon;
    } catch (_) {
      return PhosphorIcons.tag();
    }
  }
}

class CategoryChipList extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String>? onCategorySelected;
  final bool scrollable;

  const CategoryChipList({
    super.key,
    required this.categories,
    this.selectedCategory,
    this.onCategorySelected,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = categories.map((category) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: CategoryChip(
          category: category,
          isSelected: category == selectedCategory,
          onTap: () => onCategorySelected?.call(category),
        ),
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: children),
      );
    }

    return Wrap(children: children);
  }
}
