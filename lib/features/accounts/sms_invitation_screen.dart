import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/utils/formatters.dart';

class BalanceAlertScreen extends StatefulWidget {
  final Account party;

  const BalanceAlertScreen({Key? key, required this.party}) : super(key: key);

  @override
  _BalanceAlertScreenState createState() => _BalanceAlertScreenState();
}

class _BalanceAlertScreenState extends State<BalanceAlertScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initial Message Setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageService = Provider.of<LanguageService>(context, listen: false);
      final isUrdu = languageService.isUrdu;
      final balance = widget.party.balance.abs().toStringAsFixed(0);
      final status = widget.party.balance >= 0
          ? (isUrdu ? "میں نے آپ کو دینے ہیں" : "Payable")
          : (isUrdu ? "میں نے آپ سے لینے ہیں" : "Receivable");

      String initialMessage;
      if (isUrdu) {
        initialMessage = """السلام علیکم!
محترم ${widget.party.name}،
آپ کا موجودہ بیلنس RS $balance ($status) ہے۔
براہ مہربانی تصدیق کریں۔ شکریہ۔""";
      } else {
        initialMessage = """Assalam-o-Alaikum!
Dear ${widget.party.name},
Your current balance is RS $balance ($status).
Please verify. Thanks.""";
      }

      setState(() {
        _messageController.text = initialMessage;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = FontWeight.normal;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: isUrdu ? 'بیلنس کا پیغام' : 'Balance Alert',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Bill Paper Container Style (Matches Receipt)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Party Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isUrdu ? 'نام:' : 'Name:', style: TextStyle(color: Colors.grey, fontFamily: fontFamily, fontWeight: fontWeight)),
                                Text(
                                  widget.party.name,
                                  style: TextStyle(fontSize: 18, fontWeight: fontWeight, fontFamily: fontFamily, color: AppTheme.darkColor),
                                ),
                                if (widget.party.phone.isNotEmpty)
                                  Text(
                                    Formatters.formatPhoneNumber(widget.party.phone),
                                    style: const TextStyle(color: Colors.blueGrey, fontSize: 14, fontFamily: '', fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(isUrdu ? 'کل بیلنس' : 'Net Balance', style: TextStyle(color: Colors.grey, fontFamily: fontFamily, fontWeight: fontWeight)),
                                Text(
                                  'RS ${widget.party.balance.abs().toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: '',
                                    color: widget.party.balance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Divider(thickness: 1, color: Colors.grey),
                        ),

                        Text(
                          isUrdu ? 'پیغام لکھیں:' : 'Compose Message:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            fontFamily: fontFamily,
                            fontWeight: fontWeight,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Message Input
                        TextField(
                          controller: _messageController,
                          maxLines: 4,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontWeight: FontWeight.normal,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            fillColor: const Color(0xFFF9F9F9),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: AppTheme.themeColor, width: 2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Footer Message
                        Center(
                          child: Text(
                            isUrdu ? 'شکریہ!' : 'Thank you!',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontFamily: fontFamily, fontWeight: fontWeight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendSMS(context),
                    icon: Icon(PhosphorIcons.chatTeardropDots(PhosphorIconsStyle.bold), size: 20),
                    label: Text(
                      'SMS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: '',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendWhatsApp(context),
                    icon: Icon(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.bold), size: 20),
                    label: Text(
                      'WhatsApp',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: '',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // WhatsApp Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendSMS(BuildContext context) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: widget.party.phone,
      queryParameters: <String, String>{
        'body': _messageController.text,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        // Fallback for some devices
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Could not launch SMS: \$e');
    }
  }

  void _sendWhatsApp(BuildContext context) async {
    String phone = widget.party.phone.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    // Ensure international format for WhatsApp (assuming PK if not present)
    if (phone.startsWith('0')) {
      phone = '92' + phone.substring(1);
    }
    
    final String message = Uri.encodeComponent(_messageController.text);
    final Uri whatsappUri = Uri.parse("whatsapp://send?phone=\$phone&text=\$message");
    final Uri whatsappWebUri = Uri.parse("https://wa.me/\$phone?text=\$message");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(whatsappWebUri)) {
        await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(context, 'WhatsApp not installed or could not launch.');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error launching WhatsApp: \$e');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
