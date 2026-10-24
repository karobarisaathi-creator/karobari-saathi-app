import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'ur'});
  });

  testWidgets('keeps numerals default and Urdu glyphs Urdu-font in Urdu',
      (tester) async {
    final languageService = LanguageService();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: languageService,
        child: const MaterialApp(
          home: Scaffold(
            body: UrduAwareText(
              'Rs 123 اردو',
              key: ValueKey('urdu-text'),
              style: TextStyle(fontFamily: 'NooriNastaleeq'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('urdu-text')),
        matching: find.byType(RichText),
      ),
    );
    expect((richText.text as TextSpan).toPlainText(), 'Rs 123 اردو');
    final spans = _textSpans(richText.text as TextSpan);
    expect(
      spans.firstWhere((span) => span.text == '123').style?.fontFamily,
      isNot('NooriNastaleeq'),
    );
    expect(
      spans.firstWhere((span) => span.text == 'اردو').style?.fontFamily,
      'NooriNastaleeq',
    );
    expect(richText.text.style?.fontFamily, isNot('NooriNastaleeq'));
  });

  testWidgets('strips Urdu font from inline spans in English', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final languageService = LanguageService();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: languageService,
        child: const MaterialApp(
          home: Scaffold(
            body: UrduAwareText.rich(
              TextSpan(
                style: TextStyle(fontFamily: 'NooriNastaleeq'),
                children: [
                  TextSpan(text: 'Rs 123 '),
                  TextSpan(text: 'اردو'),
                ],
              ),
              key: ValueKey('urdu-text'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('urdu-text')),
        matching: find.byType(RichText),
      ),
    );
    final outerSpan = richText.text as TextSpan;
    final leaves = _textSpans(outerSpan);
    expect(leaves.map((span) => span.text).join(), 'Rs 123 اردو');
    expect(outerSpan.style?.fontFamily, isNot('NooriNastaleeq'));
    for (final span in leaves) {
      expect(span.style?.fontFamily, isNot('NooriNastaleeq'));
    }
  });

  testWidgets('styles mixed Urdu and Latin text while editing', (tester) async {
    final controller = UrduAwareTextEditingController()
      ..text = 'اردو RS 123';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            style: const TextStyle(fontFamily: ''),
          ),
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final span = controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      style: editable.style,
      withComposing: false,
    );

    final leaves = _textSpans(span);
    expect(leaves.map((item) => item.text).join(), 'اردو RS 123');
    expect(
      leaves.firstWhere((item) => item.text == 'اردو').style?.fontFamily,
      'NooriNastaleeq',
    );
    expect(
      leaves.firstWhere((item) => item.text == '123').style?.fontFamily,
      isNot('NooriNastaleeq'),
    );
    controller.dispose();
  });
}

List<TextSpan> _textSpans(TextSpan span) {
  final spans = <TextSpan>[];
  if (span.text != null) spans.add(span);
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) spans.addAll(_textSpans(child));
  }
  return spans;
}
