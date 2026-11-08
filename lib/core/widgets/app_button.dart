// lib/core/widgets/app_button.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';

enum AppButtonVariant { primary, outlined, ghost }
enum AppButtonSize { small, large, mini }

class AppButton extends StatefulWidget {
  final String? text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Color? color;
  final bool isLoading;
  final bool isFullWidth;

  final String? loadingText;           // ایک متن (سادہ)
  final List<String>? loadingTexts;    // کئی متن (سائیکل)
  final int loadingTextIntervalMs;     // متن بدلنے کا وقفہ

  const AppButton({
    super.key,
    this.text,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.small,
    this.color,
    this.isLoading = false,
    this.isFullWidth = false,
    this.loadingText,
    this.loadingTexts,
    this.loadingTextIntervalMs = 700,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  int _currentTextIndex = 0;
  Timer? _textCycleTimer;
  String _previousText = '';
  String _currentText = '';
  Key _textKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _currentText = widget.text ?? '';
    _previousText = widget.text ?? '';
    if (widget.isLoading) _startTextCycle();
  }

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading && !oldWidget.isLoading) {
      _startTextCycle();
    } else if (widget.isLoading &&
        (widget.loadingText != oldWidget.loadingText ||
            widget.loadingTexts != oldWidget.loadingTexts)) {
      _startTextCycle();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _stopTextCycle();
    } else if (!widget.isLoading && widget.text != oldWidget.text) {
      if (!mounted) return;
      setState(() {
        _currentText = widget.text ?? '';
        _previousText = widget.text ?? '';
      });
    }
  }

  void _startTextCycle() {
    _currentTextIndex = 0;
    _textCycleTimer?.cancel();

    final texts = _getLoadingTexts();
    if (texts.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _previousText = '';
      _currentText = texts[0];
      _textKey = UniqueKey();
    });

    if (texts.length > 1) {
      _textCycleTimer = Timer.periodic(
        Duration(milliseconds: widget.loadingTextIntervalMs),
        (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _currentTextIndex++;
            if (_currentTextIndex >= texts.length) {
              _currentTextIndex = texts.length - 1;
              timer.cancel();
              return;
            }
            _previousText = _currentText;
            _currentText = texts[_currentTextIndex];
            _textKey = UniqueKey();
          });
        },
      );
    }
  }

  void _stopTextCycle() {
    _textCycleTimer?.cancel();
    _textCycleTimer = null;
    if (!mounted) return;
    setState(() {
      _currentTextIndex = 0;
      _previousText = widget.text ?? '';
      _currentText = widget.text ?? '';
      _textKey = UniqueKey();
    });
  }

  List<String> _getLoadingTexts() {
    if (widget.loadingTexts != null && widget.loadingTexts!.isNotEmpty) {
      return widget.loadingTexts!;
    }
    if (widget.loadingText != null && widget.loadingText!.isNotEmpty) {
      return [widget.loadingText!];
    }
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (isUrdu) {
      return [
        'محفوظ ہو رہا ہے...',
        'عمل جاری ہے...',
      ];
    } else {
      return [
        'Saving data...',
        'Processing...',
      ];
    }
  }

  @override
  void dispose() {
    _textCycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final themeColor = widget.color ?? AppTheme.themeColor;

    double height;
    double borderRadius;
    double fontSize;
    double horizontalPadding;

    if (widget.size == AppButtonSize.large) {
      height = 46.0;
      borderRadius = 12.0;
      fontSize = 14.5;
      horizontalPadding = 12.0;
    } else if (widget.size == AppButtonSize.small) {
      height = 32.0;
      borderRadius = 16.0;
      fontSize = 12.5;
      horizontalPadding = 16.0;
    } else {
      height = 26.0;
      borderRadius = 13.0;
      fontSize = 11.0;
      horizontalPadding = 12.0;
    }

    final iconSize = widget.size == AppButtonSize.small
        ? 16.0
        : (widget.size == AppButtonSize.mini ? 14.0 : 20.0);

    // ─── لوڈنگ کے دوران گول انڈیکیٹر، ورنہ عام آئیکن ───
    Widget? iconWidget;
    if (widget.isLoading) {
      iconWidget = SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: widget.variant == AppButtonVariant.primary
              ? Colors.white
              : themeColor,
        ),
      );
    } else if (widget.icon != null) {
      iconWidget = Icon(widget.icon, size: iconSize);
    }

    Widget? textWidget;
    if (_currentText.isNotEmpty) {
      textWidget = _AnimatedButtonText(
        key: _textKey,
        text: _currentText,
        previousText: _previousText,
        fontSize: fontSize,
        fontFamily: fontFamily,
      );
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (iconWidget != null) ...[
          iconWidget,
          if (textWidget != null) const SizedBox(width: 8),
        ],
        if (textWidget != null) Flexible(child: textWidget),
      ],
    );

    final borderRadiusObj = BorderRadius.circular(borderRadius);

    Widget buildBaseButton() {
      if (widget.variant == AppButtonVariant.outlined) {
        return OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: themeColor,
            disabledForegroundColor: themeColor,
            side: BorderSide(color: themeColor),
            shape: RoundedRectangleBorder(borderRadius: borderRadiusObj),
            minimumSize: Size(widget.isFullWidth ? double.infinity : 0, height),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          ),
          child: content,
        );
      }

      if (widget.variant == AppButtonVariant.ghost) {
        return TextButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: themeColor,
            disabledForegroundColor: themeColor,
            shape: RoundedRectangleBorder(borderRadius: borderRadiusObj),
            minimumSize: Size(widget.isFullWidth ? double.infinity : 0, height),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          ),
          child: content,
        );
      }

      return ElevatedButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          disabledBackgroundColor: themeColor,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: borderRadiusObj),
          minimumSize: Size(widget.isFullWidth ? double.infinity : 0, height),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        ),
        child: content,
      );
    }

    return SizedBox(
      height: height,
      width: widget.isFullWidth ? double.infinity : null,
      child: buildBaseButton(),
    );
  }
}

class _AnimatedButtonText extends StatefulWidget {
  final String text;
  final String previousText;
  final double fontSize;
  final String fontFamily;

  const _AnimatedButtonText({
    super.key,
    required this.text,
    required this.previousText,
    required this.fontSize,
    required this.fontFamily,
  });

  @override
  State<_AnimatedButtonText> createState() => _AnimatedButtonTextState();
}

class _AnimatedButtonTextState extends State<_AnimatedButtonText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideIn = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Initial load when screen opens -> Keep text completely static & still!
    if (widget.previousText.isNotEmpty && widget.previousText != widget.text) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedButtonText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChanging = _controller.isAnimating || _controller.value < 1.0;

    return ClipRect(
      child: SizedBox(
        height: widget.fontSize * 1.4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isChanging && widget.previousText != widget.text)
              SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(0, 1),
                ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn)),
                child: FadeTransition(
                  opacity: _fadeOut,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: UrduAwareText(
                      widget.previousText,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.bold,
                        fontFamily: widget.fontFamily,
                      ),
                    ),
                  ),
                ),
              ),
            SlideTransition(
              position: _slideIn,
              child: FadeTransition(
                opacity: _fadeIn,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: UrduAwareText(
                    widget.text,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: widget.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
