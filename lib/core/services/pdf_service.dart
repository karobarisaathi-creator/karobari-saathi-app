// lib/core/services/pdf_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'balance_service.dart';

class PdfService with ChangeNotifier {
  final BalanceService _balanceService = BalanceService();
  pw.Font? _urduFont;
  pw.Font? _urduFontBold;
  pw.Font? _englishFont;

  // ═══════════════════════════════════════════════════════════
  // FONTS
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadFonts() async {
    if (_urduFont == null) {
      try {
        final urduFontData =
            await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
        _urduFont = pw.Font.ttf(urduFontData);
      } catch (e) {
        debugPrint('Urdu font load error: $e');
        _urduFont = await _getEnglishFont();
      }
    }

    if (_urduFontBold == null) {
      try {
        final urduBoldData =
            await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
        _urduFontBold = pw.Font.ttf(urduBoldData);
      } catch (e) {
        debugPrint('Urdu bold font load error: $e');
        _urduFontBold = _urduFont;
      }
    }

    if (_englishFont == null) {
      _englishFont = await _getEnglishFont();
    }
  }

  Future<pw.Font> _getEnglishFont() async {
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('English font load error: $e');
      return pw.Font.ttf(
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ 1. SALES REPORT — نیا (Report button کے لیے)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateSalesReport(
    List<Transaction> transactions,
    bool isUrdu,
  ) async {
    await _loadFonts();
    final pdf = pw.Document();

    final sales = transactions
        .where((t) => t.isQuickBill && t.type == 'income')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    double totalSales = 0;
    double totalPending = 0;

    for (var t in sales) {
      final subtotal = t.subtotal > 0 ? t.subtotal : t.amount;
      totalSales += subtotal - t.discountAmount;
      totalPending += t.pendingAmount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => [
          _buildHeader(isUrdu ? 'سیلز رپورٹ' : 'Sales Report', isUrdu),
          pw.SizedBox(height: 20),
          _buildSalesTable(sales, isUrdu),
          pw.SizedBox(height: 20),
          _buildSalesSummary(totalSales, totalPending, isUrdu),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _buildSalesTable(List<Transaction> sales, bool isUrdu) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(1.2), // Date
        1: pw.FlexColumnWidth(1.2), // Bill #
        2: pw.FlexColumnWidth(2.0), // Customer/Items
        3: pw.FlexColumnWidth(1.3), // Total
        4: pw.FlexColumnWidth(1.2), // Received
        5: pw.FlexColumnWidth(1.2), // Pending
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell(isUrdu ? 'تاریخ' : 'Date', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'بل نمبر' : 'Bill #', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'گاہک' : 'Customer', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'کل' : 'Total', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'وصول' : 'Received', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'باقی' : 'Pending', isUrdu, true, 9),
          ],
        ),
        for (var t in sales)
          pw.TableRow(
            children: [
              _buildTableCell(
                  DateFormat('dd/MM/yy').format(t.date), false, false, 8),
              _buildTableCell(t.referenceNumber ?? '-', false, false, 8),
              _buildTableCell(
                t.accountId == QuickBillConstants.cashCustomerAccountId
                    ? (isUrdu ? 'نقد' : 'Cash')
                    : t.description,
                isUrdu,
                false,
                8,
              ),
              _buildTableCell(
                  Formatters.formatAmountWithCurrency(
                      (t.subtotal > 0 ? t.subtotal : t.amount) -
                          t.discountAmount),
                  false,
                  false,
                  8),
              _buildTableCell(
                  Formatters.formatAmountWithCurrency(t.receivedAmount),
                  false,
                  false,
                  8),
              _buildTableCell(
                  Formatters.formatAmountWithCurrency(t.pendingAmount),
                  false,
                  false,
                  8),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildSalesSummary(
      double totalSales, double totalPending, bool isUrdu) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(isUrdu ? 'خلاصہ' : 'Summary', isUrdu, true, 14),
          pw.SizedBox(height: 10),
          _buildSummaryRow(isUrdu ? 'کل فروخت:' : 'Total Sales:',
              Formatters.formatAmountWithCurrency(totalSales), isUrdu),
          _buildSummaryRow(isUrdu ? 'کل باقی:' : 'Total Pending:',
              Formatters.formatAmountWithCurrency(totalPending), isUrdu),
          pw.Divider(),
          _buildSummaryRow(
              isUrdu ? 'کل وصول شدہ:' : 'Total Received:',
              Formatters.formatAmountWithCurrency(totalSales - totalPending),
              isUrdu,
              isBold: true,
              color: PdfColors.green),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ 2. STOCK REPORT — نیا (Report button کے لیے)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateStockReport(
    List<StockItem> items,
    StockService stockService,
    bool isUrdu,
  ) async {
    await _loadFonts();
    final pdf = pw.Document();

    final active = items.where((i) => !i.isArchived).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    double totalStockValue = 0;
    int lowStockCount = 0;

    for (var item in active) {
      final currentStock =
          item.trackStock ? stockService.calculateCurrentStock(item.id) : 0.0;
      totalStockValue += currentStock * item.purchasePrice;
      if (item.trackStock && currentStock <= item.minStockAlert) {
        lowStockCount++;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => [
          _buildHeader(isUrdu ? 'اسٹاک رپورٹ' : 'Stock Report', isUrdu),
          pw.SizedBox(height: 20),
          _buildStockTable(active, stockService, isUrdu),
          pw.SizedBox(height: 20),
          _buildStockSummary(
              active.length, totalStockValue, lowStockCount, isUrdu),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _buildStockTable(
      List<StockItem> items, StockService stockService, bool isUrdu) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(2.5), // Item
        1: pw.FlexColumnWidth(1.5), // Category
        2: pw.FlexColumnWidth(1.0), // Qty
        3: pw.FlexColumnWidth(1.2), // Cost
        4: pw.FlexColumnWidth(1.2), // Sale
        5: pw.FlexColumnWidth(1.3), // Value
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell(isUrdu ? 'آئٹم' : 'Item', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'کیٹیگری' : 'Category', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'اسٹاک' : 'Stock', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'خرید' : 'Cost', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'فروخت' : 'Sale', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'مالیت' : 'Value', isUrdu, true, 9),
          ],
        ),
        for (var item in items)
          pw.TableRow(
            children: [
              _buildTableCell(item.name, isUrdu, false, 8),
              _buildTableCell(item.categoryName, isUrdu, false, 8),
              _buildTableCell(
                item.trackStock
                    ? Formatters.formatAmountWithCurrency(
                        stockService.calculateCurrentStock(item.id))
                    : '-',
                false,
                false,
                8,
              ),
              _buildTableCell(
                  Formatters.formatAmountWithCurrency(item.purchasePrice),
                  false,
                  false,
                  8),
              _buildTableCell(
                  Formatters.formatAmountWithCurrency(item.sellingPrice),
                  false,
                  false,
                  8),
              _buildTableCell(
                Formatters.formatAmountWithCurrency(
                  (item.trackStock
                          ? stockService.calculateCurrentStock(item.id)
                          : 0) *
                      item.purchasePrice,
                ),
                false,
                false,
                8,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildStockSummary(
      int totalItems, double totalValue, int lowStock, bool isUrdu) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(isUrdu ? 'خلاصہ' : 'Summary', isUrdu, true, 14),
          pw.SizedBox(height: 10),
          _buildSummaryRow(isUrdu ? 'کل آئٹمز:' : 'Total Items:',
              totalItems.toString(), isUrdu),
          _buildSummaryRow(isUrdu ? 'کل اسٹاک مالیت:' : 'Total Stock Value:',
              Formatters.formatAmountWithCurrency(totalValue), isUrdu),
          _buildSummaryRow(isUrdu ? 'کم اسٹاک آئٹمز:' : 'Low Stock Items:',
              lowStock.toString(), isUrdu,
              isBold: true,
              color: lowStock > 0 ? PdfColors.red : PdfColors.green),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ 3. PROFIT REPORT — نیا (Report button کے لیے)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateProfitReport(
    List<Transaction> transactions,
    StockService stockService,
    bool isUrdu,
  ) async {
    await _loadFonts();
    final pdf = pw.Document();

    final sales = transactions
        .where((t) => t.isQuickBill && t.type == 'income')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Item-wise profit
    final itemProfits = <String, _ProfitRow>{};
    double totalRevenue = 0;
    double totalProfit = 0;

    for (var tx in sales) {
      for (var item in tx.items) {
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

        final revenue = item.total > 0 ? item.total : item.rate * item.quantity;
        final profit = (item.rate - cost) * item.quantity;
        totalRevenue += revenue;
        totalProfit += profit;

        final key = item.description.trim();
        if (itemProfits.containsKey(key)) {
          itemProfits[key]!.addQuantity(item.quantity, profit, revenue);
        } else {
          itemProfits[key] = _ProfitRow(
            name: key,
            quantity: item.quantity,
            profit: profit,
            revenue: revenue,
            cost: cost,
          );
        }
      }
    }

    final profitList = itemProfits.values.toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => [
          _buildHeader(isUrdu ? 'منافع رپورٹ' : 'Profit Report', isUrdu),
          pw.SizedBox(height: 20),
          _buildProfitTable(profitList, isUrdu),
          pw.SizedBox(height: 20),
          _buildProfitSummary(totalRevenue, totalProfit, isUrdu),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _buildProfitTable(List<_ProfitRow> profits, bool isUrdu) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(2.5), // Item
        1: pw.FlexColumnWidth(1.0), // Qty
        2: pw.FlexColumnWidth(1.3), // Revenue
        3: pw.FlexColumnWidth(1.3), // Cost
        4: pw.FlexColumnWidth(1.4), // Profit
        5: pw.FlexColumnWidth(1.0), // Margin
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell(isUrdu ? 'آئٹم' : 'Item', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'تعداد' : 'Qty', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'آمدنی' : 'Revenue', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'لاگت' : 'Cost', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'منافع' : 'Profit', isUrdu, true, 9),
            _buildTableCell(isUrdu ? 'مارجن' : 'Margin', isUrdu, true, 9),
          ],
        ),
        for (var p in profits)
          pw.TableRow(
            children: [
              _buildTableCell(p.name, isUrdu, false, 8),
              _buildTableCell(Formatters.formatAmountWithCurrency(p.quantity),
                  false, false, 8),
              _buildTableCell(Formatters.formatAmountWithCurrency(p.revenue),
                  false, false, 8),
              _buildTableCell(
                  Formatters.formatAmountWithCurrency(p.revenue - p.profit),
                  false,
                  false,
                  8),
              _buildTableCell(Formatters.formatAmountWithCurrency(p.profit),
                  false, false, 8),
              _buildTableCell(
                  '${p.margin.toStringAsFixed(1)}%', false, false, 8),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildProfitSummary(
      double totalRevenue, double totalProfit, bool isUrdu) {
    final margin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(isUrdu ? 'خلاصہ' : 'Summary', isUrdu, true, 14),
          pw.SizedBox(height: 10),
          _buildSummaryRow(isUrdu ? 'کل آمدنی:' : 'Total Revenue:',
              Formatters.formatAmountWithCurrency(totalRevenue), isUrdu),
          _buildSummaryRow(isUrdu ? 'کل منافع:' : 'Total Profit:',
              Formatters.formatAmountWithCurrency(totalProfit), isUrdu),
          _buildSummaryRow(isUrdu ? 'منافع مارجن:' : 'Profit Margin:',
              '${margin.toStringAsFixed(1)}%', isUrdu),
          pw.Divider(),
          _buildSummaryRow(
              isUrdu ? 'اوسط منافع فی فروخت:' : 'Avg Profit per Sale:',
              Formatters.formatAmountWithCurrency(
                  totalRevenue > 0 ? totalProfit : 0),
              isUrdu,
              isBold: true,
              color: totalProfit >= 0 ? PdfColors.green : PdfColors.red),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // موجودہ متھڈز (legacy — برقرار)
  // ═══════════════════════════════════════════════════════════

  Future<void> generateTransactionReceipt({
    required Transaction transaction,
    required Account? account,
    required bool isUrdu,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => _buildReceiptContent(transaction, account, isUrdu),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _buildReceiptContent(
      Transaction transaction, Account? account, bool isUrdu) {
    final accountName = account?.name ?? (isUrdu ? 'نامعلوم' : 'Unknown');
    final accountPhone = account?.phone ?? '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 2),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _buildText(
              isUrdu ? 'کاروباری ساتھی' : 'Account App', isUrdu, true, 24),
          pw.SizedBox(height: 5),
          _buildText(isUrdu ? 'رسید' : 'RECEIPT', isUrdu, true, 16),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildText(isUrdu ? 'تاریخ:' : 'Date:', isUrdu, true, 10),
              _buildText(
                  DateFormat('dd-MM-yyyy hh:mm a')
                      .format(transaction.createdAt),
                  false,
                  false,
                  10),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildText(isUrdu ? 'کسٹمر:' : 'Customer:', isUrdu, true, 12),
              _buildText(accountName, isUrdu, true, 12),
            ],
          ),
          if (accountPhone.isNotEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildText(isUrdu ? 'فون:' : 'Phone:', isUrdu, false, 10),
                _buildText(accountPhone, false, false, 10),
              ],
            ),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell(
                      isUrdu ? 'تفصیل' : 'Description', isUrdu, true, 10),
                  _buildTableCell(isUrdu ? 'تعداد' : 'Qty', isUrdu, true, 10),
                  _buildTableCell(isUrdu ? 'ریٹ' : 'Rate', isUrdu, true, 10),
                  _buildTableCell(
                      isUrdu ? 'کل رقم' : 'Amount', isUrdu, true, 10),
                ],
              ),
              if (transaction.items.isNotEmpty)
                ...transaction.items.map((item) => pw.TableRow(children: [
                      _buildTableCell(item.description, isUrdu, false, 10),
                      _buildTableCell(
                          item.quantity.toString(), false, false, 10),
                      _buildTableCell(
                          item.rate.toStringAsFixed(0), false, false, 10),
                      _buildTableCell(
                          item.total.toStringAsFixed(0), false, true, 10),
                    ]))
              else
                pw.TableRow(children: [
                  _buildTableCell(transaction.description, isUrdu, false, 10),
                  _buildTableCell(
                      transaction.quantity.toString(), false, false, 10),
                  _buildTableCell(
                      transaction.rate.toStringAsFixed(0), false, false, 10),
                  _buildTableCell(
                      transaction.amount.toStringAsFixed(0), false, true, 10),
                ]),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.grey100,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildText(isUrdu ? 'کل رقم:' : 'Total:', isUrdu, true, 14),
                _buildText(
                    Formatters.formatAmountWithCurrency(transaction.amount),
                    false,
                    true,
                    14),
              ],
            ),
          ),
          if (transaction.receivedAmount > 0) ...[
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildText(
                    isUrdu ? 'وصول شدہ:' : 'Received:', isUrdu, false, 12),
                _buildText(
                    Formatters.formatAmountWithCurrency(
                        transaction.receivedAmount),
                    false,
                    false,
                    12),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildText(isUrdu ? 'بقیہ:' : 'Pending:', isUrdu, false, 12),
                _buildText(
                    Formatters.formatAmountWithCurrency(
                        transaction.pendingAmount),
                    false,
                    false,
                    12),
              ],
            ),
          ],
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildText(isUrdu ? 'دستخط وصول کنندہ' : 'Receiver Sign',
                        isUrdu, false, 10),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 80, height: 1, color: PdfColors.black),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _buildText(isUrdu ? 'دستخط مجاز' : 'Authorized Sign',
                        isUrdu, false, 10),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 80, height: 1, color: PdfColors.black),
                  ]),
            ],
          ),
          pw.SizedBox(height: 20),
          _buildText(
              isUrdu
                  ? 'شکریہ! دوبارہ تشریف لائیں'
                  : 'Thank you for your business!',
              isUrdu,
              false,
              10),
        ],
      ),
    );
  }

  Future<void> generateAllAccountsReport(
    List<Account> accounts,
    List<Transaction> transactions,
    bool isUrdu,
  ) async {
    await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => [
          _buildHeader(
              isUrdu ? 'تمام اکاؤنٹس کی رپورٹ' : 'All Accounts Report', isUrdu),
          pw.SizedBox(height: 20),
          _buildAllAccountsTable(accounts, isUrdu),
          pw.SizedBox(height: 20),
          _buildAllAccountsSummary(accounts, isUrdu),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _buildAllAccountsTable(List<Account> accounts, bool isUrdu) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(2.0),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell(isUrdu ? 'نام' : 'Name', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'فون' : 'Phone', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'بیلنس' : 'Balance', isUrdu, true, 10),
          ],
        ),
        for (var account in accounts)
          pw.TableRow(children: [
            _buildTableCell(account.name, isUrdu, false, 9),
            _buildTableCell(account.phone, false, false, 9),
            _buildTableCell(
                Formatters.formatAmountWithCurrency(account.balance),
                false,
                false,
                9),
          ]),
      ],
    );
  }

  pw.Widget _buildAllAccountsSummary(List<Account> accounts, bool isUrdu) {
    double totalPos = 0, totalNeg = 0;
    for (var acc in accounts) {
      if (acc.balance > 0) totalPos += acc.balance;
      if (acc.balance < 0) totalNeg += acc.balance;
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(isUrdu ? 'خلاصہ' : 'Summary', isUrdu, true, 16),
          pw.SizedBox(height: 15),
          _buildSummaryRow(isUrdu ? 'کل مثبت بیلنس:' : 'Total Positive:',
              Formatters.formatAmountWithCurrency(totalPos), isUrdu),
          _buildSummaryRow(isUrdu ? 'کل منفی بیلنس:' : 'Total Negative:',
              Formatters.formatAmountWithCurrency(totalNeg), isUrdu),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'نیٹ بیلنس:' : 'Net Balance:',
            Formatters.formatAmountWithCurrency(totalPos + totalNeg),
            isUrdu,
            isBold: true,
            color: (totalPos + totalNeg) >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  Future<void> generateTransactionReport({
    required List<Transaction> transactions,
    required String title,
    required bool isUrdu,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => [
          _buildHeader(title, isUrdu),
          pw.SizedBox(height: 20),
          _buildTransactionTable(transactions, isUrdu),
          pw.SizedBox(height: 20),
          _buildSummarySection(transactions, isUrdu),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> generateAccountStatement({
    required Account account,
    required List<Transaction> transactions,
    required bool isUrdu,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => [
          _buildAccountHeader(account, isUrdu),
          pw.SizedBox(height: 20),
          _buildTransactionTable(transactions, isUrdu),
          pw.SizedBox(height: 20),
          _buildAccountSummary(account, transactions, isUrdu),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> generateFinancialReport({
    required int year,
    required int month,
    required bool isUrdu,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();
    final monthlySummary = _balanceService.calculateMonthlySummary(year, month);
    final categorySummary =
        _balanceService.calculateCategorySummary('income', year, month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: isUrdu ? _urduFont! : _englishFont!,
          bold: isUrdu ? _urduFontBold! : _englishFont!,
        ),
        build: (context) => [
          _buildFinancialReportHeader(year, month, isUrdu),
          pw.SizedBox(height: 20),
          _buildFinancialSummary(monthlySummary, isUrdu),
          pw.SizedBox(height: 20),
          _buildCategoryChart(categorySummary, isUrdu),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers (موجودہ)
  // ═══════════════════════════════════════════════════════════
  pw.Widget _buildHeader(String title, bool isUrdu) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildText(isUrdu ? 'کاروباری ساتھی' : 'Account App', isUrdu, true, 24),
        pw.SizedBox(height: 10),
        _buildText(title, isUrdu, true, 18),
        pw.SizedBox(height: 10),
        _buildText(
          '${DateFormat('dd/MM/yyyy').format(DateTime.now())} ${DateFormat('hh:mm a').format(DateTime.now())}',
          false,
          false,
          12,
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildTransactionTable(
      List<Transaction> transactions, bool isUrdu) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell(isUrdu ? 'تاریخ' : 'Date', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'تفصیل' : 'Description', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'قسم' : 'Type', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'رقم' : 'Amount', isUrdu, true, 10),
          ],
        ),
        for (var transaction in transactions)
          pw.TableRow(children: [
            _buildTableCell(transaction.formattedDate, false, false, 9),
            _buildTableCell(transaction.description, isUrdu, false, 9),
            _buildTableCell(
              transaction.type == 'income'
                  ? (isUrdu ? 'جمع' : 'Credit')
                  : (isUrdu ? 'بنام' : 'Debit'),
              isUrdu,
              false,
              9,
            ),
            _buildTableCell(
                Formatters.formatAmountWithCurrency(transaction.amount),
                false,
                false,
                9),
          ]),
      ],
    );
  }

  pw.Widget _buildSummarySection(List<Transaction> transactions, bool isUrdu) {
    final totalIncome = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    final netProfit = totalIncome - totalExpense;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(isUrdu ? 'خلاصہ' : 'Summary', isUrdu, true, 16),
          pw.SizedBox(height: 15),
          _buildSummaryRow(isUrdu ? 'کل جمع:' : 'Total Received:',
              Formatters.formatAmountWithCurrency(totalIncome), isUrdu),
          _buildSummaryRow(isUrdu ? 'کل بنام:' : 'Total Paid:',
              Formatters.formatAmountWithCurrency(totalExpense), isUrdu),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'کل بیلنس:' : 'Total Balance:',
            Formatters.formatAmountWithCurrency(netProfit),
            isUrdu,
            isBold: true,
            color: netProfit >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAccountHeader(Account account, bool isUrdu) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildText(
            isUrdu ? 'اکاؤنٹ اسٹیٹمنٹ' : 'Account Statement', isUrdu, true, 20),
        pw.SizedBox(height: 15),
        _buildDetailRow(isUrdu ? 'نام:' : 'Name:', account.name, isUrdu),
        _buildDetailRow(isUrdu ? 'فون:' : 'Phone:', account.phone, isUrdu),
        _buildDetailRow(isUrdu ? 'کل بیلنس:' : 'Total Balance:',
            Formatters.formatAmountWithCurrency(account.balance), isUrdu),
        pw.SizedBox(height: 10),
        _buildText(
          '${DateFormat('dd/MM/yyyy').format(DateTime.now())} ${DateFormat('hh:mm a').format(DateTime.now())}',
          false,
          false,
          12,
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildAccountSummary(
      Account account, List<Transaction> transactions, bool isUrdu) {
    final accountIncome = _balanceService.calculateAccountIncome(account.id);
    final accountExpense = _balanceService.calculateAccountExpense(account.id);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(
              isUrdu ? 'اکاؤنٹ خلاصہ' : 'Account Summary', isUrdu, true, 16),
          pw.SizedBox(height: 15),
          _buildSummaryRow(
              isUrdu ? 'ابتدائی بیلنس:' : 'Initial Balance:',
              Formatters.formatAmountWithCurrency(account.initialBalance),
              isUrdu),
          _buildSummaryRow(isUrdu ? 'کل جمع:' : 'Total Received:',
              Formatters.formatAmountWithCurrency(accountIncome), isUrdu),
          _buildSummaryRow(isUrdu ? 'کل بنام:' : 'Total Paid:',
              Formatters.formatAmountWithCurrency(accountExpense), isUrdu),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'کل بیلنس:' : 'Total Balance:',
            Formatters.formatAmountWithCurrency(account.balance),
            isUrdu,
            isBold: true,
            color: account.balance >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFinancialReportHeader(int year, int month, bool isUrdu) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildText(
            isUrdu ? 'مالی رپورٹ' : 'Financial Report', isUrdu, true, 24),
        pw.SizedBox(height: 10),
        _buildText(
          '${isUrdu ? 'برائے' : 'For'} ${DateFormat('MMMM yyyy').format(DateTime(year, month))}',
          isUrdu,
          false,
          16,
        ),
        pw.SizedBox(height: 10),
        _buildText(
          '${DateFormat('dd/MM/yyyy').format(DateTime.now())} ${DateFormat('hh:mm a').format(DateTime.now())}',
          false,
          false,
          12,
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildFinancialSummary(Map<String, double> summary, bool isUrdu) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(
              isUrdu ? 'ماہانہ خلاصہ' : 'Monthly Summary', isUrdu, true, 18),
          pw.SizedBox(height: 15),
          _buildSummaryRow(
              isUrdu ? 'جمع (آمدنی):' : 'Received (Income):',
              Formatters.formatAmountWithCurrency(summary['income'] ?? 0),
              isUrdu),
          _buildSummaryRow(
              isUrdu ? 'بنام (اخراجات):' : 'Paid (Expense):',
              Formatters.formatAmountWithCurrency(summary['expense'] ?? 0),
              isUrdu),
          _buildSummaryRow(
              isUrdu ? 'بقایا:' : 'Pending:',
              Formatters.formatAmountWithCurrency(summary['pending'] ?? 0),
              isUrdu),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'کل بقیہ:' : 'Total Remaining:',
            Formatters.formatAmountWithCurrency(summary['net'] ?? 0),
            isUrdu,
            isBold: true,
            color: (summary['net'] ?? 0) >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCategoryChart(
      Map<String, double> categorySummary, bool isUrdu) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(isUrdu ? 'آمدنی کی تقسیم' : 'Income Distribution', isUrdu,
              true, 18),
          pw.SizedBox(height: 15),
          for (var entry in categorySummary.entries)
            _buildSummaryRow(entry.key,
                Formatters.formatAmountWithCurrency(entry.value), isUrdu),
        ],
      ),
    );
  }

  pw.Widget _buildText(String text, bool isUrdu, bool isBold, double fontSize) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        font: isUrdu ? (isBold ? _urduFontBold : _urduFont) : _englishFont,
      ),
      textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
  }

  pw.Widget _buildTableCell(
      String text, bool isUrdu, bool isHeader, double fontSize) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8.0),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: isUrdu ? (isHeader ? _urduFontBold : _urduFont) : _englishFont,
        ),
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value,
    bool isUrdu, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildText(label, isUrdu, isBold, 12),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            font: _englishFont,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDetailRow(String label, String value, bool isUrdu) {
    return pw.Row(
      children: [
        _buildText(label, isUrdu, false, 12),
        pw.SizedBox(width: 10),
        _buildText(value, isUrdu, false, 12),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Helper Classes
// ═══════════════════════════════════════════════════════════════
class _ProfitRow {
  final String name;
  double quantity;
  double profit;
  double revenue;
  final double cost;

  _ProfitRow({
    required this.name,
    required this.quantity,
    required this.profit,
    required this.revenue,
    required this.cost,
  });

  double get margin => revenue > 0 ? (profit / revenue) * 100 : 0;

  void addQuantity(double qty, double newProfit, double newRevenue) {
    quantity += qty;
    profit += newProfit;
    revenue += newRevenue;
  }
}
