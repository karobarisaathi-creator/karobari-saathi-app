import 'package:account_app/core/models/stock_analytics_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';

class StockAnalyticsService {
  static double _lineAmount(TransactionItem line) {
    final amount = line.total > 0 ? line.total : line.quantity * line.rate;
    return amount.isFinite && amount > 0 ? amount : 0;
  }

  static double _discountedSubtotal(
    Transaction transaction,
    List<TransactionItem> lines,
  ) {
    final subtotal = lines.fold<double>(
      0,
      (sum, line) => sum + _lineAmount(line),
    );
    if (transaction.type != 'income' ||
        transaction.discountAmount <= 0 ||
        subtotal <= 0) {
      return subtotal;
    }

    final transactionSubtotal = transaction.subtotal > 0
        ? transaction.subtotal
        : transaction.items.fold<double>(
            0,
            (sum, line) => sum + _lineAmount(line),
          );
    if (transactionSubtotal <= 0) return subtotal;

    final discountShare =
        (transaction.discountAmount * (subtotal / transactionSubtotal))
            .clamp(0.0, subtotal)
            .toDouble();
    return subtotal - discountShare;
  }

  static List<StockMovement> includeUnlinkedTransactions({
    required List<StockItem> items,
    required List<StockMovement> movements,
    required List<Transaction> transactions,
    Map<String, String> partyNamesById = const {},
  }) {
    final trackedItems = {
      for (final item in items)
        if (item.trackStock) item.id: item,
    };
    final transactionsById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    final datedMovements = movements.map((movement) {
      final transactionId = movement.transactionId.isNotEmpty
          ? movement.transactionId
          : movement.note.startsWith('Transaction ')
              ? movement.note.substring('Transaction '.length)
              : '';
      final transaction = transactionsById[transactionId];
      if (transaction == null) return movement;
      var unitPrice = movement.unitPrice;
      if (movement.type == StockMovementType.sale &&
          transaction.type == 'income' &&
          transaction.discountAmount > 0) {
        final itemLines = transaction.items
            .where((line) =>
                line.stockItemId == movement.stockItemId && line.quantity > 0)
            .toList(growable: false);
        final quantity = itemLines.fold<double>(
          0,
          (total, line) => total + line.quantity,
        );
        if (quantity > 0) {
          unitPrice = _discountedSubtotal(transaction, itemLines) / quantity;
        }
      }
      return StockMovement(
        id: movement.id,
        stockItemId: movement.stockItemId,
        stockItemName: movement.stockItemName,
        type: movement.type,
        quantity: movement.quantity,
        unitPrice: unitPrice,
        reason: movement.reason,
        note: movement.note,
        partyId: movement.partyId.isNotEmpty
            ? movement.partyId
            : transaction.accountId,
        partyName: movement.partyName.isNotEmpty
            ? movement.partyName
            : partyNamesById[transaction.accountId] ?? '',
        transactionId: movement.transactionId,
        timestamp: transaction.date,
      );
    }).toList(growable: false);
    final linkedMovements = <String>{
      for (final movement in datedMovements)
        if (movement.transactionId.isNotEmpty)
          '${movement.transactionId}:${movement.stockItemId}',
      for (final movement in datedMovements)
        if (movement.note.startsWith('Transaction '))
          '${movement.note.substring('Transaction '.length)}:${movement.stockItemId}',
    };
    final result = [...datedMovements];

    for (final transaction in transactions) {
      final linkedItems = <String, List<TransactionItem>>{};
      for (final line in transaction.items) {
        final itemId = line.stockItemId;
        if (itemId == null ||
            itemId.isEmpty ||
            line.quantity <= 0 ||
            !trackedItems.containsKey(itemId)) {
          continue;
        }
        linkedItems.putIfAbsent(itemId, () => []).add(line);
      }

      for (final entry in linkedItems.entries) {
        if (linkedMovements.contains('${transaction.id}:${entry.key}')) {
          continue;
        }
        final item = trackedItems[entry.key]!;
        final lines = entry.value;
        final quantity = lines.fold<double>(
          0,
          (total, line) => total + line.quantity,
        );
        final netTotal = _discountedSubtotal(transaction, lines);
        result.add(
          StockMovement(
            id: 'legacy_tx_${transaction.id}_${entry.key}',
            stockItemId: item.id,
            stockItemName: item.name,
            type: transaction.type == 'income'
                ? StockMovementType.sale
                : StockMovementType.purchase,
            quantity: quantity,
            unitPrice: quantity > 0 ? netTotal / quantity : 0,
            reason: 'Legacy transaction fallback',
            note: 'Transaction ${transaction.id}',
            partyId: transaction.accountId,
            partyName: partyNamesById[transaction.accountId] ?? '',
            transactionId: transaction.id,
            timestamp: transaction.date,
          ),
        );
      }
    }
    return result;
  }

