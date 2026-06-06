import 'dart:io';
import 'dart:convert'; // Import for utf8
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';

class ExcelService with ChangeNotifier {
  
  // Helper function to convert list of rows to CSV format manually
  // Using standard CSV with UTF-8 BOM for Excel support with Urdu
  String _listToCsv(List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    // Add BOM for UTF-8 to help Excel open it correctly with special characters (Urdu)
    buffer.write('\uFEFF'); 
    
    for (final row in rows) {
      final line = row.map((field) {
        String value = field.toString();
        // Escape quotes and wrap in quotes if necessary
        if (value.contains(',') || value.contains('"') || value.contains('\n')) {
          value = value.replaceAll('"', '""');
          return '"$value"';
        }
        return value;
      }).join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  Future<void> generateAndShareAllAccountsCsv(
    List<Account> accounts,
    bool isUrdu,
  ) async {
    
    List<List<dynamic>> rows = [];
    
    // Header
    rows.add([
      isUrdu ? 'نام' : 'Name',
      isUrdu ? 'فون' : 'Phone',
      isUrdu ? 'بیلنس' : 'Balance',
    ]);

    // Data
    for (var account in accounts) {
      rows.add([
        account.name,
        account.phone,
        account.balance.toStringAsFixed(0),
      ]);
    }
    
    // Convert to CSV with BOM
    String csvData = _listToCsv(rows);
    
    // Save to file
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/all_accounts_report.csv";
    final File file = File(path);
    
    // Write using Bytes and UTF8 encoding to ensure Urdu characters are preserved
    await file.writeAsBytes(utf8.encode(csvData));
    
    // Share
    await Share.shareXFiles([XFile(path)], text: isUrdu ? 'تمام اکاؤنٹس کی رپورٹ' : 'All Accounts Report');
  }
  
  Future<void> generateAndShareTransactionReportCsv(
    List<Transaction> transactions,
    String title,
    bool isUrdu,
  ) async {
     List<List<dynamic>> rows = [];
     
     // Title
     rows.add([title]);
     rows.add([]); // Empty row

     // Header
     rows.add([
       isUrdu ? 'تاریخ' : 'Date',
       isUrdu ? 'تفصیل' : 'Description',
       isUrdu ? 'قسم' : 'Type',
       isUrdu ? 'رقم' : 'Amount',
     ]);

     // Data
     for (var t in transactions) {
       rows.add([
         t.formattedDate,
         t.description,
         // Updated text here for Credit/Debit
         t.type == 'income' 
             ? (isUrdu ? 'جمع' : 'Credit') 
             : (isUrdu ? 'بنام' : 'Debit'),
         t.amount.toStringAsFixed(0),
       ]);
     }
     
     String csvData = _listToCsv(rows);
     final directory = await getTemporaryDirectory();
     final path = "${directory.path}/transaction_report.csv";
     final File file = File(path);
     
     // Write using Bytes and UTF8 encoding
     await file.writeAsBytes(utf8.encode(csvData));
     
     await Share.shareXFiles([XFile(path)], text: title);
  }
}
