import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/services/chat_service.dart';
import 'package:account_app/core/models/chat_message_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  bool _isFocused = false;
  DateTime? _lastTypingTime;

  @override
  void initState() {
    super.initState();
    _chatService.markAsRead(widget.otherUserId);
    _chatService.updateLastActive();

    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });

    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _setTyping(true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        _setTyping(false);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setTyping(bool typing) {
    if (!mounted) return;
    setState(() => _isTyping = typing);
    _chatService.setTypingStatus(widget.otherUserId, typing);
    if (typing) {
      _lastTypingTime = DateTime.now();
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_lastTypingTime != null &&
            DateTime.now().difference(_lastTypingTime!).inSeconds >= 3) {
          _setTyping(false);
        }
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _setTyping(false);
      _chatService.sendMessage(widget.otherUserId, _messageController.text);
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: CustomAppBar(
        centerTitle: false,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  (widget.otherUserImage != null && widget.otherUserImage!.isNotEmpty)
                      ? NetworkImage(widget.otherUserImage!)
                      : null,
              child: (widget.otherUserImage == null || widget.otherUserImage!.isEmpty)
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: fontFamily),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<bool>(
                    stream: _chatService.getOnlineStatus(widget.otherUserId),
                    builder: (context, snapshot) {
                      final bool isOnline = snapshot.data ?? false;
                      return Text(
                        isOnline
                            ? (isUrdu ? 'آن لائن' : 'Online')
                            : (isUrdu ? 'آف لائن' : 'Offline'),
                        style: TextStyle(
                            color: isOnline ? Colors.greenAccent : Colors.white60,
                            fontSize: 10,
                            fontFamily: fontFamily),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.otherUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Icon(PhosphorIcons.chatCircleDots(),
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        isUrdu ? 'گفتگو کا آغاز کریں' : 'Start a conversation',
                        style: TextStyle(color: Colors.grey, fontFamily: fontFamily),
                      ),
                      const Spacer(),
                      _buildQuickReplies(isUrdu, fontFamily),
                      const SizedBox(height: 20),
                    ],
                  );
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return StreamBuilder<bool>(
                        stream: _chatService.getTypingStatus(widget.otherUserId),
                        builder: (context, typingSnap) {
                          if (typingSnap.data == true) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                isUrdu
                                    ? '${widget.otherUserName} لکھ رہا ہے...'
                                    : '${widget.otherUserName} is typing...',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: fontFamily),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }

                    final msg = messages[index - 1];
                    final bool isMe = msg.senderId == _chatService.currentUserId;

                    // Date Separator Logic
                    bool showDate = false;
                    if (index == messages.length) {
                      showDate = true;
                    } else {
                      final nextMsg = messages[index];
                      if (msg.timestamp.day != nextMsg.timestamp.day) {
                        showDate = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDate)
                          _buildDateSeparator(msg.timestamp, isUrdu, fontFamily),
                        _buildMessageBubble(msg, isMe, fontFamily),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input Field
          _buildInputArea(isUrdu, fontFamily),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, String fontFamily) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          border: isMe
              ? Border.all(color: AppTheme.goldColor, width: 1.5)
              : Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.message,
              style: TextStyle(
                color: AppTheme.darkColor,
                fontSize: 15,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('hh:mm a').format(msg.timestamp),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.status == 'read' ? Icons.done_all : Icons.done,
                    size: 12,
                    color: msg.status == 'read' ? Colors.blueAccent : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isUrdu, String fontFamily) {
    String label;
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      label = isUrdu ? 'آج' : 'Today';
    } else if (date.day == now.subtract(const Duration(days: 1)).day) {
      label = isUrdu ? 'کل' : 'Yesterday';
    } else {
      label = DateFormat('MMM dd, yyyy').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
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

  Widget _buildQuickReplies(bool isUrdu, String fontFamily) {
    final replies = isUrdu
        ? ['کیا یہ دستیاب ہے؟', 'آخری قیمت کیا ہوگی؟', 'آپ کہاں سے ہیں؟']
        : [
            'Is this available?',
            'What is the final price?',
            'Where are you located?'
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: replies
            .map((text) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _messageController.text = text;
                      _sendMessage();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.themeColor.withOpacity(0.4)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: Colors.transparent,
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: isUrdu ? 16 : 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: fontFamily,
                        color: AppTheme.themeColor,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInputArea(bool isUrdu, String fontFamily) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
        top: 8,
      ),
      color: Colors.transparent,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: _isFocused ? AppTheme.goldColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: isUrdu ? 'پیغام لکھیں...' : 'Type a message...',
                  hintStyle: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 14,
                      color: Colors.grey[400]),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.themeColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
