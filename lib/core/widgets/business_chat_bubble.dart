// lib/features/business_chat/widgets/business_chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/business_chat_model.dart';

class BusinessChatBubble extends StatelessWidget {
  final BusinessChatMessage message;
  final bool isMe;
  final bool isUrdu;
  final String fontFamily;
  final Function(String)? onImageTap;
  final Function(String)? onOrderTap;

  const BusinessChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isUrdu,
    required this.fontFamily,
    this.onImageTap,
    this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.themeColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // فائل / تصویر
            if (message.fileUrl != null && message.messageType == 'image')
              _buildImageContent(context),

            // آرڈر لنک
            if (message.orderId != null)
              _buildOrderContent(context),

            // ٹیکسٹ
            if (message.message.isNotEmpty)
              Text(
                message.message,
                style: TextStyle(
                  color: isMe ? Colors.white : AppTheme.darkColor,
                  fontSize: 15,
                  fontFamily: fontFamily,
                ),
              ),

            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('hh:mm a').format(message.timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey,
                    fontSize: 9,
                  ),
                ),
                if (message.editedAt != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    isUrdu ? '(ترمیم شدہ)' : '(edited)',
                    style: TextStyle(
                      color: isMe ? Colors.white60 : Colors.grey,
                      fontSize: 8,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () => onImageTap?.call(message.fileUrl!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[100],
          image: DecorationImage(
            image: CachedNetworkImageProvider(message.fileUrl!),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.black26, Colors.transparent],
            ),
          ),
          alignment: Alignment.topRight,
          padding: const EdgeInsets.all(6),
          child: Icon(
            PhosphorIcons.magnifyingGlassPlus(),
            color: Colors.white70,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderContent(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    return GestureDetector(
      onTap: () => onOrderTap?.call(message.orderId!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.goldColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill),
                color: AppTheme.goldColor, size: 16),
            const SizedBox(width: 8),
            Text(
              isUrdu ? 'آرڈر دیکھیں' : 'View Order',
              style: TextStyle(
                color: AppTheme.goldColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(width: 4),
            Icon(PhosphorIcons.arrowRight(),
                color: AppTheme.goldColor, size: 12),
          ],
        ),
      ),
    );
  }
}