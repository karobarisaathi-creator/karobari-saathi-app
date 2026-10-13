// lib/features/quick_bill/widgets/receipt_widget.dart

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

class ReceiptWidget extends StatelessWidget {
  /// ٹرانزیکشن — بل کا مکمل ڈیٹا
  final Transaction transaction;

  /// گاہک (party) — اگر ہے تو پرانا balance دکھے گا
  final Account? account;

  /// کاروبار کی معلومات
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String billedToName;
  final String billedToPhone;
  final bool isIncomingReceipt;

  /// Color customization (optional)
  final Color? accentColor;
  final Color? headerColor;

  const ReceiptWidget({
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

  // ═══════════════════════════════════════════════════════════
  // CALCULATIONS
  // ═══════════════════════════════════════════════════════════

  /// کیا پارٹی ہے؟
  bool get _hasParty =>
      account != null &&
      account!.id != 'default_account' &&
      account!.id != 'artisan_internal_income' &&
      account!.id != QuickBillConstants.cashCustomerAccountId;

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

  /// کیا ڈسکاؤنٹ ہے؟
  bool get _hasDiscount => transaction.discountAmount > 0;

  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final receiptBalance = _receiptBalanceBreakdown(context);

    final themeAccent = accentColor ?? AppTheme.themeColor;
    final themeHeader = headerColor ?? const Color(0xFF24445B);

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
            // ═══ Header ═══
            _buildHeader(isUrdu, fontFamily, themeHeader),

            // ═══ Body ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDashedDivider(),

                  // Date + Amount
                  _buildDateAmountRow(isUrdu, fontFamily),

                  _buildDashedDivider(),

                  // Payment Due Badge
                  if (transaction.isPending || transaction.pendingAmount > 0)
                    _buildPaymentDueBadge(isUrdu, fontFamily),

                  // Items Table
                  _buildItemsTable(isUrdu, fontFamily),

                  _buildDashedDivider(),

                  // Invoice totals and time-specific account balance.
                  _buildTotalsSection(
                    isUrdu,
                    fontFamily,
                    receiptBalance: receiptBalance,
                  ),

                  if (receiptBalance == null &&
                      (transaction.receivedAmount > 0 ||
                          transaction.pendingAmount > 0 ||
                          transaction.isPending)) ...[
                    _buildDashedDivider(),
                    _buildPaymentRows(isUrdu, fontFamily),
                  ],

                  _buildDashedDivider(),

                  // Footer
                  _buildFooter(isUrdu, fontFamily, themeAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(bool isUrdu, String? fontFamily, Color headerColor) {
    final senderPhone = isIncomingReceipt
        ? Formatters.formatPhoneNumber(businessPhone)
        : businessPhone;
    final customerName = billedToName.trim().isNotEmpty
        ? billedToName.trim()
        : account?.name ??
            (isIncomingReceipt
                ? (isUrdu ? 'آپ' : 'You')
                : (isUrdu ? 'نقد گاہک' : 'Cash Customer'));
    final customerPhone = billedToPhone.trim().isNotEmpty
        ? billedToPhone.trim()
        : account?.phone ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: headerColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business name + phone
          UrduAwareText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: businessName.isNotEmpty
                      ? businessName
                      : (isUrdu ? 'کاروبار' : 'Business'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                if (senderPhone.isNotEmpty) ...[
                  const TextSpan(
                    text: '   ·   ',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  TextSpan(
                    text: senderPhone,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: '',
                    ),
                  ),
                ],
              ],
            ),
            style: TextStyle(fontFamily: fontFamily),
          ),

          // Address
          if (businessAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            UrduAwareText(
              businessAddress,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamily,
              ),
            ),
          ],

          // Dashed divider
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: Colors.white24,
          ),
          const SizedBox(height: 10),

