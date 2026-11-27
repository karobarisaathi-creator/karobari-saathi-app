import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/profession_model.dart';

void main() {
  Profession createProfession({
    String? description,
    String? notes,
  }) {
    return Profession(
      id: 'profession-1',
      name: 'Farmer',
      categories: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      description: description,
      notes: notes,
    );
  }

  test('notes round-trip separately from profession description', () {
    final profession = createProfession(
      description: 'ICON:agriculture|Farmer',
      notes: 'Good yield this season',
    );

    final restored = Profession.fromMap(profession.toMap());

    expect(restored.notes, 'Good yield this season');
    expect(restored.description, 'ICON:agriculture|Farmer');
    expect(restored.copyWith(notes: '').notes, isEmpty);
  });

  test('legacy plain descriptions migrate to notes without changing them', () {
    final legacyMap = createProfession(description: 'Older season note').toMap()
      ..remove('notes');

    final restored = Profession.fromMap(legacyMap);

    expect(restored.notes, 'Older season note');
    expect(restored.description, 'Older season note');
  });

  test('an explicitly cleared note stays empty after serialization', () {
    final profession = createProfession(
      description: 'Older season note',
      notes: '',
    );

    final restored = Profession.fromMap(profession.toMap());

    expect(restored.notes, isEmpty);
    expect(restored.description, 'Older season note');
  });

  test('legacy icon metadata is not treated as a note', () {
    final legacyMap = createProfession(
      description: 'ICON:agriculture|Farmer',
    ).toMap()
      ..remove('notes');

    final restored = Profession.fromMap(legacyMap);

    expect(restored.notes, isEmpty);
    expect(restored.description, 'ICON:agriculture|Farmer');
  });
}
