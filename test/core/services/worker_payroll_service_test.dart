import 'dart:io';

import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/worker_payroll_model.dart';
import 'package:account_app/core/models/worker_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/worker_payroll_service.dart';
import 'package:account_app/core/services/worker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late WorkerPayrollService service;

  setUpAll(() async {
    hiveDirectory =
        await Directory.systemTemp.createTemp('worker-payroll-service-test-');
    Hive.init(hiveDirectory.path);
    service = WorkerPayrollService();
    for (var attempt = 0; service.isLoading && attempt < 100; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });

  tearDownAll(() async {
    service.dispose();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('reloads payroll records written by backup restore', () async {
    final box = await Hive.openBox('worker_payroll_box_v1');
    await box.put(
      'attendance-1',
      WorkerAttendanceRecord(
        id: 'attendance-1',
        workerId: 'worker-1',
        date: DateTime(2026, 11, 23),
        status: WorkerAttendanceStatus.present,
      ).toMap(),
    );

    for (var attempt = 0;
        service.attendance.isEmpty && attempt < 100;
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(service.attendance, hasLength(1));
    expect(service.attendance.single.id, 'attendance-1');
  });

  test('reassigns payroll history and its ledger transactions to one account',
      () async {
    final box = await Hive.openBox('worker_payroll_box_v1');
    await box.clear();
    final date = DateTime(2026, 11, 23);
    final attendance = WorkerAttendanceRecord(
      id: 'attendance_old-worker_2026-11-23',
      workerId: 'old-worker',
      date: date,
      status: WorkerAttendanceStatus.present,
    );
    final rate = WorkerWageRate(
      id: 'rate_old-worker_2026-11-23',
      workerId: 'old-worker',
      type: WorkerWageType.daily,
      amount: 1500,
      effectiveFrom: date,
    );
    await box.put(attendance.id, attendance.toMap());
    await box.put(rate.id, rate.toMap());

    final transaction = Transaction(
      id: 'worker_wage_earned_${attendance.id}',
      accountId: 'old-worker',
      amount: 1500,
      type: 'income',
      category: 'حاضری کی واجب اجرت',
      description: 'حاضری کی واجب اجرت',
      date: date,
      referenceNumber:
          '${Transaction.workerWageAccrualReference}:${attendance.id}',
      createdAt: date,
      updatedAt: date,
    );
    final databaseService = _MemoryDatabaseService(
      accounts: {
        'worker-account': Account(
          id: 'worker-account',
          name: 'Ali',
          phone: '03001234567',
          category: 'worker',
          initialBalance: 0,
          balanceType: 'Receivable',
          balance: 0,
          createdAt: date,
          updatedAt: date,
        ),
      },
      transactions: [transaction],
    );

    await service.reassignWorkerId(
      fromWorkerId: 'old-worker',
      toWorkerId: 'worker-account',
      databaseService: databaseService,
    );

    expect(service.attendance.single.workerId, 'worker-account');
    expect(service.rates.single.workerId, 'worker-account');
    expect(databaseService.transactions.single.accountId, 'worker-account');
  });

  test('recovers legacy worker type without losing the overwritten profession',
      () async {
    final workerBox = await Hive.openBox('workers_box_v1');
    await workerBox.clear();
    final date = DateTime(2026, 11, 23);
    final worker = WorkerModel(
      id: 'legacy-worker',
      name: 'Ali',
      phone: '03001234567',
      skill: '',
      createdAt: date,
    );
    await workerBox.put(worker.id, worker.toMap());
    final workerService = WorkerService();
    await workerService.ensureInitialized();

    final databaseService = _MemoryDatabaseService(
      accounts: {
        worker.id: Account(
          id: worker.id,
          name: worker.name,
          phone: worker.phone,
          category: 'Electrician',
          initialBalance: 0,
          balanceType: 'none',
          balance: 0,
          createdAt: date,
          updatedAt: date,
        ),
      },
      transactions: [],
    );

    final accounts = await workerService.ensureWorkerAccounts(databaseService);

    expect(accounts.single.accountType, 'worker');
    expect(accounts.single.profession, 'Electrician');
    expect(databaseService.getAccount(worker.id)!.accountType, 'worker');
    await workerBox.clear();
  });
}

class _MemoryDatabaseService implements DatabaseService {
  _MemoryDatabaseService({
    required Map<String, Account> accounts,
    required List<Transaction> transactions,
  })  : _accountById = accounts,
        _transactions = transactions;

  final Map<String, Account> _accountById;
  final List<Transaction> _transactions;

  @override
  List<Account> get accounts => List.unmodifiable(_accountById.values);

  @override
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  @override
  Account? getAccount(String id) => _accountById[id];

  @override
  List<Transaction> getAllTransactions() => List.unmodifiable(_transactions);

  @override
  Transaction? getTransaction(String id) {
    for (final transaction in _transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  Future<bool> updateTransaction(Transaction transaction) async {
    final index =
        _transactions.indexWhere((existing) => existing.id == transaction.id);
    if (index < 0) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    return true;
  }

  @override
  Future<void> updateAccount(Account account) async {
    _accountById[account.id] = account;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
