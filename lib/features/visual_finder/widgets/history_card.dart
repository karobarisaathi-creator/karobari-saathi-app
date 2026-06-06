import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HistoryCard extends StatelessWidget {
  final Map<String, String> item;
  final VoidCallback onTap;
  final String Function(String?, bool) getFont;
  final bool isUrdu;

  const HistoryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.getFont,
    required this.isUrdu,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: getFont(item['name'], isUrdu),
              ),
            ),
            const Spacer(),
            Text(
              "Rs ${item['price']}",
              style: const TextStyle(
                color: AppTheme.themeColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
