import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/transaction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'ur'});
  });

  testWidgets(
      'renders transaction columns within a decorated notification card',
      (tester) async {
    final date = DateTime(2026, 11, 12);
    final transaction = Transaction(
      id: 'incoming-partial',
      accountId: 'party',
      amount: 400,
      subtotal: 500,
      receivedAmount: 100,
      type: 'expense',
      category: 'Sale',
      description: 'Imported transaction',
      date: date,
      createdAt: date,
      updatedAt: date,
      receiptFromCounterparty: true,
      contractName: 'Shop renovation',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white),
              child: TransactionCard(
                transaction: transaction,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('بنام:'), findsOneWidget);
    expect(find.textContaining('جمع:'), findsOneWidget);
    expect(find.text('Shop renovation'), findsOneWidget);
  });
}
