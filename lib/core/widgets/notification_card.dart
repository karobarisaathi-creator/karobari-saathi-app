import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/notification_model.dart';
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
    final data = notification.data;
    final isTransaction =
        notification.type == NotificationType.transaction && data != null;
    final isSystem = notification.type == NotificationType.system;
    final isAdded = data?['isAdded'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            if (isSystem) _buildSystemHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: isSystem
                            ? _buildSystemIdentity()
                            : ProfileInfoWidget(
                                name: data?['senderName'] ??
                                    (isUrdu ? 'صارف' : 'User'),
                                phone: data?['senderPhone'] ?? '',
                                profileImage: data?['senderPhotoUrl'],
                                customSize: 42,
                                borderRadius: 6,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          UrduAwareText(
                            _formatTime(notification.timestamp),
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
                              decoration: const BoxDecoration(
                                color: AppTheme.themeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(left: isSystem ? 0 : 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notification.title.isNotEmpty)
                          UrduAwareText(
                            _getTranslatedTitle(notification.title),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        const SizedBox(height: 2),
                        UrduAwareText(
                          isTransaction &&
                                  data?['description'] != null &&
                                  data!['description']
                                      .toString()
                                      .trim()
                                      .isNotEmpty
                              ? data['description'].toString()
                              : isTransaction
                                  ? _getTransactionMessage(data!, isUrdu)
                                  : notification.message,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 15,
                            color: AppTheme.darkColor.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isTransaction)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    AppButton(
                      text: isAdded
                          ? (isUrdu ? 'کھاتے میں شامل ہے' : 'Added')
                          : (isUrdu ? 'کھاتے میں شامل کریں' : 'Add to Ledger'),
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.small,
                      color: isAdded ? Colors.grey : AppTheme.themeColor,
                      onPressed: isAdded ? null : onAddPressed,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onDeletePressed,
                      icon: Icon(PhosphorIcons.trash(),
                          color: Colors.red.shade300, size: 20),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onDeletePressed,
                  icon: Icon(PhosphorIcons.trash(),
                      color: Colors.red.shade300, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.info(PhosphorIconsStyle.bold),
              color: Colors.white, size: 14),
          const SizedBox(width: 8),
          UrduAwareText(
            isUrdu ? 'اہم پیغام' : 'Important Notice',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemIdentity() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.themeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
              color: AppTheme.themeColor, size: 20),
        ),
        const SizedBox(width: 12),
        UrduAwareText(
          isUrdu ? 'سسٹم پیغام' : 'System Message',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _getTranslatedTitle(String title) {
    if (isUrdu && title.toLowerCase().contains('transaction')) {
      return 'نیا لین دین';
    }
    if (!isUrdu && title.contains('نیا لین دین')) return 'New Transaction';
    return title;
  }

  String _getTransactionMessage(Map<String, dynamic> data, bool isUrdu) {
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final formattedAmount = Formatters.formatCurrency(amount);
    final type = data['transactionType'] ?? 'income';
    if (isUrdu) {
      return type == 'income'
          ? '$formattedAmount آپ کے کھاتے میں بنام کیے ہیں'
          : '$formattedAmount آپ کے کھاتے میں جمع کیے ہیں';
    }
    return type == 'income'
        ? '$formattedAmount has been billed to your account'
        : '$formattedAmount has been added to your account';
  }

  String _formatTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return isUrdu ? 'ابھی' : 'Just now';
    if (difference.inHours < 1) {
      return isUrdu
          ? '${difference.inMinutes} منٹ پہلے'
          : '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) return DateFormat('hh:mm a').format(timestamp);
    return DateFormat('dd MMM').format(timestamp);
  }
}