          // Billed To
          Row(
            children: [
              UrduAwareText(
                isUrdu ? 'بنام' : 'BILLED TO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
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
                        text: customerName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontFamily: fontFamily,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (customerPhone.isNotEmpty) ...[
                        const TextSpan(
                          text: '   ·   ',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: customerPhone,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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

  // ═══════════════════════════════════════════════════════════
  // Date + Bill Number
  // ═══════════════════════════════════════════════════════════
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
    bool numeric = false,
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
          textDirection: numeric ? ui.TextDirection.ltr : null,
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

  // ═══════════════════════════════════════════════════════════
  // Payment Due Badge
  // ═══════════════════════════════════════════════════════════
  Widget _buildPaymentDueBadge(bool isUrdu, String? fontFamily) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 12,
                color: Color(0xFF8E5200),
              ),
              const SizedBox(width: 5),
              UrduAwareText(
                isUrdu ? 'ادائیگی باقی ہے' : 'PAYMENT DUE',
                style: TextStyle(
                  color: const Color(0xFF8E5200),
                  fontFamily: fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Items Table
  // ═══════════════════════════════════════════════════════════
  Widget _buildItemsTable(bool isUrdu, String? fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
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

        // Items
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
                : (isUrdu ? 'نقد لین دین' : 'Cash Transaction'),
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
      letterSpacing: -0.2,
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
          // Description
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
          // Quantity
          Expanded(
            flex: 2,
            child: UrduAwareText(qtyText, textAlign: TextAlign.center, style: numStyle),
          ),
          // Rate
          Expanded(
            flex: 2,
            child: UrduAwareText(
              rate.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: numStyle,
            ),
          ),
          // Total
          Expanded(
            flex: 3,
            child: UrduAwareText(
              total.toStringAsFixed(0),
              textAlign: TextAlign.end,
              style: numStyle,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Totals Section (Subtotal + Discount + Total)
  // ═══════════════════════════════════════════════════════════
  Widget _buildTotalsSection(
    bool isUrdu,
    String? fontFamily, {
    ReceiptBalanceBreakdown? receiptBalance,
  }) {
    final breakdown = receiptBalance;
    final subtotal = transaction.subtotal > 0
        ? transaction.subtotal
        : transaction.amount + transaction.discountAmount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (breakdown != null) ...[
            _buildSimpleRow(
              label: isUrdu
                  ? 'موجودہ بل / آئٹمز کی کل رقم'
                  : 'CURRENT BILL / ITEMS TOTAL',
              value: subtotal.toStringAsFixed(0),
              fontFamily: fontFamily,
            ),
            _buildAccountBalanceRow(
              label: _balanceLabel(
                isUrdu,
                breakdown.openingBalance,
                isOpening: true,
              ),
              balance: breakdown.openingBalance,
              fontFamily: fontFamily,
            ),
            _buildAccountBalanceRow(
              label: isUrdu ? 'مجموعی رقم' : 'GRAND TOTAL',
              balance: breakdown.balanceBeforeDiscount,
              fontFamily: fontFamily,
              emphasized: true,
            ),
          ],
          if (breakdown == null && _hasDiscount)
            _buildSimpleRow(
              label: isUrdu ? 'ذیلی رقم' : 'Subtotal',
              value: subtotal.toStringAsFixed(0),
              fontFamily: fontFamily,
            ),
          if (_hasDiscount) _buildDiscountRow(isUrdu, fontFamily),
          if (breakdown != null && _hasDiscount)
            _buildAccountBalanceRow(
              label: _balanceLabel(isUrdu, breakdown.balanceAfterDiscount,
                  isAfterDiscount: true),
              balance: breakdown.balanceAfterDiscount,
              fontFamily: fontFamily,
              emphasized: true,
            ),
          if (breakdown != null && transaction.receivedAmount > 0)
            _buildPaymentRow(
              label: isUrdu ? 'وصول ہو چکے' : 'Received',
              amount: transaction.receivedAmount,
              color: AppTheme.incomeColor,
              fontFamily: fontFamily,
            ),
          if (breakdown != null)
            _buildAccountBalanceRow(
              label: _balanceLabel(
                isUrdu,
                breakdown.finalBalance,
                isFinal: true,
              ),
              balance: breakdown.finalBalance,
              fontFamily: fontFamily,
              emphasized: true,
              isFinal: true,
            ),
          if (breakdown == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: UrduAwareText(
                      isUrdu ? 'اس بل کی کل رقم' : 'INVOICE TOTAL',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  UrduAwareText(
                    'Rs ${transaction.amount.toStringAsFixed(0)}',
                    textDirection: ui.TextDirection.ltr,
                    style: const TextStyle(
                      color: AppTheme.darkColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _balanceLabel(
    bool isUrdu,
    double balance, {
    bool isOpening = false,
    bool isAfterDiscount = false,
    bool isFinal = false,
  }) {
    final isPayableOnReceipt = balance >= 0;
    if (isUrdu) {
      final side = isPayableOnReceipt ? 'دینا' : 'لینا';
      if (isOpening) return 'پچھلا بقایا ($side)';
      if (isAfterDiscount) return 'رعایت کے بعد بقایا ($side)';
      if (isFinal) return 'فائنل بقایا ($side)';
    } else {
      final side = isPayableOnReceipt ? 'Payable' : 'Receivable';
      if (isOpening) return 'Previous Balance ($side)';
      if (isAfterDiscount) return 'Balance After Discount ($side)';
      if (isFinal) return 'FINAL BALANCE ($side)';
    }
    return isUrdu ? 'مجموعی بقایا' : 'GRAND TOTAL';
  }

  Widget _buildAccountBalanceRow({
    required String label,
    required double balance,
    required String? fontFamily,
    bool emphasized = false,
    bool isFinal = false,
  }) {
    final color = isFinal
        ? (balance < 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
        : (balance < 0 ? AppTheme.themeColor : AppTheme.expenseColor);
    final sign = balance < 0 ? '−' : '+';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(
                color: color,
                fontFamily: fontFamily,
                fontSize: 12,
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
          UrduAwareText(
            '$sign Rs ${balance.abs().toStringAsFixed(0)}',
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: emphasized ? 16 : 14,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRow({
    required String label,
    required String value,
    String? fontFamily,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontFamily: fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          UrduAwareText(
            'Rs $value',
            textDirection: ui.TextDirection.ltr,
            style: const TextStyle(
              color: AppTheme.darkColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountRow(bool isUrdu, String? fontFamily) {
    final percent = transaction.discountPercent;
    final label = percent != null && percent > 0
        ? (isUrdu
            ? 'رعایت (${percent.toStringAsFixed(0)}%)'
            : 'Discount (${percent.toStringAsFixed(0)}%)')
        : (isUrdu ? 'رعایت' : 'Discount');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_outlined,
            size: 13,
            color: AppTheme.verifiedGold,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(
                color: AppTheme.verifiedGold,
                fontFamily: fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          UrduAwareText(
            'Rs ${transaction.discountAmount.toStringAsFixed(0)} −',
            textDirection: ui.TextDirection.ltr,
            style: const TextStyle(
              color: AppTheme.verifiedGold,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Previous Balance Section
  // ═══════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════
  // Payment Rows
  // ═══════════════════════════════════════════════════════════
  Widget _buildPaymentRows(
    bool isUrdu,
    String? fontFamily,
  ) {
    final finalBalance = transaction.pendingAmount;
    final isZero = finalBalance <= 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Received
          if (transaction.receivedAmount > 0)
            _buildPaymentRow(
              label: isUrdu ? 'وصول ہو چکے' : 'Received',
              amount: transaction.receivedAmount,
              color: AppTheme.incomeColor,
              fontFamily: fontFamily,
            ),

          // Final Balance
          if (transaction.receivedAmount > 0) ...[
            _buildPaymentRow(
              label: isUrdu ? 'فائنل بقایا' : 'FINAL BALANCE',
              amount: finalBalance,
              color: isZero ? AppTheme.incomeColor : AppTheme.expenseColor,
              fontFamily: fontFamily,
            ),
          ],

          if (transaction.receivedAmount == 0 && finalBalance > 0)
            _buildPaymentRow(
              label: isUrdu ? 'فائنل بقایا' : 'FINAL BALANCE',
              amount: finalBalance,
              color: AppTheme.expenseColor,
              fontFamily: fontFamily,
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required String label,
    required double amount,
    required Color color,
    String? fontFamily,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(
                color: color,
                fontFamily: fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          UrduAwareText(
            'Rs ${amount.toStringAsFixed(0)}',
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Footer
  // ═══════════════════════════════════════════════════════════
  Widget _buildFooter(bool isUrdu, String? fontFamily, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 15),
      child: Column(
        children: [
          UrduAwareText(
            isUrdu
                ? 'آپ کے کاروبار کے لیے کاروباری ساتھی استعمال کرنے کا شکریہ'
                : 'Thank you for keeping your business records with Karobari Saathi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.5,
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

  // ═══════════════════════════════════════════════════════════
  // Dashed Divider
  // ═══════════════════════════════════════════════════════════
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
