import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/widgets/app_filter_chip.dart';

class ArtisanFilterBar extends StatelessWidget {
  final String selectedProfession;
  final Function(String) onProfessionSelected;
  final VoidCallback onViewAllTap;
  final bool isUrdu;
  final String fontFamily;

  const ArtisanFilterBar({
    super.key,
    required this.selectedProfession,
    required this.onProfessionSelected,
    required this.onViewAllTap,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final allProfessions = ArtisanService.getProfessions();
    
    // Select top 6 most popular professions
    final topProfessions = allProfessions.take(6).toList();

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // "All" Chip
          AppFilterChip(
            labelEn: 'All',
            labelUr: 'سب',
            icon: PhosphorIcons.gridFour(),
            isSelected: selectedProfession == 'all',
            activeColor: AppTheme.goldColor,
            onTap: () => onProfessionSelected('all'),
          ),

          // Top 6 Professions
          ...topProfessions.map((p) {
            final icon = p['icon'];
            return AppFilterChip(
              labelEn: p['id']!,
              labelUr: p['name']!,
              icon: icon is IconData ? icon : null,
              isSelected: selectedProfession == p['id'],
              activeColor: AppTheme.goldColor,
              onTap: () => onProfessionSelected(p['id']!),
            );
          }),

          // "View All" Chip Style
          AppFilterChip(
            labelEn: 'More...',
            labelUr: 'مزید...',
            icon: PhosphorIcons.dotsThreeCircle(),
            isSelected: false,
            activeColor: AppTheme.goldColor,
            onTap: onViewAllTap,
          ),
        ],
      ),
    );
  }
}
