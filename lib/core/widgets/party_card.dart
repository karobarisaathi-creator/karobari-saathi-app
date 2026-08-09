import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'profile_info_widget.dart';

class PartyCard extends StatefulWidget {
  final Account party;
  final VoidCallback onView;
  final VoidCallback onMessage;

  const PartyCard({
    super.key,
    required this.party,
    required this.onView,
    required this.onMessage,
  });

  @override
  State<PartyCard> createState() => _PartyCardState();
}

class _PartyCardState extends State<PartyCard> {
  Map<String, String>? _remoteProfileMap;
  String? _remoteProfession;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  @override
  void didUpdateWidget(PartyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // اگر فون نمبر بدل جائے تو دوبارہ چیک کریں
    if (oldWidget.party.phone != widget.party.phone) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (widget.party.phone.length < 10) return;
    
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final profile = await dbService.findPublicProfileByPhone(widget.party.phone);
    
    if (mounted && profile != null) {
      setState(() {
        _remoteProfession = profile['profession'];
        _remoteProfileMap = profile;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint("Could not launch call: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    final bool isPayable = widget.party.balance > 0;
    final bool isReceivable = widget.party.balance < 0;
    final bool isSettled = widget.party.balance == 0;

    final Color balanceColor = isSettled 
        ? AppTheme.textSecondary 
        : (isPayable ? AppTheme.expenseColor : AppTheme.incomeColor);

    final String balanceText = isSettled
        ? (isUrdu ? 'حساب صاف ہے' : 'Settled')
        : (isPayable 
            ? (isUrdu ? 'دینے ہیں' : 'To Pay') 
            : (isUrdu ? 'لینے ہیں' : 'To Receive'));

    final IconData balanceIcon = isSettled 
        ? PhosphorIcons.checkCircle() 
        : (isPayable ? PhosphorIcons.arrowUpRight() : PhosphorIcons.arrowDownLeft());

    final String displayCategory = _remoteProfession != null && _remoteProfession!.isNotEmpty
        ? _remoteProfession!
        : (isUrdu ? 'پرسنل کھاتہ' : 'Personal Account');

    final String displayName = widget.party.name.trim().isEmpty
        ? (isUrdu ? 'نامعلوم' : 'Unknown')
        : widget.party.name;

    // Standardized Update Comparison Logic (Name, Photo, or Profession)
    final remoteName = _remoteProfileMap?['name']?.trim() ?? '';
    final localName = widget.party.name.trim();
    final remotePhoto = _remoteProfileMap?['photoUrl']?.trim() ?? '';
    final localPhoto = widget.party.profileImage?.trim() ?? '';
    final remoteProf = _remoteProfileMap?['profession']?.trim() ?? '';
    final localProf = (isUrdu ? 'پرسنل کھاتہ' : 'Personal Account').trim(); // Default local comparison

    final bool hasUpdate = _remoteProfileMap != null && 
        ((remoteName.isNotEmpty && remoteName != localName) || 
         (remotePhoto.isNotEmpty && remotePhoto != localPhoto) ||
         (remoteProf.isNotEmpty && remoteProf != widget.party.category && remoteProf != localProf));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSettled 
            ? Colors.white 
            : balanceColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isSettled 
              ? AppTheme.darkColor.withOpacity(0.15) 
              : balanceColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onView,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileInfoWidget(
                          name: widget.party.name,
                          phone: widget.party.phone,
                          profileImage: widget.party.profileImage,
                          showText: false,
                          customSize: 42,
                          borderRadius: 6,
                          hasUpdate: hasUpdate,
                        ),
                        Consumer<NotificationService>(
                          builder: (context, notificationService, _) {
                            final unreadCount = notificationService.notifications.where((n) {
                              if (n.isRead) return false;
                              if (n.relatedAccountId == widget.party.id) return true;
                              final data = n.data;
                              if (data != null) {
                                if (data['accountId'] == widget.party.id) return true;
                                final senderPhone = data['senderPhone']?.toString().replaceAll(RegExp(r'\D'), '');
                                final partyPhone = widget.party.phone.replaceAll(RegExp(r'\D'), '');
                                if (senderPhone != null && senderPhone.isNotEmpty && partyPhone.isNotEmpty) {
                                  if (senderPhone.endsWith(partyPhone.length > 10 ? partyPhone.substring(partyPhone.length - 10) : partyPhone)) {
                                    return true;
                                  }
                                }
                              }
                              return false;
                            }).length;

                            if (unreadCount == 0) return const SizedBox.shrink();

                            return Positioned(
                              left: 28, 
                              top: 26,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.expenseColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                                  ],
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: ''),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: fontWeight,
                                    color: AppTheme.darkColor,
                                    fontFamily: fontFamily,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.party.isVerified) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                                  size: 16,
                                  color: AppTheme.verifiedGold,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayCategory,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.themeColor,
                                    fontFamily: fontFamily,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    balanceText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: balanceColor,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                  if (!isSettled) ...[
                                    const SizedBox(width: 4),
                                    Icon(balanceIcon, size: 14, color: balanceColor),
                                  ],
                                  const SizedBox(width: 6),
                                  Text(
                                    'Rs ${widget.party.balance.abs().toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: balanceColor,
                                      fontFamily: '', 
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1, color: AppTheme.darkColor.withOpacity(0.08)),

              // Bottom Section: Actions
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent, // پور کارڈ پر رنگ دکھانے کے لیے اسے ٹرانسپیرنٹ کر دیا
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // Call Action
                    Expanded(
                      child: InkWell(
                        onTap: () => _makePhoneCall(widget.party.phone),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.phone(), size: 20, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                isUrdu ? 'کال کریں' : 'Call Party',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: fontWeight,
                                  color: AppTheme.darkColor,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    Container(height: 24, width: 1, color: Colors.grey.withOpacity(0.3)),

                    // Reminder Action
                    Expanded(
                      child: InkWell(
                        onTap: widget.onMessage,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isUrdu ? 'یاددہانی بھیجیں' : 'Send Reminder',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: fontWeight,
                                  color: AppTheme.themeColor,
                                  fontFamily: fontFamily,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(PhosphorIcons.bell(), size: 20, color: AppTheme.themeColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
