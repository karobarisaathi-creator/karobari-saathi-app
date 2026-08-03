import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/services/chat_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatService chatService = ChatService();
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'میسجز' : 'Messages',
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: chatService.getChatRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.chatTeardropDots(), size: 80, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  Text(
                    isUrdu ? 'کوئی میسج نہیں ملا' : 'No messages yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontFamily: fontFamily),
                  ),
                ],
              ),
            );
          }

          final chatRooms = snapshot.data!;
          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final room = chatRooms[index];
              final participants = List<String>.from(room['participants'] ?? []);
              final String otherUserId = participants.firstWhere((id) => id != chatService.currentUserId, orElse: () => '');
              final int unreadCount = room['unreadCount_${chatService.currentUserId}'] ?? 0;

              return FutureBuilder<Map<String, String>?>(
                future: Provider.of<DatabaseService>(context, listen: false).findPublicProfileByUid(otherUserId),
                builder: (context, profileSnapshot) {
                  final profile = profileSnapshot.data;
                  final String name = profile?['name'] ?? (isUrdu ? 'صارف' : 'User');
                  final String? image = profile?['photoUrl'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: (image != null && image.isNotEmpty) ? NetworkImage(image) : null,
                      child: (image == null || image.isEmpty) ? Icon(PhosphorIcons.user(), color: Colors.grey) : null,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: fontFamily),
                    ),
                    subtitle: Text(
                      room['lastMessage'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unreadCount > 0 ? AppTheme.darkColor : Colors.grey,
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (room['lastMessageTime'] != null)
                          Text(
                            DateFormat('hh:mm a').format((room['lastMessageTime'] as dynamic).toDate()),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppTheme.themeColor, shape: BoxShape.circle),
                            child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                        otherUserId: otherUserId, 
                        otherUserName: name,
                        otherUserImage: image,
                      )));
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
