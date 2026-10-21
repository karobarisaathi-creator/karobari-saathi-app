import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/utils/formatters.dart';

class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final movementMap = <String, StockMovement>{};
    for (final movement in stockService.movements) {
      final key = movement.id.isNotEmpty
          ? movement.id
          : '${movement.stockItemId}|${movement.type.name}|${movement.quantity}|${movement.timestamp.millisecondsSinceEpoch}';
      movementMap[key] = movement;
    }
    final movements = movementMap.values
        .where((movement) => movement.type != StockMovementType.purchase)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'اسٹاک ہسٹری لاگ' : 'Stock History Log',
      ),
      body: movements.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.clockAfternoon(),
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    UrduAwareText(
                      isUrdu
                          ? 'کوئی اسٹاک ہسٹری موجود نہیں'
                          : 'No history movements yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              itemCount: movements.length,
              itemBuilder: (context, index) {
                final m = movements[index];
                StockItem? stockItem;
                if (m.stockItemId.isNotEmpty) {
                  stockItem = stockService.items
                      .where((item) => item.id == m.stockItemId)
                      .firstOrNull;
                }

                String typeLabel;
                Color typeColor;
                switch (m.type) {
                  case StockMovementType.customerReturn:
                    typeLabel = isUrdu ? 'گاہک کی واپسی' : 'Customer Return';
                    typeColor = AppTheme.incomeColor;
                    break;
                  case StockMovementType.supplierReturn:
                    typeLabel = isUrdu ? 'سپلائر کو واپسی' : 'Supplier Return';
                    typeColor = AppTheme.expenseColor;
                    break;
                  case StockMovementType.sale:
                    typeLabel = isUrdu ? 'فروخت' : 'Sale';
                    typeColor = AppTheme.expenseColor;
                    break;
                  case StockMovementType.adjustment:
                    typeLabel = isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment';
                    typeColor = AppTheme.verifiedGold;
                    break;
                  case StockMovementType.purchase:
                    typeLabel = isUrdu ? 'خریداری' : 'Purchase';
                    typeColor = AppTheme.incomeColor;
                    break;
                }

                final itemName =
                    isUrdu && stockItem?.nameUrdu.isNotEmpty == true
                        ? stockItem!.nameUrdu
                        : m.stockItemName;
                final quantityLabel = isUrdu ? 'تعداد' : 'Quantity';
                final rateLabel = isUrdu ? 'ریٹ' : 'Rate';

                return Directionality(
                  textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    color: Theme.of(context).cardTheme.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: AppTheme.themeColor
                                      .withValues(alpha: 0.1),
                                  child: _buildMovementAvatar(
                                      stockItem, m, isUrdu),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: isUrdu
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    UrduAwareText(
                                      itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.darkColor,
                                        fontFamily: fontFamily,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      alignment: isUrdu
                                          ? WrapAlignment.end
                                          : WrapAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: typeColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: UrduAwareText(
                                            typeLabel,
                                            style: TextStyle(
                                              color: typeColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: fontFamily,
                                            ),
                                          ),
                                        ),
                                        if (m.partyName.isNotEmpty)
                                          UrduAwareText(
                                            isUrdu
                                                ? 'پارٹی: ${m.partyName}'
                                                : 'Party: ${m.partyName}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[700],
                                              fontFamily: fontFamily,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (m.reason.isNotEmpty || m.note.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            UrduAwareText(
                              m.note.isNotEmpty ? m.note : m.reason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 10),
                          Row(
                            textDirection:
                                isUrdu ? TextDirection.rtl : TextDirection.ltr,
                            children: [
                              _buildMovementMetric(
                                label: quantityLabel,
                                value:
                                    '${_formatQuantity(m.quantity)} ${stockItem?.unit ?? ''}'
                                        .trim(),
                                isUrdu: isUrdu,
                                fontFamily: fontFamily,
                              ),
                              const SizedBox(width: 12),
                              _buildMovementMetric(
                                label: rateLabel,
                                value:
                                    'Rs ${Formatters.formatAmount(m.unitPrice)}',
                                isUrdu: isUrdu,
                                fontFamily: fontFamily,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: isUrdu
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: UrduAwareText(
                              Formatters.formatDateWithTime(m.timestamp),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMovementMetric({
    required String label,
    required String value,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          UrduAwareText(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 3),
          Directionality(
            textDirection: TextDirection.ltr,
            child: UrduAwareText(
              value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.darkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return Formatters.formatAmount(quantity.toInt());
    }

    return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  Widget _buildMovementAvatar(
      StockItem? stockItem, StockMovement m, bool isUrdu) {
    final path = stockItem?.imagePath;
    if (path == null || path.isEmpty) {
      return Center(
        child: UrduAwareText(
          m.stockItemName.isNotEmpty ? m.stockItemName[0] : '?',
          style: const TextStyle(
            color: AppTheme.darkColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }
    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return isRemote
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: UrduAwareText(
                m.stockItemName.isNotEmpty ? m.stockItemName[0] : '?',
                style: const TextStyle(
                  color: AppTheme.darkColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          )
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: UrduAwareText(
                m.stockItemName.isNotEmpty ? m.stockItemName[0] : '?',
                style: const TextStyle(
                  color: AppTheme.darkColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
  }
}
