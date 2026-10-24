import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';

void main() {
  group('Transaction stock links', () {
    test('transaction item preserves stock item id through map conversion', () {
      final item = TransactionItem(
        description: 'Flour',
        quantity: 2,
        rate: 100,
        total: 200,
        unit: 'Kg',
        stockItemId: 'stock_flour',
      );

      final restored = TransactionItem.fromMap(item.toMap());

      expect(restored.stockItemId, 'stock_flour');
      expect(restored.quantity, 2);
      expect(restored.total, 200);
    });

    test('legacy transaction item without stock id remains readable', () {
      final item = TransactionItem.fromMap({
        'description': 'Custom service',
        'quantity': 1,
        'rate': 300,
        'total': 300,
      });

      expect(item.stockItemId, isNull);
      expect(item.description, 'Custom service');
    });

    test('stock movement preserves its originating transaction id', () {
      final movement = StockMovement(
        id: 'tx_sale_1_stock_flour',
        stockItemId: 'stock_flour',
        stockItemName: 'Flour',
        type: StockMovementType.sale,
        quantity: 2,
        unitPrice: 100,
        transactionId: 'sale_1',
        timestamp: DateTime(2026, 10, 4),
      );

      final restored = StockMovement.fromMap(movement.toMap());

      expect(restored.transactionId, 'sale_1');
      expect(restored.type, StockMovementType.sale);
    });
  });
}
