import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/utils/formatters.dart';

void main() {
  group('Formatters Tests', () {
    test('Should sanitize malicious HTML and control characters', () {
      const input = "<script>alert('XSS')</script> Hello\u200BWorld\x01";
      final result = Formatters.sanitizeText(input);
      expect(result, "alert('XSS') HelloWorld");
      expect(result.contains('<script>'), false);
      expect(result.contains('\u200B'), false);
    });

    test('Should normalize international phone numbers to E.164', () {
      // Pakistan Local to E.164
      expect(Formatters.normalizePhoneNumber("03001234567"), "+923001234567");
      expect(Formatters.normalizePhoneNumber("923001234567"), "+923001234567");

      // International
      expect(Formatters.normalizePhoneNumber("+14155552671"), "+14155552671");
      expect(Formatters.normalizePhoneNumber("0014155552671"), "+14155552671");
      expect(
        Formatters.normalizePhoneNumber("919876543210"),
        "+919876543210",
      );

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
      expect(Formatters.phoneMatchesSearch('03001234567', '03'), isFalse);
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
        final formattedDigits = Formatters.displayPhone(entry.key)
            .replaceAll(RegExp(r'[\u2066\u2069]'), '')
            .replaceAll(RegExp(r'\D'), '');
        expect(formattedDigits.startsWith(entry.value), isFalse);
      }

      expect(
        Formatters.displayPhone('+923001234567')
            .replaceAll(RegExp(r'[\u2066\u2069]'), '')
            .replaceAll(RegExp(r'\D'), ''),
        '03001234567',
      );
      final formatted = Formatters.formatPhoneNumber('+923001234567');
      expect(
        Formatters.displayPhone('+923001234567'),
        '\u2066$formatted\u2069',
      );
      expect(
        Formatters.displayPhone(''),
        '',
      );
      expect(
        Formatters.maskPhoneNumber('+923001234567'),
        '\u2066${formatted.substring(0, 4)}*******\u2069',
      );
    });

    test('Text helpers preserve whitespace and joining characters', () {
      expect(Formatters.getInitials(' Ali  Khan '), 'AK');
      expect(Formatters.getInitials('Ali '), 'A');
      expect(Formatters.getInitials('  '), '?');

      const input = '<script>alert(1)</script> line one\n\tاردو\u200Cجوڑ\u200D';
      final sanitized = Formatters.sanitizeText(input);
      expect(sanitized, "alert(1) line one\n\tاردو\u200Cجوڑ\u200D");
      expect(Formatters.sanitizeText('x < 3 > 2'), 'x < 3 > 2');
    });

    test('Formatting helpers preserve signs, scale, and language', () {
      expect(Formatters.formatBalance(-500), '-Rs 500');
      expect(Formatters.formatPercentage(85), '85.0%');
      expect(Formatters.formatNumberCompact(999999), '1.0M');
      expect(
        Formatters.formatPendingAmount(500, isUrdu: false),
        'Rs 500 pending',
      );
      expect(
        Formatters.formatRelativeTime(
          DateTime.now().subtract(const Duration(minutes: 2)),
          isUrdu: false,
        ),
        '2 min ago',
      );
    });

    test('E.164 helpers share international normalization behavior', () {
      expect(
        Formatters.toE164('0091 98765 43210'),
        Formatters.normalizePhoneNumber('+91 98765 43210'),
      );
      expect(
        Formatters.toE164('4155552671', defaultCountryCode: '+1'),
        '+14155552671',
      );
    });
  });
}
