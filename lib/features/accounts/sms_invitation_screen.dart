import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';

class BalanceAlertDialog extends StatefulWidget {
  final Account party;

  const BalanceAlertDialog({super.key, required this.party});

  static Future<void> show(
    BuildContext context, {
    required Account party,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => BalanceAlertDialog(party: party),
    );
  }

  @override
  State<BalanceAlertDialog> createState() => _BalanceAlertDialogState();
}

class _BalanceAlertDialogState extends State<BalanceAlertDialog> {
  final UrduAwareTextEditingController _messageController =
      UrduAwareTextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initial Message Setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
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
    _messageController.isUrdu = isUrdu;
    const fontFamily = '';
    final fontWeight = FontWeight.normal;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: UrduAwareText(
                      isUrdu ? 'بیلنس کا پیغام' : 'Balance Alert',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isUrdu ? 'بند کریں' : 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Bill Paper Container Style (Matches Receipt)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5)),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        UrduAwareText(isUrdu ? 'نام:' : 'Name:',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontFamily: fontFamily,
                                                fontWeight: fontWeight)),
                                        UrduAwareText(
                                          widget.party.name,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: fontWeight,
                                              fontFamily: fontFamily,
                                              color: AppTheme.darkColor),
                                        ),
                                        if (widget.party.phone.isNotEmpty)
                                          UrduAwareText(
                                            Formatters.formatPhoneNumber(
                                                widget.party.phone),
                                            style: const TextStyle(
                                                color: Colors.blueGrey,
                                                fontSize: 14,
                                                fontFamily: '',
                                                fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        UrduAwareText(
                                            isUrdu ? 'کل بیلنس' : 'Net Balance',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontFamily: fontFamily,
                                                fontWeight: fontWeight)),
                                        UrduAwareText(
                                          'RS ${widget.party.balance.abs().toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: '',
                                            color: widget.party.balance >= 0
                                                ? AppTheme.incomeColor
                                                : AppTheme.expenseColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  child:
                                      Divider(thickness: 1, color: Colors.grey),
                                ),

                                UrduAwareText(
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
                                      borderSide:
                                          const BorderSide(color: Colors.grey),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: const BorderSide(
                                          color: AppTheme.themeColor, width: 2),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Footer Message
                                Center(
                                  child: UrduAwareText(
                                    isUrdu ? 'شکریہ!' : 'Thank you!',
                                    style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                        fontFamily: fontFamily,
                                        fontWeight: fontWeight),
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
                          child: AppButton(
                            text: 'SMS',
                            onPressed: () => _sendSMS(context),
                            icon: PhosphorIcons.chatTeardropDots(
                                PhosphorIconsStyle.bold),
                            color: Colors.blueGrey,
                            size: AppButtonSize.large,
                            isFullWidth: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: 'WhatsApp',
                            onPressed: () => _sendWhatsApp(context),
                            icon: PhosphorIcons.whatsappLogo(
                                PhosphorIconsStyle.bold),
                            color: Colors.green,
                            size: AppButtonSize.large,
                            isFullWidth: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendSMS(BuildContext context) async {
    final rawPhone = widget.party.phone;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final normalizedPhone = Formatters.normalizePhoneNumber(rawPhone);

    if (normalizedPhone == null) {
      _showErrorSnackBar(
          context, isUrdu ? 'فون نمبر درست نہیں ہے' : 'Invalid phone number');
      return;
    }

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: normalizedPhone.replaceAll('+', ''),
      queryParameters: <String, String>{
        'body': _messageController.text.trim(),
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showErrorSnackBar(
          context, isUrdu ? 'SMS شروع نہیں ہو سکا' : 'Could not launch SMS');
    }
  }

  void _sendWhatsApp(BuildContext context) async {
    final rawPhone = widget.party.phone;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final normalizedPhone = Formatters.normalizePhoneNumber(rawPhone);

    if (normalizedPhone == null) {
      _showErrorSnackBar(
          context, isUrdu ? 'فون نمبر درست نہیں ہے' : 'Invalid phone number');
      return;
    }

    final phoneDigits = normalizedPhone.replaceAll('+', '');
    final String message = Uri.encodeComponent(_messageController.text.trim());
    final Uri whatsappUri =
        Uri.parse('whatsapp://send?phone=$phoneDigits&text=$message');
    final Uri whatsappWebUri =
        Uri.parse('https://wa.me/$phoneDigits?text=$message');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(whatsappWebUri)) {
        await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(
            context,
            isUrdu
                ? 'واٹس ایپ چل نہیں سکی'
                : 'WhatsApp not installed or could not launch.');
      }
    } catch (e) {
      _showErrorSnackBar(context,
          isUrdu ? 'واٹس ایپ چل نہیں سکی' : 'Could not launch WhatsApp');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    AppToast.error(context, message);
  }
}
