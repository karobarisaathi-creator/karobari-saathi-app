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
    required this.party,
    required this.onView,
    required this.onMessage,
  });

  @override
  State<PartyCard> createState() => _PartyCardState();
}

class _PartyCardState extends State<PartyCard> {
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (widget.party.phone.length < 10) return;
    
    // Check if we have a remote profile that differs from local
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final profile = await dbService.findPublicProfileByPhone(widget.party.phone);
    
    if (mounted && profile != null) {
      if (profile['name'] != widget.party.name || profile['photoUrl'] != widget.party.profileImage) {
        setState(() {
          _hasUpdate = true;
        });
      }
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileInfoWidget(
                            name: widget.party.name,
                            phone: widget.party.phone,
                            profileImage: widget.party.profileImage,
                            category: widget.party.category,
                            date: widget.party.createdAt,
                            showDate: false,
                            hasUpdate: _hasUpdate,
                            isVerified: widget.party.isVerified,
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
                                left: 24, // Image is 36x36, placing badge at bottom-right of image
                                top: 22,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.expenseColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: '', // Ensure numbers look good
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  balanceText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: balanceColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ),
                            ),
                            if (!isSettled) ...[
                              const SizedBox(width: 4),
                              Icon(
                                balanceIcon,
                                size: 14,
                                color: balanceColor,
                                weight: 3,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Rs ${widget.party.balance.abs().toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: balanceColor,
                              fontFamily: '', 
                            ),
                          ),
                        ),
                      ],
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
