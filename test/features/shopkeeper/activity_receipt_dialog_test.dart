import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/receipt_paper_wrapper.dart';
import 'package:account_app/features/shopkeeper/widgets/activity_receipt_dialog.dart';

void main() {
  group('ReceiptClipper tests', () {
    test('generates valid non-empty clip path', () {
      const clipper = ReceiptClipper(toothWidth: 10, toothHeight: 6);
      final path = clipper.getClip(const Size(300, 500));
      expect(path.getBounds().isEmpty, isFalse);
      expect(path.getBounds().width, equals(300));
      expect(path.getBounds().height, equals(500));
    });

    test('reclip returns correct equality check', () {
      const clipper1 = ReceiptClipper(toothWidth: 10, toothHeight: 6);
      const clipper2 = ReceiptClipper(toothWidth: 10, toothHeight: 6);
      const clipper3 = ReceiptClipper(toothWidth: 12, toothHeight: 6);

      expect(clipper1.shouldReclip(clipper2), isFalse);
      expect(clipper1.shouldReclip(clipper3), isTrue);
    });
  });

  group('ActivityReceiptDialog Widget tests', () {
    testWidgets('renders receipt dialog with profile info widget and receipt header',
        (WidgetTester tester) async {
      final notification = AppNotification(
        id: 'notif-1',
        title: 'Test Notification',
        message: 'Test message',
        type: NotificationType.transaction,
        timestamp: DateTime(2025, 2, 25, 14, 30),
        data: {
          'senderName': 'احمد رضا',
          'senderPhone': '03001234567',
          'referenceNumber': 'REF-9988',
          'transactionType': 'income',
          'amount': 1500,
          'receivedAmount': 500,
          'pendingAmount': 1000,
          'items': [
            {'description': 'گندم کی بوری', 'quantity': 2, 'total': 1000},
            {'description': 'چاول', 'quantity': 1, 'total': 500},
          ],
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageService>(
          create: (_) => LanguageService(),
          child: MaterialApp(
            home: Scaffold(
              body: ActivityReceiptDialog(
                notification: notification,
                isUrdu: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('سرگرمی رسید'), findsOneWidget);
      expect(find.byType(ProfileInfoWidget), findsOneWidget);
      expect(find.text('احمد رضا'), findsOneWidget);
      expect(find.textContaining('0300'), findsOneWidget);
      expect(find.text('REF-9988'), findsOneWidget);
      expect(find.text('گندم کی بوری'), findsOneWidget);
      expect(find.text('چاول'), findsOneWidget);
      expect(find.byType(DashedLineDivider), findsWidgets);
    });

    testWidgets('shows disabled button when activity is already added to ledger',
        (WidgetTester tester) async {
      final notification = AppNotification(
        id: 'notif-2',
        title: 'Test Notification',
        message: 'Test message',
        type: NotificationType.transaction,
        timestamp: DateTime(2025, 2, 25, 14, 30),
        data: {
          'senderName': 'علی احمد',
          'transactionType': 'income',
          'amount': 2000,
          'isAdded': true,
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageService>(
          create: (_) => LanguageService(),
          child: MaterialApp(
            home: Scaffold(
              body: ActivityReceiptDialog(
                notification: notification,
                isUrdu: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'کھاتے میں شامل ہے');
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });
  });
}
