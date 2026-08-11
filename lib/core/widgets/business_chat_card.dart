// lib/features/business_chat/widgets/business_chat_card.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = DateTime.now();
      }
      
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
              ? AppTheme.themeColor.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                ProfileInfoWidget(
                  name: name,
                  phone: '',
                  profileImage: image,
                  category: profession,
                  isVerticalCategory: true,
                  customSize: 50,
                  borderRadius: 10,
                  isVerified: isVerified,
                  bottom: Row(
                    children: [
                      Icon(PhosphorIcons.chatText(),
                          size: 14,
                          color: AppTheme.darkColor.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkColor,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned.directional(
                  textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  end: 0, // In RTL (Urdu), end is Screen Left
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.darkColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: ''),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}