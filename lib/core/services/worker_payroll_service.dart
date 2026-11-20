

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/worker_payroll_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/database_service.dart';

class WorkerPayrollService extends ChangeNotifier {
  static const String _boxName = 'worker_payroll_box_v1';
  static const Uuid _uuid = Uuid();

  Box? _box;
  bool _isLoading = true;
  Object? _initializationError;
  late final Future<void> _initialization;
  List<WorkerAttendanceRecord> _attendance = [];
  List<WorkerWageRate> _rates = [];
  List<WorkerWagePayment> _payments = [];

  bool get isLoading => _isLoading;
  List<WorkerAttendanceRecord> get attendance => List.unmodifiable(_attendance);
  List<WorkerWageRate> get rates => List.unmodifiable(_rates);
  List<WorkerWagePayment> get payments => List.unmodifiable(_payments);

  WorkerPayrollService() {
    _initialization = _init();
  }

  Future<void> _init() async {
    try {
      _box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      _loadFromBox();
    } catch (error) {
      _initializationError = error;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureInitialized() async {
    await _initialization;
    if (_initializationError != null) {
      throw StateError(
          'Worker payroll storage could not be initialized: $_initializationError');
    }
    if (_box == null) {
      throw StateError('Worker payroll storage is not initialized.');
    }
  }

  void _loadFromBox() {
    final entries = _box!.values.whereType<Map>().toList();
    _attendance = entries
        .where((entry) => entry['kind'] == 'attendance')
        .map(WorkerAttendanceRecord.fromMap)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _rates = entries
        .where((entry) => entry['kind'] == 'rate')
        .map(WorkerWageRate.fromMap)
        .toList()
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    _payments = entries
        .where((entry) => entry['kind'] == 'payment')
        .map(WorkerWagePayment.fromMap)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _isLoading = false;
    notifyListeners();
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Account _requireWorkerAccount(
    String workerId,
    DatabaseService databaseService,
  ) {
    final account = databaseService.getAccount(workerId);
    if (account == null) {
      throw StateError(
          'Create a worker account before recording attendance or wages.');
    }
    return account;
  }

  String _attendanceTransactionId(WorkerAttendanceRecord record) =>
      'worker_wage_earned_${record.id}';

  Transaction _wagePaymentTransaction(
    WorkerWagePayment payment,
    String accountId, {
    Transaction? existing,
  }) {
    return Transaction(
      id: 'worker_wage_${payment.id}',
      accountId: accountId,
      amount: payment.amount,
      type: 'expense',
      category: 'اجرت کی ادائیگی',
      description: payment.note.isEmpty
          ? 'اجرت کی ادائیگی'
          : 'اجرت کی ادائیگی - ${payment.note}',
      date: payment.date,
      quantity: 1,
      rate: payment.amount,
      receivedAmount: 0,
      pendingAmount: 0,
      referenceNumber:
          '${Transaction.workerWagePaymentReference}:${payment.id}',
      paymentMethod: existing?.paymentMethod ?? 'cash',
      isPending: false,
      createdAt: existing?.createdAt ?? payment.date,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _syncAttendanceLedger(
    WorkerAttendanceRecord record,
    DatabaseService databaseService,
  ) async {
    final account = _requireWorkerAccount(record.workerId, databaseService);
    final transactionId = _attendanceTransactionId(record);
    final existing = databaseService.getTransaction(transactionId);
    final amount = WorkerPayrollCalculator.earningFor(
      record,
      getRatesForWorker(record.workerId),
    );

    if (amount <= 0) {
      if (existing != null) {
        await databaseService.deleteTransaction(transactionId);
      }
      return;
    }

    final transaction = Transaction(
      id: transactionId,
      accountId: account.id,
      amount: amount,
      type: 'income',
      category: 'حاضری کی واجب اجرت',
      description:
          'حاضری کی واجب اجرت - ${_dayKey(record.date)}${record.note.isEmpty ? '' : ' - ${record.note}'}',
      date: record.date,
      quantity: 1,
      rate: amount,
      receivedAmount: amount,
      pendingAmount: 0,
      referenceNumber: '${Transaction.workerWageAccrualReference}:${record.id}',
      isPending: false,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (existing == null) {
      await databaseService.addTransaction(transaction);
    } else {
      await databaseService.updateTransaction(transaction);
    }
  }

  Future<void> reconcileWorkerLedger({
    required String workerId,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    _requireWorkerAccount(workerId, databaseService);
    for (final record in getAttendanceForWorker(workerId)) {
      await _syncAttendanceLedger(record, databaseService);
    }
  }

  WorkerAttendanceRecord? getAttendance(String workerId, DateTime date) {
    final key = _dayKey(date);
    for (final record in _attendance) {
      if (record.workerId == workerId && _dayKey(record.date) == key) {
        return record;
      }
    }
    return null;
  }

  WorkerWageRate? getRateForDate(String workerId, DateTime date) {
    final workerRates =
        _rates.where((rate) => rate.workerId == workerId).toList();
    return WorkerPayrollCalculator.rateForDate(workerRates, date);
  }

  List<WorkerAttendanceRecord> getAttendanceForWorker(String workerId) =>
      _attendance.where((record) => record.workerId == workerId).toList();

  List<WorkerWageRate> getRatesForWorker(String workerId) =>
      _rates.where((rate) => rate.workerId == workerId).toList();

  List<WorkerWagePayment> getPaymentsForWorker(String workerId) =>
      _payments.where((payment) => payment.workerId == workerId).toList();

  Future<void> saveAttendance({
    required String workerId,
    required DateTime date,
    required WorkerAttendanceStatus status,
    String note = '',
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    if (workerId.trim().isEmpty) {
      throw ArgumentError.value(workerId, 'workerId', 'Worker ID is required.');
    }
    _requireWorkerAccount(workerId, databaseService);
    final normalizedDate = _dateOnly(date);
    final id = 'attendance_${workerId}_${_dayKey(normalizedDate)}';
    final previous = getAttendance(workerId, normalizedDate);
    final record = WorkerAttendanceRecord(
      id: id,
      workerId: workerId,
      date: normalizedDate,
      status: status,
      note: note.trim(),
    );
    await _syncAttendanceLedger(record, databaseService);
    try {
      await _box!.put(id, record.toMap());
    } catch (error) {
      if (previous != null) {
        await _syncAttendanceLedger(previous, databaseService);
      } else {
        await databaseService
            .deleteTransaction(_attendanceTransactionId(record));
      }
      rethrow;
    }
    _loadFromBox();
  }

  Future<void> setWageRate({
    required String workerId,
    required WorkerWageType type,
    required double amount,
    required DateTime effectiveFrom,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    if (workerId.trim().isEmpty) {
      throw ArgumentError.value(workerId, 'workerId', 'Worker ID is required.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Wage must be positive.');
    }
    _requireWorkerAccount(workerId, databaseService);
    final effectiveDate = _dateOnly(effectiveFrom);
    final id = 'rate_${workerId}_${_dayKey(effectiveDate)}';
    final previous = _box!.get(id);
    await _box!.put(
      id,
      WorkerWageRate(
        id: id,
        workerId: workerId,
        type: type,
        amount: amount,
        effectiveFrom: effectiveDate,
      ).toMap(),
    );
    _loadFromBox();
    try {
      await reconcileWorkerLedger(
        workerId: workerId,
        databaseService: databaseService,
      );
    } catch (error) {
      if (previous == null) {
        await _box!.delete(id);
      } else {
        await _box!.put(id, previous);
      }
      _loadFromBox();
      await reconcileWorkerLedger(
        workerId: workerId,
        databaseService: databaseService,
      );
      rethrow;
    }
  }

  Future<void> addWagePayment({
    required String workerId,
    required double amount,
    required String note,
    required String? contractId,
    required ContractService contractService,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    if (workerId.trim().isEmpty) {
      throw ArgumentError.value(workerId, 'workerId', 'Worker ID is required.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Payment must be positive.');
    }
    final account = _requireWorkerAccount(workerId, databaseService);
    final payment = WorkerWagePayment(
      id: _uuid.v4(),
      workerId: workerId,
      amount: amount,
      date: DateTime.now(),
      note: note.trim(),
    );
    final transaction = _wagePaymentTransaction(payment, account.id);
    await databaseService.addTransaction(transaction);
    try {
      await _box!.put('payment_${payment.id}', payment.toMap());
      await contractService.syncPayrollLaborPayment(
        paymentId: payment.id,
        workerId: payment.workerId,
        workerName: account.name,
        amount: payment.amount,
        date: payment.date,
        note: payment.note,
        contractId: contractId,
      );
    } catch (error) {
      await contractService.syncPayrollLaborPayment(
        paymentId: payment.id,
        workerId: payment.workerId,
        workerName: account.name,
        amount: payment.amount,
        date: payment.date,
        note: payment.note,
        contractId: null,
      );
      await _box!.delete('payment_${payment.id}');
      await databaseService.deleteTransaction('worker_wage_${payment.id}');
      rethrow;
    }
    _loadFromBox();
  }

  Future<void> editWagePayment({
    required WorkerWagePayment payment,
    required double amount,
    required String note,
    required String? contractId,
    required ContractService contractService,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Payment must be positive.');
    }
    if (!_payments.any((entry) => entry.id == payment.id)) {
      throw StateError('Worker wage payment not found: ${payment.id}');
    }
    final updatedPayment = WorkerWagePayment(
      id: payment.id,
      workerId: payment.workerId,
      amount: amount,
      date: payment.date,
      note: note.trim(),
    );
    final previousContractId =
        contractService.contractIdForPayrollPayment(payment.id);
    final account = databaseService.getAccount(payment.workerId);
    final transactionId = 'worker_wage_${payment.id}';
    final existing = databaseService.getTransaction(transactionId);
    try {
      if (account != null || existing != null) {
        final transaction = _wagePaymentTransaction(
          updatedPayment,
          account?.id ?? existing!.accountId,
          existing: existing,
        );
        if (existing == null) {
          await databaseService.addTransaction(transaction);
        } else {
          await databaseService.updateTransaction(transaction);
        }
      }
      await _box!.put('payment_${payment.id}', updatedPayment.toMap());
      await contractService.syncPayrollLaborPayment(
        paymentId: payment.id,
        workerId: payment.workerId,
        workerName: account?.name ?? payment.workerId,
        amount: amount,
        date: payment.date,
        note: note.trim(),
        contractId: contractId,
      );
    } catch (error) {
      await _box!.put('payment_${payment.id}', payment.toMap());
      if (existing != null) {
        await databaseService.updateTransaction(existing);
      } else {
        await databaseService.deleteTransaction(transactionId);
      }
      await contractService.syncPayrollLaborPayment(
        paymentId: payment.id,
        workerId: payment.workerId,
        workerName: account?.name ?? payment.workerId,
        amount: payment.amount,
        date: payment.date,
        note: payment.note,
        contractId: previousContractId,
      );
      rethrow;
    }
    _loadFromBox();
  }

  Future<void> deleteWagePayment({
    required WorkerWagePayment payment,
    required ContractService contractService,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    final previousContractId =
        contractService.contractIdForPayrollPayment(payment.id);
    final account = databaseService.getAccount(payment.workerId);
    final existingTransaction =
        databaseService.getTransaction('worker_wage_${payment.id}');
    try {
      await contractService.syncPayrollLaborPayment(
        paymentId: payment.id,
        workerId: payment.workerId,
        workerName: account?.name ?? payment.workerId,
        amount: payment.amount,
        date: payment.date,
        note: payment.note,
        contractId: null,
      );
      await databaseService.deleteTransaction('worker_wage_${payment.id}');
      await _box!.delete('payment_${payment.id}');
    } catch (error) {
      await _box!.put('payment_${payment.id}', payment.toMap());
      if (existingTransaction != null) {
        await databaseService.updateTransaction(existingTransaction);
      }
      await contractService.syncPayrollLaborPayment(
        paymentId: payment.id,
        workerId: payment.workerId,
        workerName: account?.name ?? payment.workerId,
        amount: payment.amount,
        date: payment.date,
        note: payment.note,
        contractId: previousContractId,
      );
      rethrow;
    }
    _loadFromBox();
  }
}
