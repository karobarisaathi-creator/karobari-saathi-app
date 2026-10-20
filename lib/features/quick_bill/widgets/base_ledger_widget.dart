// lib/features/quick_bill/widgets/base_ledger_widget.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';

/// ═══════════════════════════════════════════════════════════════
/// BaseLedgerWidget — بنیادی رسید کا ڈھانچہ
///
/// یہ فائل خود کبھی نہیں چلتی۔ یہ صرف بنیاد ہے۔
/// اسے Incoming یا Outgoing فائل چلاتی ہے۔
///
/// isIncomingReceipt = false → Outgoing (میری طرف)
/// isIncomingReceipt = true  → Incoming (پارٹی کی طرف)
/// ═══════════════════════════════════════════════════════════════
class BaseLedgerWidget extends StatelessWidget {
  final Transaction transaction;
  final Account? account;
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String billedToName;
  final String billedToPhone;
  final bool isIncomingReceipt;
  final Color? accentColor;
  final Color? headerColor;

  const BaseLedgerWidget({
    super.key,
    required this.transaction,
    this.account,
    this.businessName = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.billedToName = '',
    this.billedToPhone = '',
    this.isIncomingReceipt = false,
    this.accentColor,
    this.headerColor,
  });

  // ═════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════
  bool get _hasParty =>
      account != null &&
      account!.id != 'default_account' &&
      account!.id != 'artisan_internal_income' &&
      account!.id != QuickBillConstants.cashCustomerAccountId;

  double get _subtotal =>
      transaction.subtotal > 0 ? transaction.subtotal : transaction.amount;

  String _discountPercentLabel() {
    final p = transaction.discountPercent;
    if (p == null || p <= 0) return '';
    return ' (${p.toStringAsFixed(0)}%)';
  }

