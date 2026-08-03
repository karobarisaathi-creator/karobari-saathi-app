import 'package:account_app/core/services/verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerificationService admin access', () {
    test('allows access when user is explicitly marked as admin', () {
      final result = VerificationService.canAccessAdminPanel(
        userData: {'isAdmin': true},
        uid: 'abc123',
        email: 'admin@example.com',
        phone: '+923001234567',
      );

      expect(result, isTrue);
    });

    test('allows access for a trusted admin uid', () {
      final result = VerificationService.canAccessAdminPanel(
        userData: {},
        uid: 'trusted-admin',
        email: 'user@example.com',
        phone: '+923001234567',
      );

      expect(result, isTrue);
    });

    test('denies access for normal users', () {
      final result = VerificationService.canAccessAdminPanel(
        userData: {'isAdmin': false},
        uid: 'user-1',
        email: 'user@example.com',
        phone: '+923001234567',
      );

      expect(result, isFalse);
    });
  });
}
