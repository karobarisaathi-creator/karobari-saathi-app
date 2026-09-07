import 'package:flutter/material.dart';
import 'package:account_app/core/models/account_model.dart';
import 'base_service.dart';

class AccountService extends BaseService {
  Future<void> addAccount(Account account) async {
    // 1. Save locally (Guaranteed success)
    await accountsBox?.put(account.id, account);
    notifyListeners();

    // 2. Fire and Forget Cloud Sync (Don't make user wait)
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('accounts')
          .doc(account.id)
          .set(account.toMap())
          .catchError(
              (e) => debugPrint("Offline Sync: Account addition delayed"));
    }
  }

  Future<void> updateAccount(Account account) async {
    // 1. Update locally
    await accountsBox?.put(account.id, account);
    notifyListeners();

    // 2. Fire and Forget Cloud Sync
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('accounts')
          .doc(account.id)
          .update(account.toMap())
          .catchError(
              (e) => debugPrint("Offline Sync: Account update delayed"));
    }
  }

  Future<void> deleteAccount(String accountId) async {
    final account = accountsBox?.get(accountId);
    if (account == null) return;
    final transactionsToDelete = transactionsBox?.values
            .where((t) => t.accountId == accountId)
            .toList() ??
        [];
    for (var transaction in transactionsToDelete) {
      await transactionsBox?.delete(transaction.id);
      if (auth.currentUser != null) {
        await firestore
            .collection('users')
            .doc(auth.currentUser!.uid)
            .collection('transactions')
            .doc(transaction.id)
            .delete();
      }
    }

    // 🆕 کلاؤڈ سے اکاؤنٹ ڈیلیٹ کریں (Fire and Forget)
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('accounts')
          .doc(accountId)
          .delete()
          .catchError(
              (e) => debugPrint("Offline Sync: Account deletion delayed"));
    }

    await accountsBox?.delete(accountId);
    notifyListeners();
  }

  List<Account> getAccounts() => accountsBox?.values.toList() ?? [];
  Account? getAccount(String id) => accountsBox?.get(id);

  Future<void> recalculateAccountBalance(String accountId) async {
    final account = accountsBox?.get(accountId);
    if (account != null) {
      final transactions = transactionsBox?.values
              .where((t) => t.accountId == accountId)
              .toList() ??
          [];
      double income = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      double expense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);
      double openingBalance = account.initialBalance;
      if (account.balanceType.toLowerCase() == 'payable') {
        openingBalance = -openingBalance;
      }
      double newBalance = openingBalance + income - expense;
      await accountsBox?.put(account.id, account.copyWith(balance: newBalance));
    }
  }

  Future<int> getPartiesCount() async => accountsBox?.length ?? 0;
  Future<int> getPendingDuesCount() async =>
      accountsBox?.values.where((p) => p.balance != 0).length ?? 0;

  Future<void> updateMyVerificationStatus(bool isVerified) async {
    final user = auth.currentUser;
    if (user == null || accountsBox == null) return;
    try {
      final myAccount =
          accountsBox!.values.firstWhere((a) => a.phone == user.phoneNumber);
      await accountsBox!
          .put(myAccount.id, myAccount.copyWith(isVerified: isVerified));
      notifyListeners();
    } catch (_) {}
  }
}
