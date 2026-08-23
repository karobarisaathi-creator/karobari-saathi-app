import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/job_bid_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/job_negotiation_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database/job_negotiation_service.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:intl/intl.dart';

class WorkNegotiationPopup extends StatefulWidget {
  final JobPost? job;
  final JobBid? bid;
  final ArtisanWorkOrder? workOrder;
  final bool isDirect;

  const WorkNegotiationPopup({
    super.key,
    this.job,
    this.bid,
    this.workOrder,
    this.isDirect = false,
  });

  @override
  State<WorkNegotiationPopup> createState() => _WorkNegotiationPopupState();
}

class _WorkNegotiationPopupState extends State<WorkNegotiationPopup> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final FocusNode _rateFocusNode = FocusNode();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final JobNegotiationService _negotiationService = JobNegotiationService();
  
  late Stream<List<NegotiationMessage>> _messagesStream;
  late Stream<DocumentSnapshot> _headerStream;
  
  bool _isFinalizing = false;
  bool _showRateInput = false;
  bool _isInputFocused = false;

  String get _jobId => widget.isDirect ? widget.workOrder!.id : widget.job!.id;
  String get _artisanId => widget.isDirect ? widget.workOrder!.artisanId : widget.bid!.artisanId;

  @override
  void initState() {
    super.initState();
    _rateFocusNode.addListener(_onFocusChange);
    _messageFocusNode.addListener(_onFocusChange);
    
    // Initialize streams once to prevent "refresh" on focus/keyboard popup
    _messagesStream = _negotiationService.getNegotiationMessages(_jobId, _artisanId, isDirect: widget.isDirect);
    
    if (widget.isDirect) {
      _headerStream = FirebaseFirestore.instance.collection('artisans').doc(_artisanId).collection('work_orders').doc(_jobId).snapshots();
    } else {
      _headerStream = FirebaseFirestore.instance.collection('jobs').doc(_jobId).collection('bids').doc(_artisanId).snapshots();
    }
  }

  void _onFocusChange() {
    setState(() {
      _isInputFocused = _rateFocusNode.hasFocus || _messageFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _rateController.dispose();
    _rateFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.removeListener(_onFocusChange);
    _rateFocusNode.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    final rateText = _rateController.text.trim();
    
    // اگر ریٹ دیا ہے تو میسج خالی ہو سکتا ہے، لیکن اگر میسج دیا ہے تو کم از کم 20 حروف ہوں
    if (text.isEmpty && rateText.isEmpty) return;
    if (text.isNotEmpty && text.length < 20) return;

    double? proposedAmount = double.tryParse(rateText);

    await _negotiationService.sendNegotiationMessage(
      jobId: _jobId,
      artisanId: _artisanId,
      message: text,
      proposedAmount: proposedAmount,
      isDirect: widget.isDirect,
    );

    _messageController.clear();
    _rateController.clear();
    setState(() => _showRateInput = false);
    _scrollToBottom();
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

  void _finalizeDeal(bool isUrdu) async {
    setState(() => _isFinalizing = true);
    try {
      if (widget.isDirect) {
        // Direct Request Finalization
        await FirebaseFirestore.instance
            .collection('artisans')
            .doc(_artisanId)
            .collection('work_orders')
            .doc(_jobId)
            .update({
          'customerAgreed': true,
          'customerAcceptedTerms': true,
          'agreedAt': FieldValue.serverTimestamp(),
          'status': 'confirmed',
        });
      } else {
        // Bid Finalization
        await JobService().selectBid(_jobId, _artisanId);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? '✅ ڈیل فائنل ہو گئی!' : '✅ Deal finalized!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error finalizing deal in popup: $e");
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: AppTheme.darkColor,
            elevation: 0,
            centerTitle: true,
            title: Text(
              isUrdu ? 'کام اور ریٹ فائنل کریں' : 'Finalize Work & Rate',
              style: TextStyle(fontFamily: fontFamily, fontSize: 14),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8, left: 8),
                child: AppButton(
                  text: isUrdu ? 'فائنل کریں' : 'Finalize',
                  color: Colors.green,
                  isLoading: _isFinalizing,
                  size: AppButtonSize.mini,
                  onPressed: () => _finalizeDeal(isUrdu),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Summary Header
              _buildLiveBidHeader(isUrdu, fontFamily),

              // 2. Chat Messages
              Expanded(
                child: StreamBuilder<List<NegotiationMessage>>(
                  stream: _messagesStream, // Use initialized stream
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return _buildInitialGuide(isUrdu, fontFamily);
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final bool isMe = msg.senderId == _negotiationService.currentUserId;
                        return _buildNegotiationBubble(msg, isMe, isUrdu, fontFamily);
                      },
                    );
                  },
                ),
              ),

              // 3. Specialized Bottom Action Area
              _buildInputArea(isUrdu, fontFamily),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBidHeader(bool isUrdu, String fontFamily) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _headerStream, // Use initialized stream
      builder: (context, snapshot) {
        double currentAmount = widget.isDirect ? (widget.workOrder?.amount ?? 0) : widget.bid!.amount;
        if (snapshot.hasData && snapshot.data!.exists) {
          currentAmount = (snapshot.data!.data() as Map<String, dynamic>)['amount']?.toDouble() ?? currentAmount;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isUrdu ? 'موجودہ طے شدہ ریٹ:' : 'Current Agreed Rate:',
                    style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                  Text(
                    'Rs. ${currentAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 20),
                  ),
                ],
              ),
              if (widget.isDirect && widget.workOrder != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.workOrder!.workDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: fontFamily),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNegotiationBubble(NegotiationMessage msg, bool isMe, bool isUrdu, String fontFamily) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.themeColor : Colors.grey[100],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.proposedAmount != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.tag(), size: 14, color: isMe ? Colors.white : Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'New Rate: Rs. ${msg.proposedAmount!.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (msg.message.isNotEmpty)
                Text(
                  msg.message,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontFamily: fontFamily,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
          child: Text(
            DateFormat('hh:mm a').format(msg.timestamp),
            style: TextStyle(color: Colors.grey[500], fontSize: 9),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🆕 Unified Input Container with Perfect Centering & Clean Corners
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            clipBehavior: Clip.antiAlias, // Ensures no children overlap corners
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isInputFocused ? AppTheme.themeColor : Colors.grey[200]!,
                width: _isInputFocused ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    // 1. Rate Input (Top)
                    TextField(
                      controller: _rateController,
                      focusNode: _rateFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      decoration: InputDecoration(
                        hintText: isUrdu ? 'ریٹ (روپے میں)' : 'Rate (in Rs.)',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey[400],
                          fontFamily: fontFamily,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 6), // Reduced to move divider up
                        prefixIcon: Icon(PhosphorIcons.tag(), size: 18, color: Colors.green),
                      ),
                    ),
                    // 🆕 Middle Centered Line
                    Container(height: 1, color: const Color(0xFFE5E7EB)),
                    // 2. Message Input (Bottom)
                    TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: TextStyle(fontFamily: fontFamily, fontSize: 14),
                      maxLines: 2,
                      minLines: 1,
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: isUrdu ? 'تفصیل یا پیغام...' : 'Write details or message...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500], fontFamily: fontFamily),
                        errorText: _messageController.text.isNotEmpty && _messageController.text.length < 20
                            ? (isUrdu ? 'کم از کم 20 حروف لکھیں' : 'Min 20 characters required')
                            : null,
                        counterText: '${_messageController.text.length}/200',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 45, 12),
                      ),
                    ),
                  ],
                ),
                // 3. Send Arrow in Corner
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: (_messageController.text.isNotEmpty && _messageController.text.length < 20) 
                        ? null 
                        : _sendMessage,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (_messageController.text.isNotEmpty && _messageController.text.length < 20)
                            ? Colors.grey
                            : AppTheme.themeColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward, 
                        color: Colors.white, 
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialGuide(bool isUrdu, String fontFamily) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.handshake(), size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isUrdu 
                ? 'یہاں آپ کاریگر سے ریٹ اور کام کے بارے میں بات کر سکتے ہیں۔' 
                : 'Discuss rate and work details here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontFamily: fontFamily),
            ),
          ],
        ),
      ),
    );
  }
}
