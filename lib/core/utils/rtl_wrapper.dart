// rtl_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';

class RtlWrapper extends StatelessWidget {
  final Widget child;

  const RtlWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Directionality(
      textDirection: languageService.textDirection,
      child: child,
    );
  }
}

class RtlAwareWidget extends StatelessWidget {
  final Widget child;
  final bool forceRtl;

  const RtlAwareWidget({required this.child, this.forceRtl = false});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isRtl =
        forceRtl || languageService.textDirection == TextDirection.rtl;

    return Transform(
      transform: Matrix4.rotationY(isRtl ? 3.14159 : 0),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class BilingualText extends StatelessWidget {
  final String urduText;
  final String englishText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const BilingualText({
    required this.urduText,
    required this.englishText,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;

    return Text(
      isUrdu ? urduText : englishText,
      style:
          style?.copyWith(fontFamily: isUrdu ? 'NooriNastaleeq' : 'NotoSans') ??
          TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : 'NotoSans'),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
