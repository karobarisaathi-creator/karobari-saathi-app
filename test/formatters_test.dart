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
      expect(Formatters.containsProhibitedContent("This is a FRAUD item"), true);
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
  });
}
