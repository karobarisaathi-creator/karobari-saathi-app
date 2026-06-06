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
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/voice_comment_player.dart';
import 'package:account_app/core/widgets/image_grid_viewer.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'add_transaction_screen.dart';
import 'package:account_app/features/professions/add_profession_transaction_screen.dart';
import 'package:account_app/core/models/profession_model.dart';

import 'package:account_app/core/widgets/profile_info_widget.dart';

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
      backgroundColor: const Color(0xFFF5F5F5),
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
                // Bill Paper Container wrapped in Screenshot
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header Style
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppTheme.darkColor,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
                                ),
                              ),
                              const SizedBox(width: 8),
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

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Party Info
                              if (widget.transaction.professionId == null || widget.transaction.professionId!.isEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isUrdu ? 'بل نمبر' : 'Bill Number',
                                              style: TextStyle(fontWeight: fontWeight, fontSize: 14, fontFamily: fontFamily, color: AppTheme.textSecondary),
                                            ),
                                            Text(
                                              (widget.transaction.referenceNumber != null && widget.transaction.referenceNumber!.isNotEmpty)
                                                  ? widget.transaction.referenceNumber!
                                                  : '#${widget.transaction.id.substring(widget.transaction.id.length - 6)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkColor, fontFamily: ''),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(widget.transaction.date),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary, fontFamily: ''),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isUrdu ? 'پیشہ ورانہ ٹرانزیکشن' : 'Profession Transaction',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: fontFamily, color: AppTheme.darkColor),
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(widget.transaction.date),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    if (widget.transaction.professionName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          widget.transaction.professionName!,
                                          style: TextStyle(fontSize: 14, fontFamily: fontFamily, color: AppTheme.textSecondary),
                                        ),
                                      ),
                                  ],
                                ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 15),
                                child: Divider(thickness: 1, color: Colors.grey),
                              ),

                              // Items Table
                              Directionality(
                                textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(),
                                    1: IntrinsicColumnWidth(),
                                    2: IntrinsicColumnWidth(),
                                    3: IntrinsicColumnWidth(),
                                  },
                                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                                  children: [
                                    TableRow(
                                      children: [
                                        Text(isUrdu ? 'تفصیل' : 'Description', textAlign: TextAlign.start, style: TextStyle(fontWeight: fontWeight, fontFamily: fontFamily)),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(isUrdu ? 'تعداد' : 'Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: fontWeight, fontFamily: fontFamily))),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(isUrdu ? 'ریٹ' : 'Rate', textAlign: TextAlign.center, style: TextStyle(fontWeight: fontWeight, fontFamily: fontFamily))),
                                        Text(isUrdu ? 'ٹوٹل' : 'Total', textAlign: TextAlign.end, style: TextStyle(fontWeight: fontWeight, fontFamily: fontFamily)),
                                      ],
                                    ),
                                    const TableRow(children: [SizedBox(height: 10), SizedBox(), SizedBox(), SizedBox()]),
                                    if (widget.transaction.items.isNotEmpty)
                                      ...widget.transaction.items.map((item) => TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.description, 
                                                  textAlign: TextAlign.start,
                                                  style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight)
                                                ),
                                                if (item.unit != null && item.unit!.isNotEmpty)
                                                  Text(
                                                    'Per ${item.unit}',
                                                    textAlign: TextAlign.start,
                                                    style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: fontFamily),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                            child: Text(
                                              '${item.quantity.toStringAsFixed(0)}${item.unit != null ? " ${item.unit}" : ""}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: '')
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                            child: Text(item.rate.toStringAsFixed(0), textAlign: TextAlign.center, style: numberStyle),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Text(item.total.toStringAsFixed(0), textAlign: TextAlign.end, style: numberStyle),
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
                                              textAlign: TextAlign.start,
                                              style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight)
                                            ),
                                          ),
                                          const SizedBox(),
                                          const SizedBox(),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Text(widget.transaction.amount.toStringAsFixed(0), textAlign: TextAlign.end, style: numberStyle),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 15),
                                child: Divider(thickness: 2, color: AppTheme.darkColor),
                              ),

                              // Grand Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isUrdu ? 'کل رقم:' : 'Grand Total:',
                                    style: TextStyle(fontSize: 18, fontWeight: fontWeight, fontFamily: fontFamily),
                                  ),
                                  Text(
                                    'Rs. ${widget.transaction.amount.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: '', color: widget.transaction.type == 'income' ? AppTheme.incomeColor : AppTheme.expenseColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              if (widget.transaction.professionId == null || widget.transaction.professionId!.isEmpty)
                                Center(
                                  child: Text(
                                    isUrdu ? 'آپ کے تعاون کا شکریہ!' : 'Thank you for your business!',
                                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontFamily: fontFamily, fontWeight: fontWeight),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                if (widget.transaction.voiceNote != null || (widget.transaction.billImage != null && widget.transaction.billImage!.isNotEmpty))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.paperclip(), size: 20, color: AppTheme.darkColor),
                            const SizedBox(width: 8),
                            Text(
                              isUrdu ? 'منسلک تصاویر اور وائس نوٹ' : 'Attached Images & Voice',
                              style: TextStyle(fontWeight: fontWeight, fontFamily: fontFamily, color: AppTheme.darkColor),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (widget.transaction.voiceNote != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: VoiceCommentPlayer(audioUrl: widget.transaction.voiceNote!),
                          ),
                        if (widget.transaction.billImage != null && widget.transaction.billImage!.isNotEmpty)
                          ImageGridViewer(
                            imagePaths: widget.transaction.billImage!.split(','),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (widget.transaction.professionId != null && widget.transaction.professionId!.isNotEmpty) {
                            final db = Provider.of<DatabaseService>(context, listen: false);
                            final profession = db.getProfession(widget.transaction.professionId!);
                            if (profession != null) {
                              List<String> incomeCats = [];
                              List<String> expenseCats = [];
                              for (var cat in profession.categories) {
                                if (cat.startsWith('INC:')) {
                                  incomeCats.add(cat.substring(4));
                                } else if (cat.startsWith('EXP:')) {
                                  expenseCats.add(cat.substring(4));
                                }
                              }
                              
                              if (incomeCats.isEmpty) incomeCats = ['تنخواہ', 'فری لانس', 'کاروبار', 'دیگر'];
                              if (expenseCats.isEmpty) expenseCats = ['کرایہ', 'بجلی', 'پانی', 'ٹرانسپورٹ', 'دیگر'];

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddProfessionTransactionScreen(
                                    profession: profession,
                                    incomeCategories: incomeCats,
                                    expenseCategories: expenseCats,
                                    transactionToEdit: widget.transaction,
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AddTransactionScreen(transactionToEdit: widget.transaction)),
                          );
                        },
                        icon: Icon(PhosphorIcons.pencilLine()),
                        label: Text(isUrdu ? 'ایڈٹ کریں' : 'Edit', style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareReceiptAsImage(context, widget.transaction, account, isUrdu),
                        icon: Icon(PhosphorIcons.shareNetwork()),
                        label: Text(isUrdu ? 'شیئر کریں' : 'Share', style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
