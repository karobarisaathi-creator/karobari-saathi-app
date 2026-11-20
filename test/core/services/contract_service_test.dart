import 'dart:io';

import 'package:account_app/core/models/contract_model.dart';
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
      partyId: '',
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
}

class _NoopDatabaseService implements DatabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
