import 'package:flutter/material.dart';
import 'package:account_app/core/models/account_model.dart';
import 'base_service.dart';

class AccountService extends BaseService {
  Future<void> addAccount(Account account) async {
    await accountsBox?.put(account.id, account);
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    await accountsBox?.put(account.id, account);
    notifyListeners();
  }

  Future<void> deleteAccount(String accountId) async {
    final account = accountsBox?.get(accountId);
    if (account == null) return;
    final transactionsToDelete = transactionsBox?.values.where((t) => t.accountId == accountId).toList() ?? [];
    for (var transaction in transactionsToDelete) {
      await transactionsBox?.delete(transaction.id);
      if (auth.currentUser != null) {
        await firestore.collection('users').doc(auth.currentUser!.uid).collection('transactions').doc(transaction.id).delete();
      }
    }
    await accountsBox?.delete(accountId);
    notifyListeners();
  }

  List<Account> getAccounts() => accountsBox?.values.toList() ?? [];
  Account? getAccount(String id) => accountsBox?.get(id);

  Future<void> recalculateAccountBalance(String accountId) async {
    final account = accountsBox?.get(accountId);
    if (account != null) {
      final transactions = transactionsBox?.values.where((t) => t.accountId == accountId).toList() ?? [];
      double pendingIncome = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.pendingAmount);
      double pendingExpense = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.pendingAmount);
      double newBalance = account.initialBalance + pendingIncome - pendingExpense;
      await accountsBox?.put(account.id, account.copyWith(balance: newBalance));
    }
  }

  Future<int> getPartiesCount() async => accountsBox?.length ?? 0;
  Future<int> getPendingDuesCount() async => accountsBox?.values.where((p) => p.balance != 0).length ?? 0;

  Future<void> updateMyVerificationStatus(bool isVerified) async {
    final user = auth.currentUser;
    if (user == null || accountsBox == null) return;
    try {
      final myAccount = accountsBox!.values.firstWhere((a) => a.phone == user.phoneNumber);
      await accountsBox!.put(myAccount.id, myAccount.copyWith(isVerified: isVerified));
      notifyListeners();
    } catch (_) {}
  }
}