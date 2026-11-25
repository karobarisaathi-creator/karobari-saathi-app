import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/features/shopkeeper/widgets/home_activity_message.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _activity(Map<String, dynamic> data) => AppNotification(
      id: 'activity-1',
      title: 'Activity',
      message: '',
      type: NotificationType.transaction,
      timestamp: DateTime(2026, 1, 1),
      data: data,
    );

void main() {
  test('quick bill activity uses the transaction description', () {
    final message = HomeActivityMessage.fromNotification(
      _activity({
        'senderName': 'Ali',
        'transactionType': 'income',
        'isQuickBill': true,
        'description': 'خریداری کا مختصر نوٹ',
        'amount': 1000,
        'items': [
          {'description': 'Rice', 'quantity': 1},
          {'description': 'Oil', 'quantity': 2},
          {'description': 'Tea', 'quantity': 1},
          {'description': 'Sugar', 'quantity': 3},
        ],
      }),
      isUrdu: false,
    );

    expect(message.text, 'خریداری کا مختصر نوٹ');
    expect(message.text, isNot(contains('\n')));
    expect(message.canAddToLedger, isTrue);
  });

  test('quick bill fallback is a short single-line summary', () {
    final message = HomeActivityMessage.fromNotification(
      _activity({
        'senderName': 'Ali',
        'transactionType': 'income',
        'isQuickBill': true,
        'amount': 1000,
        'items': [
          {'description': 'Rice', 'quantity': 1},
        ],
      }),
      isUrdu: false,
    );

    expect(message.text, startsWith('Quick bill from Ali:'));
    expect(message.text, isNot(contains('\n')));
  });

  test('worker wage due is informational and cannot be added again', () {
    final message = HomeActivityMessage.fromNotification(
      _activity({
        'senderName': 'Ali',
        'referenceNumber': 'WORKER_PAYROLL:ACCRUAL:attendance-1',
        'amount': 1200,
      }),
      isUrdu: false,
    );

    expect(message.text, contains('owes you wages'));
    expect(message.canAddToLedger, isFalse);
  });

  test('purchase quick bill fallback is concise', () {
    final message = HomeActivityMessage.fromNotification(
      _activity({
        'senderName': 'Ali',
        'transactionType': 'expense',
        'isQuickBill': true,
        'amount': 1000,
        'receivedAmount': 200,
        'pendingAmount': 800,
        'items': [
          {'description': 'Rice', 'quantity': 1},
        ],
      }),
      isUrdu: false,
    );

    expect(message.text, startsWith('Purchase from Ali:'));
    expect(message.text, isNot(contains('\n')));
  });

  test('worker assignment fallback is concise', () {
    final agreed = HomeActivityMessage.fromNotification(
      _activity({
        'activityKind': 'worker_assignment',
        'senderName': 'Ali',
        'jobName': 'Shop renovation',
        'wageAmount': 2500,
        'wageBasis': 'daily',
      }),
      isUrdu: false,
    );
    final undecided = HomeActivityMessage.fromNotification(
      _activity({
        'activityKind': 'worker_assignment',
        'senderName': 'Ali',
      }),
      isUrdu: false,
    );

    expect(agreed.text, 'Ali added you to a job.');
    expect(undecided.text, 'Ali added you to a job.');
  });

  test('pending income transaction says the recipient owes the sender', () {
    final message = HomeActivityMessage.fromNotification(
      _activity({
        'senderName': 'Ali',
        'transactionType': 'income',
        'amount': 700,
        'pendingAmount': 700,
      }),
      isUrdu: false,
    );

    expect(message.text, contains('owe'));
    expect(message.canAddToLedger, isTrue);
  });
}
