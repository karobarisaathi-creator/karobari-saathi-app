import 'package:account_app/features/contracts/worker_attendance_screen.dart';
import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final date = DateTime(2026, 11, 20);

  testWidgets('keeps payment controllers alive through dialog dismissal',
      (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => WorkerWagePaymentDialog(
                    isUrdu: false,
                    paymentToEdit: null,
                    onSave: (_, __, ___) async {},
                  ),
                ),
                child: const Text('Open payment dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open payment dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, '1500');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('saves the selected contract with the wage payment',
      (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    String? savedContractId;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => WorkerWagePaymentDialog(
                    isUrdu: false,
                    paymentToEdit: null,
                    contracts: [
                      ContractModel(
                        id: 'contract-1',
                        partyId: 'party',
                        partyName: 'Customer',
                        title: 'Kitchen',
                        totalAmount: 10000,
                        startDate: date,
                        createdAt: date,
                        updatedAt: date,
                      ),
                    ],
                    initialContractId: 'contract-1',
                    onSave: (_, __, contractId) async {
                      savedContractId = contractId;
                    },
                  ),
                ),
                child: const Text('Open payment dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open payment dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1500');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();

    expect(savedContractId, 'contract-1');
    expect(tester.takeException(), isNull);
  });
}
