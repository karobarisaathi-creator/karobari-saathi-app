import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/services/chat_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChatService chatService = ChatService();
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isUrdu ? 'گفتگو / پیغامات' : 'Chats & Messages',
          style: TextStyle(
            color: Colors.white,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. Modern Dark Header
          _buildHeader(isUrdu, fontFamily),

          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchSortBar(
              controller: _searchController,
              hintText: isUrdu ? 'چیٹ تلاش کریں...' : 'Search chats...',
              padding: EdgeInsets.zero,
              onSearchChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // 3. Chat List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getChatRooms(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.themeColor));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isUrdu, fontFamily);
                }

                var chatRooms = snapshot.data!;
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        final String profession = profile?['profession'] ?? '';
                        final bool isVerified = profile?['isVerified'] == 'true';

                        // Search Filter
                        if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                          return const SizedBox.shrink();
                        }

                        return _buildChatCard(
                          context: context,
                          name: name,
                          profession: profession,
                          lastMsg: room['lastMessage'] ?? '',
                          time: room['lastMessageTime'],
                          image: image,
                          unreadCount: unreadCount,
                          isVerified: isVerified,
                          isUrdu: isUrdu,
                          fontFamily: fontFamily,
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isUrdu, String fontFamily) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 55,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Icon(PhosphorIcons.chatCircleDots(PhosphorIconsStyle.fill), size: 48, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            isUrdu ? 'اپنے گاہکوں اور ماہرین سے رابطہ کریں' : 'Connect with customers & experts',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard({
    required BuildContext context,
    required String name,
    required String profession,
    required String lastMsg,
    required dynamic time,
    required String? image,
    required int unreadCount,
    required bool isVerified,
    required bool isUrdu,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    String timeStr = "";
    if (time != null) {
      final date = (time as dynamic).toDate();
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        timeStr = DateFormat('hh:mm a').format(date);
      } else {
        timeStr = DateFormat('dd/MM/yy').format(date);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: unreadCount > 0 ? AppTheme.themeColor.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
          width: unreadCount > 0 ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ProfileInfoWidget(
                  name: name,
                  phone: '', 
                  profileImage: image,
                  category: profession.isNotEmpty ? profession : (isUrdu ? 'صارف' : 'User'),
                  isVerticalCategory: true,
                  customSize: 60,
                  borderRadius: 12,
                  isVerified: isVerified,
                  suffix: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: ''),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(PhosphorIcons.chatText(), size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: unreadCount > 0 ? AppTheme.darkColor : Colors.grey[600],
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          fontFamily: isUrdu ? fontFamily : '',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
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
}
