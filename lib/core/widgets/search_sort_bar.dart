import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';

class SearchSortBar extends StatefulWidget {
  final Function(String)? onSearchChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onSortToggled;
  final bool isAscending;
  final String? hintText;
  final TextEditingController? controller;
  final EdgeInsets? padding;
  final Widget? trailing;
  final bool showVoiceSearch;
  final bool showScanner;
  final VoidCallback? onScannerTap;
  final VoidCallback? onVoicePressed;
  final VoidCallback? onVoiceReleased;

  const SearchSortBar({
    Key? key,
    this.onSearchChanged,
    this.onSubmitted,
    this.onSortToggled,
    this.isAscending = true,
    this.hintText,
    this.controller,
    this.padding,
    this.trailing,
    this.showVoiceSearch = false,
    this.showScanner = false,
    this.onScannerTap,
    this.onVoicePressed,
    this.onVoiceReleased,
  }) : super(key: key);

  @override
  State<SearchSortBar> createState() => _SearchSortBarState();
}

class _SearchSortBarState extends State<SearchSortBar> with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pulseController.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  void _startListening() async {
    if (_isListening) return;

    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
           if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (val) {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (available) {
      HapticFeedback.mediumImpact();
      _pulseController.repeat(reverse: true);
      setState(() => _isListening = true);
      final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
      _speech.listen(
        onResult: (val) {
          if (widget.controller != null) {
            widget.controller!.text = val.recognizedWords;
          }
          if (widget.onSearchChanged != null) {
            widget.onSearchChanged!(val.recognizedWords);
          }
          if (val.finalResult) {
            _stopListening();
            if (widget.onSubmitted != null) {
              widget.onSubmitted!(val.recognizedWords);
            }
          }
        },
        localeId: isUrdu ? 'ur_PK' : 'en_US',
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      _pulseController.stop();
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    
    final activeColor = AppTheme.themeColor;
    final inactiveColor = AppTheme.darkColor;

    return Padding(
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Full Rounded Search Box
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 40,
              clipBehavior: Clip.antiAlias, // Ensures internal components don't overlap rounded corners
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isFocused ? activeColor : inactiveColor.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.onSearchChanged,
                  onSubmitted: widget.onSubmitted,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(fontFamily: fontFamily, fontSize: 14, color: AppTheme.darkColor),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? (isUrdu ? "تلاش کریں..." : "Search..."),
                    hintStyle: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontSize: 13,
                      fontFamily: fontFamily,
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                    ),
                    prefixIcon: Icon(
                      PhosphorIcons.magnifyingGlass(),
                      color: _isFocused ? activeColor : inactiveColor.withOpacity(0.5),
                      size: 18,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showVoiceSearch)
                          GestureDetector(
                            onLongPressStart: (_) => widget.onVoicePressed != null ? widget.onVoicePressed!() : _startListening(),
                            onLongPressEnd: (_) => widget.onVoiceReleased != null ? widget.onVoiceReleased!() : _stopListening(),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_isListening)
                                  ScaleTransition(
                                    scale: Tween(begin: 1.0, end: 2.0).animate(_pulseController),
                                    child: Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(
                                    _isListening ? PhosphorIcons.microphone(PhosphorIconsStyle.fill) : PhosphorIcons.microphone(),
                                    color: _isListening ? Colors.red : activeColor.withOpacity(0.6),
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.showScanner)
                          IconButton(
                            onPressed: widget.onScannerTap,
                            icon: Icon(PhosphorIcons.scan(), color: activeColor.withOpacity(0.6), size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    filled: false, // Ensure no internal background
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Trailing Widget or Sort Button
          if (widget.trailing != null)
            widget.trailing!
          else if (widget.onSortToggled != null)
            GestureDetector(
              onTap: widget.onSortToggled,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: (widget.isAscending ? activeColor : inactiveColor).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (widget.isAscending ? activeColor : inactiveColor).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.isAscending ? PhosphorIcons.sortAscending() : PhosphorIcons.sortDescending(),
                  color: widget.isAscending ? activeColor : inactiveColor,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
