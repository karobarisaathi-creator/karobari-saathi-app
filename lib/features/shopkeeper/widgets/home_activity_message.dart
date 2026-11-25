import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/formatters.dart';

class HomeActivityMessage {
  final String text;
  final bool canAddToLedger;
  final bool isRelevant;

  const HomeActivityMessage({
    required this.text,
    required this.canAddToLedger,
    required this.isRelevant,
  });

  factory HomeActivityMessage.fromNotification(
    AppNotification notification, {
    required bool isUrdu,
  }) {
    final data = notification.data ?? const <String, dynamic>{};
    final sender = _value(data['senderName'], isUrdu ? 'صارف' : 'A user');
    final description = _value(data['description'], '');
    final kind = _value(data['activityKind'], '');
    final reference = _value(data['referenceNumber'], '');
    final transactionType = _value(data['transactionType'], '');
    final amount = _number(data['amount']);
    final pendingAmount = _number(data['pendingAmount']);
    final receivedAmount = _number(data['receivedAmount']);
    final isAdded = data['isAdded'] == true;

    if (kind == 'worker_assignment') {
      return HomeActivityMessage(
        text: description.isNotEmpty
            ? description
            : _workerAssignmentMessage(sender, isUrdu),
        canAddToLedger: false,
        isRelevant: true,
      );
    }

    if (reference.startsWith(Transaction.workerWageAccrualReference) ||
        kind == 'worker_wage_due') {
      final days = _number(data['days']);
      final wageAmount = _currency(data['wageAmount'] ?? data['amount']);
      final message = description.isNotEmpty
          ? description
          : days > 0
              ? (isUrdu
                  ? '$sender: ${_quantity(days)} دن کی مزدوری واجب ہے، $wageAmount۔'
                  : '$sender: wages due for ${_quantity(days)} days, $wageAmount.')
              : (isUrdu
                  ? '$sender کے ذمے آپ کی مزدوری $wageAmount۔'
                  : '$sender owes you wages: $wageAmount.');
      return HomeActivityMessage(
        text: message,
        canAddToLedger: false,
        isRelevant: true,
      );
    }

    if (reference.startsWith(Transaction.workerWagePaymentReference) ||
        kind == 'worker_wage_payment') {
      return HomeActivityMessage(
        text: description.isNotEmpty
            ? description
            : isUrdu
                ? '$sender نے مزدوری ادا کی: ${_currency(data['amount'])}۔'
                : '$sender paid wages: ${_currency(data['amount'])}.',
        canAddToLedger: false,
        isRelevant: true,
      );
    }

    if (kind == 'contract_installment' ||
        _containsAny(_value(data['category'], ''), ['قسط', 'installment'])) {
      final isReceivedBySender = transactionType == 'income';
      return HomeActivityMessage(
        text: description.isNotEmpty
            ? description
            : isUrdu
                ? isReceivedBySender
                    ? '$sender سے قسط وصول ہوئی: ${_currency(amount)}۔'
                    : '$sender کو قسط ادا ہوئی: ${_currency(amount)}۔'
                : isReceivedBySender
                    ? 'Installment received from $sender: ${_currency(amount)}.'
                    : 'Installment paid to $sender: ${_currency(amount)}.',
        canAddToLedger: !isAdded,
        isRelevant: true,
      );
    }

    final items = data['items'];
    final isQuickBill =
        data['isQuickBill'] == true || (items is List && items.isNotEmpty);
    if (isQuickBill) {
      final total = _currency(data['amount']);
      final message = description.isNotEmpty
          ? description
          : transactionType == 'expense'
              ? isUrdu
                  ? '$sender سے خریداری: $total۔'
                  : 'Purchase from $sender: $total.'
              : isUrdu
                  ? '$sender کا فوری بل: $total۔'
                  : 'Quick bill from $sender: $total.';
      return HomeActivityMessage(
        text: message,
        canAddToLedger: !isAdded,
        isRelevant: true,
      );
    }

    final message = description.isNotEmpty
        ? description
        : _ledgerMessage(
            sender: sender,
            transactionType: transactionType,
            amount: amount,
            pendingAmount: pendingAmount,
            receivedAmount: receivedAmount,
            isUrdu: isUrdu,
          );
    return HomeActivityMessage(
      text: message,
      canAddToLedger: !isAdded,
      isRelevant: notification.type == NotificationType.transaction,
    );
  }

  static String _ledgerMessage({
    required String sender,
    required String transactionType,
    required double amount,
    required double pendingAmount,
    required double receivedAmount,
    required bool isUrdu,
  }) {
    if (pendingAmount > 0 && transactionType == 'income') {
      return isUrdu
          ? '$sender کے کھاتے میں آپ کے ذمے ${_currency(pendingAmount)}۔'
          : 'You owe ${_currency(pendingAmount)} to $sender.';
    }
    if (pendingAmount > 0 && transactionType == 'expense') {
      return isUrdu
          ? '$sender کے ذمے ${_currency(pendingAmount)}۔'
          : '$sender owes you ${_currency(pendingAmount)}.';
    }
    if (receivedAmount > 0 && transactionType == 'income') {
      return isUrdu
          ? '$sender نے ${_currency(receivedAmount)} وصول کیے۔'
          : '$sender received ${_currency(receivedAmount)} from you.';
    }
    if (receivedAmount > 0 && transactionType == 'expense') {
      return isUrdu
          ? '$sender نے آپ کو ${_currency(receivedAmount)} ادا کیے۔'
          : '$sender paid you ${_currency(receivedAmount)}.';
    }
    return isUrdu
        ? '$sender کا لین دین: ${_currency(amount)}۔'
        : 'Transaction with $sender: ${_currency(amount)}.';
  }

  static String _workerAssignmentMessage(String sender, bool isUrdu) {
    return isUrdu
        ? '$sender نے آپ کو کام میں شامل کیا۔'
        : '$sender added you to a job.';
  }

  static bool _containsAny(String value, List<String> candidates) {
    final normalized = value.toLowerCase();
    return candidates.any((candidate) => normalized.contains(candidate));
  }

  static String _currency(Object? value) =>
      Formatters.formatAmountWithCurrency(_number(value));

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _quantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  static String _value(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
