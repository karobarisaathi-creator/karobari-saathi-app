// lib/features/business_chat/widgets/business_chat_card.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';

class BusinessChatCard extends StatelessWidget {
  final String name;
  final String profession;
  final String lastMessage;
  final dynamic timestamp;
  final String? image;
  final int unreadCount;
  final bool isVerified;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onTap;

  const BusinessChatCard({
    super.key,
    required this.name,
    required this.profession,
    required this.lastMessage,
    required this.timestamp,
    this.image,
    required this.unreadCount,
    required this.isVerified,
    required this.isUrdu,
    required this.fontFamily,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String timeStr = '';
    if (timestamp != null) {
      final date = (timestamp as dynamic).toDate();
      final now = DateTime.now();
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        timeStr = DateFormat('hh:mm a').format(date);
      } else {
        timeStr = DateFormat('dd/MM/yy').format(date);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: unreadCount > 0
            ? AppTheme.themeColor.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unreadCount > 0
              ? AppTheme.themeColor.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ProfileInfoWidget(
              name: name,
              phone: '',
              profileImage: image,
              category: profession,
              isVerticalCategory: true,
              customSize: 50,
              borderRadius: 10,
              isVerified: isVerified,
              suffix: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                        fontSize: 9, color: Colors.grey, fontFamily: ''),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.themeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              bottom: Row(
                children: [
                  Icon(PhosphorIcons.chatText(),
                      size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: unreadCount > 0
                            ? AppTheme.darkColor
                            : Colors.grey[500],
                        fontWeight: unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}