  static List<StockPartyStats> buildPartyStats({
    required List<StockItem> items,
    required List<StockMovement> movements,
    required DateTime start,
    required DateTime endExclusive,
    Map<String, String> partyNamesById = const {},
    required String cashCustomerId,
    required String cashCustomerName,
    required String unknownCustomerName,
    required String unnamedSupplierName,
  }) {
    final trackedItems = {
      for (final item in items)
        if (item.trackStock) item.id: item,
    };
    final parties = <String, _MutablePartyStats>{};

    for (final movement in movements) {
      if (!_within(movement.timestamp, start, endExclusive)) continue;
      final item = trackedItems[movement.stockItemId];
      if (item == null ||
          movement.timestamp.isBefore(item.createdAt) ||
          movement.reason == 'Initial Opening Stock') {
        continue;
      }

      final isSale = movement.type == StockMovementType.sale ||
          movement.type == StockMovementType.customerReturn;
      final isPurchase = movement.type == StockMovementType.purchase ||
          movement.type == StockMovementType.supplierReturn;
      if (!isSale && !isPurchase) continue;

      final isCashCustomer = movement.partyId == cashCustomerId ||
          (isSale && movement.partyId.isEmpty && movement.partyName.isEmpty);
      final partyId = isCashCustomer ? cashCustomerId : movement.partyId;
      final partyName = isCashCustomer
          ? cashCustomerName
          : (movement.partyName.isNotEmpty
              ? movement.partyName
              : partyNamesById[movement.partyId] ??
                  (isSale ? unknownCustomerName : unnamedSupplierName));
      final key = '${isSale ? 'sale' : 'purchase'}:$partyId';
      final party = parties.putIfAbsent(
        key,
        () => _MutablePartyStats(
          partyId: partyId,
          partyName: partyName,
          isSale: isSale,
        ),
      );
      final isReturn = movement.type == StockMovementType.customerReturn ||
          movement.type == StockMovementType.supplierReturn;
      final sign = isReturn ? -1.0 : 1.0;
      final quantity = movement.quantity * sign;
      final value = movement.quantity * movement.unitPrice * sign;
      party.addItem(item, quantity, value);
    }

    final result = parties.values.map((party) => party.toStats()).toList()
      ..sort((a, b) => b.totalValue.abs().compareTo(a.totalValue.abs()));
    return result;
  }

  static StockYearlyStats buildYearlyStats({
    required List<StockItem> items,
    required List<StockMovement> movements,
    required int year,
  }) {
    final months = List.generate(
      12,
      (index) => _MutableMonth(year, index + 1),
    );
    final trackedItems = {
      for (final item in items)
        if (item.trackStock) item.id: item,
    };
    final states = {
      for (final item in trackedItems.values) item.id: _ItemState(item),
    };
    final sortedMovements = [...movements]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var movementIndex = 0;

    for (var monthIndex = 0; monthIndex < months.length; monthIndex++) {
      final periodEnd = DateTime(year, monthIndex + 2);
      while (movementIndex < sortedMovements.length &&
          sortedMovements[movementIndex].timestamp.isBefore(periodEnd)) {
        final movement = sortedMovements[movementIndex++];
        final item = trackedItems[movement.stockItemId];
        if (item == null ||
            movement.timestamp.isBefore(item.createdAt) ||
            movement.reason == 'Initial Opening Stock') {
          continue;
        }
        final state = states[item.id]!;
        _applyMovement(
          item: item,
          state: state,
          movement: movement,
          onPurchase: (quantity, value) {
            if (movement.timestamp.year == year &&
                movement.type == StockMovementType.purchase) {
              final month = months[movement.timestamp.month - 1];
              month.purchaseQuantity += quantity;
              month.purchaseValue += value;
              month.purchaseIds.add(_movementKey(movement));
            }
          },
          onSale: (quantity, revenue, profit, uncostedQuantity) {
            if (movement.timestamp.year == year) {
              final month = months[movement.timestamp.month - 1];
              month.salesQuantity += quantity;
              month.salesRevenue += revenue;
              month.grossProfit += profit;
              month.uncostedSalesQuantity += uncostedQuantity;
              if (movement.type == StockMovementType.sale) {
                month.salesIds.add(_movementKey(movement));
              }
              final day = DateTime(
                movement.timestamp.year,
                movement.timestamp.month,
                movement.timestamp.day,
              );
              month.salesByDay.update(
                day,
                (amount) => amount + revenue,
                ifAbsent: () => revenue,
              );
            }
          },
          before: periodEnd,
        );
      }

      for (final item in trackedItems.values) {
        if (!periodEnd.isBefore(item.createdAt)) {
          months[monthIndex].endingStockQuantity += states[item.id]!.quantity;
        }
      }
    }

    return StockYearlyStats(
      year: year,
      months: months.map((month) => month.toStats()).toList(growable: false),
    );
  }

