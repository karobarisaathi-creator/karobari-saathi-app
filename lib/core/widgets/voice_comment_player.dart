import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:account_app/core/theme/app_theme.dart';

class VoiceCommentPlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final VoidCallback? onDelete;

  const VoiceCommentPlayer({
    super.key,
    required this.audioUrl,
    this.isMe = false,
    this.onDelete,
  });

  @override
  State<VoiceCommentPlayer> createState() => _VoiceCommentPlayerState();
}

class _VoiceCommentPlayerState extends State<VoiceCommentPlayer> {
  late final AudioPlayer _player;
  Duration _totalDuration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      Source source;
      if (widget.audioUrl.startsWith('http')) {
        source = UrlSource(widget.audioUrl);
      } else {
        source = DeviceFileSource(widget.audioUrl);
      }

      await _player.setSource(source);

      _player.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _totalDuration = duration;
            _isLoading = false;
          });
        }
      });

      _player.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _player.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _isPlaying = false;
          });
        }
      });

      // Duration can sometimes be null or zero initially
      final duration = await _player.getDuration();
      if (duration != null && duration > Duration.zero) {
        setState(() {
          _totalDuration = duration;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading audio: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Duration get _remainingTime {
    final remaining = _totalDuration - _position;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get _displayTime {
    if (_totalDuration == Duration.zero) return "00:00";
    return _formatDuration(_remainingTime);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.incomeColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(child: SizedBox(height: 2)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 14, color: Colors.red),
            SizedBox(width: 6),
            Text('Error loading audio', style: TextStyle(fontSize: 11, color: Colors.red)),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr, // سمت ہمیشہ بائیں سے دائیں (LTR) رہے گی
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.incomeColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (_isPlaying) {
                  _player.pause();
                } else {
                  _player.resume();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: _totalDuration.inMilliseconds.toDouble() > 0 
                       ? _totalDuration.inMilliseconds.toDouble() 
                       : 1.0,
                  onChanged: (value) {
                    _player.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: Text(
                _displayTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.onDelete != null)
              GestureDetector(
                onTap: widget.onDelete,
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
