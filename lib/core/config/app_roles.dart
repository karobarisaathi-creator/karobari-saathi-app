import 'package:flutter/material.dart';

enum AppRole {
  simple,
  shopkeeper,
}

extension AppRoleExtension on AppRole {
  String get id {
    switch (this) {
      case AppRole.shopkeeper:
        return 'shopkeeper';
      case AppRole.simple:
      default:
        return 'simple';
    }
  }

  String label(bool isUrdu) {
    switch (this) {
      case AppRole.shopkeeper:
        return isUrdu ? 'دکاندار / شاپ کیپر' : 'Shopkeeper';
      case AppRole.simple:
      default:
        return isUrdu ? 'سادہ تاجر' : 'Simple Trader';
    }
  }

  String subtitle(bool isUrdu) {
    switch (this) {
      case AppRole.shopkeeper:
        return isUrdu
            ? 'دکان کا ہساب، آرڈر لسٹ اور فوری کام'
            : 'Store account, order list & quick actions';
      case AppRole.simple:
      default:
        return isUrdu
            ? 'عام کھاتہ جات اور پارٹیز کا ہساب'
            : 'General party accounts and transactions';
    }
  }

  IconData get icon {
    switch (this) {
      case AppRole.shopkeeper:
        return Icons.storefront_rounded;
      case AppRole.simple:
      default:
        return Icons.person_outline_rounded;
    }
  }

  static AppRole fromString(String? val) {
    if (val?.toLowerCase() == 'shopkeeper') {
      return AppRole.shopkeeper;
    }
    return AppRole.simple;
  }
}
