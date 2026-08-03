import 'package:account_app/core/models/work_log_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'base_service.dart';
import 'transaction_service.dart';

class WorkLogService extends BaseService {
  final TransactionService _transactionService = TransactionService();

  Future<void> addWorkLog(WorkLog log, {bool syncToKhata = true}) async {
    await workLogsBox?.put(log.id, log);

    if (syncToKhata) {
      final transaction = model.Transaction(
        id: 'log_${log.id}',
        accountId: log.accountId,
        amount: log.totalAmount,
        type: 'income',
        category: 'Service',
        description: log.description,
        date: log.date,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        professionId: log.professionId,
      );
      await _transactionService.addTransaction(transaction);
    }

    notifyListeners();
  }

  List<WorkLog> getWorkLogs() {
    return workLogsBox?.values.toList().reversed.toList() ?? [];
  }

  Future<void> deleteWorkLog(String id) async {
    await workLogsBox?.delete(id);
    notifyListeners();
  }
}
