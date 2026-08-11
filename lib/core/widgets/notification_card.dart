import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:intl/intl.dart';
import 'profile_info_widget.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onAddPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.isUrdu,
    required this.fontFamily,
    required this.onAddPressed,
    required this.onDeletePressed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTransaction = notification.type == NotificationType.transaction && notification.data != null;
    final bool isPriceDrop = notification.type == NotificationType.price_drop;
    final bool isSystem = notification.type == NotificationType.system;
    final data = notification.data;
    final bool isAdded = data?['isAdded'] == true;
    final bool isArtisanRequest = data?['type'] == 'artisan_request' || data?['type'] == 'artisan_response';
    final bool isResponded = data?['responded'] == true;
    final bool isAccepted = data?['accepted'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: notification.isRead ? const Color(0xFFF8F9FA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPriceDrop || isSystem ? AppTheme.themeColor.withOpacity(0.2) : AppTheme.darkColor.withOpacity(0.05), 
          width: isPriceDrop || isSystem ? 1.5 : 1
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            if (isPriceDrop)
              _buildPriceDropHeader(isUrdu, fontFamily),
            if (isSystem && !isPriceDrop)
              _buildSystemHeader(isUrdu, fontFamily),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. پروفائل، نام اور فون نمبر
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: (isPriceDrop || isSystem)
                          ? _buildSystemIdentity(isUrdu)
                          : ProfileInfoWidget(
                              name: data?['senderName'] ?? data?['artisanName'] ?? (isUrdu ? 'صارف' : 'User'),
                              phone: data?['senderPhone'] ?? '',
                              profileImage: data?['senderPhotoUrl'],
                              isVerified: data?['isSenderVerified'] == true || data?['isSenderVerified'] == 'true',
                            ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(notification.timestamp),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontFamily: '',
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppTheme.themeColor, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 2. تحریر / عنوان
                  Padding(
                    padding: EdgeInsets.only(left: (isPriceDrop || isSystem) ? 0 : 52), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notification.title.isNotEmpty && !isPriceDrop)
                          Text(
                            notification.title,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (isTransaction) ...[
                          Text(
                            (data?['description'] != null && data!['description'].toString().trim().isNotEmpty)
                                ? data['description'].toString()
                                : _getTransactionMessage(data!, isUrdu),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 13,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        ] else ...[
                          Text(
                            notification.message,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 3. بٹن بار
            if (isTransaction || isArtisanRequest)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    if (isTransaction)
                      ElevatedButton(
                        onPressed: isAdded ? null : onAddPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAdded ? Colors.grey.shade400 : AppTheme.themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isAdded 
                              ? (isUrdu ? 'کھاتے میں شامل ہے' : 'Added')
                              : (isUrdu ? 'کھاتے میں شامل کریں' : 'Add to Ledger'),
                          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    if (data?['type'] == 'artisan_request') ...[
                      if (!isResponded)
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _respondToRequest(context, true),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(isUrdu ? 'ہاں' : 'Yes', style: TextStyle(fontFamily: fontFamily)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.incomeColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _respondToRequest(context, false),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: Text(isUrdu ? 'ناں' : 'No', style: TextStyle(fontFamily: fontFamily)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.expenseColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _buildStatusIndicator(isAccepted, isUrdu, fontFamily),
                    ],
                    const Spacer(),
                    IconButton(
                      onPressed: onDeletePressed,
                      icon: Icon(PhosphorIcons.trash(), color: Colors.red.shade300, size: 20),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isAccepted, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAccepted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAccepted ? Icons.check_circle : Icons.cancel,
            color: isAccepted ? Colors.green : Colors.red,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isAccepted 
                ? (isUrdu ? 'منظور شدہ' : 'Accepted')
                : (isUrdu ? 'معذرت کی گئی' : 'Declined'),
            style: TextStyle(
              color: isAccepted ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHeader(bool isUrdu, String fontFamily) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.info(PhosphorIconsStyle.bold), color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text(
            isUrdu ? 'اہم پیغام' : 'Important Notice',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDropHeader(bool isUrdu, String fontFamily) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.incomeColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.trendDown(PhosphorIconsStyle.bold), color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text(
            isUrdu ? 'قیمت میں بڑی کمی!' : 'Big Price Drop!',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemIdentity(bool isUrdu) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.themeColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), color: AppTheme.themeColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          isUrdu ? 'سسٹم پیغام' : 'System Message',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontSize: 14),
        ),
      ],
    );
  }

  String _getTransactionMessage(Map<String, dynamic> data, bool isUrdu) {
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final formattedAmount = Formatters.formatCurrency(amount);
    final type = data['transactionType'] ?? 'income';
    
    if (isUrdu) {
      return type == 'income' 
          ? "$formattedAmount آپ کے کھاتے میں بنام کیے ہیں" 
          : "$formattedAmount آپ کے کھاتے میں جمع کیے ہیں";
    } else {
      return type == 'income'
          ? "$formattedAmount has been billed to your account"
          : "$formattedAmount has been added to your account";
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return DateFormat('hh:mm a').format(timestamp);
    return DateFormat('dd MMM').format(timestamp);
  }

  void _respondToRequest(BuildContext context, bool accepted) async {
    final nService = Provider.of<NotificationService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    final data = notification.data;
    
    if (data == null || user == null) return;

    await nService.respondToArtisanRequest(
      customerUid: data['senderUid'],
      artisanName: user.displayName ?? 'Artisan',
      accepted: accepted,
      notificationId: notification.id,
    );

    if (context.mounted) {
      final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrdu ? 'جواب بھیج دیا گیا!' : 'Response sent!'),
          backgroundColor: accepted ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
