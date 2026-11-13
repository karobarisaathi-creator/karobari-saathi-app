import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/transaction_model.dart';

class StockReturnTransactionUtils {
  static Transaction applyReturn({
    required Transaction transaction,
    required String stockItemId,
    required double quantityToReturn,
  }) {
    const epsilon = 0.000001;
    var remainingToReturn = quantityToReturn;
    var removedSubtotal = 0.0;
    final updatedItemsReversed = <TransactionItem>[];

    for (final line in transaction.items.reversed) {
      if (line.stockItemId != stockItemId ||
          line.quantity <= 0 ||
          remainingToReturn <= epsilon) {
        updatedItemsReversed.add(line);
        continue;
      }

      final removedQuantity =
          remainingToReturn < line.quantity ? remainingToReturn : line.quantity;
      final oldLineTotal =
          line.total > 0 ? line.total : line.quantity * line.rate;
      final remainingQuantity = line.quantity - removedQuantity;
      final remainingLineTotal = remainingQuantity <= epsilon
          ? 0.0
          : oldLineTotal * (remainingQuantity / line.quantity);
      removedSubtotal += oldLineTotal - remainingLineTotal;
      remainingToReturn -= removedQuantity;

      if (remainingQuantity > epsilon) {
        updatedItemsReversed.add(
          TransactionItem(
            description: line.description,
            quantity: remainingQuantity,
            rate: line.rate,
            total: remainingLineTotal,
            unit: line.unit,
            stockItemId: line.stockItemId,
          ),
        );
      }
    }

    if (remainingToReturn > epsilon) {
      throw StateError(
        'Return quantity exceeds the latest transaction quantity.',
      );
    }

    final updatedItems = updatedItemsReversed.reversed.toList();
    final oldSubtotal = transaction.subtotal > 0
        ? transaction.subtotal
        : transaction.items.fold<double>(
            0,
            (total, line) =>
                total +
                (line.total > 0 ? line.total : line.quantity * line.rate),
          );
    final discountReduction = oldSubtotal > 0 && transaction.discountAmount > 0
        ? (transaction.discountAmount * (removedSubtotal / oldSubtotal))
            .clamp(0.0, transaction.discountAmount)
            .toDouble()
        : 0.0;
    final amountReduction = removedSubtotal - discountReduction;
    final updatedAmount =
        (transaction.amount - amountReduction).clamp(0.0, double.infinity);
    final updatedSubtotal =
        (oldSubtotal - removedSubtotal).clamp(0.0, double.infinity);
    final updatedDiscount = (transaction.discountAmount - discountReduction)
        .clamp(0.0, double.infinity);
    final updatedBillTotal =
        (updatedSubtotal - updatedDiscount).clamp(0.0, updatedSubtotal);
    final adjustedReceivedAmount =
        transaction.receivedAmount.clamp(0.0, updatedBillTotal).toDouble();
    final updatedPending =
        (updatedBillTotal - adjustedReceivedAmount).clamp(0.0, double.infinity);

    return Transaction(
      id: transaction.id,
      accountId: transaction.accountId,
      amount: updatedAmount,
      type: transaction.type,
      category: transaction.category,
      description: transaction.description,
      date: transaction.date,
      billImage: transaction.billImage,
      quantity: transaction.quantity,
      rate: transaction.rate,
      receivedAmount: adjustedReceivedAmount,
      pendingAmount: updatedPending,
      referenceNumber: transaction.referenceNumber,
      paymentMethod: transaction.paymentMethod,
      isPending: updatedPending > epsilon,
      createdAt: transaction.createdAt,
      updatedAt: DateTime.now(),
      professionId: transaction.professionId,
      professionName: transaction.professionName,
      partnershipId: transaction.partnershipId,
      voiceNote: transaction.voiceNote,
      items: updatedItems,
      subtotal: updatedSubtotal,
      discountAmount: updatedDiscount,
      discountPercent: transaction.discountPercent,
      discountReason: transaction.discountReason,
      receiptFromCounterparty: transaction.receiptFromCounterparty,
      customerPhone: transaction.customerPhone,
    );
  }
}
