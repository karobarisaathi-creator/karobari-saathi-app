// lib/features/stock/stock_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'add_edit_stock_item_screen.dart';
import 'stock_adjustment_dialog.dart';

class StockDetailScreen extends StatelessWidget {
  final StockItem item;

  const StockDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final computedStock = stockService.calculateCurrentStock(item.id);
    final avgCost = stockService.calculateWeightedAverageCost(item.id);
    final isOutOfStock = computedStock <= 0;
    final isLowStock = computedStock <= item.minStockAlert && !isOutOfStock;

    final itemMovements = stockService.movements
        .where((m) => m.stockItemId == item.id)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'آئٹم تفصیل و ہسٹری' : 'Stock Item Details',
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.pencilSimple()),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddEditStockItemScreen(initialItem: item),
                ),
              );
            },
            tooltip: isUrdu ? 'ترمیم کریں' : 'Edit Item',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📦 Header Profile Card
            _buildHeaderCard(context, computedStock, avgCost, isOutOfStock, isLowStock, isUrdu, fontFamily),
            const SizedBox(height: 16),

            // ⚡ Quick Action Buttons
            _buildActionButtons(context, isUrdu, fontFamily),
            const SizedBox(height: 16),

            // 📜 Movement Log Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUrdu ? 'ریٹ ہسٹری اور انٹری لاگ' : 'Movement & Audit Log',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
                Text(
                  '${itemMovements.length} ${isUrdu ? 'انٹریز' : 'entries'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Movement Timeline
            if (itemMovements.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    isUrdu ? 'کوئی ہسٹری موجود نہیں' : 'No movements recorded yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              )
            else
              ...itemMovements.map(
                (m) => _buildMovementTile(m, isUrdu, fontFamily),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    double computedStock,
    double avgCost,
    bool isOutOfStock,
    bool isLowStock,
    bool isUrdu,
    String fontFamily,
  ) {
    final displayName = isUrdu && item.nameUrdu.isNotEmpty ? item.nameUrdu : item.name;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.darkColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    PhosphorIcons.package(),
                    size: 28,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                      if (item.barcode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Code: ${item.barcode}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 16),

            // Computed Stock Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUrdu ? 'موجودہ محسب شدہ اسٹاک:' : 'Calculated Current Stock:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${computedStock.toStringAsFixed(1)} ${item.unit}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? Colors.red[700]
                            : (isLowStock ? Colors.amber[800] : Colors.green[700]),
                      ),
                    ),
                  ],
                ),

                // Profit Margin Badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isUrdu ? 'فی یونٹ منافع' : 'Profit Margin',
                        style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF4F46E5),
                          fontFamily: fontFamily,
                        ),
                      ),
                      Text(
                        'Rs. ${item.profitMargin.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Rates Grid
            Row(
              children: [
                _buildRateStat(
                  isUrdu ? 'اوسط خرید ریٹ' : 'Avg Cost',
                  'Rs. ${avgCost.toStringAsFixed(0)}',
                  fontFamily,
                ),
                _buildRateStat(
                  isUrdu ? 'فروخت ریٹ' : 'Sale Price',
                  'Rs. ${item.sellingPrice.toStringAsFixed(0)}',
                  fontFamily,
                ),
                _buildRateStat(
                  isUrdu ? 'تھوک ریٹ' : 'Wholesale',
                  'Rs. ${item.wholesalePrice.toStringAsFixed(0)}',
                  fontFamily,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateStat(String label, String value, String fontFamily) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, bool isUrdu, String fontFamily) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            text: isUrdu ? 'سامان خریدا (+)' : 'Stock In (+)',
            color: Colors.green[700],
            icon: PhosphorIcons.plusCircle(),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => StockAdjustmentDialog(
                  item: item,
                  initialType: StockMovementType.purchase,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppButton(
            text: isUrdu ? 'سامان بیچا (-)' : 'Stock Out (-)',
            color: Colors.red[700],
            icon: PhosphorIcons.minusCircle(),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => StockAdjustmentDialog(
                  item: item,
                  initialType: StockMovementType.sale,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovementTile(
      StockMovement movement, bool isUrdu, String fontFamily) {
    Color iconBg;
    IconData icon;
    String typeLabel;
    String sign;

    switch (movement.type) {
      case StockMovementType.purchase:
      case StockMovementType.customerReturn:
        iconBg = const Color(0xFFD1FAE5);
        icon = PhosphorIcons.arrowDownLeft();
        typeLabel = movement.type == StockMovementType.purchase
            ? (isUrdu ? 'خریداری (Stock In)' : 'Purchase')
            : (isUrdu ? 'گاہک کی واپسی' : 'Customer Return');
        sign = '+';
        break;
      case StockMovementType.sale:
      case StockMovementType.supplierReturn:
        iconBg = const Color(0xFFFEE2E2);
        icon = PhosphorIcons.arrowUpRight();
        typeLabel = movement.type == StockMovementType.sale
            ? (isUrdu ? 'فروخت (Stock Out)' : 'Sale')
            : (isUrdu ? 'سپلاٸر کو واپسی' : 'Supplier Return');
        sign = '-';
        break;
      case StockMovementType.adjustment:
        iconBg = const Color(0xFFFEF3C7);
        icon = PhosphorIcons.sliders();
        typeLabel = isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment';
        sign = movement.quantity >= 0 ? '+' : '';
        break;
    }

    final formattedDate =
        DateFormat('dd MMM, hh:mm a').format(movement.timestamp);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconBg,
          child: Icon(icon, size: 18, color: AppTheme.darkColor),
        ),
        title: Text(
          typeLabel,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
          ),
        ),
        subtitle: Text(
          movement.note.isNotEmpty ? movement.note : formattedDate,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontFamily: fontFamily,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${movement.quantity.toStringAsFixed(1)} ${item.unit}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: sign == '+' ? Colors.green[700] : Colors.red[700],
              ),
            ),
            if (movement.unitPrice > 0)
              Text(
                'Rs. ${movement.unitPrice.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }
}
