import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';

void main() {
  group('ArtisanProfile Model Tests', () {
    final now = DateTime.now();
    
    final testProfile = ArtisanProfile(
      id: 'test_id',
      name: 'Test Artisan',
      profession: 'electrician',
      professionUrdu: 'الیکٹریشن',
      location: 'Lahore',
      phone: '03001234567',
      description: 'Experienced electrician',
      createdAt: now,
      updatedAt: now,
    );

    test('ToMap conversion', () {
      final map = testProfile.toMap();
      expect(map['id'], 'test_id');
      expect(map['name'], 'Test Artisan');
      expect(map['profession'], 'electrician');
    });

    test('FromMap conversion', () {
      final map = {
        'id': 'test_id',
        'name': 'Test Artisan',
        'profession': 'electrician',
        'professionUrdu': 'الیکٹریشن',
        'location': 'Lahore',
        'phone': '03001234567',
        'description': 'Experienced electrician',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      
      final profile = ArtisanProfile.fromMap(map);
      expect(profile.id, 'test_id');
      expect(profile.name, 'Test Artisan');
    });

    test('CopyWith method', () {
      final updated = testProfile.copyWith(name: 'Updated Name');
      expect(updated.name, 'Updated Name');
      expect(updated.id, 'test_id'); // Should remain same
    });
  });
}
