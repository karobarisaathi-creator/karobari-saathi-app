import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'add_transaction_screen.dart';
import 'package:account_app/features/professions/add_project_transaction_screen.dart';

import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:screenshot/screenshot.dart';

class TransactionReceiptScreen extends StatefulWidget {
  final Transaction transaction;
  final AppNotification? notification;
  final bool showActionButtons;

  const TransactionReceiptScreen({
    super.key,
    required this.transaction,
    this.notification,
    this.showActionButtons = false,
  });

  @override
  State<TransactionReceiptScreen> createState() =>
      _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'رسید' : 'Receipt',
        showBackButton: true,
      ),
      body: FutureBuilder<Account?>(
        future: Future.value(
            Provider.of<DatabaseService>(context, listen: false)
                .getAccount(widget.transaction.accountId)),
        builder: (context, snapshot) {
          final account = snapshot.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Screenshot(
                      controller: _screenshotController,
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
                          children: [
                            // Receipt title strip.
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 13),
                              decoration: const BoxDecoration(
                                color: AppTheme.darkColor,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isUrdu ? 'رسید' : 'RECEIPT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: fontFamily,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    PhosphorIcons.receipt(),
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 14),
                              color: const Color(0xFF24445B),
                              child: ProfileInfoWidget(
                                name: account?.name ??
                                    (widget.notification?.data?['senderName'] ??
                                        (isUrdu ? 'بنام گاہک / نامعلوم' : 'Customer / Unknown')),
                                phone: account?.phone ??
                                    (widget.notification?.data?['senderPhone'] ?? ''),
                                profileImage: account?.profileImage ??
                                    widget.notification?.data?['senderPhotoUrl'],
                                isLarge: true,
                                textColor: Colors.white,
                                subtitleColor: Colors.white70,
                                isVerified: account?.isVerified ??
                                    widget.notification?.data?['isSenderVerified'] ??
                                    false,
                                customSize: 45,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  _receiptDivider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Row(
                                      textDirection: isUrdu
                                          ? ui.TextDirection.rtl
                                          : ui.TextDirection.ltr,
                                      children: [
                                        Expanded(
                                          child: _buildInfoCell(
                                            isUrdu ? 'تاریخ' : 'DATE',
                                            DateFormat('dd MMM yyyy').format(
                                                widget.transaction.date),
                                            fontFamily,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildInfoCell(
                                            isUrdu ? 'رقم' : 'AMOUNT',
                                            widget.transaction.amount
                                                .toStringAsFixed(0),
                                            fontFamily,
                                            alignEnd: true,
                                            numeric: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _receiptDivider(),
                                  Align(
                                    alignment: isUrdu
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF0D7),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isUrdu
                                              ? (widget.transaction.type ==
                                                      'income'
                                                  ? 'مال ادھار پر دیا گیا'
                                                  : 'مال ادھار پر لیا گیا')
                                              : (widget.transaction.type ==
                                                      'income'
                                                  ? 'CREDIT'
                                                  : 'DEBIT'),
                                          style: TextStyle(
                                            color: const Color(0xFF8E5200),
                                            fontFamily: fontFamily,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _receiptDivider(),
                                  Directionality(
                                    textDirection: isUrdu
                                        ? ui.TextDirection.rtl
                                        : ui.TextDirection.ltr,
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 11, bottom: 5),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: _buildTableHeader(
                                                    isUrdu ? 'تفصیل' : 'Item',
                                                    TextAlign.start,
                                                    fontFamily),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: _buildTableHeader(
                                                    isUrdu ? 'تعداد' : 'Qty',
                                                    TextAlign.center,
                                                    fontFamily),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: _buildTableHeader(
                                                    isUrdu ? 'ریٹ' : 'Rate',
                                                    TextAlign.center,
                                                    fontFamily),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: _buildTableHeader(
                                                    isUrdu ? 'ٹوٹل' : 'Total',
                                                    TextAlign.end,
                                                    fontFamily),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (widget.transaction.items.isNotEmpty)
                                          ...widget.transaction.items.map(
                                              (item) => _buildReceiptItemRow(
                                                  item.description,
                                                  item.quantity
                                                      .toStringAsFixed(0),
                                                  item.rate.toStringAsFixed(0),
                                                  item.total.toStringAsFixed(0),
                                                  fontFamily,
                                                  fontWeight,
                                                  item.unit))
                                        else
                                          _buildReceiptItemRow(
                                            widget.transaction.description
                                                    .isNotEmpty
                                                ? widget.transaction.description
                                                : (isUrdu
                                                    ? 'نقد لین دین'
                                                    : 'Cash Transaction'),
                                            widget.transaction.quantity
                                                .toString(),
                                            widget.transaction.rate
                                                .toStringAsFixed(0),
                                            widget.transaction.amount
                                                .toStringAsFixed(0),
                                            fontFamily,
                                            fontWeight,
                                          ),
                                      ],
                                    ),
                                  ),
                                  _receiptDivider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Row(
                                      textDirection: isUrdu
                                          ? ui.TextDirection.rtl
                                          : ui.TextDirection.ltr,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            isUrdu
                                                ? 'اس بل کی کل رقم'
                                                : 'INVOICE TOTAL',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontFamily: fontFamily,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Rs ${widget.transaction.amount.toStringAsFixed(0)}',
                                          textDirection: ui.TextDirection.ltr,
                                          style: const TextStyle(
                                            color: AppTheme.darkColor,
                                            fontSize: 25,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.transaction.receivedAmount > 0 ||
                                      widget.transaction.pendingAmount > 0 ||
                                      widget.transaction.isPending) ...[
                                    _receiptDivider(),
                                    _buildPaymentRow(
                                      isUrdu ? 'وصول ہو چکے' : 'Received',
                                      widget.transaction.receivedAmount,
                                      isUrdu,
                                      fontFamily,
                                    ),
                                    _buildPaymentRow(
                                      isUrdu ? 'بقایا' : 'Balance due',
                                      widget.transaction.pendingAmount,
                                      isUrdu,
                                      fontFamily,
                                      emphasize: true,
                                    ),
                                  ],
                                  _receiptDivider(),
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 12, 0, 15),
                                    child: Column(
                                      children: [
                                        Text(
                                          isUrdu
                                              ? 'آپ کے کاروبار کے لیے کاروباری ساتھی استعمال کرنے کا شکریہ'
                                              : 'Thank you for keeping your business records with Karobari Saathi',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontFamily: fontFamily,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        const Text(
                                          'Karobari Saathi',
                                          style: TextStyle(
                                            color: AppTheme.themeColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: isUrdu ? 'ایڈٹ کریں' : 'Edit',
                        onPressed: () {
                          if (widget.transaction.accountId ==
                                  'default_account' &&
                              widget.transaction.professionId != null) {
                            final db = Provider.of<DatabaseService>(context,
                                listen: false);
                            final profession = db.getProfession(
                                widget.transaction.professionId!);
                            if (profession != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddProjectTransactionScreen(
                                    profession: profession,
                                    transactionToEdit: widget.transaction,
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddTransactionScreen(
                                transactionToEdit: widget.transaction,
                              ),
                            ),
                          );
                        },
                        icon: PhosphorIcons.pencilLine(),
                        color: Colors.blueGrey,
                        size: AppButtonSize.large,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: isUrdu ? 'شیئر کریں' : 'Share',
                        onPressed: () => _shareReceiptAsImage(
                            context, widget.transaction, account, isUrdu),
                        icon: PhosphorIcons.shareNetwork(),
                        color: AppTheme.themeColor,
                        size: AppButtonSize.large,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableHeader(String label, TextAlign align, String fontFamily) {
    return Text(
      label,
      textAlign: align,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: AppTheme.textSecondary,
        fontFamily: fontFamily,
      ),
    );
  }

  Widget _receiptDivider() => _buildDashedDivider();

  Widget _buildInfoCell(
    String label,
    String value,
    String fontFamily, {
    bool alignEnd = false,
    bool numeric = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textDirection: numeric ? ui.TextDirection.ltr : null,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppTheme.darkColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptItemRow(
    String description,
    String quantity,
    String rate,
    String total,
    String fontFamily,
    FontWeight fontWeight, [
    String? unit,
  ]) {
    const numberStyle = TextStyle(
      color: AppTheme.darkColor,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                    fontSize: 12,
                    fontWeight: fontWeight,
                  ),
                ),
                if (unit != null && unit.isNotEmpty)
                  Text(
                    unit,
                    style: const TextStyle(color: Colors.grey, fontSize: 9),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child:
                Text(quantity, textAlign: TextAlign.center, style: numberStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(rate, textAlign: TextAlign.center, style: numberStyle),
          ),
          Expanded(
            flex: 3,
            child: Text(total, textAlign: TextAlign.end, style: numberStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    String label,
    double amount,
    bool isUrdu,
    String fontFamily, {
    bool emphasize = false,
  }) {
    final color = emphasize ? AppTheme.expenseColor : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: fontFamily,
                fontSize: 12,
                fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            'Rs ${amount.toStringAsFixed(0)}',
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
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

  Future<void> _shareReceiptAsImage(
      BuildContext context, Transaction t, Account? a, bool isUrdu) async {
    try {
      // 1. Capture screenshot
      final image = await _screenshotController.capture();

      if (image != null) {
        // 2. Save to temporary directory
        final directory = await getTemporaryDirectory();
        final imagePath = await File(
                '${directory.path}/receipt_${t.id.substring(t.id.length - 6)}.png')
            .create();
        await imagePath.writeAsBytes(image);

        // 3. Prepare share text
        String text = isUrdu
            ? "رسید: ${t.type == 'income' ? 'رقم لی' : 'رقم دی'}\nرقم: Rs. ${t.amount}"
            : "Receipt: ${t.type == 'income' ? 'Received' : 'Paid'}\nAmount: Rs. ${t.amount}";

        // 4. Share image
        await Share.shareXFiles([XFile(imagePath.path)], text: text);
      }
    } catch (e) {
      debugPrint("Error sharing receipt image: $e");
      // Fallback to text if image fails
      _shareReceiptAsText(t, a, isUrdu);
    }
  }

  void _shareReceiptAsText(Transaction t, Account? a, bool isUrdu) {
    String text = isUrdu
        ? "رسید: ${t.type == 'income' ? 'رقم لی' : 'رقم دی'}\nنام: ${a?.name ?? 'Unknown'}\nرقم: Rs. ${t.amount}\nتاریخ: ${t.date.day}/${t.date.month}/${t.date.year}"
        : "Receipt: ${t.type == 'income' ? 'Received' : 'Paid'}\nName: ${a?.name ?? 'Unknown'}\nAmount: Rs. ${t.amount}\nDate: ${t.date.day}/${t.date.month}/${t.date.year}";

    Share.share(text);
  }
}
