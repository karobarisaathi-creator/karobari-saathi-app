// lib/features/business_chat/screens/business_chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/database/business_chat_service.dart';
import 'package:account_app/core/models/business_chat_model.dart';
import 'package:account_app/core/widgets/business_chat_bubble.dart';
import 'package:account_app/core/widgets/business_quick_replies.dart';

class BusinessChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const BusinessChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<BusinessChatScreen> createState() => _BusinessChatScreenState();
}

class _BusinessChatScreenState extends State<BusinessChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final BusinessChatService _chatService = BusinessChatService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;
  Map<String, String>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _chatService.markAsRead(widget.otherUserId);

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadProfile() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final profile = await dbService.findPublicProfileByUid(widget.otherUserId);
    if (mounted) {
      setState(() => _profile = profile);
    }
  }

  Future<void> _sendMessage({String? fileUrl, String? fileName, String? fileSize}) async {
    final message = _messageController.text.trim();
    if (message.isEmpty && fileUrl == null) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        receiverId: widget.otherUserId,
        message: message,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      final file = File(image.path);
      try {
        final uploadResult = await _chatService.uploadFile(file);
        await _sendMessage(
          fileUrl: uploadResult['url'],
          fileName: uploadResult['name'],
          fileSize: uploadResult['size'],
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File upload failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final bool isVerified = _profile?['isVerified'] == 'true';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        centerTitle: false,
        title: ProfileInfoWidget(
          name: widget.otherUserName,
          phone: '',
          profileImage: widget.otherUserImage ?? _profile?['photoUrl'],
          category: isUrdu ? 'آن لائن' : 'Online',
          isVerticalCategory: true,
          customSize: 38,
          borderRadius: 10,
          textColor: Colors.white,
          categoryColor: Colors.greenAccent,
          isVerified: isVerified,
        ),
      ),
      body: Column(
        children: [
          // میسج لسٹ
          Expanded(
            child: StreamBuilder<List<BusinessChatMessage>>(
              stream: _chatService.getMessages(widget.otherUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isUrdu, fontFamily);
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _chatService.currentUserId;

                    bool showDate = index == messages.length - 1 ||
                        msg.timestamp.day != messages[index + 1].timestamp.day;

                    return Column(
                      children: [
                        if (showDate)
                          _buildDateSeparator(msg.timestamp, isUrdu, fontFamily),
                        BusinessChatBubble(
                          message: msg,
                          isMe: isMe,
                          isUrdu: isUrdu,
                          fontFamily: fontFamily,
                          onImageTap: (url) {
                            // تصویر کو بڑا دکھائیں
                          },
                          onOrderTap: (orderId) {
                            // آرڈر کی تفصیل کھولیں
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // کوئیک ریپلائز
          BusinessQuickReplies(
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            onReplyTap: (reply) {
              _messageController.text = reply;
              _sendMessage();
            },
          ),

          // انپٹ ایریا
          _buildInputArea(isUrdu, fontFamily),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isUrdu, String fontFamily) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        left: 12,
        right: 12,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // اٹیچمنٹ بٹن
          IconButton(
            onPressed: _pickImage,
            icon: Icon(PhosphorIcons.paperclip(),
                color: AppTheme.themeColor, size: 24),
          ),

          // ٹیکسٹ فیلڈ
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: isUrdu ? 'پیغام لکھیں...' : 'Type a message...',
                  hintStyle: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 14,
                      color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // بھیجیں بٹن
          if (_messageController.text.isNotEmpty)
            IconButton(
              onPressed: _isSending ? null : () => _sendMessage(),
              icon: Icon(
                PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                color: _isSending ? Colors.grey : AppTheme.themeColor,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isUrdu, String fontFamily) {
    String label;
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      label = isUrdu ? 'آج' : 'Today';
    } else if (date.day == now.subtract(const Duration(days: 1)).day) {
      label = isUrdu ? 'کل' : 'Yesterday';
    } else {
      label = DateFormat('MMM dd, yyyy').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily)),
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.chatCircleDots(),
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کاروباری گفتگو شروع کریں' : 'Start a business conversation',
            style: TextStyle(
                color: Colors.grey, fontSize: 16, fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }
}