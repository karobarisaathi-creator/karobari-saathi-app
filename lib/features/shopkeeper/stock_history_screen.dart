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

class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final movements = stockService.movements;

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
              padding: const EdgeInsets.all(16),
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
                switch (m.type) {
                  case StockMovementType.purchase:
                  case StockMovementType.customerReturn:
                    typeLabel = m.type == StockMovementType.purchase
                        ? (isUrdu ? 'خریداری (Stock In)' : 'Purchase')
                        : (isUrdu ? 'گاہک کی واپسی' : 'Customer Return');
                    break;
                  case StockMovementType.sale:
                  case StockMovementType.supplierReturn:
                    typeLabel = m.type == StockMovementType.sale
                        ? (isUrdu ? 'فروخت (Stock Out)' : 'Sale')
                        : (isUrdu ? 'سپلاٸر کو واپسی' : 'Supplier Return');
                    break;
                  case StockMovementType.adjustment:
                    typeLabel = isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment';
                    break;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 42,
                        height: 42,
                        color: AppTheme.themeColor.withValues(alpha: 0.1),
                        child: _buildMovementAvatar(stockItem, m, isUrdu),
                      ),
                    ),
                    title: UrduAwareText(
                      m.stockItemName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: fontFamily,
                      ),
                    ),
                    subtitle: UrduAwareText(
                      '$typeLabel • ${m.reason.isNotEmpty ? m.reason : (isUrdu ? 'معمول کا لین دین' : 'Regular transaction')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontFamily: fontFamily,
                      ),
                    ),
                    trailing: UrduAwareText(
                      '${m.quantity} x Rs. ${m.unitPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
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
