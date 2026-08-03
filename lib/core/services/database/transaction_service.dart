import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'base_service.dart';
import 'account_service.dart';
import 'profession_service.dart';

class TransactionService extends BaseService {
  final AccountService _accountService = AccountService();
  final ProfessionService _professionService = ProfessionService();

  Future<void> addTransaction(model.Transaction transaction) async {
    await transactionsBox?.put(transaction.id, transaction);
    await _accountService.recalculateAccountBalance(transaction.accountId);
    final account = accountsBox?.get(transaction.accountId);
    if (account != null) await _syncTransactionToSharedUsers(transaction, account);
    if (transaction.professionId != null) await _professionService.recalculateProfessionFinance(transaction.professionId!);
    notifyListeners();
  }

  Future<void> updateTransaction(model.Transaction transaction) async {
    final oldTransaction = transactionsBox?.get(transaction.id);
    await transactionsBox?.put(transaction.id, transaction);
    await _accountService.recalculateAccountBalance(transaction.accountId);
    final account = accountsBox?.get(transaction.accountId);
    if (account != null) await _syncTransactionToSharedUsers(transaction, account);
    if (transaction.professionId != null) await _professionService.recalculateProfessionFinance(transaction.professionId!);
    if (oldTransaction?.professionId != null && oldTransaction?.professionId != transaction.professionId) {
      await _professionService.recalculateProfessionFinance(oldTransaction!.professionId!);
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final transaction = transactionsBox?.get(transactionId);
    if (transaction != null) {
      final account = accountsBox?.get(transaction.accountId);
      if (account != null && account.isShared) await _syncDeleteToSharedUsers(transactionId, account);
      await transactionsBox?.delete(transactionId);
      await _accountService.recalculateAccountBalance(transaction.accountId);
      if (transaction.professionId != null) await _professionService.recalculateProfessionFinance(transaction.professionId!);
      if (auth.currentUser != null) {
        await firestore.collection('users').doc(auth.currentUser!.uid).collection('transactions').doc(transactionId).delete();
      }
      notifyListeners();
    }
  }

  List<model.Transaction> getTransactions(String accountId) => transactionsBox?.values.where((t) => t.accountId == accountId).toList() ?? [];
  List<model.Transaction> getAllTransactions() => transactionsBox?.values.toList() ?? [];
  model.Transaction? getTransaction(String id) => transactionsBox?.get(id);

  Future<void> cleanUnknownTransactions({
    required Set<String> accountIds,
    required Set<String> professionIds,
  }) async {
    final txs = getAllTransactions();
    final user = auth.currentUser;

    for (var t in txs) {
      bool isOrphaned = !accountIds.contains(t.accountId);
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

  Future<void> _syncTransactionToSharedUsers(model.Transaction transaction, Account account) async {
    if (account.isShared && account.sharedWith.isNotEmpty) {
      for (String phone in account.sharedWith) {
        String clean = phone.replaceAll(RegExp(r'\D'), '');
        List<String> formats = ['+$clean', '0${clean.substring(clean.length > 10 ? 2 : 0)}'];
        for (String p in formats) {
          final q = await firestore.collection('users').where('phoneNumber', isEqualTo: p).limit(1).get();
          if (q.docs.isNotEmpty && q.docs.first.id != auth.currentUser?.uid) {
            await firestore.collection('users').doc(q.docs.first.id).collection('transactions').doc(transaction.id).set(transaction.toMap());
          }
        }
      }
    }
  }

  Future<void> _syncDeleteToSharedUsers(String transactionId, Account account) async {
    if (account.isShared && account.sharedWith.isNotEmpty) {
      for (String phone in account.sharedWith) {
        String clean = phone.replaceAll(RegExp(r'\D'), '');
        final q = await firestore.collection('users').where('phoneNumber', isEqualTo: '+$clean').limit(1).get();
        if (q.docs.isNotEmpty && q.docs.first.id != auth.currentUser?.uid) {
          await firestore.collection('users').doc(q.docs.first.id).collection('transactions').doc(transactionId).delete();
        }
      }
    }
  }
}