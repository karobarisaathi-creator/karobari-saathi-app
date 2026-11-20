import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 11, 20);

  test('earned wage is credit and wage payment is debit in worker account', () {
    final earnedWage = Transaction(
      id: 'earned',
      accountId: 'worker',
      amount: 1200,
      type: 'income',
      category: 'حاضری کی واجب اجرت',
      description: 'حاضری کی واجب اجرت',
      referenceNumber: '${Transaction.workerWageAccrualReference}:attendance_1',
      date: date,
      createdAt: date,
      updatedAt: date,
    );
    final wagePayment = Transaction(
      id: 'paid',
      accountId: 'worker',
      amount: 500,
      type: 'expense',
      category: 'اجرت کی ادائیگی',
      description: 'اجرت کی ادائیگی',
      referenceNumber: '${Transaction.workerWagePaymentReference}:payment_1',
      date: date,
      createdAt: date,
      updatedAt: date,
    );

    expect(earnedWage.isWorkerPayrollTransaction, isTrue);
    expect(wagePayment.isWorkerPayrollTransaction, isTrue);
    expect(AccountBalanceUtils.transactionColumns(earnedWage).credit, 1200);
    expect(AccountBalanceUtils.transactionColumns(wagePayment).debit, 500);
    expect(
      AccountBalanceUtils.ledgerBalance([earnedWage, wagePayment]),
      -700,
    );
  });

  test('ordinary wage-related transactions are not marked as payroll journals',
      () {
    final ordinaryExpense = Transaction(
      id: 'ordinary',
      accountId: 'worker',
      amount: 500,
      type: 'expense',
      category: 'مزدوری',
      description: 'Other labor expense',
      date: date,
      createdAt: date,
      updatedAt: date,
    );

    expect(ordinaryExpense.isWorkerPayrollTransaction, isFalse);
  });
}
