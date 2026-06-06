import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:account_app/core/theme/app_theme.dart';

class VoiceRecorder extends StatefulWidget {
  final void Function(String path) onRecordingComplete;

  const VoiceRecorder({super.key, required this.onRecordingComplete});

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _isRecording = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return _buildRecordingUI();
    } else {
      return _buildIdleUI();
    }
  }

  Widget _buildIdleUI() {
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        color: Colors.transparent, 
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, color: AppTheme.themeColor, size: 20), // Reduced from 24
            const SizedBox(height: 1), // Reduced from 2
            const Text("Tap to Record", style: TextStyle(color: Colors.grey, fontSize: 9)), // Reduced from 10
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return GestureDetector(
      onTap: _stopAndAttach,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        alignment: Alignment.center,
        child: Row( // Changed Column to Row to save vertical space
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stop_circle, color: AppTheme.expenseColor, size: 16), // Smaller icon
            const SizedBox(width: 4),
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.expenseColor),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig(encoder: AudioEncoder.aacLc);
        await _audioRecorder.start(config, path: filePath);

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _startTimer();
      }
    } catch (e) {
      _showError('Recording failed: $e');
    }
  }

  Future<void> _stopAndAttach() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();
      
      if (path != null) {
        // Save to permanent location
        final directory = await getApplicationDocumentsDirectory();
        final voiceNotesDir = Directory('${directory.path}/voice_notes');
        if (!await voiceNotesDir.exists()) {
          await voiceNotesDir.create(recursive: true);
        }

        final fileName = path.split('/').last;
        final savedPath = '${voiceNotesDir.path}/$fileName';

        await File(path).copy(savedPath);
        
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
          
          widget.onRecordingComplete(savedPath);
        }
      }
    } catch (e) {
      _showError('Failed to save: $e');
    }
  }

  void _startTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      } else {
        timer.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
