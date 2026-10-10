import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/stock_service.dart';

void main() {
  StockMovement movement(StockMovementType type, double quantity) {
    return StockMovement(
      id: 'movement',
      stockItemId: 'item',
      stockItemName: 'Test item',
      type: type,
      quantity: quantity,
      unitPrice: 1,
      timestamp: DateTime(2026),
    );
  }

  group('Stock movement balance', () {
    test('stock-in, stock-out, and signed adjustment use consistent deltas',
        () {
      expect(movement(StockMovementType.purchase, 4).stockDelta, 4);
      expect(movement(StockMovementType.customerReturn, 2).stockDelta, 2);
      expect(movement(StockMovementType.sale, 3).stockDelta, -3);
      expect(movement(StockMovementType.supplierReturn, 1).stockDelta, -1);
      expect(movement(StockMovementType.adjustment, -2).stockDelta, -2);
    });

    test('stock reductions cannot overdraw available quantity', () {
      expect(
        StockService.canApplyMovement(
          availableStock: 5,
          movement: movement(StockMovementType.sale, 5),
        ),
        isTrue,
      );
      expect(
        StockService.canApplyMovement(
          availableStock: 4,
          movement: movement(StockMovementType.sale, 5),
        ),
        isFalse,
      );
      expect(
        StockService.canApplyMovement(
          availableStock: 4,
          movement: movement(StockMovementType.adjustment, -5),
        ),
        isFalse,
      );
      expect(
        StockService.canApplyMovement(
          availableStock: -2,
          movement: movement(StockMovementType.purchase, 1),
        ),
        isTrue,
      );
    });

    test('sales respect the item out-of-stock policy', () {
      expect(
        StockService.canSellQuantity(
          availableStock: 2,
          quantity: 3,
        ),
        isFalse,
      );
      expect(
        StockService.canSellQuantity(
          availableStock: 2,
          quantity: 3,
          stopWhenOut: false,
        ),
        isTrue,
      );
      expect(
        StockService.canApplyMovement(
          availableStock: 2,
          movement: movement(StockMovementType.sale, 3),
          stopWhenOut: false,
        ),
        isTrue,
      );
    });

    test('sales reject invalid quantities and stock values', () {
      expect(
        StockService.canSellQuantity(availableStock: 2, quantity: -1),
        isFalse,
      );
      expect(
        StockService.canSellQuantity(
          availableStock: double.infinity,
          quantity: 1,
        ),
        isFalse,
      );
      expect(
        StockService.canApplyMovement(
          availableStock: 2,
          movement: movement(StockMovementType.sale, double.nan),
          stopWhenOut: false,
        ),
        isFalse,
      );
    });
  });
}
