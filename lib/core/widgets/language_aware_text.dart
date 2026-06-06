import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';

class LanguageAwareText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const LanguageAwareText({
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    
    return Text(
      text,
      style: style?.copyWith(
        fontFamily: languageService.getFontFamily(text),
      ) ?? TextStyle(
        fontFamily: languageService.getFontFamily(text),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}