// lib/features/business_chat/screens/business_chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/database/business_chat_service.dart';
import 'package:account_app/core/models/business_chat_model.dart';
import 'package:account_app/core/widgets/business_chat_card.dart';
import 'business_chat_screen.dart';

class BusinessChatListScreen extends StatefulWidget {
  const BusinessChatListScreen({super.key});

  @override
  State<BusinessChatListScreen> createState() =>
      _BusinessChatListScreenState();
}

class _BusinessChatListScreenState extends State<BusinessChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final BusinessChatService _chatService = BusinessChatService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? '💼 کاروباری رابطے' : '💼 Business Connect',
        showBackButton: false,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.magnifyingGlass(), color: Colors.white),
            onPressed: () {
              // سرچ فوکس کریں
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // سرچ بار
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchSortBar(
              controller: _searchController,
              hintText: isUrdu ? 'رابطہ تلاش کریں...' : 'Search contacts...',
              padding: EdgeInsets.zero,
              onSearchChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // چیٹ لسٹ
          Expanded(
            child: StreamBuilder<List<BusinessChatRoom>>(
              stream: _chatService.getChatRooms(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.themeColor));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isUrdu, fontFamily);
                }

                var chatRooms = snapshot.data!;

                // سرچ فلٹر
                if (_searchQuery.isNotEmpty) {
                  // یہاں فلٹرنگ کا کوڈ
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: chatRooms.length,
                  itemBuilder: (context, index) {
                    final room = chatRooms[index];
                    final otherUserId = room.participants.firstWhere(
                            (id) => id != _chatService.currentUserId,
                        orElse: () => '');

                    return FutureBuilder<Map<String, String>?>(
                      future: Provider.of<DatabaseService>(context, listen: false)
                          .findPublicProfileByUid(otherUserId),
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data;
                        final String name =
                            profile?['name'] ?? (isUrdu ? 'صارف' : 'User');
                        final String? image = profile?['photoUrl'];
                        final String profession = profile?['profession'] ?? '';
                        final bool isVerified =
                            profile?['isVerified'] == 'true';

                        return BusinessChatCard(
                          name: name,
                          profession: profession,
                          lastMessage: room.lastMessage ?? '',
                          timestamp: room.lastMessageTime,
                          image: image,
                          unreadCount: room.unreadCount,
                          isVerified: isVerified,
                          isUrdu: isUrdu,
                          fontFamily: fontFamily,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BusinessChatScreen(
                                  otherUserId: otherUserId,
                                  otherUserName: name,
                                  otherUserImage: image,
                                ),
                              ),
                            );
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

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.chatTeardropDots(),
              size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی کاروباری رابطہ نہیں' : 'No business contacts',
            style: TextStyle(
                color: Colors.grey, fontSize: 16, fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }
}