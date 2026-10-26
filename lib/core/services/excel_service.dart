// lib/core/services/excel_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';

class ExcelService with ChangeNotifier {
  // ═══════════════════════════════════════════════════════════
  // CSV Helpers
  // ═══════════════════════════════════════════════════════════
  String _listToCsv(List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM

    for (final row in rows) {
      final line = row.map((field) {
        String value = field?.toString() ?? '';
        if (value.contains(',') ||
            value.contains('"') ||
            value.contains('\n')) {
          value = value.replaceAll('"', '""');
          return '"$value"';
        }
        return value;
      }).join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  Future<void> _writeAndShare(
    List<List<dynamic>> rows,
    String filename,
    String shareText,
  ) async {
    final csvData = _listToCsv(rows);
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/$filename";
    final File file = File(path);
    await file.writeAsBytes(utf8.encode(csvData));
    await Share.shareXFiles([XFile(path)], text: shareText);
  }

  // ═══════════════════════════════════════════════════════════
  // 1. ALL ACCOUNTS (موجودہ — legacy)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateAndShareAllAccountsCsv(
    List<Account> accounts,
    bool isUrdu,
  ) async {
    final rows = <List<dynamic>>[
      [
        isUrdu ? 'نام' : 'Name',
        isUrdu ? 'فون' : 'Phone',
        isUrdu ? 'بیلنس' : 'Balance',
      ],
    ];

    for (var account in accounts) {
      rows.add([
        account.name,
        account.phone,
        Formatters.formatAmountWithCurrency(account.balance),
      ]);
    }

    await _writeAndShare(
      rows,
      'all_accounts_report.csv',
      isUrdu ? 'تمام اکاؤنٹس کی رپورٹ' : 'All Accounts Report',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. TRANSACTIONS (موجودہ — legacy)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateAndShareTransactionReportCsv(
    List<Transaction> transactions,
    String title,
    bool isUrdu,
  ) async {
    final rows = <List<dynamic>>[
      [title],
      [],
      [
        isUrdu ? 'تاریخ' : 'Date',
        isUrdu ? 'تفصیل' : 'Description',
        isUrdu ? 'قسم' : 'Type',
        isUrdu ? 'رقم' : 'Amount',
      ],
    ];

    for (var t in transactions) {
      rows.add([
        t.formattedDate,
        t.description,
        t.type == 'income'
            ? (isUrdu ? 'جمع' : 'Credit')
            : (isUrdu ? 'بنام' : 'Debit'),
        Formatters.formatAmountWithCurrency(t.amount),
      ]);
    }

    await _writeAndShare(rows, 'transaction_report.csv', title);
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ 3. SALES CSV — نیا (Report button کے لیے)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateSalesCsv(
    List<Transaction> transactions,
    bool isUrdu,
  ) async {
    final sales = transactions
        .where((t) => t.isQuickBill && t.type == 'income')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final rows = <List<dynamic>>[
      [isUrdu ? 'سیلز رپورٹ' : 'Sales Report'],
      [
        isUrdu ? 'تاریخ' : 'Date',
        isUrdu ? 'بل نمبر' : 'Bill #',
        isUrdu ? 'گاہک' : 'Customer',
        isUrdu ? 'اشیاء' : 'Items',
        isUrdu ? 'کل' : 'Subtotal',
        isUrdu ? 'رعایت' : 'Discount',
        isUrdu ? 'خالص' : 'Total',
        isUrdu ? 'وصول' : 'Received',
        isUrdu ? 'باقی' : 'Pending',
        isUrdu ? 'طریقہ' : 'Method',
      ],
    ];

    double totalSales = 0;
    double totalPending = 0;

    for (var t in sales) {
      final subtotal = t.subtotal > 0 ? t.subtotal : t.amount;
      final total = subtotal - t.discountAmount;
      totalSales += total;
      totalPending += t.pendingAmount;

      rows.add([
        DateFormat('dd/MM/yyyy').format(t.date),
        t.referenceNumber ?? '',
        t.accountId == QuickBillConstants.cashCustomerAccountId
            ? (isUrdu ? 'نقد گاہک' : 'Cash')
            : (t.description.isNotEmpty ? t.description : ''),
        t.items.length.toString(),
        Formatters.formatAmountWithCurrency(subtotal),
        Formatters.formatAmountWithCurrency(t.discountAmount),
        Formatters.formatAmountWithCurrency(total),
        Formatters.formatAmountWithCurrency(t.receivedAmount),
        Formatters.formatAmountWithCurrency(t.pendingAmount),
        t.paymentMethod,
      ]);
    }

    rows.add([]);
    rows.add([
      isUrdu ? 'خلاصہ' : 'Summary',
      '',
      '',
      '',
      '',
      '',
      Formatters.formatAmountWithCurrency(totalSales),
      '',
      Formatters.formatAmountWithCurrency(totalPending),
      '',
    ]);

    await _writeAndShare(
      rows,
      'sales_report.csv',
      isUrdu ? 'سیلز رپورٹ' : 'Sales Report',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ 4. STOCK CSV — نیا (Report button کے لیے)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateStockCsv(
    List<StockItem> items,
    StockService stockService,
    bool isUrdu,
  ) async {
    final active = items.where((i) => !i.isArchived).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final rows = <List<dynamic>>[
      [isUrdu ? 'اسٹاک رپورٹ' : 'Stock Report'],
      [
        isUrdu ? 'آئٹم' : 'Item',
        isUrdu ? 'کیٹیگری' : 'Category',
        isUrdu ? 'اکائی' : 'Unit',
        isUrdu ? 'خرید قیمت' : 'Cost Price',
        isUrdu ? 'فروخت قیمت' : 'Sale Price',
        isUrdu ? 'موجودہ اسٹاک' : 'Current Stock',
        isUrdu ? 'کم الرٹ' : 'Min Alert',
        isUrdu ? 'کل مالیت' : 'Stock Value',
      ],
    ];

    double totalStockValue = 0;

    for (var item in active) {
      final currentStock =
          item.trackStock ? stockService.calculateCurrentStock(item.id) : 0.0;
      final stockValue = currentStock * item.purchasePrice;
      totalStockValue += stockValue;

      rows.add([
        item.name,
        item.categoryName,
        item.unit,
        Formatters.formatAmountWithCurrency(item.purchasePrice),
        Formatters.formatAmountWithCurrency(item.sellingPrice),
        item.trackStock
            ? Formatters.formatAmountWithCurrency(currentStock)
            : (isUrdu ? 'ٹریک نہیں' : 'Not tracked'),
        Formatters.formatAmountWithCurrency(item.minStockAlert),
        Formatters.formatAmountWithCurrency(stockValue),
      ]);
    }

    rows.add([]);
    rows.add([
      isUrdu ? 'کل اسٹاک مالیت' : 'Total Stock Value',
      '',
      '',
      '',
      '',
      '',
      '',
      Formatters.formatAmountWithCurrency(totalStockValue),
    ]);
    rows.add([
      isUrdu ? 'کل اشیاء' : 'Total Items',
      active.length.toString(),
    ]);

    await _writeAndShare(
      rows,
      'stock_report.csv',
      isUrdu ? 'اسٹاک رپورٹ' : 'Stock Report',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ 5. PROFIT CSV — نیا (Report button کے لیے)
  // ═══════════════════════════════════════════════════════════
  Future<void> generateProfitCsv(
    List<Transaction> transactions,
    StockService stockService,
    bool isUrdu,
  ) async {
    final sales = transactions
        .where((t) => t.isQuickBill && t.type == 'income')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final rows = <List<dynamic>>[
      [isUrdu ? 'منافع رپورٹ' : 'Profit Report'],
      [
        isUrdu ? 'تاریخ' : 'Date',
        isUrdu ? 'بل نمبر' : 'Bill #',
        isUrdu ? 'آئٹم' : 'Item',
        isUrdu ? 'تعداد' : 'Qty',
        isUrdu ? 'فروخت ریٹ' : 'Sale Rate',
        isUrdu ? 'خرید قیمت' : 'Cost',
        isUrdu ? 'فی یونٹ منافع' : 'Profit/Unit',
        isUrdu ? 'کل منافع' : 'Total Profit',
      ],
    ];

    double totalProfit = 0;

    for (var tx in sales) {
      for (var item in tx.items) {
        // خرید قیمت تلاش کریں
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
        totalProfit += itemProfit;

        rows.add([
          DateFormat('dd/MM/yyyy').format(tx.date),
          tx.referenceNumber ?? '',
          item.description,
          Formatters.formatAmountWithCurrency(item.quantity),
          Formatters.formatAmountWithCurrency(item.rate),
          Formatters.formatAmountWithCurrency(cost),
          Formatters.formatAmountWithCurrency(item.rate - cost),
          Formatters.formatAmountWithCurrency(itemProfit),
        ]);
      }
    }

    rows.add([]);
    rows.add([
      isUrdu ? 'کل منافع' : 'Total Profit',
      '',
      '',
      '',
      '',
      '',
      '',
      Formatters.formatAmountWithCurrency(totalProfit),
    ]);

    await _writeAndShare(
      rows,
      'profit_report.csv',
      isUrdu ? 'منافع رپورٹ' : 'Profit Report',
    );
  }
}
