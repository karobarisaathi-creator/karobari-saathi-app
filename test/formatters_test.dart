import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/utils/formatters.dart';

void main() {
  group('Enterprise Security & Validation Tests', () {
    test('Should sanitize malicious HTML and control characters', () {
      const input = "<script>alert('XSS')</script> Hello\u200BWorld\x01";
      final result = Formatters.sanitizeText(input);
      expect(result, "alert('XSS') HelloWorld");
      expect(result.contains('<script>'), false);
      expect(result.contains('\u200B'), false);
    });

    test('Should detect prohibited keywords even with case variations', () {
      expect(
          Formatters.containsProhibitedContent("This is a FRAUD item"), true);
      expect(Formatters.containsProhibitedContent("یہ جَعلی چیز ہے"), true);
      expect(Formatters.containsProhibitedContent("Fresh Apples"), false);
    });

    test('Should normalize international phone numbers to E.164', () {
      // Pakistan Local to E.164
      expect(Formatters.normalizePhoneNumber("03001234567"), "+923001234567");
      expect(Formatters.normalizePhoneNumber("923001234567"), "+923001234567");

      // International
      expect(Formatters.normalizePhoneNumber("+14155552671"), "+14155552671");
      expect(Formatters.normalizePhoneNumber("0014155552671"), "+14155552671");

      // Invalid
      expect(Formatters.normalizePhoneNumber("12345"), null);
    });

    test('Phone matching ignores country and trunk prefixes', () {
      expect(
        Formatters.phoneNumbersMatch('03001234567', '+92 300 1234567'),
        isTrue,
      );
      expect(
        Formatters.phoneNumbersMatch('+1 415 555 2671', '4155552671'),
        isTrue,
      );
      expect(
        Formatters.phoneNumbersMatch('+93 70 123 4567', '0701234567'),
        isTrue,
      );
      expect(
        Formatters.phoneNumbersMatch('+992 917 123456', '0917123456'),
        isTrue,
      );
      expect(
        Formatters.phoneNumbersMatch('03001234567', '03007654321'),
        isFalse,
      );
    });

    test('Phone search accepts numbers with or without the country code', () {
      expect(
        Formatters.phoneMatchesSearch('+923001234567', '0300-123-4567'),
        isTrue,
      );
      expect(
        Formatters.phoneMatchesSearch('03001234567', '+92 300 123'),
        isTrue,
      );
      expect(Formatters.phoneMatchesSearch('03001234567', 'abc'), isFalse);
    });

    test('Phone lookup tries international and national stored formats', () {
      final pakistanCandidates =
          Formatters.phoneNumberLookupCandidates('+923001234567');
      expect(pakistanCandidates, contains('03001234567'));
      expect(pakistanCandidates, contains('+923001234567'));

      final afghanistanCandidates =
          Formatters.phoneNumberLookupCandidates('+93701234567');
      expect(afghanistanCandidates, contains('+93701234567'));
      expect(
        afghanistanCandidates,
        contains(Formatters.formatPhoneNumber('+93701234567')),
      );
    });

    test('Phone display uses local formats without international country codes',
        () {
      final countryNumbers = {
        '+923001234567': '92',
        '+919876543210': '91',
        '+93701234567': '93',
        '+992917123456': '992',
        '+8801712345678': '880',
      };

      for (final entry in countryNumbers.entries) {
        final formattedDigits = Formatters.formatPhoneNumber(entry.key)
            .replaceAll(RegExp(r'\D'), '');
        expect(formattedDigits.startsWith(entry.value), isFalse);
      }

      expect(
        Formatters.formatPhoneNumber('+923001234567').replaceAll(
          RegExp(r'\D'),
          '',
        ),
        '03001234567',
      );
    });
  });
}
