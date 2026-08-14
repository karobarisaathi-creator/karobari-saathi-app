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
    if (transaction.professionId != null) await _professionService.recalculateProfessionFinance(transaction.professionId!);
    notifyListeners();
  }

  Future<void> updateTransaction(model.Transaction transaction) async {
    final oldTransaction = transactionsBox?.get(transaction.id);
    await transactionsBox?.put(transaction.id, transaction);
    await _accountService.recalculateAccountBalance(transaction.accountId);
    if (transaction.professionId != null) await _professionService.recalculateProfessionFinance(transaction.professionId!);
    if (oldTransaction?.professionId != null && oldTransaction?.professionId != transaction.professionId) {
      await _professionService.recalculateProfessionFinance(oldTransaction!.professionId!);
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final transaction = transactionsBox?.get(transactionId);
    if (transaction != null) {
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

}