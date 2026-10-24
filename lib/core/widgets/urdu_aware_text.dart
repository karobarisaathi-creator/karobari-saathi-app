import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';

class UrduAwareText extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  final TextScaler? textScaler;

  const UrduAwareText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.textScaler,
  }) : textSpan = null;

  const UrduAwareText.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.textScaler,
  }) : data = null;

  static InlineSpan transformTextSpan(InlineSpan span, bool isUrdu) =>
      _transformSpan(span, isUrdu);

  static final _urduRun = RegExp(
    r'[\u0600-\u0605\u0608-\u060F\u0610-\u061A\u061C-\u064A'
    r'\u066E-\u066F\u0670-\u06D3\u06D5-\u06EF\u06FA-\u06FC\u06FF'
    r'\u0750-\u077F]+',
  );
  static final _numberOrLatinRun =
      RegExp(r'[0-9]+(?:[.,:/-][0-9]+)*|[A-Za-z]+');

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final rootStyle = _withoutUrduFont(style);
    final text = data ?? '';
    final content = textSpan == null
        ? _buildTextSpan(text, isUrdu, style: rootStyle)
        : _transformSpan(textSpan!, isUrdu);

    return Text.rich(
      content,
      style: rootStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
      textScaler: textScaler,
    );
  }

  static TextSpan _buildTextSpan(
    String text,
    bool isUrdu, {
    TextStyle? style,
  }) {
    final matches = [
      ..._urduRun.allMatches(text),
      ..._numberOrLatinRun.allMatches(text),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start < lastEnd) continue;
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: style,
          ),
        );
      }
      final run = match.group(0)!;
      final isUrduRun = _urduRun.hasMatch(run);
      final useUrduFont = isUrduRun && isUrdu;
      spans.add(
        TextSpan(
          text: run,
          style: useUrduFont
              ? style?.copyWith(fontFamily: 'NooriNastaleeq') ??
                  const TextStyle(fontFamily: 'NooriNastaleeq')
              : style,
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }
    return TextSpan(children: spans);
  }

  static InlineSpan _transformSpan(InlineSpan span, bool isUrdu) {
    if (span is! TextSpan) return span;

    final style = _withoutUrduFont(span.style);
    final children = <InlineSpan>[];
    if (span.text != null) {
      children.addAll(
        _buildTextSpan(
          span.text!,
          isUrdu,
          style: style,
        ).children!,
      );
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      children.add(_transformSpan(child, isUrdu));
    }

    return TextSpan(
      children: children,
      style: style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  static TextStyle? _withoutUrduFont(TextStyle? style) {
    if (style?.fontFamily != 'NooriNastaleeq') return style;

    return TextStyle(
      inherit: style!.inherit,
      color: style.color,
      backgroundColor: style.backgroundColor,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      foreground: style.foreground,
      background: style.background,
      shadows: style.shadows,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: style.decoration,
      decorationColor: style.decorationColor,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      debugLabel: style.debugLabel,
      fontFamilyFallback: style.fontFamilyFallback,
      overflow: style.overflow,
    );
  }
}

class UrduAwareTextEditingController extends TextEditingController {
  UrduAwareTextEditingController({this.isUrdu = true});

  bool isUrdu;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final span = super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
    final transformed = UrduAwareText.transformTextSpan(span, isUrdu);
    return transformed is TextSpan
        ? transformed
        : TextSpan(children: [transformed]);
  }
}
