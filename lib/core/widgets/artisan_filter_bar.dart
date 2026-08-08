// lib/features/artisans/widgets/artisan_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/artisan_service.dart';

class ArtisanFilterBar extends StatelessWidget {
  final String selectedProfession;
  final Function(String) onProfessionSelected;
  final bool isUrdu;
  final String fontFamily;

  const ArtisanFilterBar({
    super.key,
    required this.selectedProfession,
    required this.onProfessionSelected,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final professions = ArtisanService.getProfessions();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: professions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFilterChip(
              id: 'all',
              label: isUrdu ? 'سب' : 'All',
              icon: PhosphorIcons.gridFour(),
            );
          }

          final profession = professions[index - 1];
          return _buildFilterChip(
            id: profession['id']!,
            label: isUrdu ? profession['name']! : profession['id']!,
            icon: profession['icon']!,
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required dynamic icon,
  }) {
    final isSelected = selectedProfession == id;

    return GestureDetector(
      onTap: () => onProfessionSelected(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.themeColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.themeColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon is String ? icon : '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}