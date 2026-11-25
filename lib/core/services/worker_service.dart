// lib/core/services/worker_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/worker_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/worker_payroll_service.dart';
import 'package:account_app/core/utils/formatters.dart';

class WorkerService extends ChangeNotifier {
  static const String boxName = 'workers_box_v1';
  static const String _boxName = boxName;
  static const String _hiddenWorkerKeyPrefix = 'directory_hidden_';
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
    DatabaseService databaseService, {
    WorkerPayrollService? payrollService,
    ContractService? contractService,
  }) async {
    await _init();
    final accounts = <Account>[];
    for (final worker in _workers) {
      if (isHiddenFromDirectory(worker.id)) continue;
      var account = databaseService.getAccount(worker.id);
      final samePhoneAndName = worker.phone.trim().isEmpty
          ? <Account>[]
          : databaseService.accounts.where((candidate) {
              return candidate.isActive &&
                  candidate.phone.trim().isNotEmpty &&
                  Formatters.phoneNumbersMatch(
                    worker.phone,
                    candidate.phone,
                  ) &&
                  _normalizedName(candidate.name) ==
                      _normalizedName(worker.name);
            }).toList()
        ..sort((first, second) => first.createdAt.compareTo(second.createdAt));

      if (samePhoneAndName.isNotEmpty) {
        final nonWorkerAccounts = samePhoneAndName
            .where((candidate) => !candidate.isWorkerAccount)
            .toList();
        final canonical = nonWorkerAccounts.isNotEmpty
            ? nonWorkerAccounts.first
            : samePhoneAndName.first;
        if (payrollService == null) {
          account ??= canonical;
        } else {
          for (final duplicate in samePhoneAndName) {
            if (duplicate.id == canonical.id || !duplicate.isWorkerAccount) {
              continue;
            }
            await _mergeWorkerAccount(
              duplicate: duplicate,
              canonical: canonical,
              databaseService: databaseService,
              payrollService: payrollService,
              contractService: contractService,
            );
          }
          account = databaseService.getAccount(canonical.id) ?? canonical;
          if (!account.isWorkerAccount) {
            account = _asWorkerAccount(account);
            await databaseService.updateAccount(account);
          }
          await _rekeyWorker(worker, account.id);
        }
      }

      if (account == null) {
        final matchingAccounts = databaseService.accounts.where((candidate) {
          final samePhone = worker.phone.trim().isNotEmpty &&
              candidate.phone.trim().isNotEmpty &&
              Formatters.phoneNumbersMatch(worker.phone, candidate.phone);
          return samePhone;
        }).toList();
        final exactNameMatches = matchingAccounts
            .where((candidate) =>
                _normalizedName(candidate.name) == _normalizedName(worker.name))
            .toList();
        final candidates =
            exactNameMatches.isNotEmpty ? exactNameMatches : matchingAccounts;
        if (candidates.length > 1) {
          throw StateError(
            'Multiple accounts match worker "${worker.name}". '
            'Resolve the duplicate accounts before continuing.',
          );
        }

        if (candidates.isNotEmpty) {
          account = candidates.single;
          if (payrollService != null) {
            await payrollService.reassignWorkerId(
              fromWorkerId: worker.id,
              toWorkerId: account.id,
              databaseService: databaseService,
              contractService: contractService,
            );
          }
          await _rekeyWorker(worker, account.id);
          if (!account.isWorkerAccount) {
            account = _asWorkerAccount(account);
            await databaseService.updateAccount(account);
          }
        } else {
          final now = DateTime.now();
          account = Account(
            id: worker.id,
            name: worker.name,
            phone: worker.phone,
            accountType: 'worker',
            initialBalance: 0,
            balanceType: 'Receivable',
            balance: 0,
            createdAt: worker.createdAt,
            updatedAt: now,
          );
          await databaseService.addAccount(account);
        }
      }
      if (!account.isWorkerAccount) {
        account = _asWorkerAccount(account);
        await databaseService.updateAccount(account);
      }
      accounts.add(account);
    }

    final includedIds = accounts.map((account) => account.id).toSet();
    for (final account in databaseService.accounts) {
      if (account.isWorkerAccount &&
          !isHiddenFromDirectory(account.id) &&
          includedIds.add(account.id)) {
        accounts.add(account);
      }
    }

    if (contractService != null) {
      for (final contract in contractService.contracts) {
        for (final laborPayment in contract.laborPayments) {
          Account? account;
          final workerId = laborPayment.workerId?.trim() ?? '';
          if (workerId.isNotEmpty) {
            account = databaseService.getAccount(workerId);
          }
          if (account == null) {
            final normalizedName = _normalizedName(laborPayment.workerName);
            final matches = databaseService.accounts
                .where((candidate) =>
                    _normalizedName(candidate.name) == normalizedName)
                .toList();
            if (matches.length > 1) {
              throw StateError(
                'Multiple accounts match contract worker '
                '"${laborPayment.workerName}". Resolve the duplicate accounts.',
              );
            }
            if (matches.isNotEmpty) account = matches.single;
          }
          if (account == null ||
              !account.isActive ||
              isHiddenFromDirectory(account.id)) {
            continue;
          }
          if (!account.isWorkerAccount) {
            account = _asWorkerAccount(account);
            await databaseService.updateAccount(account);
          }
          if (includedIds.add(account.id)) accounts.add(account);
        }
      }
    }
    return accounts;
  }

  Future<void> _mergeWorkerAccount({
    required Account duplicate,
    required Account canonical,
    required DatabaseService databaseService,
    required WorkerPayrollService payrollService,
    required ContractService? contractService,
  }) async {
    final duplicateOpening = duplicate.balanceType.toLowerCase() == 'payable'
        ? -duplicate.initialBalance
        : duplicate.initialBalance;
    final canonicalOpening = canonical.balanceType.toLowerCase() == 'payable'
        ? -canonical.initialBalance
        : canonical.initialBalance;
    final mergedOpening = duplicateOpening + canonicalOpening;
    final updatedCanonical = _asWorkerAccount(canonical).copyWith(
      initialBalance: mergedOpening.abs(),
      balanceType: mergedOpening < 0 ? 'Payable' : 'Receivable',
      updatedAt: DateTime.now(),
    );
    await databaseService.updateAccount(updatedCanonical);

    await payrollService.reassignWorkerId(
      fromWorkerId: duplicate.id,
      toWorkerId: canonical.id,
      databaseService: databaseService,
      contractService: contractService,
    );

    await databaseService.updateAccount(
      duplicate.copyWith(
        accountType: 'general',
        initialBalance: 0,
        balanceType: 'none',
        balance: 0,
        isActive: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Set<String> get hiddenAccountIds {
    final box = _box;
    if (box == null || !box.isOpen) return const {};
    return box.keys
        .whereType<String>()
        .where((key) =>
            key.startsWith(_hiddenWorkerKeyPrefix) && box.get(key) == true)
        .map((key) => key.substring(_hiddenWorkerKeyPrefix.length))
        .toSet();
  }

  bool isHiddenFromDirectory(String accountId) =>
      hiddenAccountIds.contains(accountId);

  Future<void> hideFromDirectory(String accountId) async {
    await _init();
    await _box!.put('$_hiddenWorkerKeyPrefix$accountId', true);
    _loadWorkers();
  }

  Future<void> showInDirectory(String accountId) async {
    await _init();
    await _box!.delete('$_hiddenWorkerKeyPrefix$accountId');
    _loadWorkers();
  }

  Future<Account> markAccountAsWorker(
    Account account,
    DatabaseService databaseService,
  ) async {
    await _init();
    if (account.isWorkerAccount) {
      await showInDirectory(account.id);
      return account;
    }

    final workerAccount = _asWorkerAccount(account);
    await databaseService.updateAccount(workerAccount);
    await showInDirectory(account.id);
    return workerAccount;
  }

  Future<void> _rekeyWorker(WorkerModel worker, String accountId) async {
    if (worker.id == accountId) return;
    if (!_box!.containsKey(accountId)) {
      await _box!.put(accountId, worker.copyWith(id: accountId).toMap());
    }
    await _box!.delete(worker.id);
  }

  String _normalizedName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Account _asWorkerAccount(Account account) {
    final oldAccountType = account.accountType.trim();
    final existingProfession = account.profession?.trim() ?? '';
    final recoveredProfession = existingProfession.isNotEmpty
        ? existingProfession
        : Account.isKnownAccountType(oldAccountType)
            ? null
            : oldAccountType;
    return account.copyWith(
      accountType: 'worker',
      profession: recoveredProfession,
      updatedAt: DateTime.now(),
    );
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
        accountType: 'worker',
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
