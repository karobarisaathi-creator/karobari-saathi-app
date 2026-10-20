// lib/core/widgets/item_rate_history_card_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/utils/formatters.dart';

class ItemPriceHistory {
  final double price;
  final double quantity;
  final double total;
  final DateTime date;
  final String type;
  final double? changePercentage;
  final int? daysInterval;
  final String? unit;

  const ItemPriceHistory({
    required this.price,
    this.quantity = 1.0,
    double? total,
    required this.date,
    required this.type,
    this.changePercentage,
    this.daysInterval,
    this.unit,
  }) : total = total ?? (price * quantity);
}

class ItemRateHistoryCardWidget extends StatelessWidget {
  final String itemName;
  final String partyName;
  final List<ItemPriceHistory> history;
  final bool isUrdu;
  final String? fontFamily;
  final VoidCallback? onItemUpdated;
  final EdgeInsetsGeometry? margin;

  const ItemRateHistoryCardWidget({
    super.key,
    required this.itemName,
    required this.partyName,
    required this.history,
    this.isUrdu = true,
    this.fontFamily,
    this.onItemUpdated,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final latest = history.first;
    final isDecrease =
        latest.changePercentage != null && latest.changePercentage! < 0;
    final totalAmount = history.fold<double>(0, (s, h) => s + h.total);
    final totalQty = history.fold<double>(0, (s, h) => s + h.quantity);
    final badgeColor =
        isDecrease ? AppTheme.incomeColor : AppTheme.expenseColor;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openItemHistorySheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        PhosphorIcons.package(),
                        color: AppTheme.themeColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UrduAwareText(
                            itemName,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          UrduAwareText(
                            '${history.length} ${isUrdu ? "خریداریاں" : "purchases"}',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        UrduAwareText(
                          'Rs ${latest.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.themeColor,
                          ),
                        ),
                        if (latest.changePercentage != null) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: UrduAwareText(
                              '${latest.changePercentage!.abs().toStringAsFixed(1)}% ${isDecrease ? "↓" : "↑"}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UrduAwareText(
                            isUrdu ? 'کل حجم' : 'Total Volume',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          UrduAwareText(
                            '${totalQty.toStringAsFixed(totalQty % 1 == 0 ? 0 : 1)} ${latest.unit ?? (isUrdu ? "عدد" : "units")}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppTheme.backgroundColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UrduAwareText(
                            isUrdu ? 'کل رقم' : 'Total Amount',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          UrduAwareText(
                            'Rs ${Formatters.formatAmount(totalAmount)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      PhosphorIcons.caretRight(),
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // ITEM HISTORY BOTTOM SHEET
  // ═════════════════════════════════════════════════════════════
  void _openItemHistorySheet(BuildContext context) {
    final DateFormat formatter =
        DateFormat('d MMM yyyy, h:mm a', isUrdu ? 'ur' : 'en');

    final totalEntries = history.length;
    final totalSpent = history.fold<double>(0, (s, h) => s + h.total);
    final totalQty = history.fold<double>(0, (s, h) => s + h.quantity);
    final avgPrice = totalQty > 0
        ? (totalSpent / totalQty)
        : (totalEntries > 0 ? (totalSpent / totalEntries) : 0.0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Top Dark Summary Header Card
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          PhosphorIcons.package(),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UrduAwareText(
                              itemName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFamily: fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            UrduAwareText(
                              '$partyName • $totalEntries ${isUrdu ? "خریداریاں" : "purchases"}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(sheetCtx),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _sheetStat('Rs ${Formatters.formatAmount(totalSpent)}',
                          isUrdu ? 'کل رقم' : 'Total Amount'),
                      _sheetStat(
                          '$totalEntries', isUrdu ? 'خریداریاں' : 'Purchases'),
                      _sheetStat('Rs ${Formatters.formatAmount(avgPrice)}',
                          isUrdu ? 'اوسط ریٹ' : 'Average Rate'),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                child: Column(
                  children: [
                    // Rate Journey Line Chart Card (if >1 prices)
                    if (history.length > 1) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UrduAwareText(
                              isUrdu
                                  ? 'ریٹ کا سفر (قیمتوں کا گراف)'
                                  : 'Rate Journey',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkColor,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 80,
                              child: CustomPaint(
                                painter: _SheetRateChartPainter(
                                  prices: history.reversed
                                      .map((h) => h.price)
                                      .toList(),
                                  color: AppTheme.themeColor,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                UrduAwareText(
                                  DateFormat('dd/MM/yy')
                                      .format(history.last.date),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                UrduAwareText(
                                  DateFormat('dd/MM/yy')
                                      .format(history.first.date),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Per Purchase Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UrduAwareText(
                            isUrdu
                                ? 'ہر خریداری کی تفصیل'
                                : 'Per Purchase Detail',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...history.asMap().entries.map((entry) {
                            final i = entry.key;
                            final h = entry.value;
                            double? oldPrice;
                            if (i < history.length - 1) {
                              oldPrice = history[i + 1].price;
                            }
                            final isLast = i == history.length - 1;
                            return _sheetPurchaseRow(
                              h,
                              oldPrice,
                              isLast,
                              isUrdu,
                              fontFamily,
                              formatter,
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Button (Rename & Unit)
                    SizedBox(
                      width: double.infinity,
                      child: _sheetActionButton(
                        label: isUrdu
                            ? 'نام اور اکائی ترمیم کریں'
                            : 'Edit Name & Unit',
                        onTap: () => _showEditItemNameAndUnitDialog(
                            context, itemName, isUrdu, fontFamily),
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateItemNameAndUnit(
    BuildContext context,
    String oldName,
    String newName,
    String newUnit,
  ) async {
    if (newName.trim().isEmpty) return;
    final db = Provider.of<DatabaseService>(context, listen: false);

    final allTx = db.getAllTransactions().toList();

    for (var tx in allTx) {
      bool modified = false;
      final updatedItems = tx.items.map((item) {
        if (item.description.trim() == oldName.trim()) {
          modified = true;
          return TransactionItem(
            description: newName.trim(),
            quantity: item.quantity,
            rate: item.rate,
            total: item.total,
            unit: newUnit,
            stockItemId: item.stockItemId,
          );
        }
        return item;
      }).toList();

      if (modified) {
        final map = tx.toMap();
        map['items'] = updatedItems.map((x) => x.toMap()).toList();
        map['updatedAt'] = DateTime.now().toIso8601String();
        final updatedTx = Transaction.fromMap(map);
        await db.updateTransaction(updatedTx);
      }
    }

    AppToast.success(
      context,
      isUrdu
          ? 'آئٹم کا نام اور اکائی تبدیل ہو گئی'
          : 'Item updated successfully',
    );
    if (onItemUpdated != null) onItemUpdated!();
  }

  void _showEditItemNameAndUnitDialog(
    BuildContext context,
    String itemName,
    bool isUrdu,
    String? fontFamily,
  ) {
    final nameCtrl = UrduAwareTextEditingController(isUrdu: isUrdu);
    nameCtrl.text = itemName;
    final units = ['ڈبہ', 'کلو', 'لیٹر', 'من', 'یونٹ', 'عدد', 'بوری', 'پیکٹ'];
    String selectedUnit = 'ڈبہ';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: UrduAwareText(
            isUrdu ? 'نام اور اکائی ترمیم کریں' : 'Edit Name & Unit',
            style:
                TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'آئٹم کا نیا نام' : 'Item Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              UrduAwareText(
                isUrdu ? 'اکائی منتخب کریں:' : 'Select Unit:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: units.map((u) {
                  final isSelected = u == selectedUnit;
                  return ChoiceChip(
                    label: UrduAwareText(u,
                        style: TextStyle(fontFamily: fontFamily)),
                    selected: isSelected,
                    selectedColor: AppTheme.themeColor,
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87),
                    onSelected: (_) => setDialogState(() => selectedUnit = u),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
            ),
            AppButton(
              text: isUrdu ? 'محفوظ کریں' : 'Save',
              onPressed: () {
                final newName = nameCtrl.text.trim();
                Navigator.pop(dialogContext);
                if (newName.isNotEmpty) {
                  _updateItemNameAndUnit(
                      context, itemName, newName, selectedUnit);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetActionButton({
    required String label,
    required VoidCallback onTap,
    String? fontFamily,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: UrduAwareText(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkColor,
          ),
        ),
      ),
    );
  }

  Widget _sheetPurchaseRow(
    ItemPriceHistory h,
    double? oldPrice,
    bool isLast,
    bool isUrdu,
    String? fontFamily,
    DateFormat formatter,
  ) {
    final change = h.changePercentage;
    final isDecrease = change != null && change < 0;
    final isFirst = oldPrice == null;
    final badgeColor =
        isDecrease ? AppTheme.incomeColor : AppTheme.expenseColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chevron_left, color: Color(0xFF94A3B8), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  'Rs ${Formatters.formatAmount(h.total)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                ),
                const SizedBox(height: 2),
                UrduAwareText(
                  '${h.quantity.toStringAsFixed(h.quantity % 1 == 0 ? 0 : 1)} ${h.unit != null && h.unit!.isNotEmpty ? h.unit! : (isUrdu ? "عدد" : "units")}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (change != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: UrduAwareText(
                '${change.abs().toStringAsFixed(1)}% ${isDecrease ? "↓" : "↑"}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: UrduAwareText(
                isFirst
                    ? (isUrdu ? 'پہلی بار' : 'First time')
                    : (isUrdu ? 'وہی ریٹ' : 'Same rate'),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UrduAwareText(
                formatter.format(h.date),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
              if (h.daysInterval != null) ...[
                const SizedBox(height: 2),
                UrduAwareText(
                  isUrdu
                      ? '${h.daysInterval} دن بعد'
                      : '${h.daysInterval} days later',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetStat(String value, String label) {
    return Column(
      children: [
        UrduAwareText(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        UrduAwareText(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// SHEET RATE CHART PAINTER
// ═══════════════════════════════════════════════════════
class _SheetRateChartPainter extends CustomPainter {
  final List<double> prices;
  final Color color;

  _SheetRateChartPainter({required this.prices, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);

    final stepX = size.width / (prices.length - 1);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < prices.length; i++) {
      final x = i * stepX;
      final y = size.height -
          ((prices[i] - minPrice) / range) * (size.height - 20) -
          10;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
