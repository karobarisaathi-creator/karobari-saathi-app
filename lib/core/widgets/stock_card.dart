// lib/core/widgets/stock_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';

class StockCard extends StatelessWidget {
  final StockItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;
  final VoidCallback onQuickRemove;

  const StockCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickAdd,
    required this.onQuickRemove,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final computedStock = stockService.calculateCurrentStock(item.id);
    final isOutOfStock = computedStock <= 0;
    final isLowStock = computedStock <= item.minStockAlert && !isOutOfStock;

    final displayName = isUrdu && item.nameUrdu.isNotEmpty ? item.nameUrdu : item.name;

    Color badgeColor;
    Color badgeTextColor;
    String badgeText;

    if (isOutOfStock) {
      badgeColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFDC2626);
      badgeText = isUrdu ? 'ختم اسٹاک' : 'Out of Stock';
    } else if (isLowStock) {
      badgeColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFD97706);
      badgeText = isUrdu ? 'کم اسٹاک' : 'Low Stock';
    } else {
      badgeColor = const Color(0xFFD1FAE5);
      badgeTextColor = const Color(0xFF059669);
      badgeText = isUrdu ? 'اسٹاک موجود' : 'In Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOutOfStock
              ? const Color(0xFFFCA5A5)
              : (isLowStock ? const Color(0xFFFCD34D) : const Color(0xFFE5E7EB)),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Item Icon/Image + Name + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.darkColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIcons.package(),
                      size: 24,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.categoryName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.categoryName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 12),

              // Bottom Row: Price Info & Calculated Stock with Quick Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price Details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'فروخت قیمت:' : 'Sale Price:',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontFamily: fontFamily,
                        ),
                      ),
                      Text(
                        'Rs. ${item.sellingPrice.toStringAsFixed(0)} / ${item.unit}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor,
                        ),
                      ),
                      if (item.purchasePrice > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          isUrdu
                              ? 'خرید: Rs. ${item.purchasePrice.toStringAsFixed(0)} (منافع ${item.profitMarginPercent.toStringAsFixed(0)}%)'
                              : 'Cost: Rs. ${item.purchasePrice.toStringAsFixed(0)} (${item.profitMarginPercent.toStringAsFixed(0)}% profit)',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey[600],
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Stock Quantity & Quick Actions
                  Row(
                    children: [
                      // Quick Remove (-)
                      IconButton(
                        onPressed: onQuickRemove,
                        icon: Icon(
                          PhosphorIcons.minusCircle(),
                          color: Colors.red[600],
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: isUrdu ? 'اسٹاک کم کریں' : 'Reduce Stock',
                      ),
                      const SizedBox(width: 8),

                      // Quantity Display
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          '${computedStock.toStringAsFixed(computedStock.truncateToDouble() == computedStock ? 0 : 1)} ${item.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? Colors.red[700]
                                : AppTheme.darkColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quick Add (+)
                      IconButton(
                        onPressed: onQuickAdd,
                        icon: Icon(
                          PhosphorIcons.plusCircle(),
                          color: Colors.green[600],
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: isUrdu ? 'اسٹاک بڑھائیں' : 'Add Stock',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
