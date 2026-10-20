// lib/features/shopkeeper/cash_customer_bills_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/utils/receipt_dialog_helper.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';

class CashCustomerBillsScreen extends StatelessWidget {
  const CashCustomerBillsScreen({super.key});

  double _getTxDisplayAmount(Transaction tx) {
    if (tx.isQuickBill) {
      if (tx.subtotal > 0) {
        return (tx.subtotal - tx.discountAmount).clamp(0, double.infinity);
      }
      if ((tx.receivedAmount + tx.pendingAmount) > 0) {
        return tx.receivedAmount + tx.pendingAmount;
      }
    }
    return tx.amount > 0 ? tx.amount : (tx.receivedAmount + tx.pendingAmount);
  }

  double _calculateTxProfit(Transaction tx, StockService stockService) {
    double profit = 0;
    for (final item in tx.items) {
      double cost = 0;
      if (item.stockItemId != null && item.stockItemId!.isNotEmpty) {
        final stockItem = stockService.items
            .where((i) => i.id == item.stockItemId)
            .firstOrNull;
        if (stockItem != null) {
          cost = stockItem.purchasePrice;
        } else {
          cost = stockService.calculateWeightedAverageCost(item.stockItemId!);
        }
      }
      final itemProfit = (item.rate - cost) * item.quantity;
      profit += itemProfit;
    }
    if (tx.items.isEmpty) {
      final displayAmt = _getTxDisplayAmount(tx);
      profit = displayAmt * 0.2; // 20% estimated profit
    }
    return profit;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final databaseService = Provider.of<DatabaseService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final cashBills = databaseService
        .getAllTransactions()
        .where((t) => 
            (t.accountId == QuickBillConstants.cashCustomerAccountId || t.isQuickBill) &&
            t.pendingAmount <= 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Group by date (yyyy-MM-dd)
    final groupedBills = <String, List<Transaction>>{};
    for (final tx in cashBills) {
      final dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      groupedBills.putIfAbsent(dateKey, () => []).add(tx);
    }

    final dateKeys = groupedBills.keys.toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'نقد گاہک کے بل' : 'Cash Customer Bills',
      ),
      body: cashBills.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.receipt(PhosphorIconsStyle.duotone),
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  UrduAwareText(
                    isUrdu ? 'کوئی نقد بل موجود نہیں' : 'No cash bills found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: dateKeys.length,
              itemBuilder: (context, dateIndex) {
                final dateKey = dateKeys[dateIndex];
                final dayBills = groupedBills[dateKey]!;
                final parsedDate = DateTime.parse(dateKey);
                final formattedDateHeader = DateFormat('dd MMM yyyy').format(parsedDate);

                double dayTotalAmount = 0;
                double dayTotalProfit = 0;
                for (final tx in dayBills) {
                  dayTotalAmount += _getTxDisplayAmount(tx);
                  dayTotalProfit += _calculateTxProfit(tx, stockService);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200, width: 1.5),
                  ),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header inside Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.calendarBlank(), size: 16, color: AppTheme.themeColor),
                            const SizedBox(width: 6),
                            UrduAwareText(
                              formattedDateHeader,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.themeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: UrduAwareText(
                                isUrdu ? '${dayBills.length} بل' : '${dayBills.length} bills',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.themeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFEEF1F5)),

                      // Bills list separated by full-width dividers
                      ...dayBills.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final tx = entry.value;
                        final billNo = tx.referenceNumber?.trim().isNotEmpty == true
                            ? tx.referenceNumber!
                            : tx.id.substring(tx.id.length - 4);
                        final displayAmount = _getTxDisplayAmount(tx);
                        final txProfit = _calculateTxProfit(tx, stockService);

                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                ReceiptDialogHelper.showReceiptDialog(
                                  context,
                                  transaction: tx,
                                  isLocalTransaction: true,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppTheme.verifiedGold.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                                        color: AppTheme.verifiedGold,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          UrduAwareText(
                                            '${isUrdu ? 'بل #' : 'Bill #'}$billNo',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              fontFamily: fontFamily,
                                              color: AppTheme.darkColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              UrduAwareText(
                                                DateFormat('hh:mm a').format(tx.date),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              if (tx.items.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                                const SizedBox(width: 6),
                                                UrduAwareText(
                                                  isUrdu
                                                      ? '${tx.items.length} اشیاء'
                                                      : '${tx.items.length} items',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        UrduAwareText(
                                          'Rs ${Formatters.formatAmount(displayAmount)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: AppTheme.incomeColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        UrduAwareText(
                                          '${isUrdu ? 'نفع:' : 'Profit:'} Rs ${Formatters.formatAmount(txProfit)}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.verifiedGold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (idx < dayBills.length - 1)
                              const Divider(height: 1, color: Color(0xFFEEF1F5)),
                          ],
                        );
                      }),

                      const Divider(height: 1, color: Color(0xFFEEF1F5)),

                      // Bottom Total Row (Edge-to-edge full width layout)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Row(
                          children: [
                            UrduAwareText(
                              isUrdu ? 'اس دن کا کل ٹوٹل:' : 'Day Total:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                                fontFamily: fontFamily,
                              ),
                            ),
                            const Spacer(),
                            UrduAwareText(
                              'Rs ${Formatters.formatAmount(dayTotalAmount)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            UrduAwareText(
                              '${isUrdu ? 'نفع:' : 'Profit:'} Rs ${Formatters.formatAmount(dayTotalProfit)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.verifiedGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
