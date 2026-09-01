import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/job_negotiation_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/database/job_negotiation_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/logging_service.dart';
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
  final _logger = LoggingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final JobNegotiationService _negotiationService = JobNegotiationService();
  
  NotificationService? _notificationService;
  Stream<List<NegotiationMessage>>? _messagesStream;
  StreamSubscription<List<NegotiationMessage>>? _messageSubscription;
  
  bool _isSending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _initializeStream();
    _messageController.addListener(_onTextChanged);
  }

  void _initializeStream() {
    _messagesStream = _negotiationService.getNegotiationMessages(
      widget.workOrder.id,
      widget.workOrder.artisanId,
      isDirect: true,
    );
    
    _messageSubscription = _messagesStream?.listen(
      _onMessagesReceived,
      onError: (error) {
        _logger.error("Messages stream error", error);
      },
    );
  }

  void _onMessagesReceived(List<NegotiationMessage> messages) {
    if (!mounted) return;
    
    final hasUnread = messages.any((m) =>
        !m.isRead && m.senderId != _negotiationService.currentUserId);
    
    if (hasUnread) {
      _negotiationService.markConversationAsRead(
        jobId: widget.workOrder.id,
        artisanId: widget.workOrder.artisanId,
        isDirect: true,
      );
    }
  }

  void _onTextChanged() {
    final newHasText = _messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText) {
      setState(() => _hasText = newHasText);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationService = Provider.of<NotificationService>(context, listen: false);
    _notificationService?.setOpenNegotiation(widget.workOrder.id);
    _notificationService?.markNegotiationAsRead(widget.workOrder.id);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _notificationService?.setOpenNegotiation(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
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
    } catch (e, stack) {
      _logger.error("Send message error", e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LanguageService>(context, listen: false).isUrdu
                  ? 'پیغام بھیجنے میں ناکامی'
                  : 'Unable to send message',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
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

    return Column(
      children: [
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: StreamBuilder<List<NegotiationMessage>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    isUrdu ? 'پیغامات لوڈ کرنے میں ناکامی' : 'Failed to load messages',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return _buildInitialGuide(isUrdu, fontFamily);
              }

              return Column(
                children: [
                  _buildStatusBanner(isUrdu, fontFamily),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final bool isMe =
                            msg.senderId == _negotiationService.currentUserId;
                        final bool showDateSeparator = _shouldShowDateSeparator(messages, index);

                        return Column(
                          children: [
                            if (showDateSeparator)
                              _buildDateSeparator(msg.timestamp, isUrdu, fontFamily),
                            _buildModernBubble(msg, isMe, isUrdu, fontFamily),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _buildInput(isUrdu, fontFamily),
      ],
    );
  }

  bool _shouldShowDateSeparator(List<NegotiationMessage> messages, int index) {
    if (index == 0) return true;
    final prevMsg = messages[index - 1];
    final currMsg = messages[index];
    return prevMsg.timestamp.day != currMsg.timestamp.day ||
        prevMsg.timestamp.month != currMsg.timestamp.month ||
        prevMsg.timestamp.year != currMsg.timestamp.year;
  }

  Widget _buildDateSeparator(DateTime date, bool isUrdu, String fontFamily) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);
    
    String label = DateFormat('dd MMM, yyyy').format(date);
    if (msgDate == today) {
      label = isUrdu ? 'آج' : 'Today';
    } else if (msgDate == yesterday) {
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
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildModernBubble(
    NegotiationMessage msg,
    bool isMe,
    bool isUrdu,
    String fontFamily,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showDeleteMessageDialog(msg, isUrdu, fontFamily),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? AppTheme.themeColor : Colors.white,
                  border: isMe ? null : Border.all(color: Colors.grey[400]!),
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.isRead
                            ? PhosphorIcons.envelopeOpen()
                            : PhosphorIcons.envelope(),
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
    NegotiationMessage msg,
    bool isUrdu,
    String fontFamily,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isUrdu ? 'میسج حذف کریں؟' : 'Delete Message?',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isUrdu ? 'نہیں' : 'No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _negotiationService.deleteNegotiationMessage(
                  jobId: widget.workOrder.id,
                  artisanId: widget.workOrder.artisanId,
                  messageId: msg.id,
                  isDirect: true,
                );
              } catch (e, stack) {
                _logger.error("Delete message error", e, stack);
              }
            },
            child: Text(
              isUrdu ? 'ہاں' : 'Yes',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: TextField(
        controller: _messageController,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          color: AppTheme.darkColor,
        ),
        maxLines: 4,
        minLines: 1,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppTheme.backgroundColor,
          hintText: isUrdu ? 'اپنا پیغام لکھیں...' : 'Write your message...',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontFamily: fontFamily,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(4.0),
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

  Widget _buildStatusBanner(bool isUrdu, String fontFamily) {
    final status = widget.workOrder.status;
    
    // اگر کام شروع ہو چکا ہے تو دونوں کو اسٹیٹس دکھائیں
    if (status != 'negotiating') {
      String statusText = isUrdu ? 'کام شروع ہو چکا ہے' : 'Work In Progress';
      if (status == 'completed') statusText = isUrdu ? 'کام مکمل ہو گیا' : 'Work Completed';
      
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        color: Colors.green.withValues(alpha: 0.1),
        child: Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.green[700],
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
          ),
        ),
      );
    }

    // اگر نیگوششن جاری ہے
    if (widget.isArtisanMode) {
      // کاریگر کے لیے صرف پیغام
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        color: AppTheme.themeColor.withValues(alpha: 0.05),
        child: Text(
          isUrdu 
            ? 'گاہک کے فیصلے کا انتظار ہے...' 
            : 'Waiting for customer to start work...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.themeColor,
            fontStyle: FontStyle.italic,
            fontSize: 12,
            fontFamily: fontFamily,
          ),
        ),
      );
    } else {
      // گاہک کے لیے بٹن
      return _buildStartWorkPrompt(isUrdu, fontFamily);
    }
  }

  Widget _buildStartWorkPrompt(bool isUrdu, String fontFamily) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isUrdu 
                      ? 'بات چیت مکمل ہو گئی؟ کام شروع کرنے کے لیے بٹن دبائیں۔' 
                      : 'Negotiation complete? Click the button to hire.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.themeColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _showStartWorkConfirmation(isUrdu, fontFamily),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 34),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isUrdu ? 'ہائر کریں' : 'Hire Now',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  void _showStartWorkConfirmation(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUrdu ? 'اس کاریگر کو ہائر کریں؟' : 'Hire this Artisan?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی اس کاریگر کو ہائر کرنا چاہتے ہیں؟\n\nاس کے بعد آپ کی جاب پوسٹ براؤز اسکرین سے ختم ہو جائے گی اور کام شروع ہو جائے گا۔'
              : 'Are you sure you want to hire this artisan?\n\nYour job post will be removed from the browse screen and work will officially begin.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'کینسل' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _startWorkOrder(isUrdu);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isUrdu ? 'جی ہاں، ہائر کریں' : 'Yes, Hire Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkOrder(bool isUrdu) async {
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.updateArtisanWorkStatus(
        widget.workOrder.artisanId,
        widget.workOrder.id,
        'confirmed',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'کام شروع کر دیا گیا ہے!' : 'Work order started!'),
            backgroundColor: AppTheme.themeColor,
          ),
        );
      }
    } catch (e) {
      _logger.error("Start work from chat error", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'کام شروع کرنے میں خرابی آئی' : 'Error starting work'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              child: Icon(
                PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
                size: 48,
                color: AppTheme.themeColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isUrdu ? 'بات چیت کا آغاز کریں' : 'Start the Conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
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
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
