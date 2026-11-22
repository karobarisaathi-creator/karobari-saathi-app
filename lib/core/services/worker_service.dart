// lib/core/services/worker_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/worker_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/worker_payroll_service.dart';

class WorkerService extends ChangeNotifier {
  static const String _boxName = 'workers_box_v1';
  static const Uuid _uuid = Uuid();
  Box? _box;
  List<WorkerModel> _workers = [];

  List<WorkerModel> get workers => _workers;

  WorkerService() {
    _init();
  }

  Future<void> _init() async {
    if (_box == null || !(_box?.isOpen ?? false)) {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
    }
    _loadWorkers();
  }

  Future<void> ensureInitialized() async {
    await _init();
  }

  Future<List<Account>> ensureWorkerAccounts(
      DatabaseService databaseService) async {
    await _init();
    final accounts = <Account>[];
    for (final worker in _workers) {
      var account = databaseService.getAccount(worker.id);
      if (account == null) {
        final now = DateTime.now();
        account = Account(
          id: worker.id,
          name: worker.name,
          phone: worker.phone,
          category: 'worker',
          initialBalance: 0,
          balanceType: 'Receivable',
          balance: 0,
          createdAt: worker.createdAt,
          updatedAt: now,
        );
        await databaseService.addAccount(account);
      }
      accounts.add(account);
    }
    return accounts;
  }

  void _loadWorkers() {
    if (_box == null) return;
    try {
      _workers = _box!.values
          .map((e) {
            if (e is Map) {
              return WorkerModel.fromMap(e);
            }
            return null;
          })
          .whereType<WorkerModel>()
          .toList();

      // Sort by creation date desc
      _workers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading workers: $e');
    }
  }

  Future<void> addWorker({
    required String name,
    required String phone,
    required String skill,
    required DatabaseService databaseService,
  }) async {
    await _init();
    final id = _uuid.v4();
    final now = DateTime.now();
    final worker = WorkerModel(
      id: id,
      name: name,
      phone: phone,
      skill: skill,
      createdAt: now,
    );

    await databaseService.addAccount(
      Account(
        id: id,
        name: name,
        phone: phone,
        category: 'worker',
        initialBalance: 0,
        balanceType: 'Receivable',
        balance: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _box!.put(id, worker.toMap());
    _loadWorkers();
  }

  Future<void> updateWorker(WorkerModel worker) async {
    await _init();
    await _box?.put(worker.id, worker.toMap());
    _loadWorkers();
  }

  Future<void> deleteWorker({
    required String id,
    required DatabaseService databaseService,
    required WorkerPayrollService payrollService,
    required ContractService contractService,
  }) async {
    await _init();
    await payrollService.deleteWorkerRecords(
      workerId: id,
      databaseService: databaseService,
      contractService: contractService,
    );
    await databaseService.deleteAccount(id);
    await _box!.delete(id);
    _loadWorkers();
  }
}