  static List<StockItemStats> buildItemStats({
    required List<StockItem> items,
    required List<StockMovement> movements,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final trackedItems = {
      for (final item in items)
        if (item.trackStock) item.id: item,
    };
    final states = {
      for (final item in trackedItems.values) item.id: _ItemState(item),
    };
    final accumulators = {
      for (final item in trackedItems.values) item.id: _MutableItemStats(item),
    };
    final sortedMovements = [...movements]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final movement in sortedMovements) {
      final item = trackedItems[movement.stockItemId];
      if (item == null ||
          movement.timestamp.isBefore(item.createdAt) ||
          movement.reason == 'Initial Opening Stock') {
        continue;
      }
      final state = states[item.id]!;
      _applyMovement(
        item: item,
        state: state,
        movement: movement,
        onPurchase: (quantity, value) {
          if (_within(movement.timestamp, start, endExclusive) &&
              movement.type == StockMovementType.purchase) {
            final stats = accumulators[item.id]!;
            stats.purchaseQuantity += quantity;
            stats.purchaseValue += value;
          }
        },
        onSale: (quantity, revenue, profit, uncostedQuantity) {
          if (_within(movement.timestamp, start, endExclusive)) {
            final stats = accumulators[item.id]!;
            stats.salesQuantity += quantity;
            stats.salesRevenue += revenue;
            stats.grossProfit += profit;
            stats.uncostedSalesQuantity += uncostedQuantity;
          }
        },
        before: endExclusive,
      );
    }

    return accumulators.values
        .map((stats) {
          if (!endExclusive.isBefore(stats.item.createdAt)) {
            stats.endingStockQuantity = states[stats.item.id]!.quantity;
          }
          return stats.toStats();
        })
        .where((stats) =>
            stats.purchaseQuantity != 0 ||
            stats.salesQuantity != 0 ||
            stats.purchaseValue != 0 ||
            stats.salesRevenue != 0)
        .toList()
      ..sort((a, b) => b.salesRevenue.compareTo(a.salesRevenue));
  }

  static bool _within(DateTime date, DateTime start, DateTime endExclusive) =>
      !date.isBefore(start) && date.isBefore(endExclusive);

  static String _movementKey(StockMovement movement) =>
      movement.transactionId.isNotEmpty ? movement.transactionId : movement.id;

  static void _applyMovement({
    required StockItem item,
    required _ItemState state,
    required StockMovement movement,
    required void Function(double quantity, double value) onPurchase,
    required void Function(
      double quantity,
      double revenue,
      double profit,
      double uncostedQuantity,
    ) onSale,
    DateTime? before,
  }) {
    if (before != null && !movement.timestamp.isBefore(before)) return;
    final quantity = movement.quantity;
    if (!quantity.isFinite || quantity <= 0) return;
    final unitPrice = movement.unitPrice.isFinite ? movement.unitPrice : 0.0;

    switch (movement.type) {
      case StockMovementType.purchase:
        if (movement.reason == 'Initial Opening Stock') return;
        final cost = unitPrice > 0 ? unitPrice : item.purchasePrice;
        onPurchase(quantity, quantity * cost);
        state.addStock(quantity, cost);
        break;
      case StockMovementType.sale:
        final revenue = quantity * unitPrice;
        final costPerUnit =
            state.averageCost > 0 ? state.averageCost : item.purchasePrice;
        final uncostedQuantity = costPerUnit > 0 ? 0.0 : quantity;
        final cogs = quantity * costPerUnit;
        onSale(quantity, revenue, revenue - cogs, uncostedQuantity);
        state.removeStock(quantity, costPerUnit);
        break;
      case StockMovementType.customerReturn:
        final returnCost =
            state.averageCost > 0 ? state.averageCost : item.purchasePrice;
        final revenue = -quantity * unitPrice;
        final uncostedQuantity = returnCost > 0 ? 0.0 : quantity;
        onSale(
          -quantity,
          revenue,
          revenue + quantity * returnCost,
          uncostedQuantity,
        );
        state.addStock(quantity, returnCost);
        break;
      case StockMovementType.supplierReturn:
        final returnCost = unitPrice > 0
            ? unitPrice
            : (state.averageCost > 0 ? state.averageCost : item.purchasePrice);
        onPurchase(-quantity, -quantity * returnCost);
        state.removeStock(quantity, returnCost);
        break;
      case StockMovementType.adjustment:
        final delta = movement.stockDelta;
        if (delta > 0) {
          state.addStock(delta,
              state.averageCost > 0 ? state.averageCost : item.purchasePrice);
        } else if (delta < 0) {
          state.removeStock(-delta, state.averageCost);
        }
        break;
    }
  }
}