  ReceiptBalanceBreakdown? _receiptBalanceBreakdown(BuildContext context) {
    if (!_hasParty) return null;
    final transactions = Provider.of<DatabaseService>(
      context,
      listen: false,
    ).getAllTransactions();
    return AccountBalanceUtils.receiptBreakdown(
      transactions: transactions,
      receipt: transaction,
      initialBalance: account!.balanceType.toLowerCase() == 'payable'
          ? -account!.initialBalance
          : account!.initialBalance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final breakdown = _receiptBalanceBreakdown(context);
    final themeAccent = accentColor ?? AppTheme.themeColor;
    final themeHeader = headerColor ?? AppTheme.darkColor;

    return Directionality(
      textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9E0E5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isUrdu, fontFamily, themeHeader),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDashedDivider(),
                  _buildDateAmountRow(isUrdu, fontFamily),
                  _buildDashedDivider(),
                  _buildItemsTable(isUrdu, fontFamily),
                  _buildDashedDivider(),
                  _buildTAccount(isUrdu, fontFamily, breakdown),
                  _buildDashedDivider(),
                  _buildFooter(isUrdu, fontFamily, themeAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // HEADER — دو طرفہ نام
  // ═════════════════════════════════════════════════════════════
  Widget _buildHeader(bool isUrdu, String? fontFamily, Color headerColor) {
    final String topName = businessName.trim().isNotEmpty
        ? businessName.trim()
        : (isUrdu ? 'میرا کاروبار' : 'My Business');
    final String topPhone = businessPhone;

    final String bottomName = billedToName.trim().isNotEmpty
        ? billedToName.trim()
        : (account?.name ?? (isUrdu ? 'نقد گاہک' : 'Cash Customer'));
    final String bottomPhone = billedToPhone.trim().isNotEmpty
        ? billedToPhone.trim()
        : (account?.phone ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: headerColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrduAwareText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: topName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (topPhone.isNotEmpty) ...[
                  const TextSpan(
                    text: '   ·   ',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  TextSpan(
                    text: topPhone,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            style: TextStyle(fontFamily: fontFamily),
          ),
          if (businessAddress.isNotEmpty && !isIncomingReceipt) ...[
            const SizedBox(height: 4),
            UrduAwareText(
              businessAddress,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamily,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 10),
          Row(
            children: [
              UrduAwareText(
                isUrdu ? 'بنام' : 'BILLED TO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: UrduAwareText.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: bottomName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: fontFamily,
                        ),
                      ),
                      if (bottomPhone.isNotEmpty) ...[
                        const TextSpan(
                          text: '   ·   ',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        TextSpan(
                          text: bottomPhone,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Date + Bill Number
  // ═════════════════════════════════════════════════════════════
  Widget _buildDateAmountRow(bool isUrdu, String? fontFamily) {
    final billNo = (transaction.referenceNumber != null &&
            transaction.referenceNumber!.trim().isNotEmpty)
        ? '#${transaction.referenceNumber!.trim()}'
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCell(
              isUrdu ? 'تاریخ' : 'DATE',
              DateFormat('dd MMM yyyy').format(transaction.date),
              fontFamily,
            ),
          ),
          Expanded(
            child: _buildInfoCell(
              isUrdu ? 'بل نمبر' : 'BILL NO.',
              billNo,
              fontFamily,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCell(
    String label,
    String value,
    String? fontFamily, {
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            fontFamily: fontFamily,
          ),
        ),
        const SizedBox(height: 3),
        UrduAwareText(
          value,
          style: TextStyle(
            color: AppTheme.darkColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: fontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // ITEMS TABLE
  // ═════════════════════════════════════════════════════════════
  Widget _buildItemsTable(bool isUrdu, String? fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildTableHeader(
                  isUrdu ? 'تفصیل' : 'ITEM',
                  TextAlign.start,
                  fontFamily,
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildTableHeader(
                  isUrdu ? 'تعداد' : 'QTY',
                  TextAlign.center,
                  fontFamily,
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildTableHeader(
                  isUrdu ? 'ریٹ' : 'RATE',
                  TextAlign.center,
                  fontFamily,
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildTableHeader(
                  isUrdu ? 'ٹوٹل' : 'TOTAL',
                  TextAlign.end,
                  fontFamily,
                ),
              ),
            ],
          ),
        ),
        if (transaction.items.isNotEmpty)
          ...transaction.items.map((item) => _buildItemRow(
                description: item.description,
                quantity: item.quantity,
                rate: item.rate,
                total: item.total,
                unit: item.unit,
                fontFamily: fontFamily,
              ))
        else
          _buildItemRow(
            description: transaction.description.isNotEmpty
                ? transaction.description
                : (isUrdu ? 'نقد لین دین' : 'Cash'),
            quantity: transaction.quantity.toDouble(),
            rate: transaction.rate,
            total: transaction.amount,
            fontFamily: fontFamily,
          ),
      ],
    );
  }

  Widget _buildTableHeader(String label, TextAlign align, String? fontFamily) {
    return UrduAwareText(
      label,
      textAlign: align,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: AppTheme.textSecondary,
        fontFamily: fontFamily,
      ),
    );
  }

  Widget _buildItemRow({
    required String description,
    required double quantity,
    required double rate,
    required double total,
    String? unit,
    String? fontFamily,
  }) {
    const numStyle = TextStyle(
      color: AppTheme.darkColor,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    final qtyText = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (unit != null && unit.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  UrduAwareText(
                    unit,
                    style: const TextStyle(
                      color: Color(0xFF8A9199),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: UrduAwareText(qtyText,
                textAlign: TextAlign.center, style: numStyle),
          ),
          Expanded(
            flex: 2,
            child: UrduAwareText(
              Formatters.formatAmount(rate),
              textAlign: TextAlign.center,
              style: numStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: UrduAwareText(
              Formatters.formatAmount(total),
              textAlign: TextAlign.end,
              style: numStyle,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // ⭐ T-ACCOUNT — ٹرانزیکشن کی قسم اور رسید کی سمت
  //
  // اصول: "جمع = لیا، بنام = دیا"
  //
  // isIncomingReceipt = false → Outgoing (میری طرف)
  //   آئٹمز → بنام 🔴
  //   وصول → جمع 🟢
  //
  // isIncomingReceipt = true → Incoming (پارٹی کی طرف)
  //   آئٹمز → جمع 🟢
  //   ادا شدہ → بنام 🔴
  // ═════════════════════════════════════════════════════════════
  Widget _buildTAccount(
    bool isUrdu,
    String? fontFamily,
    ReceiptBalanceBreakdown? breakdown,
  ) {
    final opening = breakdown?.openingBalance ?? 0;
    final subtotal = _subtotal;
    final discount = transaction.discountAmount;
    final received = transaction.receivedAmount;

    final debitLines = <_LedgerLine>[];
    final creditLines = <_LedgerLine>[];

    // Imported counterparty entries store the sender's type inverted.
    final bool subtotalIsDebit = transaction.isQuickBill
        ? !isIncomingReceipt
        : isIncomingReceipt
            ? transaction.receiptFromCounterparty
                ? transaction.type == 'expense'
                : transaction.type == 'income'
            : transaction.type == 'expense';

    final subtotalLines = subtotalIsDebit ? debitLines : creditLines;
    final paymentLines = subtotalIsDebit ? creditLines : debitLines;

    // 1. کل رقم
    subtotalLines.add(_LedgerLine(
      label: isUrdu ? 'کل رقم' : 'Total Amount',
      amount: subtotal,
      color: subtotalIsDebit ? AppTheme.expenseColor : AppTheme.incomeColor,
    ));

    // 2. رعایت
    if (discount > 0) {
      subtotalLines.add(_LedgerLine(
        label: isUrdu
            ? 'رعایت${_discountPercentLabel()}'
            : 'Discount${_discountPercentLabel()}',
        amount: discount,
        color: AppTheme.verifiedGold,
        prefix: '− ',
      ));
    }

    // 3. وصول / ادا شدہ
    if (received > 0) {
      paymentLines.add(_LedgerLine(
        label: isUrdu
            ? (subtotalIsDebit ? 'وصول' : 'ادا شدہ')
            : (subtotalIsDebit ? 'Received' : 'Paid'),
        amount: received,
        color: subtotalIsDebit ? AppTheme.incomeColor : AppTheme.expenseColor,
      ));
    }

    // 4. پرانا بقایا
    if (!isIncomingReceipt) {
      // Outgoing (میری طرف)
      if (opening > 0) {
        debitLines.add(_LedgerLine(
          label: isUrdu ? 'پرانا بقایا' : 'Opening',
          amount: opening,
          color: AppTheme.expenseColor,
          prefix: '+ ',
        ));
      }
      if (opening < 0) {
        creditLines.add(_LedgerLine(
          label: isUrdu ? 'پرانا بقایا' : 'Opening',
          amount: opening.abs(),
          color: AppTheme.incomeColor,
          prefix: '+ ',
        ));
      }
    } else {
      // Incoming view shows a receivable opening balance on the debit side.
      if (opening > 0) {
        debitLines.add(_LedgerLine(
          label: isUrdu ? 'پرانا بقایا' : 'Opening',
          amount: opening,
          color: AppTheme.expenseColor,
          prefix: '+ ',
        ));
      }
      if (opening < 0) {
        creditLines.add(_LedgerLine(
          label: isUrdu ? 'پرانا بقایا' : 'Opening',
          amount: opening.abs(),
          color: AppTheme.incomeColor,
          prefix: '+ ',
        ));
      }
    }

    // ═══ Totals ═══
    double totalDebit = 0, totalCredit = 0;
    for (final l in debitLines) {
      totalDebit += l.prefix == '− ' ? -l.amount : l.amount;
    }
    for (final l in creditLines) {
      totalCredit += l.prefix == '− ' ? -l.amount : l.amount;
    }

    // A larger debit means the counterparty still owes the business.
    final double balanceDifference = totalDebit - totalCredit;
    final double absAmount = balanceDifference.abs();
    final bool isSettled = absAmount < 0.01;

    final String displayLabel;
    final Color displayColor;

    if (isSettled) {
      displayLabel = isUrdu ? 'حساب صاف' : 'Settled';
      displayColor = AppTheme.themeColor;
    } else if (balanceDifference > 0) {
      displayLabel = isUrdu ? 'لینے ہیں' : 'Receivable';
      displayColor = AppTheme.incomeColor;
    } else {
      displayLabel = isUrdu ? 'دینے ہیں' : 'Payable';
      displayColor = AppTheme.expenseColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Center(
                      child: UrduAwareText(
                        isUrdu ? 'بنام' : 'DEBIT',
                        style: TextStyle(
                          color: AppTheme.expenseColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Center(
                      child: UrduAwareText(
                        isUrdu ? 'جمع' : 'CREDIT',
                        style: TextStyle(
                          color: AppTheme.incomeColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: debitLines.isEmpty
                              ? const SizedBox(height: 40)
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: debitLines
                                      .map((l) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: _buildTLine(
                                              label: l.label,
                                              amount: l.amount,
                                              color: l.color,
                                              prefix: l.prefix,
                                              fontFamily: fontFamily,
                                            ),
                                          ))
                                      .toList(),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: creditLines.isEmpty
                              ? const SizedBox(height: 40)
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: creditLines
                                      .map((l) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: _buildTLine(
                                              label: l.label,
                                              amount: l.amount,
                                              color: l.color,
                                              prefix: l.prefix,
                                              fontFamily: fontFamily,
                                            ),
                                          ))
                                      .toList(),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: UrduAwareText(
                                  isUrdu ? 'کل بنام' : 'Total Debit',
                                  style: TextStyle(
                                    color: AppTheme.expenseColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ),
                              UrduAwareText(
                                Formatters.formatAmount(totalDebit),
                                style: const TextStyle(
                                  color: AppTheme.expenseColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: UrduAwareText(
                                  isUrdu ? 'کل جمع' : 'Total Credit',
                                  style: TextStyle(
                                    color: AppTheme.incomeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ),
                              UrduAwareText(
                                Formatters.formatAmount(totalCredit),
                                style: const TextStyle(
                                  color: AppTheme.incomeColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Balance Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        isUrdu ? 'کل بیلنس' : 'TOTAL BALANCE',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontFamily: fontFamily,
                        ),
                      ),
                      const SizedBox(height: 3),
                      UrduAwareText(
                        displayLabel,
                        style: TextStyle(
                          color: displayColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                UrduAwareText(
                  isSettled
                      ? 'Rs 0'
                      : 'Rs ${Formatters.formatAmount(absAmount)}',
                  style: TextStyle(
                    color: displayColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTLine({
    required String label,
    required double amount,
    required Color color,
    String? fontFamily,
    String? prefix,
  }) {
    return Row(
      children: [
        Expanded(
          child: UrduAwareText(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: fontFamily,
            ),
          ),
        ),
        UrduAwareText(
          '${prefix ?? ''}${Formatters.formatAmount(amount)}',
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Footer
  // ═════════════════════════════════════════════════════════════
  Widget _buildFooter(bool isUrdu, String? fontFamily, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 15),
      child: Column(
        children: [
          UrduAwareText(
            isUrdu
                ? 'کاروباری ساتھی استعمال کرنے کا شکریہ'
                : 'Thank you for using Karobari Saathi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          UrduAwareText(
            'Karobari Saathi',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Row(
      children: List.generate(
        30,
        (index) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

/// ═════════════════════════════════════════════════════════════
/// Ledger Line Helper
/// ═════════════════════════════════════════════════════════════
class _LedgerLine {
  final String label;
  final double amount;
  final Color color;
  final String? prefix;

  const _LedgerLine({
    required this.label,
    required this.amount,
    required this.color,
    this.prefix,
  });
}
