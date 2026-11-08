import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/utils/quick_bill_trust_metrics.dart';
import 'base_service.dart';
import 'account_service.dart';
import 'profession_service.dart';

class TransactionService extends BaseService {
  final AccountService _accountService = AccountService();
  final ProfessionService _professionService = ProfessionService();

  Future<void> updateQuickBillTrustMetrics() async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final metrics =
          QuickBillTrustMetrics.fromTransactions(getAllTransactions());
      final shopRef = firestore.collection('public_shops').doc(user.uid);
      final shopSnapshot = await shopRef.get();
      if (!shopSnapshot.exists) return;

      await shopRef.update({
        'customerCount': metrics.customerCount,
        'quickBillSatisfactionPercent': metrics.satisfiedCustomerPercent,
        'satisfaction': metrics.satisfiedCustomerPercent,
        'quickBillCount': metrics.billCount,
        'trustMetricSource': 'quick_bill',
        'trustCount': FieldValue.delete(),
        'returning': FieldValue.delete(),
      });
    } catch (error, stackTrace) {
      debugPrint('Error updating quick bill trust metrics: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> addTransaction(model.Transaction transaction) async {
    final box = transactionsBox;
    if (box == null) {
      throw StateError('Transaction storage is not initialized.');
    }

    // 1. Save locally first
    await box.put(transaction.id, transaction);
    await _accountService.recalculateAccountBalance(transaction.accountId);

    if (transaction.isQuickBill) {
      unawaited(updateQuickBillTrustMetrics());
    }

    // Recalculate profession finance (this helper now handles master/season hierarchy)
    if (transaction.professionId != null) {
      await _professionService
          .recalculateProfessionFinance(transaction.professionId!);
    }

    notifyListeners();

    // 2. Background Cloud Sync
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap())
          .catchError(
              (e) => debugPrint("Offline Sync: Transaction addition delayed"));
    }
  }

  Future<bool> syncTransactionToCloud(
    model.Transaction transaction, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final user = auth.currentUser;
    if (user == null) return false;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap(), SetOptions(merge: true))
          .timeout(timeout);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Transaction cloud sync not confirmed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> updateTransaction(model.Transaction transaction) async {
    final oldTransaction = transactionsBox?.get(transaction.id);
    final String? oldAccountId = oldTransaction?.accountId;

    // 1. Update locally
    await transactionsBox?.put(transaction.id, transaction);
    await _accountService.recalculateAccountBalance(transaction.accountId);

    // If account was changed, recalculate the old account balance too
    if (oldAccountId != null && oldAccountId != transaction.accountId) {
      await _accountService.recalculateAccountBalance(oldAccountId);
    }

    if (transaction.professionId != null)
      await _professionService
          .recalculateProfessionFinance(transaction.professionId!);
    if (oldTransaction?.professionId != null &&
        oldTransaction?.professionId != transaction.professionId) {
      await _professionService
          .recalculateProfessionFinance(oldTransaction!.professionId!);
    }
    notifyListeners();

    if (transaction.isQuickBill || oldTransaction?.isQuickBill == true) {
      unawaited(updateQuickBillTrustMetrics());
    }

    // 2. Background Cloud Update
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('transactions')
          .doc(transaction.id)
          .update(transaction.toMap())
          .catchError(
              (e) => debugPrint("Offline Sync: Transaction update delayed"));
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    final transaction = transactionsBox?.get(transactionId);
    if (transaction != null) {
      await transactionsBox?.delete(transactionId);
      await _accountService.recalculateAccountBalance(transaction.accountId);
      if (transaction.professionId != null)
        await _professionService
            .recalculateProfessionFinance(transaction.professionId!);
      if (transaction.isQuickBill) {
        unawaited(updateQuickBillTrustMetrics());
      }
      if (auth.currentUser != null) {
        firestore
            .collection('users')
            .doc(auth.currentUser!.uid)
            .collection('transactions')
            .doc(transactionId)
            .delete()
            .catchError((e) =>
                debugPrint("Offline Sync: Transaction deletion delayed"));
      }
      notifyListeners();
    }
  }

  List<model.Transaction> getTransactions(String accountId) =>
      transactionsBox?.values.where((t) => t.accountId == accountId).toList() ??
      [];
  List<model.Transaction> getAllTransactions() =>
      transactionsBox?.values.toList() ?? [];
  model.Transaction? getTransaction(String id) => transactionsBox?.get(id);

  Future<void> cleanUnknownTransactions({
    required Set<String> accountIds,
    required Set<String> professionIds,
  }) async {
    final txs = getAllTransactions();
    final user = auth.currentUser;
    const protectedAccountIds = {
      'default_account',
      'artisan_internal_income',
    };

    for (var t in txs) {
      final isProtectedInternalAccount =
          protectedAccountIds.contains(t.accountId);
      bool isOrphaned =
          !accountIds.contains(t.accountId) && !isProtectedInternalAccount;
      if (!isOrphaned && t.professionId != null) {
        isOrphaned = !professionIds.contains(t.professionId);
      }

      if (isOrphaned) {
        await transactionsBox?.delete(t.id);
        if (user != null) {
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .doc(t.id)
              .delete()
              .catchError((_) {});
        }
      }
    }
  }
}
