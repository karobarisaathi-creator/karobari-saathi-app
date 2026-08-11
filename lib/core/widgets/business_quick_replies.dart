// lib/features/business_chat/widgets/business_quick_replies.dart
import 'package:flutter/material.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/database/business_chat_service.dart';

class BusinessQuickReplies extends StatelessWidget {
  final bool isUrdu;
  final String fontFamily;
  final Function(String) onReplyTap;

  const BusinessQuickReplies({
    super.key,
    required this.isUrdu,
    required this.fontFamily,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final replies = BusinessChatService.getQuickReplies();

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: replies.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 6),
            child: OutlinedButton(
              onPressed: () => onReplyTap(replies[index]),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.themeColor.withValues(alpha: 0.3)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                replies[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.themeColor,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}