import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/account_model.dart';

void main() {
  Account makeAccount({Map<String, String>? settlementNotes = const {}}) {
    return Account(
      id: 'party-1',
      name: 'Test Party',
      phone: '',
      category: 'customer',
      initialBalance: 0,
      balanceType: 'receivable',
      balance: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      settlementNotes: settlementNotes,
    );
  }

  test('settlement notes survive account map serialization', () {
    final account = makeAccount(
      settlementNotes: const {'settlement-1': 'پرانا لین دین مکمل'},
    );

    final restored = Account.fromMap(account.toMap());

    expect(
      restored.settlementNotes,
      {'settlement-1': 'پرانا لین دین مکمل'},
    );
  });

  test('legacy account maps default to no settlement notes', () {
    final account = makeAccount().toMap()..remove('settlementNotes');

    expect(Account.fromMap(account).settlementNotes, isEmpty);
  });

  test('copyWith tolerates accounts without the new note map', () {
    final legacyAccount = makeAccount(settlementNotes: null);

    expect(legacyAccount.copyWith(balance: 10).settlementNotes, isEmpty);
  });
}
