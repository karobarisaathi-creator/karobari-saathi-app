import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/utils/artisan_validators.dart';

void main() {
  group('ArtisanValidators Tests', () {
    test('Phone Validation', () {
      expect(ArtisanValidators.isValidPhone('03001234567'), true);
      expect(ArtisanValidators.isValidPhone('+923001234567'), true);
      expect(ArtisanValidators.isValidPhone('123'), false); // Too short
      expect(ArtisanValidators.isValidPhone('abc'), false); // Not numbers
    });

    test('Description Validation', () {
      expect(ArtisanValidators.isValidDescription('This is a valid description.'), true);
      expect(ArtisanValidators.isValidDescription('Short'), false); // Too short
      expect(ArtisanValidators.isValidDescription('A' * 501), false); // Too long
    });

    test('Budget Validation', () {
      expect(ArtisanValidators.isValidBudget(500), true);
      expect(ArtisanValidators.isValidBudget(0), false);
      expect(ArtisanValidators.isValidBudget(-10), false);
      expect(ArtisanValidators.isValidBudget(null), false);
    });

    test('Experience Validation', () {
      expect(ArtisanValidators.isValidExperience(5), true);
      expect(ArtisanValidators.isValidExperience(0), true);
      expect(ArtisanValidators.isValidExperience(71), false);
      expect(ArtisanValidators.isValidExperience(-1), false);
    });

    test('Location Validation', () {
      expect(ArtisanValidators.isValidLocation(30.0, 70.0), true);
      expect(ArtisanValidators.isValidLocation(91.0, 70.0), false); // Lat out of range
      expect(ArtisanValidators.isValidLocation(30.0, 181.0), false); // Long out of range
      expect(ArtisanValidators.isValidLocation(null, 70.0), false);
    });

    test('Error Messages (Urdu)', () {
      expect(ArtisanValidators.getErrorMessage('phone', isUrdu: true), contains('فون نمبر'));
      expect(ArtisanValidators.getErrorMessage('description', isUrdu: true), contains('تفصیل'));
    });
  });
}
