import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/stock_analytics_service.dart';

StockItem _item({
  String id = 'item-1',
  double openingQuantity = 10,
  double purchasePrice = 5,
}) {
  final createdAt = DateTime(2025);
  return StockItem(
    id: id,
    name: 'Product',
    unit: 'Pieces',
    initialQuantity: openingQuantity,
    purchasePrice: purchasePrice,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

StockMovement _movement({
  required String id,
  required StockMovementType type,
  required double quantity,
  required double unitPrice,
  required DateTime timestamp,
  String itemId = 'item-1',
  String reason = '',
  String transactionId = '',
  String partyId = '',
  String partyName = '',
}) {
  return StockMovement(
    id: id,
    stockItemId: itemId,
    stockItemName: 'Product',
    type: type,
    quantity: quantity,
    unitPrice: unitPrice,
    timestamp: timestamp,
    reason: reason,
    partyId: partyId,
    partyName: partyName,
    transactionId: transactionId,
  );
}

Transaction _transaction({
  required String id,
  required String type,
  required DateTime date,
  required List<TransactionItem> items,
  String accountId = 'account',
  double discountAmount = 0,
  double? subtotal,
}) {
  final itemsSubtotal = items.fold<double>(
    0,
    (total, item) => total + item.total,
  );
  return Transaction(
    id: id,
    accountId: accountId,
    amount: itemsSubtotal - discountAmount,
    subtotal: subtotal ?? itemsSubtotal,
    discountAmount: discountAmount,
    type: type,
    category: type == 'income' ? 'Sale' : 'Purchase',
    description: type,
    date: date,
    createdAt: date,
    updatedAt: date,
    items: items,
  );
}

void main() {
  group('StockAnalyticsService', () {
    test('calculates quantities and gross profit from stock movements', () {
      final stats = StockAnalyticsService.buildYearlyStats(
        items: [_item()],
        movements: [
          _movement(
            id: 'purchase',
            type: StockMovementType.purchase,
            quantity: 10,
            unitPrice: 7,
            timestamp: DateTime(2026, 1, 10),
          ),
          _movement(
            id: 'sale',
            type: StockMovementType.sale,
            quantity: 8,
            unitPrice: 12,
            timestamp: DateTime(2026, 1, 20),
            transactionId: 'sale-tx',
          ),
          _movement(
            id: 'opening-log',
            type: StockMovementType.purchase,
            quantity: 10,
            unitPrice: 5,
            timestamp: DateTime(2026, 1, 1),
            reason: 'Initial Opening Stock',
          ),
        ],
        year: 2026,
      );
      final january = stats.months.first;

      expect(january.purchaseQuantity, 10);
      expect(january.purchaseValue, 70);
      expect(january.salesQuantity, 8);
      expect(january.salesRevenue, 96);
      expect(january.grossProfit, 48);
      expect(january.endingStockQuantity, 12);
      expect(january.salesCount, 1);
      expect(january.purchaseCount, 1);
    });

    test('uses pre-period purchases for moving average cost', () {
      final stats = StockAnalyticsService.buildYearlyStats(
        items: [_item(openingQuantity: 0, purchasePrice: 0)],
        movements: [
          _movement(
            id: 'old-purchase',
            type: StockMovementType.purchase,
            quantity: 4,
            unitPrice: 5,
            timestamp: DateTime(2025, 12, 1),
          ),
          _movement(
            id: 'new-sale',
            type: StockMovementType.sale,
            quantity: 2,
            unitPrice: 9,
            timestamp: DateTime(2026, 2, 4),
          ),
        ],
        year: 2026,
      );

      expect(stats.months[1].grossProfit, 8);
      expect(stats.months[1].endingStockQuantity, 2);
    });

    test('legacy linked transactions fill only missing stock movements', () {
      final existing = _movement(
        id: 'synced-sale',
        type: StockMovementType.sale,
        quantity: 1,
        unitPrice: 12,
        timestamp: DateTime(2026, 1, 10),
        transactionId: 'existing',
      );
      final transactions = [
        _transaction(
          id: 'existing',
          type: 'income',
          date: DateTime(2026, 1, 3),
          items: [
            TransactionItem(
              description: 'Product',
              quantity: 1,
              rate: 12,
              total: 12,
              stockItemId: 'item-1',
            ),
          ],
        ),
        _transaction(
          id: 'legacy',
          type: 'income',
          date: DateTime(2026, 1, 4),
          items: [
            TransactionItem(
              description: 'Product',
              quantity: 2,
              rate: 14,
              total: 28,
              stockItemId: 'item-1',
            ),
          ],
        ),
      ];

      final movements = StockAnalyticsService.includeUnlinkedTransactions(
        items: [_item()],
        movements: [existing],
        transactions: transactions,
        partyNamesById: {'account': 'Customer A'},
      );

      expect(movements, hasLength(2));
      expect(movements.first.timestamp, DateTime(2026, 1, 3));
      expect(
        movements.where((movement) => movement.transactionId == 'existing'),
        hasLength(1),
      );
      final legacy = movements.singleWhere(
        (movement) => movement.transactionId == 'legacy',
      );
      expect(legacy.type, StockMovementType.sale);
      expect(legacy.quantity, 2);
      expect(legacy.unitPrice, 14);
      expect(legacy.partyId, 'account');
      expect(legacy.partyName, 'Customer A');
      expect(movements.first.partyName, 'Customer A');
    });

    test('discount is distributed across linked and fallback stock sales', () {
      final transaction = _transaction(
        id: 'discounted-sale',
        type: 'income',
        date: DateTime(2026, 1, 4),
        discountAmount: 20,
        subtotal: 100,
        items: [
          TransactionItem(
            description: 'Product 1',
            quantity: 1,
            rate: 50,
            total: 50,
            stockItemId: 'item-1',
          ),
          TransactionItem(
            description: 'Product 2',
            quantity: 1,
            rate: 50,
            total: 50,
            stockItemId: 'item-2',
          ),
        ],
      );
      final movements = StockAnalyticsService.includeUnlinkedTransactions(
        items: [_item(id: 'item-1'), _item(id: 'item-2')],
        movements: [
          _movement(
            id: 'existing-sale',
            type: StockMovementType.sale,
            quantity: 1,
            unitPrice: 50,
            timestamp: DateTime(2026, 1, 4),
            transactionId: transaction.id,
          ),
        ],
        transactions: [transaction],
      );

      expect(movements, hasLength(2));
      expect(
        movements.every((movement) => movement.unitPrice == 40),
        isTrue,
      );
      final stats = StockAnalyticsService.buildYearlyStats(
        items: [_item(id: 'item-1'), _item(id: 'item-2')],
        movements: movements,
        year: 2026,
      );
      expect(stats.salesRevenue, 80);
    });

    test('item report returns period movement values and ending stock', () {
      final rows = StockAnalyticsService.buildItemStats(
        items: [_item()],
        movements: [
          _movement(
            id: 'purchase',
            type: StockMovementType.purchase,
            quantity: 6,
            unitPrice: 8,
            timestamp: DateTime(2026, 5, 2),
          ),
          _movement(
            id: 'sale',
            type: StockMovementType.sale,
            quantity: 3,
            unitPrice: 12,
            timestamp: DateTime(2026, 5, 4),
          ),
          _movement(
            id: 'outside',
            type: StockMovementType.sale,
            quantity: 2,
            unitPrice: 12,
            timestamp: DateTime(2026, 6, 1),
          ),
        ],
        start: DateTime(2026, 5),
        endExclusive: DateTime(2026, 6),
      );

      expect(rows, hasLength(1));
      expect(rows.single.purchaseQuantity, 6);
      expect(rows.single.salesQuantity, 3);
      expect(rows.single.grossProfit, 17.625);
      expect(rows.single.endingStockQuantity, 13);
    });

    test('party report groups sales, purchases, returns, and cash sales', () {
      final parties = StockAnalyticsService.buildPartyStats(
        items: [_item()],
        movements: [
          _movement(
            id: 'customer-sale',
            type: StockMovementType.sale,
            quantity: 4,
            unitPrice: 12,
            timestamp: DateTime(2026, 5, 2),
            partyId: 'customer',
          ),
          _movement(
            id: 'customer-return',
            type: StockMovementType.customerReturn,
            quantity: 1,
            unitPrice: 12,
            timestamp: DateTime(2026, 5, 3),
            partyId: 'customer',
          ),
          _movement(
            id: 'cash-sale',
            type: StockMovementType.sale,
            quantity: 2,
            unitPrice: 10,
            timestamp: DateTime(2026, 5, 4),
            partyId: 'cash',
          ),
          _movement(
            id: 'supplier-purchase',
            type: StockMovementType.purchase,
            quantity: 8,
            unitPrice: 5,
            timestamp: DateTime(2026, 5, 5),
            partyId: 'supplier',
          ),
          _movement(
            id: 'supplier-return',
            type: StockMovementType.supplierReturn,
            quantity: 2,
            unitPrice: 5,
            timestamp: DateTime(2026, 5, 6),
            partyId: 'supplier',
          ),
          _movement(
            id: 'outside-period',
            type: StockMovementType.sale,
            quantity: 100,
            unitPrice: 12,
            timestamp: DateTime(2026, 6, 1),
            partyId: 'customer',
          ),
        ],
        start: DateTime(2026, 5),
        endExclusive: DateTime(2026, 6),
        partyNamesById: {
          'customer': 'Customer A',
          'supplier': 'Supplier A',
        },
        cashCustomerId: 'cash',
        cashCustomerName: 'Cash sales',
        unknownCustomerName: 'Unknown customer',
        unnamedSupplierName: 'Unknown supplier',
      );

      final customer =
          parties.singleWhere((party) => party.partyId == 'customer');
      final cash = parties.singleWhere((party) => party.partyId == 'cash');
      final supplier =
          parties.singleWhere((party) => party.partyId == 'supplier');

      expect(customer.partyName, 'Customer A');
      expect(customer.isSale, isTrue);
      expect(customer.items.single.quantity, 3);
      expect(customer.totalValue, 36);
      expect(cash.partyName, 'Cash sales');
      expect(cash.totalValue, 20);
      expect(supplier.partyName, 'Supplier A');
      expect(supplier.isSale, isFalse);
      expect(supplier.items.single.quantity, 6);
      expect(supplier.totalValue, 30);
    });
  });
}
