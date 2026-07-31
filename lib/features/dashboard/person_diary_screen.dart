import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import '../../core/services/ai_visual_service.dart';
import '../../core/services/language_service.dart';
import '../../core/models/work_log_model.dart';
import '../../core/models/account_model.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../accounts/add_transaction_screen.dart';

class PersonDiaryScreen extends StatefulWidget {
  final String accountId;
  final String accountName;

  const PersonDiaryScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<PersonDiaryScreen> createState() => _PersonDiaryScreenState();
}

class _PersonDiaryScreenState extends State<PersonDiaryScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceText = "";
  bool _isAnalyzing = false;
  Map<String, dynamic>? _previewData;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  // --- Logic ---

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
           if (mounted && _isListening) _stopListening();
        }
      },
      onError: (val) => debugPrint('STT Error: $val'),
    );

    if (available) {
      HapticFeedback.mediumImpact();
      final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
      setState(() {
        _isListening = true;
        _voiceText = "";
        _previewData = null;
      });
      _pulseController.repeat(reverse: true);
      _speech.listen(
        onResult: (val) => setState(() => _voiceText = val.recognizedWords),
        localeId: isUrdu ? 'ur_PK' : 'en_US',
      );
    }
  }

  void _stopListening() async {
    if (!_isListening) return;
    setState(() {
      _isListening = false;
      _pulseController.stop();
    });
    await _speech.stop();
    if (_voiceText.isNotEmpty) _analyzeText(_voiceText);
  }

  Future<void> _analyzeText(String text) async {
    setState(() => _isAnalyzing = true);
    final aiService = AIVisualService();
    final result = await aiService.parseWorkLog(text);
    
    if (mounted) {
      if (result.isSuccess && result.data != null) {
        setState(() {
          _previewData = result.data;
          _isAnalyzing = false;
        });
      } else {
        // Smart Fallback
        double amount = 0;
        final match = RegExp(r'(\d+)').firstMatch(text);
        if (match != null) amount = double.tryParse(match.group(1)!) ?? 0;
        String summary = text.replaceAll(RegExp(r'\d+'), '').replaceAll('روپے', '').trim();
        
        setState(() {
          _previewData = {
            'work_summary': summary.isEmpty ? text : summary,
            'total': amount.toString(),
            'quantity': '1.0',
            'multiplier': '1',
            'rate': amount.toString(),
            'unit': 'work'
          };
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _saveEntry() async {
    if (_previewData == null) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    final log = WorkLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: widget.accountId,
      accountName: widget.accountName,
      description: _voiceText.isNotEmpty ? _voiceText : (_previewData!['work_summary'] ?? ''),
      quantity: double.tryParse(_previewData!['quantity']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '1') ?? 1.0,
      multiplier: int.tryParse(_previewData!['multiplier']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '1') ?? 1,
      rate: double.tryParse(_previewData!['rate']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0,
      totalAmount: double.tryParse(_previewData!['total']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0,
      unitName: _previewData!['unit'] ?? 'unit',
      date: DateTime.now(),
    );

    await dbService.addWorkLog(log);
    HapticFeedback.heavyImpact();
    setState(() {
      _previewData = null;
      _voiceText = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final dbService = Provider.of<DatabaseService>(context);
    final logs = dbService.getWorkLogs().where((l) => l.accountId == widget.accountId).toList();
    final account = dbService.getAccount(widget.accountId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: isUrdu ? '${widget.accountName} کا رجسٹر' : '${widget.accountName}\'s Log'),
      body: Stack(
        children: [
          logs.isEmpty
              ? _buildEmptyState(isUrdu, fontFamily)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => _buildNarrativeRow(logs[index], isUrdu, fontFamily, account),
                ),
          
          // Floating Recording UI
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomEntryUI(isUrdu, fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrativeRow(WorkLog log, bool isUrdu, String fontFamily, Account? account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full width narrative text first
          SizedBox(
            width: double.infinity,
            child: _buildHighlightedText(log.description, fontFamily),
          ),
          
          if (log.quantity > 1 || log.multiplier > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "${log.quantity} x ${log.multiplier} @ ${log.rate.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),

          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade50),
          const SizedBox(height: 12),

          // Bottom Row: Date and Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(PhosphorIcons.calendar(), size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(log.date),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              _buildActionButtons(log, account),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String fontFamily) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'(\d+)');
    int lastIndex = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(color: AppTheme.incomeColor, fontWeight: FontWeight.w900, fontSize: 22),
      ));
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 18, fontFamily: fontFamily, color: AppTheme.darkColor, height: 1.6),
        children: spans,
      ),
    );
  }

  Widget _buildActionButtons(WorkLog log, Account? account) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add to Khata Button
        IconButton(
          icon: Icon(PhosphorIcons.wallet(), size: 18, color: AppTheme.themeColor),
          onPressed: () {
            if (account != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(
                    account: account,
                    initialDescription: log.description,
                    initialAmount: log.totalAmount,
                  ),
                ),
              );
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
          onPressed: () => _showEditDialog(log),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
          onPressed: () => _showDeleteConfirm(log.id),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This will remove this record from the diary.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<DatabaseService>(context, listen: false).deleteWorkLog(id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(WorkLog log) {
    final controller = TextEditingController(text: log.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Entry'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final updatedLog = WorkLog(
                id: log.id,
                accountId: log.accountId,
                accountName: log.accountName,
                description: controller.text,
                quantity: log.quantity,
                multiplier: log.multiplier,
                rate: log.rate,
                totalAmount: log.totalAmount,
                unitName: log.unitName,
                date: log.date,
              );
              // Note: We need a method to update work log in db service
              Provider.of<DatabaseService>(context, listen: false).addWorkLog(updatedLog, syncToKhata: false);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomEntryUI(bool isUrdu, String fontFamily) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isListening || _voiceText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
              child: Text(
                _voiceText.isEmpty ? (isUrdu ? "سن رہا ہوں..." : "Listening...") : _voiceText,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: isUrdu ? 'NooriNastaleeq' : null),
                textAlign: TextAlign.center,
              ),
            ),
          
          if (_isAnalyzing)
            const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)),

          if (_previewData != null)
            _buildActionPreview(isUrdu, fontFamily),

          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_previewData != null)
                IconButton(
                  onPressed: () => setState(() { _previewData = null; _voiceText = ""; }),
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              
              const SizedBox(width: 20),

              GestureDetector(
                onLongPressStart: (_) => _startListening(),
                onLongPressEnd: (_) => _stopListening(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isListening)
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: 2.0).animate(_pulseController),
                        child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), shape: BoxShape.circle)),
                      ),
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: _isListening ? Colors.red : AppTheme.themeColor,
                      child: Icon(_isListening ? PhosphorIcons.microphone(PhosphorIconsStyle.fill) : PhosphorIcons.microphone(), color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              if (_previewData != null)
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: IconButton(onPressed: _saveEntry, icon: const Icon(Icons.check, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu ? 'ریکارڈ کرنے کے لیے مائیک دبا کر رکھیں' : 'Hold mic to record work',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPreview(bool isUrdu, String fontFamily) {
    final double amount = double.tryParse(_previewData!['total']?.toString() ?? '0') ?? 0.0;
    final bool hasAmount = amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.incomeColor.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: AppTheme.incomeColor.withValues(alpha: 0.2))
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _previewData!['work_summary'] ?? '', 
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: fontFamily)
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Rs. ${amount.toStringAsFixed(0)}", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: hasAmount ? AppTheme.incomeColor : Colors.grey)
                  ),
                  if (!hasAmount)
                    Text(
                      isUrdu ? '(رقم درج کریں)' : '(No price)',
                      style: const TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              "${_previewData!['quantity']} x ${_previewData!['multiplier']} @ ${_previewData!['rate']}",
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
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
          Icon(PhosphorIcons.article(), size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(isUrdu ? 'اس رجسٹر میں کوئی تحریر نہیں ہے' : 'No entries in this register', style: TextStyle(color: Colors.grey, fontFamily: fontFamily)),
        ],
      ),
    );
  }
}
