import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/profile_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('updating remote profession preserves worker account type',
      (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final date = DateTime(2026);
    final databaseService = _TestDatabaseService();
    final worker = Account(
      id: 'worker-1',
      name: 'Ali',
      phone: '',
      accountType: 'worker',
      initialBalance: 0,
      balanceType: 'none',
      balance: 0,
      createdAt: date,
      updatedAt: date,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageService>(
            create: (_) => LanguageService(),
          ),
          ChangeNotifierProvider<DatabaseService>.value(
            value: databaseService,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProfileUpdateDialog(
              party: worker,
              remoteProfile: const {
                'name': 'Ali',
                'photoUrl': '',
                'profession': 'Electrician',
                'address': '',
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(databaseService.updatedAccount, isNotNull);
    expect(databaseService.updatedAccount!.accountType, 'worker');
    expect(databaseService.updatedAccount!.profession, 'Electrician');
    await tester.pump(const Duration(seconds: 3));
  });
}

class _TestDatabaseService extends ChangeNotifier implements DatabaseService {
  Account? updatedAccount;

  @override
  Future<void> updateAccount(Account account) async {
    updatedAccount = account;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
