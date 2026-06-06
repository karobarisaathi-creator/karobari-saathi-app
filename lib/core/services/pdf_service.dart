import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'balance_service.dart';


class PdfService with ChangeNotifier {
  final BalanceService _balanceService = BalanceService();
  pw.Font? _urduFont;
  pw.Font? _urduFontBold;
  pw.Font? _englishFont;

  // Load Fonts
  Future<void> _loadFonts() async {
    // Load Urdu/Arabic Regular Font
    if (_urduFont == null) {
      try {
        final urduFontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
        _urduFont = pw.Font.ttf(urduFontData);
      } catch (e) {
        print('Urdu font load error: $e');
        _urduFont = await _getEnglishFont();
      }
    }

    // Load Urdu/Arabic Bold Font
    if (_urduFontBold == null) {
      try {
        final urduBoldData = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
        _urduFontBold = pw.Font.ttf(urduBoldData);
      } catch (e) {
        print('Urdu bold font load error: $e');
        _urduFontBold = _urduFont;
      }
    }

    // Load English Font
    if (_englishFont == null) {
      _englishFont = await _getEnglishFont();
    }
  }

  Future<pw.Font> _getEnglishFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      print('English font load error: $e');
      return pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    }
  }

  // Helper to reshape Arabic/Urdu text
  String _formatText(String text) {
    return text;
  }

  // --- Generate Single Transaction Receipt (Invoice) ---
  Future<void> generateTransactionReceipt({
    required Transaction transaction,
    required Account? account,
    required bool isUrdu,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, // Smaller page size for receipt
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

  pw.Widget _buildReceiptContent(Transaction transaction, Account? account, bool isUrdu) {
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
          // Business Header
          _buildText(isUrdu ? 'کاروباری ساتھی' : 'Account App', isUrdu, true, 24),
          pw.SizedBox(height: 5),
          _buildText(isUrdu ? 'رسید' : 'RECEIPT', isUrdu, true, 16),
          pw.Divider(thickness: 2),
          
          pw.SizedBox(height: 10),

          // Date & Time
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildText(isUrdu ? 'تاریخ:' : 'Date:', isUrdu, true, 10),
              _buildText(DateFormat('dd-MM-yyyy hh:mm a').format(transaction.createdAt), false, false, 10),
            ],
          ),
          pw.SizedBox(height: 15),

          // Customer Details
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

          // Transaction Details Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell(isUrdu ? 'تفصیل' : 'Description', isUrdu, true, 10),
                  _buildTableCell(isUrdu ? 'تعداد' : 'Qty', isUrdu, true, 10),
                  _buildTableCell(isUrdu ? 'ریٹ' : 'Rate', isUrdu, true, 10),
                  _buildTableCell(isUrdu ? 'کل رقم' : 'Amount', isUrdu, true, 10),
                ],
              ),
              // Data Rows
              if (transaction.items.isNotEmpty)
                ...transaction.items.map((item) => pw.TableRow(
                   children: [
                     _buildTableCell(item.description, isUrdu, false, 10),
                     _buildTableCell(item.quantity.toString(), false, false, 10),
                     _buildTableCell(item.rate.toStringAsFixed(0), false, false, 10),
                     _buildTableCell(item.total.toStringAsFixed(0), false, true, 10),
                   ]
                ))
              else
                 // Legacy support (fallback to main fields if no items)
                 pw.TableRow(
                   children: [
                     _buildTableCell(transaction.description, isUrdu, false, 10),
                     _buildTableCell(transaction.quantity.toString(), false, false, 10),
                     _buildTableCell(transaction.rate.toStringAsFixed(0), false, false, 10),
                     _buildTableCell(transaction.amount.toStringAsFixed(0), false, true, 10),
                   ],
                 ),
            ],
          ),

          pw.SizedBox(height: 15),

          // Total Amount Section
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.grey100,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildText(isUrdu ? 'کل رقم (RS):' : 'Total (RS):', isUrdu, true, 14),
                _buildText(transaction.amount.toStringAsFixed(0), false, true, 14),
              ],
            ),
          ),
          
          if (transaction.receivedAmount > 0)
            pw.Column(
              children: [
                pw.SizedBox(height: 5),
                 pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildText(isUrdu ? 'وصول شدہ:' : 'Received:', isUrdu, false, 12),
                    _buildText(transaction.receivedAmount.toStringAsFixed(0), false, false, 12),
                  ],
                ),
                 pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildText(isUrdu ? 'بقیہ:' : 'Pending:', isUrdu, false, 12),
                    _buildText(transaction.pendingAmount.toStringAsFixed(0), false, false, 12),
                  ],
                ),
              ],
            ),

          pw.Spacer(),

          // Footer / Signature
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.start,
                 children: [
                    _buildText(isUrdu ? 'دستخط وصول کنندہ' : 'Receiver Sign', isUrdu, false, 10),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 80, height: 1, color: PdfColors.black),
                 ]
              ),
              pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.end,
                 children: [
                    _buildText(isUrdu ? 'دستخط مجاز' : 'Authorized Sign', isUrdu, false, 10),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 80, height: 1, color: PdfColors.black),
                 ]
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          _buildText(isUrdu ? 'شکریہ! دوبارہ تشریف لائیں' : 'Thank you for your business!', isUrdu, false, 10),
        ],
      ),
    );
  }

  // --- Generate ALL Accounts Report (New Method) ---
  Future<void> generateAllAccountsReport(
    List<Account> accounts,
    List<Transaction> transactions,
    bool isUrdu,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    double totalBalance = 0;

    for (var acc in accounts) {
       totalBalance += acc.balance;
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
          _buildHeader(isUrdu ? 'تمام اکاؤنٹس کی رپورٹ' : 'All Accounts Report', isUrdu),
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
        0: pw.FlexColumnWidth(2.0), // Name
        1: pw.FlexColumnWidth(1.5), // Phone
        2: pw.FlexColumnWidth(1.5), // Balance
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            _buildTableCell(isUrdu ? 'نام' : 'Name', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'فون' : 'Phone', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'بیلنس' : 'Balance', isUrdu, true, 10),
          ],
        ),
        for (var account in accounts)
          pw.TableRow(
            children: [
              _buildTableCell(account.name, isUrdu, false, 9),
              _buildTableCell(account.phone, false, false, 9),
              _buildTableCell(
                  'RS ${account.balance.toStringAsFixed(0)}', 
                  false, 
                  false, 
                  9
              ),
            ],
          ),
      ],
    );
  }
  
  pw.Widget _buildAllAccountsSummary(List<Account> accounts, bool isUrdu) {
      double totalPos = 0;
      double totalNeg = 0;
      
      for (var acc in accounts) {
          if (acc.balance > 0) totalPos += acc.balance;
          if (acc.balance < 0) totalNeg += acc.balance;
      }
      
      return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(
            isUrdu ? 'خلاصہ' : 'Summary',
            isUrdu,
            true,
            16,
          ),
          pw.SizedBox(height: 15),
          _buildSummaryRow(
              isUrdu ? 'کل مثبت بیلنس:' : 'Total Positive:',
              'RS ${totalPos.toStringAsFixed(0)}',
              isUrdu
          ),
          _buildSummaryRow(
              isUrdu ? 'کل منفی بیلنس:' : 'Total Negative:',
              'RS ${totalNeg.toStringAsFixed(0)}',
              isUrdu
          ),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'نیٹ بیلنس:' : 'Net Balance:',
            'RS ${(totalPos + totalNeg).toStringAsFixed(0)}',
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
    final categorySummary = _balanceService.calculateCategorySummary(
      'income',
      year,
      month,
    );

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

  pw.Widget _buildHeader(String title, bool isUrdu) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildText(
          isUrdu ? 'کاروباری ساتھی' : 'Account App',
          isUrdu,
          true,
          24,
        ),
        pw.SizedBox(height: 10),
        _buildText(
          title,
          isUrdu,
          true,
          18,
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

  pw.Widget _buildTransactionTable(
      List<Transaction> transactions,
      bool isUrdu,
      ) {
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
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            _buildTableCell(isUrdu ? 'تاریخ' : 'Date', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'تفصیل' : 'Description', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'قسم' : 'Type', isUrdu, true, 10),
            _buildTableCell(isUrdu ? 'رقم' : 'Amount', isUrdu, true, 10),
          ],
        ),
        for (var transaction in transactions)
          pw.TableRow(
            children: [
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
              _buildTableCell('RS ${transaction.amount.toStringAsFixed(2)}', false, false, 9),
            ],
          ),
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
          _buildText(
            isUrdu ? 'خلاصہ' : 'Summary',
            isUrdu,
            true,
            16,
          ),
          pw.SizedBox(height: 15),
          _buildSummaryRow(
              isUrdu ? 'کل جمع:' : 'Total Received:',
              'RS ${totalIncome.toStringAsFixed(2)}',
              isUrdu
          ),
          _buildSummaryRow(
              isUrdu ? 'کل بنام:' : 'Total Paid:',
              'RS ${totalExpense.toStringAsFixed(2)}',
              isUrdu
          ),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'کل بیلنس:' : 'Total Balance:',
            'RS ${netProfit.toStringAsFixed(2)}',
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
          isUrdu ? 'اکاؤنٹ اسٹیٹمنٹ' : 'Account Statement',
          isUrdu,
          true,
          20,
        ),
        pw.SizedBox(height: 15),
        _buildDetailRow(isUrdu ? 'نام:' : 'Name:', account.name, isUrdu),
        _buildDetailRow(isUrdu ? 'فون:' : 'Phone:', account.phone, isUrdu),
        _buildDetailRow(
            isUrdu ? 'کل بیلنس:' : 'Total Balance:',
            'RS ${account.balance.toStringAsFixed(2)}',
            isUrdu
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

  pw.Widget _buildAccountSummary(
      Account account,
      List<Transaction> transactions,
      bool isUrdu,
      ) {
    final accountIncome = _balanceService.calculateAccountIncome(account.id);
    final accountExpense = _balanceService.calculateAccountExpense(account.id);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(
            isUrdu ? 'اکاؤنٹ خلاصہ' : 'Account Summary',
            isUrdu,
            true,
            16,
          ),
          pw.SizedBox(height: 15),
          _buildSummaryRow(
              isUrdu ? 'ابتدائی بیلنس:' : 'Initial Balance:',
              'RS ${account.initialBalance.toStringAsFixed(2)}',
              isUrdu
          ),
          _buildSummaryRow(
              isUrdu ? 'کل جمع:' : 'Total Received:',
              'RS ${accountIncome.toStringAsFixed(2)}',
              isUrdu
          ),
          _buildSummaryRow(
              isUrdu ? 'کل بنام:' : 'Total Paid:',
              'RS ${accountExpense.toStringAsFixed(2)}',
              isUrdu
          ),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'کل بیلنس:' : 'Total Balance:',
            'RS ${account.balance.toStringAsFixed(2)}',
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
          isUrdu ? 'مالی رپورٹ' : 'Financial Report',
          isUrdu,
          true,
          24,
        ),
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
            isUrdu ? 'ماہانہ خلاصہ' : 'Monthly Summary',
            isUrdu,
            true,
            18,
          ),
          pw.SizedBox(height: 15),
          _buildSummaryRow(
              isUrdu ? 'جمع (آمدنی):' : 'Received (Income):',
              'RS ${summary['income']?.toStringAsFixed(2) ?? '0.00'}',
              isUrdu
          ),
          _buildSummaryRow(
              isUrdu ? 'بنام (اخراجات):' : 'Paid (Expense):',
              'RS ${summary['expense']?.toStringAsFixed(2) ?? '0.00'}',
              isUrdu
          ),
          _buildSummaryRow(
              isUrdu ? 'بقایا:' : 'Pending:',
              'RS ${summary['pending']?.toStringAsFixed(2) ?? '0.00'}',
              isUrdu
          ),
          pw.Divider(),
          _buildSummaryRow(
            isUrdu ? 'کل بقیہ:' : 'Total Remaining:',
            'RS ${summary['net']?.toStringAsFixed(2) ?? '0.00'}',
            isUrdu,
            isBold: true,
            color: (summary['net'] ?? 0) >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCategoryChart(
      Map<String, double> categorySummary,
      bool isUrdu,
      ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildText(
            isUrdu ? 'آمدنی کی تقسیم' : 'Income Distribution',
            isUrdu,
            true,
            18,
          ),
          pw.SizedBox(height: 15),
          for (var entry in categorySummary.entries)
            _buildSummaryRow(
                entry.key,
                'RS ${entry.value.toStringAsFixed(2)}',
                isUrdu
            ),
        ],
      ),
    );
  }

  // Helper Methods
  pw.Widget _buildText(String text, bool isUrdu, bool isBold, double fontSize) {
    final processedText = isUrdu ? _formatText(text) : text;

    return pw.Text(
      processedText,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        font: isUrdu ? (isBold ? _urduFontBold : _urduFont) : _englishFont,
      ),
      textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
  }

  pw.Widget _buildTableCell(String text, bool isUrdu, bool isHeader, double fontSize) {
    final processedText = isUrdu ? _formatText(text) : text;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8.0),
      child: pw.Text(
        processedText,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: isUrdu ? (isHeader ? _urduFontBold : _urduFont) : _englishFont,
        ),
        textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, String value, bool isUrdu, {bool isBold = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildText(label, isUrdu, isBold, 12),
        _buildText(value, false, isBold, 12),
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
