// lib/features/quick_bill/widgets/outgoing_receipt_widget.dart

import 'package:flutter/material.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/features/quick_bill/widgets/base_ledger_widget.dart';

/// ═════════════════════════════════════════════════════════════
/// OutgoingReceiptWidget — جانے والی رسید
///
/// یہ اس وقت استعمال ہوتی ہے جب میں نے خود ٹرانزیکشن کی ہو:
///   - QuickBill بنایا
///   - AddTransaction سے لین دین کیا
///
/// isIncomingReceipt = false
/// ائٹمز: بنام 🔴 (میں نے دیا)
/// وصول: جمع 🟢 (میں نے لیا)
/// ═════════════════════════════════════════════════════════════
class OutgoingReceiptWidget extends StatelessWidget {
  final Transaction transaction;
  final Account? account;
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String billedToName;
  final String billedToPhone;

  const OutgoingReceiptWidget({
    super.key,
    required this.transaction,
    this.account,
    this.businessName = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.billedToName = '',
    this.billedToPhone = '',
  });

  @override
  Widget build(BuildContext context) {
    return BaseLedgerWidget(
      transaction: transaction,
      account: account,
      businessName: businessName,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
      billedToName: billedToName,
      billedToPhone: billedToPhone,
      isIncomingReceipt: false,
    );
  }
}
