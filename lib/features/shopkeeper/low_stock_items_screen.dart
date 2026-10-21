import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/stock_card.dart';
import 'package:account_app/features/shopkeeper/stock_adjustment_dialog.dart';
import 'package:account_app/features/shopkeeper/stock_detail_screen.dart';

class LowStockItemsScreen extends StatelessWidget {
  const LowStockItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final lowStockItems = stockService.items.where((i) {
      if (i.isArchived || !i.trackStock) return false;
      final currentStock = stockService.calculateCurrentStock(i.id);
      return currentStock <= i.minStockAlert;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'کم اسٹاک آئٹمز' : 'Low Stock Items',
      ),
      body: lowStockItems.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.checkCircle(),
                      size: 64,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 16),
                    UrduAwareText(
                      isUrdu
                          ? 'تمام اسٹاک تسلی بخش ہے!'
                          : 'All stock levels are optimal!',
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
              itemCount: lowStockItems.length,
              itemBuilder: (context, index) {
                final item = lowStockItems[index];
                return StockCard(
                  item: item,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockDetailScreen(item: item),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
