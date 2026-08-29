import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/job_negotiation_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/database/job_negotiation_service.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:intl/intl.dart';

class NegotiationView extends StatefulWidget {
  final ArtisanWorkOrder workOrder;
  final bool isArtisanMode;

  const NegotiationView({
    super.key,
    required this.workOrder,
    required this.isArtisanMode,
  });

  @override
  State<NegotiationView> createState() => _NegotiationViewState();
}

class _NegotiationViewState extends State<NegotiationView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final JobNegotiationService _negotiationService = JobNegotiationService();
  late NotificationService _notificationService;
  bool _isSending = false;
  bool _hasText = false;
  late Stream<List<NegotiationMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = _negotiationService.getNegotiationMessages(
        widget.workOrder.id, widget.workOrder.artisanId,
        isDirect: true);
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _messageController.text.trim().isNotEmpty;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationService = Provider.of<NotificationService>(context, listen: false);
    _notificationService.setOpenNegotiation(widget.workOrder.id);
    _notificationService.markNegotiationAsRead(widget.workOrder.id);
  }

  @override
  void dispose() {
    _notificationService.setOpenNegotiation(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();

    if (_isSending || text.isEmpty || text.length < 5) return;

    setState(() => _isSending = true);

    try {
      await _negotiationService.sendNegotiationMessage(
        jobId: widget.workOrder.id,
        artisanId: widget.workOrder.artisanId,
        message: text,
        proposedAmount: null,
        isDirect: true,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // 1. Chat Messages
          Expanded(
            child: StreamBuilder<List<NegotiationMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty)
                  return _buildInitialGuide(isUrdu, fontFamily);

                // Mark as read if there are unread messages from others
                final hasUnread = messages.any((m) => !m.isRead && m.senderId != _negotiationService.currentUserId);
                if (hasUnread) {
                  _negotiationService.markConversationAsRead(
                    jobId: widget.workOrder.id,
                    artisanId: widget.workOrder.artisanId,
                    isDirect: true,
                  );
                }

                // Auto-scroll logic
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe =
                        msg.senderId == _negotiationService.currentUserId;

                    // Logic for Date Separators
                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMsg = messages[index - 1];
                      if (msg.timestamp.day != prevMsg.timestamp.day) {
                        showDateSeparator = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateSeparator)
                          _buildDateSeparator(
                              msg.timestamp, isUrdu, fontFamily),
                        _buildModernBubble(msg, isMe, isUrdu, fontFamily),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // 2. Input Area
          _buildInput(isUrdu, fontFamily),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isUrdu, String fontFamily) {
    final now = DateTime.now();
    String label = DateFormat('dd MMM, yyyy').format(date);

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      label = isUrdu ? 'آج' : 'Today';
    } else if (date.day == now.subtract(const Duration(days: 1)).day) {
      label = isUrdu ? 'کل' : 'Yesterday';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily),
      ),
    );
  }

  Widget _buildModernBubble(
      NegotiationMessage msg, bool isMe, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showDeleteMessageDialog(msg, isUrdu, fontFamily),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? AppTheme.themeColor : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.message,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppTheme.darkColor,
                    fontSize: 15,
                    fontFamily: fontFamily,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(msg.timestamp),
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead ? PhosphorIcons.envelopeOpen() : PhosphorIcons.envelope(),
                      size: 12,
                      color: msg.isRead ? Colors.blue : Colors.grey[400],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showDeleteMessageDialog(
      NegotiationMessage msg, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'میسج حذف کریں؟' : 'Delete Message?',
            style: TextStyle(fontFamily: fontFamily)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'نہیں' : 'No')),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _negotiationService.deleteNegotiationMessage(
                    jobId: widget.workOrder.id,
                    artisanId: widget.workOrder.artisanId,
                    messageId: msg.id,
                    isDirect: true,
                  );
                } catch (e) {
                  debugPrint('Error deleting message: $e');
                }
              },
              child: Text(isUrdu ? 'ہاں' : 'Yes',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildInput(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _hasText ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: TextField(
        controller: _messageController,
        style: TextStyle(
            fontFamily: fontFamily, fontSize: 15, color: AppTheme.darkColor),
        maxLines: 4,
        minLines: 1,
        decoration: InputDecoration(
          hintText: isUrdu ? 'اپنا پیغام لکھیں...' : 'Write your message...',
          hintStyle: TextStyle(
              color: Colors.grey[500], fontSize: 14, fontFamily: fontFamily),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: InputBorder.none,
          suffixIcon: Padding(
            padding: const EdgeInsets.all(6.0),
            child: GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _hasText ? AppTheme.themeColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        color: _hasText ? Colors.white : AppTheme.themeColor,
                        size: 24,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialGuide(bool isUrdu, String fontFamily) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
                  size: 48, color: AppTheme.themeColor),
            ),
            const SizedBox(height: 24),
            Text(
              isUrdu ? 'بات چیت کا آغاز کریں' : 'Start the Conversation',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily),
            ),
            const SizedBox(height: 8),
            Text(
              isUrdu
                  ? 'کام کی تفصیلات اور دیگر معلومات کے لیے یہاں میسج کریں۔'
                  : 'Send a message to discuss work details and other information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontFamily: fontFamily,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
