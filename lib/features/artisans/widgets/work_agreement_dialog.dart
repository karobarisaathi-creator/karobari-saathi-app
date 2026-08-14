import 'package:flutter/material.dart';
import 'package:account_app/core/widgets/app_button.dart';

class WorkAgreementDialog extends StatelessWidget {
  final String artisanName;
  final String customerName;
  final double amount;
  final String workDescription;
  final VoidCallback onAgree;
  final bool isUrdu;
  final String fontFamily;

  const WorkAgreementDialog({
    super.key,
    required this.artisanName,
    required this.customerName,
    required this.amount,
    required this.workDescription,
    required this.onAgree,
    this.isUrdu = false,
    this.fontFamily = '',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isUrdu ? '📜 کام کا معاہدہ' : '📜 Work Agreement', 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: fontFamily),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                isUrdu ? '1. فریقین' : '1. Parties', 
                isUrdu 
                  ? '• کاریگر: $artisanName\n• گاہک: $customerName' 
                  : '• Artisan: $artisanName\n• Customer: $customerName',
                fontFamily
              ),
              _buildSection(isUrdu ? '2. کام کی تفصیل' : '2. Work Description', workDescription, fontFamily),
              _buildSection(isUrdu ? '3. معاہدہ کردہ رقم' : '3. Agreed Amount', 'Rs. ${amount.toStringAsFixed(0)}', fontFamily),
              _buildSection(
                isUrdu ? '4. ادائیگی کی شرائط' : '4. Payment Terms', 
                isUrdu 
                  ? '• 50% پیشگی ادائیگی کام شروع کرنے سے پہلے\n• 50% کام مکمل ہونے پر\n• ادائیگی بینک ٹرانسفر یا ایزی پیسہ کے ذریعے'
                  : '• 50% advance before start\n• 50% on completion\n• Payment via Bank/EasyPaisa',
                fontFamily
              ),
              _buildSection(
                isUrdu ? '5. منسوخی کی پالیسی' : '5. Cancellation', 
                isUrdu 
                  ? '• گاہک 24 گھنٹے پہلے منسوخ کر سکتا ہے\n• 24 گھنٹے سے کم میں منسوخی پر 25% چارجز'
                  : '• Cancel 24h before for free\n• 25% charges if late cancellation',
                fontFamily
              ),
              _buildSection(
                isUrdu ? '6. وارنٹی' : '6. Warranty', 
                isUrdu 
                  ? '• کاریگر 30 دن کی وارنٹی فراہم کرے گا\n• کسی بھی خرابی کی صورت میں مفت مرمت'
                  : '• Artisan provides 30 days warranty\n• Free repair if issues occur',
                fontFamily
              ),
              _buildSection(
                isUrdu ? '7. ذمہ داریاں' : '7. Responsibilities', 
                isUrdu 
                  ? '• کاریگر محفوظ اور معیاری کام کرنے کا پابند\n• گاہک کام کے لیے محفوظ ماحول فراہم کرے گا'
                  : '• Artisan: Quality & safe work\n• Customer: Safe environment',
                fontFamily
              ),
              _buildSection(
                isUrdu ? '8. تنازعات کا حل' : '8. Dispute Resolution', 
                isUrdu 
                  ? '• پہلے باہمی گفتگو سے حل کرنے کی کوشش\n• اگر حل نہ ہو تو پلیٹ فارم کی مدد لی جائے'
                  : '• Resolve via mutual talk first\n• Platform help if unresolved',
                fontFamily
              ),
              _buildSection(
                isUrdu ? '9. دستخط' : '9. Signatures', 
                isUrdu 
                  ? 'میں نے یہ معاہدہ پڑھ لیا ہے اور میں اس پر متفق ہوں۔'
                  : 'I have read and agree to this contract.',
                fontFamily
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isUrdu ? 'مسترد' : 'Reject', style: TextStyle(color: Colors.red, fontFamily: fontFamily)),
        ),
        AppButton(
          text: isUrdu ? '✅ منظور' : '✅ Agree',
          onPressed: () {
            Navigator.pop(context);
            onAgree();
          },
          color: Colors.green,
          size: AppButtonSize.small,
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey, fontFamily: fontFamily),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4, fontFamily: fontFamily),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
