import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/features/quick_bill/widgets/customer_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('hides excluded accounts and keeps other parties selectable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final date = DateTime(2026, 11, 23);
    final databaseService = _TestDatabaseService([
      _account(id: 'worker-1', name: 'Existing worker', date: date),
      _account(id: 'legacy-cash-customer', name: 'نقد گاہک', date: date),
      _account(
        id: 'merged-inactive',
        name: 'Other party',
        date: date,
        isActive: false,
      ),
      _account(
        id: 'partner-1',
        name: 'Business partner',
        date: date,
        category: 'Partner',
      ),
      _account(id: 'customer-1', name: 'Other party', date: date),
      _account(
        id: 'customer-1',
        name: 'Other party',
        date: date.add(const Duration(minutes: 1)),
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageService>(
            create: (_) => LanguageService(),
          ),
          ChangeNotifierProvider<DatabaseService>.value(value: databaseService),
          ChangeNotifierProvider<NotificationService>.value(
            value: _TestNotificationService(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCustomerPickerSheet(
                  context,
                  excludedAccountIds: const {'worker-1'},
                ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    final visibleParties = tester
        .widgetList<PartyCard>(find.byType(PartyCard))
        .map((card) => card.party.id)
        .toList();
    expect(visibleParties, ['customer-1']);
  });
}

Account _account({
  required String id,
  required String name,
  required DateTime date,
  bool isActive = true,
  String? category,
}) {
  return Account(
    id: id,
    name: name,
    phone: '',
    category: category ?? (id.startsWith('worker') ? 'worker' : 'Customer'),
    initialBalance: 0,
    balanceType: 'none',
    balance: 0,
    createdAt: date,
    updatedAt: date,
    isActive: isActive,
  );
}

class _TestDatabaseService extends ChangeNotifier implements DatabaseService {
  _TestDatabaseService(this._accounts);

  final List<Account> _accounts;

  @override
  List<Account> getAccounts() => _accounts;

  @override
  List<model.Transaction> getAllTransactions() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestNotificationService extends ChangeNotifier
    implements NotificationService {
  @override
  List<AppNotification> get notifications => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
