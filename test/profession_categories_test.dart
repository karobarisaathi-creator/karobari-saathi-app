import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/config/professions_config.dart';
import 'package:account_app/core/models/profession_model.dart';

void main() {
  group('Profession category defaults', () {
    test('agriculture includes seed and fertilizer categories', () {
      final categories = ProfessionsConfig.defaultCategories(
        ProfessionCategory.agriculture,
        isUrdu: false,
      );

      expect(categories, contains('Seeds'));
      expect(categories, contains('Fertilizer'));
      expect(categories, isNot(contains('Cement')));
    });

    test('construction categories are relevant to construction work', () {
      final categories = ProfessionsConfig.defaultCategories(
        ProfessionCategory.construction,
        isUrdu: false,
      );

      expect(categories, contains('Cement'));
      expect(categories, contains('Bricks'));
      expect(categories, isNot(contains('Seeds')));
    });

    test('Urdu defaults are localized for the selected profession group', () {
      final categories = ProfessionsConfig.defaultCategories(
        ProfessionCategory.agriculture,
        isUrdu: true,
      );

      expect(categories, contains('بیج'));
      expect(categories, contains('کھاد'));
    });
  });
}
