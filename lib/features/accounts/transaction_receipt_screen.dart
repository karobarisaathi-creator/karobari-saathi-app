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
import 'package:account_app/core/widgets/voice_comment_player.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'add_transaction_screen.dart';
import 'package:account_app/features/professions/add_project_transaction_screen.dart';

import 'package:account_app/core/widgets/profile_info_widget.dart';

import 'package:account_app/core/widgets/app_button.dart';
import 'package:screenshot/screenshot.dart';

class TransactionReceiptScreen extends StatefulWidget {
  final Transaction transaction;

  const TransactionReceiptScreen({super.key, required this.transaction});

  @override
  State<TransactionReceiptScreen> createState() => _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    final numberStyle = const TextStyle(fontFamily: '', fontWeight: FontWeight.bold);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'رسید' : 'Receipt',
        showBackButton: true,
      ),
      body: FutureBuilder<Account?>(
        future: Future.value(Provider.of<DatabaseService>(context, listen: false).getAccount(widget.transaction.accountId)),
        builder: (context, snapshot) {
          final account = snapshot.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                  Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // --- Modern Header with Gradient ---
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.darkColor,
                                AppTheme.darkColor.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: ProfileInfoWidget(
                                  name: account?.name ?? 'Unknown',
                                  phone: account?.phone ?? '',
                                  profileImage: account?.profileImage,
                                  category: account?.category,
                                  address: account?.address,
                                  textColor: Colors.white,
                                  subtitleColor: Colors.white70,
                                  isVerified: account?.isVerified ?? false,
                                  customSize: 40,
                                  borderRadius: 6,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  Image.asset(
                                    'assets/images/icons/zalooq.png',
                                    height: 40,
                                    errorBuilder: (context, error, stackTrace) => Icon(PhosphorIcons.wallet(), color: Colors.white, size: 40),
                                  ),
                                  Text(
                                    isUrdu ? 'کاروباری ساتھی' : 'KAROBARI SAATHI',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: fontFamily),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // --- Receipt Body ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bill Info Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isUrdu ? 'بل نمبر' : 'INVOICE NO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: AppTheme.textSecondary,
                                          fontFamily: fontFamily,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (widget.transaction.referenceNumber != null && widget.transaction.referenceNumber!.isNotEmpty)
                                            ? widget.transaction.referenceNumber!
                                            : '#${widget.transaction.id.substring(widget.transaction.id.length - 6)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.darkColor,
                                          fontFamily: '',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isUrdu ? 'تاریخ' : 'DATE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: AppTheme.textSecondary,
                                          fontFamily: fontFamily,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd MMM, yyyy').format(widget.transaction.date),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.darkColor,
                                          fontFamily: '',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              _buildDashedDivider(),
                              const SizedBox(height: 20),

                              // Items / Description Table
                              Directionality(
                                textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(4.7),
                                    1: FlexColumnWidth(1.5),
                                    2: FlexColumnWidth(1.5),
                                    3: FlexColumnWidth(1.8),
                                  },
                                  children: [
                                    TableRow(
                                      children: [
                                        _buildTableHeader(isUrdu ? 'تفصیل' : 'Item', TextAlign.start, fontFamily),
                                        _buildTableHeader(isUrdu ? 'تعداد' : 'Qty', TextAlign.center, fontFamily),
                                        _buildTableHeader(isUrdu ? 'ریٹ' : 'Rate', TextAlign.center, fontFamily),
                                        _buildTableHeader(isUrdu ? 'ٹوٹل' : 'Amount', TextAlign.end, fontFamily),
                                      ],
                                    ),
                                    const TableRow(children: [SizedBox(height: 12), SizedBox(), SizedBox(), SizedBox()]),
                                    if (widget.transaction.items.isNotEmpty)
                                      ...widget.transaction.items.map((item) => TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item.description, style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight, fontSize: 13)),
                                                if (item.unit != null && item.unit!.isNotEmpty)
                                                  Text(item.unit!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Text(item.quantity.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Text(item.rate.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Text(item.total.toStringAsFixed(0), textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ))
                                    else
                                      TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Text(
                                              widget.transaction.description.isNotEmpty ? widget.transaction.description : (isUrdu ? 'نقد لین دین' : 'Cash Transaction'), 
                                              style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight, fontSize: 14)
                                            ),
                                          ),
                                          const SizedBox(),
                                          const SizedBox(),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Text(widget.transaction.amount.toStringAsFixed(0), textAlign: TextAlign.end, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
                              _buildDashedDivider(),
                              const SizedBox(height: 25),

                              // --- Simple Stacked Total Section ---
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isUrdu ? 'کل رقم' : 'TOTAL AMOUNT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppTheme.textSecondary,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rs. ${widget.transaction.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: widget.transaction.type == 'income' ? AppTheme.incomeColor : AppTheme.expenseColor,
                                      fontFamily: '',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isUrdu ? (widget.transaction.type == 'income' ? 'موصول شدہ' : 'ادا شدہ') : 'Status: ${widget.transaction.type.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: widget.transaction.type == 'income' ? AppTheme.incomeColor : AppTheme.expenseColor,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              // Footer Branding
                              Center(
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          'assets/images/icons/zalooq.png',
                                          height: 20,
                                          errorBuilder: (context, error, stackTrace) => Icon(PhosphorIcons.wallet(), size: 20, color: AppTheme.darkColor),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isUrdu ? 'شکریہ! کاروباری ساتھی' : 'POWERED BY KAROBARI SAATHI',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                            color: Colors.grey.shade400,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                      ],
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
                
                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: isUrdu ? 'ایڈٹ کریں' : 'Edit',
                        onPressed: () {
                          if (widget.transaction.accountId == 'default_account' && widget.transaction.professionId != null) {
                            final db = Provider.of<DatabaseService>(context, listen: false);
                            final profession = db.getProfession(widget.transaction.professionId!);
                            if (profession != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddProjectTransactionScreen(
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
                        onPressed: () => _shareReceiptAsImage(context, widget.transaction, account, isUrdu),
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

  Future<void> _shareReceiptAsImage(BuildContext context, Transaction t, Account? a, bool isUrdu) async {
    try {
      // 1. Capture screenshot
      final image = await _screenshotController.capture();
      
      if (image != null) {
        // 2. Save to temporary directory
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/receipt_${t.id.substring(t.id.length - 6)}.png').create();
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
