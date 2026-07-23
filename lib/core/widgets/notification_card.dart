import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/notification_model.dart';
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
    Key? key,
    required this.notification,
    required this.isUrdu,
    required this.fontFamily,
    required this.onAddPressed,
    required this.onDeletePressed,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isTransaction = notification.type == NotificationType.transaction && notification.data != null;
    final bool isPriceDrop = notification.type == NotificationType.price_drop;
    final data = notification.data;
    final bool isAdded = data?['isAdded'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: notification.isRead ? const Color(0xFFF8F9FA) : const Color(0xFFEDF0F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPriceDrop ? AppTheme.incomeColor.withOpacity(0.2) : AppTheme.darkColor.withOpacity(0.05), 
          width: isPriceDrop ? 2 : 1
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. پروفائل، نام اور فون نمبر
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: isPriceDrop 
                          ? _buildSystemIdentity(isUrdu)
                          : ProfileInfoWidget(
                              name: data?['senderName'] ?? (isUrdu ? 'نامعلوم یوزر' : 'Unknown User'),
                              phone: data?['senderPhone'] ?? '',
                              profileImage: data?['senderPhotoUrl'],
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
                              fontSize: 11,
                              fontFamily: '',
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
                    padding: EdgeInsets.only(left: isPriceDrop ? 0 : 56), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTransaction) ...[
                          Text(
                            (data?['description'] != null && data!['description'].toString().trim().isNotEmpty)
                                ? data['description'].toString()
                                : _getTransactionMessage(data!, isUrdu),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 14,
                              height: 1.4,
                              color: AppTheme.darkColor,
                              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (data?['description'] != null && data!['description'].toString().trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _getTransactionMessage(data, isUrdu),
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                        ] else ...[
                          Text(
                            notification.message,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: isPriceDrop ? 15 : 13,
                              color: AppTheme.darkColor,
                              fontWeight: isPriceDrop ? FontWeight.bold : FontWeight.normal,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (isTransaction)
                    ElevatedButton(
                      onPressed: isAdded ? null : onAddPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdded ? Colors.grey.shade400 : AppTheme.themeColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        isAdded 
                            ? (isUrdu ? 'کھاتے میں شامل ہے' : 'Added to Ledger')
                            : (isUrdu ? 'کھاتے میں شامل کریں' : 'Add to Ledger'),
                        style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  if (isPriceDrop)
                    ElevatedButton.icon(
                      onPressed: onTap,
                      icon: Icon(PhosphorIcons.tag(PhosphorIconsStyle.fill), size: 16),
                      label: Text(
                        isUrdu ? 'آئٹم دیکھیں' : 'View Deal',
                        style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.incomeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDeletePressed,
                    icon: Icon(PhosphorIcons.trash(), color: Colors.red.shade400, size: 20),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          isUrdu ? 'مارکیٹ الرٹ' : 'Market Alert',
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
}
