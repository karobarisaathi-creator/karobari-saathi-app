import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';
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
    final bool isSystem = notification.type == NotificationType.system;
    final data = notification.data;
    final bool isAdded = data?['isAdded'] == true;
    final bool isArtisanRequest = data?['type'] == 'artisan_request' || data?['type'] == 'artisan_response';
    final bool isResponded = data?['responded'] == true;
    final bool isAccepted = data?['accepted'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notification.isRead ? const Color(0xFFF8F9FA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSystem ? AppTheme.themeColor.withOpacity(0.2) : AppTheme.darkColor.withOpacity(0.05), 
          width: isSystem ? 1.5 : 1
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
            if (isSystem)
              _buildSystemHeader(isUrdu, fontFamily),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. پروفائل، نام اور فون نمبر
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: isSystem
                          ? _buildSystemIdentity(isUrdu)
                          : ProfileInfoWidget(
                              name: data?['senderName'] ?? data?['artisanName'] ?? (isUrdu ? 'صارف' : 'User'),
                              phone: data?['senderPhone'] ?? '',
                              profileImage: data?['senderPhotoUrl'],
                              isVerified: data?['isSenderVerified'] == true || data?['isSenderVerified'] == 'true',
                              customSize: 36, // Reduced size
                            ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(notification.timestamp, isUrdu),
                            style: TextStyle(
                              color: AppTheme.darkColor.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontFamily: isUrdu ? fontFamily : '',
                              fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 8),
                  // 2. تحریر / عنوان
                  Padding(
                    padding: EdgeInsets.only(left: isSystem ? 0 : 48), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notification.title.isNotEmpty)
                          Text(
                            _getTranslatedTitle(notification.title, isUrdu),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        const SizedBox(height: 2),
                        if (isTransaction) ...[
                          Text(
                            (data?['description'] != null && data!['description'].toString().trim().isNotEmpty)
                                ? data['description'].toString()
                                : _getTransactionMessage(data!, isUrdu),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 15,
                              color: AppTheme.darkColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          Text(
                            _getTranslatedMessage(notification.message, isUrdu),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 15,
                              color: AppTheme.darkColor.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        // 🔥 Additional fields for Artisan Request (Budget & Date)
                        if (data?['type'] == 'artisan_request' || data?['type'] == 'artisan_response')
                          _buildRequestExtraInfo(data, isUrdu, fontFamily),
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
                      AppButton(
                        text: isAdded 
                            ? (isUrdu ? 'کھاتے میں شامل ہے' : 'Added')
                            : (isUrdu ? 'کھاتے میں شامل کریں' : 'Add to Ledger'),
                        variant: AppButtonVariant.outlined,
                        size: AppButtonSize.small, // 🔥 Fixed Small (38px)
                        color: isAdded ? Colors.grey : AppTheme.themeColor,
                        onPressed: isAdded ? null : onAddPressed,
                      ),
                    if (data?['type'] == 'artisan_request') ...[
                      if (!isResponded) ...[
                        AppButton(
                          text: isUrdu ? 'ہاں' : 'Yes',
                          icon: Icons.check,
                          variant: AppButtonVariant.outlined,
                          size: AppButtonSize.small, // 🔥 Fixed Small (38px)
                          color: AppTheme.incomeColor,
                          onPressed: () => _respondToRequest(context, true),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          text: isUrdu ? 'ناں' : 'No',
                          icon: Icons.close,
                          variant: AppButtonVariant.outlined,
                          size: AppButtonSize.small, // 🔥 Fixed Small (38px)
                          color: AppTheme.expenseColor,
                          onPressed: () => _respondToRequest(context, false),
                        ),
                      ] else
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
    final color = isAccepted ? Colors.green : Colors.red;
    return AppButton(
      text: isAccepted 
          ? (isUrdu ? 'منظور شدہ' : 'Accepted')
          : (isUrdu ? 'معذرت کی گئی' : 'Declined'),
      onPressed: null,
      variant: AppButtonVariant.outlined,
      size: AppButtonSize.small,
      color: color,
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
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontSize: 16),
        ),
      ],
    );
  }

  String _getTranslatedTitle(String title, bool isUrdu) {
    if (isUrdu) {
      if (title.toLowerCase().contains('work request')) return 'کام کی درخواست';
      if (title.toLowerCase().contains('transaction')) return 'نیا لین دین';
      return title;
    } else {
      if (title.contains('کام کی درخواست')) return 'Work Request';
      if (title.contains('نیا لین دین')) return 'New Transaction';
      return title;
    }
  }

  String _getTranslatedMessage(String message, bool isUrdu) {
    if (isUrdu) {
       return message; // Usually messages are already in Urdu or contain names
    } else {
       if (message.contains('آپ سے کام کے بارے میں پوچھ رہے ہیں')) {
          return 'is asking about work. Are you available?';
       }
       return message;
    }
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

  String _formatTime(DateTime timestamp, bool isUrdu) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return isUrdu ? 'ابھی' : 'Just now';
    if (difference.inHours < 1) return isUrdu ? '${difference.inMinutes} منٹ پہلے' : '${difference.inMinutes}m ago';
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

  Widget _buildRequestExtraInfo(Map<String, dynamic>? data, bool isUrdu, String fontFamily) {
    if (data == null) return const SizedBox.shrink();

    final budget = data['budget'];
    final expectedDateStr = data['expectedDate'];
    DateTime? expectedDate;
    if (expectedDateStr != null) expectedDate = DateTime.tryParse(expectedDateStr);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (budget != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.money(), size: 14, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    "Rs. $budget",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontFamily: '',
                    ),
                  ),
                ],
              ),
            ),
          if (expectedDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.calendar(), size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatDate(expectedDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontFamily: '',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
