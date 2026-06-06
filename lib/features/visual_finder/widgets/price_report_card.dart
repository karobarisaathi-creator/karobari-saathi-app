import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/price_report_model.dart';

class PriceReportCard extends StatelessWidget {
  final PriceReport report;
  final bool isUrdu;
  final String Function(String?, bool) getFont;

  const PriceReportCard({
    super.key,
    required this.report,
    required this.isUrdu,
    required this.getFont,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.darkColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorIcons.storefront(), color: AppTheme.themeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    report.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: getFont(report.shopName, isUrdu))
                ),
                Text(
                    report.locationName,
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontFamily: getFont(report.locationName, isUrdu))
                ),
              ],
            ),
          ),
          Text(
              "Rs ${report.price.toStringAsFixed(0)}",
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)
          ),
        ],
      ),
    );
  }
}
