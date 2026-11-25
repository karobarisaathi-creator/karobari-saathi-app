import 'dart:io';

import 'package:account_app/core/models/account_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory =
        await Directory.systemTemp.createTemp('account-profession-test-');
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(AccountAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('keeps profession separate from account type through map round trip',
      () {
    final account = Account(
      id: 'worker-1',
      name: 'Ali',
      phone: '',
      accountType: 'worker',
      profession: 'Electrician',
      initialBalance: 0,
      balanceType: 'none',
      balance: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final restored = Account.fromMap(account.toMap());

    expect(restored.accountType, 'worker');
    expect(restored.category, 'worker');
    expect(restored.profession, 'Electrician');
  });

  test('prefers the new accountType key and reads legacy category maps', () {
    final legacy = Account.fromMap({
      'id': 'worker-1',
      'name': 'Ali',
      'phone': '',
      'category': 'worker',
      'initialBalance': 0,
      'balanceType': 'none',
      'balance': 0,
      'createdAt': DateTime(2026).toIso8601String(),
      'updatedAt': DateTime(2026).toIso8601String(),
    });
    final updatedFormat = Account.fromMap({
      ...legacy.toMap(),
      'accountType': 'worker',
      'category': 'Electrician',
      'profession': 'Electrician',
    });

    expect(legacy.accountType, 'worker');
    expect(updatedFormat.accountType, 'worker');
    expect(updatedFormat.profession, 'Electrician');
  });

  test('copying profession never changes account type and can clear it', () {
    final account = Account(
      id: 'worker-1',
      name: 'Ali',
      phone: '',
      category: 'worker',
      profession: 'Electrician',
      initialBalance: 0,
      balanceType: 'none',
      balance: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final updated = account.copyWith(profession: 'Plumber');
    final cleared = updated.copyWith(clearProfession: true);

    expect(updated.accountType, 'worker');
    expect(updated.profession, 'Plumber');
    expect(cleared.accountType, 'worker');
    expect(cleared.profession, isNull);
  });

  test('persists account type and profession in Hive', () async {
    final box = await Hive.openBox<Account>('accounts');
    final account = Account(
      id: 'worker-1',
      name: 'Ali',
      phone: '',
      accountType: 'worker',
      profession: 'Electrician',
      initialBalance: 0,
      balanceType: 'none',
      balance: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await box.put(account.id, account);

    expect(box.get(account.id)?.accountType, 'worker');
    expect(box.get(account.id)?.profession, 'Electrician');
  });
}
