import 'package:flutter/material.dart';
import '../../../core/models/price_report_model.dart';

class PriceComparisonCard extends StatelessWidget {
  final PriceReport report;
  final bool isBestDeal;

  const PriceComparisonCard({
    super.key,
    required this.report,
    this.isBestDeal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBestDeal ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBestDeal ? Colors.green.withOpacity(0.5) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.shopName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                report.locationName,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          Text(
            "Rs ${report.price.toStringAsFixed(0)}",
            style: TextStyle(
              color: isBestDeal ? Colors.greenAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
