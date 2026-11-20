// lib/core/services/contract_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:uuid/uuid.dart';

class ContractService extends ChangeNotifier {
  static const String boxName = 'contracts_box_v1';
  Box? _box;
  bool _isLoading = true;
  List<ContractModel> _contracts = [];
  Object? _initializationError;
  late final Future<void> _initialization;
  StreamSubscription<BoxEvent>? _boxSubscription;
  static const Uuid _uuid = Uuid();

  bool get isLoading => _isLoading;
  List<ContractModel> get contracts => List.unmodifiable(_contracts);

  ContractService() {
    _initialization = _init();
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        _box = await Hive.openBox(boxName);
      } else {
        _box = Hive.box(boxName);
      }
      _loadFromBox();
      _boxSubscription = _box!.watch().listen(
        (_) => _loadFromBox(),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Contract storage watch failed: $error');
        },
      );
    } catch (e) {
      debugPrint('Error initializing ContractService: $e');
      _initializationError = e;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadFromBox() {
    final rawList = _box!.values.toList();
    _contracts = rawList
        .whereType<Map>()
        .map((item) => ContractModel.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _ensureInitialized() async {
    await _initialization;
    if (_initializationError != null) {
      throw StateError(
          'Contract storage could not be initialized: $_initializationError');
    }
    if (_box == null) {
      throw StateError('Contract storage is not initialized.');
    }
  }

  ContractModel _requireContract(String contractId) {
    for (final contract in _contracts) {
      if (contract.id == contractId) return contract;
    }
    throw StateError('Contract not found: $contractId');
  }

  String? contractIdForPayrollPayment(String paymentId) {
    for (final contract in _contracts) {
      if (contract.laborPayments
          .any((payment) => payment.workerPayrollPaymentId == paymentId)) {
        return contract.id;
      }
    }
    return null;
  }

  Future<void> syncPayrollLaborPayment({
    required String paymentId,
    required String workerId,
    required String workerName,
    required double amount,
    required DateTime date,
    required String note,
    required String? contractId,
  }) async {
    await _ensureInitialized();
    _validatePaymentAmount(amount);

    ContractModel? targetContract;
    if (contractId != null) {
      targetContract = _requireContract(contractId);
      if (!targetContract.isIncoming) {
        throw StateError(
            'Payroll payments can only be linked to incoming contracts.');
      }
    }

    final updates = <String, ContractModel>{};
    for (final contract in _contracts) {
      final remaining = contract.laborPayments
          .where((payment) => payment.workerPayrollPaymentId != paymentId)
          .toList();
      if (remaining.length != contract.laborPayments.length) {
        updates[contract.id] = contract.copyWith(laborPayments: remaining);
      }
    }

    if (targetContract != null) {
      final updatedPayment = ContractLaborPayment(
        id: 'payroll_$paymentId',
        workerName: workerName,
        amount: amount,
        date: date,
        note: note,
        workerId: workerId,
        workerPayrollPaymentId: paymentId,
      );
      final current = updates[targetContract.id] ?? targetContract;
      updates[targetContract.id] = current.copyWith(
        laborPayments: [...current.laborPayments, updatedPayment],
      );
    }

    if (updates.isEmpty) return;
    final originals = {
      for (final contract in _contracts)
        if (updates.containsKey(contract.id)) contract.id: contract,
    };
    try {
      for (final entry in updates.entries) {
        await _box!.put(entry.key, entry.value.toMap());
      }
    } catch (error) {
      for (final entry in originals.entries) {
        await _box!.put(entry.key, entry.value.toMap());
      }
      _loadFromBox();
      rethrow;
    }
    _loadFromBox();
  }

  ContractPayment? _findClientPayment(
      ContractModel contract, String paymentId) {
    for (final payment in contract.payments) {
      if (payment.id == paymentId) return payment;
    }
    return null;
  }

  ContractLaborPayment? _findLaborPayment(
      ContractModel contract, String paymentId) {
    for (final payment in contract.laborPayments) {
      if (payment.id == paymentId) return payment;
    }
    return null;
  }

  void _validatePaymentAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
          amount, 'amount', 'Must be a positive finite amount.');
    }
  }

  Account? _findWorkerAccount(DatabaseService databaseService, String name) {
    final normalizedName = name.trim().toLowerCase();
    for (final account in databaseService.accounts) {
      if (account.name.trim().toLowerCase() == normalizedName) return account;
    }
    return null;
  }

  Transaction _clientTransaction(
    ContractModel contract,
    ContractPayment payment, {
    Transaction? existing,
  }) {
    final note = payment.note.isNotEmpty ? payment.note : 'Installment';
    return Transaction(
      id: 'contract_${contract.id}_${payment.id}',
      accountId: contract.partyId,
      amount: payment.amount,
      type: contract.isIncoming ? 'income' : 'expense',
      category: contract.isIncoming ? 'ٹھیکہ وصولی' : 'ٹھیکہ ادائیگی',
      description: '${contract.title}: $note',
      date: payment.date,
      quantity: 1,
      rate: payment.amount,
      receivedAmount: contract.isIncoming ? payment.amount : 0,
      pendingAmount: 0,
      paymentMethod: existing?.paymentMethod ?? 'cash',
      isPending: false,
      createdAt: existing?.createdAt ?? payment.date,
      updatedAt: DateTime.now(),
    );
  }

  Transaction _laborTransaction(
    ContractModel contract,
    ContractLaborPayment payment,
    String accountId, {
    Transaction? existing,
  }) {
    final note = payment.note.isNotEmpty ? payment.note : 'Worker Wage';
    return Transaction(
      id: 'labor_${contract.id}_${payment.id}',
      accountId: accountId,
      amount: payment.amount,
      type: 'expense',
      category: 'مزدوری',
      description: 'Contract Labor Wage: ${contract.title} - $note',
      date: payment.date,
      quantity: 1,
      rate: payment.amount,
      receivedAmount: 0,
      pendingAmount: 0,
      paymentMethod: existing?.paymentMethod ?? 'cash',
      isPending: false,
      createdAt: existing?.createdAt ?? payment.date,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> addContract(ContractModel contract) async {
    await _ensureInitialized();
    if (contract.id.trim().isEmpty) {
      throw ArgumentError.value(contract.id, 'id', 'Contract ID is required.');
    }
    if (contract.totalAmount <= 0 || !contract.totalAmount.isFinite) {
      throw ArgumentError.value(contract.totalAmount, 'totalAmount',
          'Must be a positive finite amount.');
    }
    if (_box!.containsKey(contract.id)) {
      throw StateError('Contract already exists: ${contract.id}');
    }
    await _box!.put(contract.id, contract.toMap());
    _loadFromBox();
  }

  Future<void> updateContract(ContractModel contract) async {
    await _ensureInitialized();
    final existing = _requireContract(contract.id);
    if (!contract.totalAmount.isFinite || contract.totalAmount <= 0) {
      throw ArgumentError.value(contract.totalAmount, 'totalAmount',
          'Must be a positive finite amount.');
    }
    if (contract.totalAmount < existing.totalPaid) {
      throw StateError(
          'Contract amount cannot be less than the installments already paid.');
    }
    if (existing.partyId.isNotEmpty &&
        contract.partyId != existing.partyId &&
        existing.payments.isNotEmpty) {
      throw StateError(
          'The party account cannot change after installments are recorded.');
    }
    if (contract.isIncoming != existing.isIncoming &&
        (existing.payments.isNotEmpty || existing.laborPayments.isNotEmpty)) {
      throw StateError(
          'Contract direction cannot change after payments are recorded.');
    }
    final updated = contract.copyWith(updatedAt: DateTime.now());
    await _box!.put(updated.id, updated.toMap());
    _loadFromBox();
  }

  Future<void> deleteContract(
    String contractId, {
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    final contract = _requireContract(contractId);
    for (final payment in contract.payments) {
      await databaseService
          .deleteTransaction('contract_${contract.id}_${payment.id}');
    }
    for (final payment in contract.laborPayments) {
      await databaseService
          .deleteTransaction('labor_${contract.id}_${payment.id}');
    }
    await _box!.delete(contractId);
    _loadFromBox();
  }

  Future<void> addClientPayment({
    required String contractId,
    required double amount,
    required String note,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    _validatePaymentAmount(amount);
    final contract = _requireContract(contractId);
    if (contract.partyId.trim().isEmpty) {
      throw StateError(
          'A party account is required before recording contract installments.');
    }
    if (amount > contract.remainingBalance) {
      throw StateError('Payment exceeds the remaining contract balance.');
    }
    final now = DateTime.now();
    final newPayment = ContractPayment(
      id: _uuid.v4(),
      amount: amount,
      date: now,
      note: note.isNotEmpty ? note : 'Contract Installment',
    );
    await updateContract(
        contract.copyWith(payments: [...contract.payments, newPayment]));
    if (contract.partyId.isNotEmpty) {
      await databaseService
          .addTransaction(_clientTransaction(contract, newPayment));
    }
  }

  Future<void> addLaborPayment({
    required String contractId,
    required String workerName,
    required double amount,
    required String note,
    DatabaseService? databaseService,
  }) async {
    await _ensureInitialized();
    _validatePaymentAmount(amount);
    final contract = _requireContract(contractId);
    if (!contract.isIncoming || contract.status == 'completed') {
      throw StateError(
          'Labor payments are only allowed for active incoming contracts.');
    }
    final now = DateTime.now();
    final newLaborPayment = ContractLaborPayment(
      id: _uuid.v4(),
      workerName: workerName,
      amount: amount,
      date: now,
      note: note.isNotEmpty ? note : 'Worker Wage',
    );
    await updateContract(contract
        .copyWith(laborPayments: [...contract.laborPayments, newLaborPayment]));
    if (databaseService != null) {
      final account = _findWorkerAccount(databaseService, workerName);
      if (account != null) {
        await databaseService.addTransaction(
            _laborTransaction(contract, newLaborPayment, account.id));
      }
    }
  }

  Future<void> editLaborPayment({
    required String contractId,
    required String paymentId,
    required String workerName,
    required double amount,
    required String note,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    _validatePaymentAmount(amount);
    final contract = _requireContract(contractId);
    final oldPayment = _findLaborPayment(contract, paymentId);
    if (oldPayment == null) {
      throw StateError('Labor payment not found: $paymentId');
    }
    final account = _findWorkerAccount(databaseService, workerName);
    final transactionId = 'labor_${contract.id}_$paymentId';
    final oldTransaction = databaseService.getTransaction(transactionId);
    final accountId = account?.id ?? oldTransaction?.accountId;
    final updatedPayments = contract.laborPayments.map((p) {
      if (p.id == paymentId) {
        return ContractLaborPayment(
          id: p.id,
          workerName: workerName,
          amount: amount,
          date: p.date,
          note: note,
        );
      }
      return p;
    }).toList();
    await updateContract(contract.copyWith(laborPayments: updatedPayments));
    if (accountId != null) {
      final transaction = _laborTransaction(
        contract,
        updatedPayments.firstWhere((payment) => payment.id == paymentId),
        accountId,
        existing: oldTransaction,
      );
      if (oldTransaction == null) {
        await databaseService.addTransaction(transaction);
      } else {
        await databaseService.updateTransaction(transaction);
      }
    }
  }

  Future<void> deleteLaborPayment({
    required String contractId,
    required String paymentId,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    final contract = _requireContract(contractId);
    if (!contract.laborPayments.any((payment) => payment.id == paymentId)) {
      throw StateError('Labor payment not found: $paymentId');
    }
    await databaseService.deleteTransaction('labor_${contract.id}_$paymentId');
    final updatedPayments = contract.laborPayments
        .where((payment) => payment.id != paymentId)
        .toList();
    await updateContract(contract.copyWith(laborPayments: updatedPayments));
  }

  Future<void> deleteClientPayment({
    required String contractId,
    required String paymentId,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    final contract = _requireContract(contractId);
    if (!contract.payments.any((payment) => payment.id == paymentId)) {
      throw StateError('Contract payment not found: $paymentId');
    }
    await databaseService
        .deleteTransaction('contract_${contract.id}_$paymentId');
    final updatedPayments =
        contract.payments.where((payment) => payment.id != paymentId).toList();
    await updateContract(contract.copyWith(payments: updatedPayments));
  }

  Future<void> editClientPayment({
    required String contractId,
    required String paymentId,
    required double amount,
    required String note,
    required DatabaseService databaseService,
  }) async {
    await _ensureInitialized();
    _validatePaymentAmount(amount);
    final contract = _requireContract(contractId);
    final oldPayment = _findClientPayment(contract, paymentId);
    if (oldPayment == null) {
      throw StateError('Contract payment not found: $paymentId');
    }
    if (amount > contract.remainingBalance + oldPayment.amount) {
      throw StateError('Payment exceeds the remaining contract balance.');
    }
    final updatedPayment = ContractPayment(
      id: oldPayment.id,
      amount: amount,
      date: oldPayment.date,
      note: note.isNotEmpty ? note : 'Contract Installment',
    );
    final updatedContract = contract.copyWith(
      payments: contract.payments
          .map((payment) => payment.id == paymentId ? updatedPayment : payment)
          .toList(),
    );
    await updateContract(updatedContract);
    if (contract.partyId.isNotEmpty) {
      final transactionId = 'contract_${contract.id}_${updatedPayment.id}';
      final existing = databaseService.getTransaction(transactionId);
      final transaction = _clientTransaction(
        contract,
        updatedPayment,
        existing: existing,
      );
      if (existing == null) {
        await databaseService.addTransaction(transaction);
      } else {
        await databaseService.updateTransaction(transaction);
      }
    }
  }
}
