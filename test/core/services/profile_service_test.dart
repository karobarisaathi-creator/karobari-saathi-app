import 'package:account_app/core/services/database/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public profiles omit private account and device fields', () {
    final profile = ProfileService.publicProfileData(
      uid: 'user-1',
      userData: {
        'phoneNumber': '+923009999999',
        'displayName': 'Shop owner',
        'businessAddress': 'Main market',
        'email': 'private@example.com',
        'fcmToken': 'device-token',
        'isPremium': true,
        'isDeactivated': false,
      },
      verifiedPhoneNumber: '+923001234567',
    );

    expect(profile, {
      'uid': 'user-1',
      'phoneNumber': '+923001234567',
      'displayName': 'Shop owner',
      'businessAddress': 'Main market',
    });
  });
}