class _ItemState {
  double quantity;
  double costValue;

  _ItemState(StockItem item)
      : quantity = item.initialQuantity,
        costValue = item.initialQuantity * item.purchasePrice;

  double get averageCost {
    if (quantity <= 0 || costValue <= 0) return 0;
    return costValue / quantity;
  }

  void addStock(double amount, double unitCost) {
    if (amount <= 0) return;
    final validCost = unitCost.isFinite && unitCost > 0 ? unitCost : 0.0;
    if (quantity < 0) {
      final clearsNegativeStock = amount.clamp(0.0, -quantity);
      quantity += clearsNegativeStock;
      amount -= clearsNegativeStock;
      if (amount <= 0) return;
    }
    quantity += amount;
    costValue += amount * validCost;
  }

  void removeStock(double amount, double fallbackCost) {
    if (amount <= 0) return;
    final currentCost = averageCost > 0 ? averageCost : fallbackCost;
    final removedFromAvailable = amount.clamp(0.0, quantity);
    quantity -= amount;
    costValue = (costValue - removedFromAvailable * currentCost)
        .clamp(0.0, double.infinity);
  }
}

class _MutableMonth {
  final int year;
  final int month;
  double salesRevenue = 0;
  double purchaseValue = 0;
  double purchaseQuantity = 0;
  double salesQuantity = 0;
  double grossProfit = 0;
  double endingStockQuantity = 0;
  double uncostedSalesQuantity = 0;
  final Set<String> salesIds = {};
  final Set<String> purchaseIds = {};
  final Map<DateTime, double> salesByDay = {};

  _MutableMonth(this.year, this.month);

  StockMonthlyStats toStats() {
    DateTime? bestSalesDay;
    var bestDaySales = 0.0;
    for (final entry in salesByDay.entries) {
      if (bestSalesDay == null || entry.value > bestDaySales) {
        bestSalesDay = entry.key;
        bestDaySales = entry.value;
      }
    }
    return StockMonthlyStats(
      year: year,
      month: month,
      salesRevenue: salesRevenue,
      purchaseValue: purchaseValue,
      purchaseQuantity: purchaseQuantity,
      salesQuantity: salesQuantity,
      grossProfit: grossProfit,
      salesCount: salesIds.length,
      purchaseCount: purchaseIds.length,
      endingStockQuantity: endingStockQuantity,
      uncostedSalesQuantity: uncostedSalesQuantity,
      bestSalesDay: bestSalesDay,
      bestDaySales: bestDaySales,
    );
  }
}

class _MutableItemStats {
  final StockItem item;
  double purchaseQuantity = 0;
  double salesQuantity = 0;
  double purchaseValue = 0;
  double salesRevenue = 0;
  double grossProfit = 0;
  double endingStockQuantity = 0;
  double uncostedSalesQuantity = 0;

  _MutableItemStats(this.item);

  StockItemStats toStats() => StockItemStats(
        itemId: item.id,
        name: item.name,
        nameUrdu: item.nameUrdu,
        unit: item.unit,
        purchaseQuantity: purchaseQuantity,
        salesQuantity: salesQuantity,
        purchaseValue: purchaseValue,
        salesRevenue: salesRevenue,
        grossProfit: grossProfit,
        endingStockQuantity: endingStockQuantity,
        uncostedSalesQuantity: uncostedSalesQuantity,
      );
}

class _MutablePartyStats {
  final String partyId;
  final String partyName;
  final bool isSale;
  final Map<String, _MutablePartyItemStats> items = {};

  _MutablePartyStats({
    required this.partyId,
    required this.partyName,
    required this.isSale,
  });

  void addItem(StockItem item, double quantity, double value) {
    items
        .putIfAbsent(item.id, () => _MutablePartyItemStats(item))
        .add(quantity, value);
  }

  StockPartyStats toStats() {
    final itemStats = items.values.map((item) => item.toStats()).toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return StockPartyStats(
      partyId: partyId,
      partyName: partyName,
      isSale: isSale,
      totalValue: itemStats.fold(0, (total, item) => total + item.value),
      items: itemStats,
    );
  }
}

class _MutablePartyItemStats {
  final StockItem item;
  double quantity = 0;
  double value = 0;

  _MutablePartyItemStats(this.item);

  void add(double amount, double total) {
    quantity += amount;
    value += total;
  }

  StockPartyItemStats toStats() => StockPartyItemStats(
        itemId: item.id,
        itemName: item.name,
        itemNameUrdu: item.nameUrdu,
        unit: item.unit,
        quantity: quantity,
        value: value,
      );
}
