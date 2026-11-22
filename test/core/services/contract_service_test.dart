import 'dart:io';

import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late ContractService contractService;

  setUpAll(() async {
    hiveDirectory =
        await Directory.systemTemp.createTemp('contract-service-test-');
    Hive.init(hiveDirectory.path);
    contractService = ContractService();
  });

  tearDownAll(() async {
    contractService.dispose();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('syncs payroll payments into one contract and moves/removes them',
      () async {
    final now = DateTime(2026, 11, 20);
    final firstContract = ContractModel(
      id: 'contract-1',
      partyId: 'party',
      partyName: 'Customer',
      title: 'Kitchen',
      totalAmount: 10000,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    );
    final secondContract = firstContract.copyWith(
      title: 'Store',
      updatedAt: now,
    );
    await contractService.addContract(firstContract);
    await contractService.addContract(
      ContractModel(
        id: 'contract-2',
        partyId: secondContract.partyId,
        partyName: secondContract.partyName,
        title: secondContract.title,
        totalAmount: secondContract.totalAmount,
        startDate: secondContract.startDate,
        createdAt: secondContract.createdAt,
        updatedAt: secondContract.updatedAt,
      ),
    );

    await contractService.syncPayrollLaborPayment(
      paymentId: 'payment-1',
      workerId: 'worker-1',
      workerName: 'Ali',
      amount: 1500,
      date: now,
      note: 'Advance',
      contractId: firstContract.id,
    );
    await contractService.syncPayrollLaborPayment(
      paymentId: 'payment-1',
      workerId: 'worker-1',
      workerName: 'Ali',
      amount: 2000,
      date: now,
      note: 'Updated',
      contractId: firstContract.id,
    );

    var linked = contractService.contracts
        .singleWhere((contract) => contract.id == firstContract.id);
    expect(linked.totalLaborPaid, 2000);
    expect(linked.laborPayments, hasLength(1));
    expect(contractService.contractIdForPayrollPayment('payment-1'),
        firstContract.id);

    await contractService.syncPayrollLaborPayment(
      paymentId: 'payment-1',
      workerId: 'worker-1',
      workerName: 'Ali',
      amount: 2000,
      date: now,
      note: 'Updated',
      contractId: 'contract-2',
    );
    expect(
      contractService.contracts
          .singleWhere((contract) => contract.id == firstContract.id)
          .totalLaborPaid,
      0,
    );
    expect(
      contractService.contracts
          .singleWhere((contract) => contract.id == 'contract-2')
          .totalLaborPaid,
      2000,
    );

    await contractService.syncPayrollLaborPayment(
      paymentId: 'payment-1',
      workerId: 'worker-1',
      workerName: 'Ali',
      amount: 2000,
      date: now,
      note: 'Updated',
      contractId: null,
    );
    expect(
      contractService.contracts
          .every((contract) => contract.laborPayments.isEmpty),
      isTrue,
    );
    expect(contractService.contractIdForPayrollPayment('payment-1'), isNull);
  });

  test('completed work can still collect an outstanding client balance',
      () async {
    final now = DateTime(2026, 11, 20);
    final contract = ContractModel(
      id: 'completed-contract',
      partyId: 'customer',
      partyName: 'Customer',
      title: 'Finished project',
      totalAmount: 10000,
      status: 'completed',
      startDate: now,
      createdAt: now,
      updatedAt: now,
    );
    await contractService.addContract(contract);

    await contractService.addClientPayment(
      contractId: contract.id,
      amount: 2500,
      note: 'Final collection',
      databaseService: _NoopDatabaseService(),
    );

    final updatedContract =
        contractService.contracts.singleWhere((item) => item.id == contract.id);
    expect(updatedContract.status, 'completed');
    expect(updatedContract.totalPaid, 2500);
    expect(updatedContract.remainingBalance, 7500);
    await expectLater(
      contractService.addClientPayment(
        contractId: contract.id,
        amount: 8000,
        note: 'Over collection',
        databaseService: _NoopDatabaseService(),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('editing a given contract preserves direction and paid amount limits',
      () async {
    final now = DateTime(2026, 11, 20);
    final contract = ContractModel(
      id: 'given-contract',
      partyId: 'contractor',
      partyName: 'Contractor',
      title: 'Roof repair',
      totalAmount: 10000,
      isIncoming: false,
      startDate: now,
      payments: [
        ContractPayment(
          id: 'installment-1',
          amount: 3000,
          date: now,
          note: 'Advance',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await contractService.addContract(contract);

    await expectLater(
      contractService.updateContract(contract.copyWith(isIncoming: true)),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      contractService.updateContract(contract.copyWith(partyId: 'another')),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      contractService.updateContract(contract.copyWith(totalAmount: 2500)),
      throwsA(isA<StateError>()),
    );

    final unchanged =
        contractService.contracts.singleWhere((item) => item.id == contract.id);
    expect(unchanged.isIncoming, isFalse);
    expect(unchanged.totalAmount, 10000);
  });

  test('cannot record a contract installment without a linked party account',
      () async {
    final now = DateTime(2026, 11, 20);
    await contractService.addContract(
      ContractModel(
        id: 'unlinked-contract',
        partyId: '',
        partyName: 'Unlinked Party',
        title: 'Unlinked work',
        totalAmount: 10000,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await expectLater(
      contractService.addClientPayment(
        contractId: 'unlinked-contract',
        amount: 1000,
        note: 'Advance',
        databaseService: _NoopDatabaseService(),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('deleting a contract unlinks but keeps its expense transaction',
      () async {
    final now = DateTime(2026, 11, 20);
    final contract = ContractModel(
      id: 'contract-with-expense',
      partyId: 'customer',
      partyName: 'Customer',
      title: 'Kitchen',
      totalAmount: 10000,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    );
    final databaseService = _NoopDatabaseService()
      ..seedTransaction(
        Transaction(
          id: 'material-expense',
          accountId: 'default_account',
          amount: 1250,
          type: 'expense',
          category: 'EXP:Materials',
          description: 'Cement',
          date: now,
          createdAt: now,
          updatedAt: now,
          contractId: contract.id,
        ),
      );
    await contractService.addContract(contract);

    await contractService.deleteContract(
      contract.id,
      databaseService: databaseService,
    );

    expect(
      databaseService.transactions.single.contractId,
      isNull,
    );
    expect(databaseService.transactions.single.amount, 1250);
    expect(
      contractService.contracts.any((item) => item.id == contract.id),
      isFalse,
    );
  });
}

class _NoopDatabaseService implements DatabaseService {
  final List<Transaction> _transactions = [];

  @override
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  void seedTransaction(Transaction transaction) {
    _transactions.add(transaction);
  }

  @override
  Future<bool> addTransaction(Transaction transaction) async => true;

  @override
  Future<bool> updateTransaction(Transaction transaction) async {
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index >= 0) _transactions[index] = transaction;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
