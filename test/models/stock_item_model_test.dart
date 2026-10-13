import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/stock_item_model.dart';

void main() {
  group('StockItem serialization', () {
    test('round trips all fields from the stock item form', () {
      final item = StockItem(
        id: 'item-1',
        name: 'Laptop',
        nameUrdu: 'لیپ ٹاپ',
        barcode: '12345',
        sku: 'LAP-01',
        categoryName: 'Electronics',
        purchasePrice: 80000,
        sellingPrice: 95000,
        wholesalePrice: 90000,
        mrp: 100000,
        initialQuantity: 4,
        minStockAlert: 1,
        unit: 'Pieces',
        description: 'Business laptop',
        brand: 'Example',
        model: 'X1',
        supplierName: 'Supplier',
        batchNo: 'B-20',
        warranty: 24,
        featured: true,
        trackStock: false,
        allowReturn: false,
        stopWhenOut: false,
        isArchived: true,
        imagePath: 'https://example.test/laptop.png',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 2),
      );

      final restored = StockItem.fromMap(item.toMap());

      expect(restored.id, item.id);
      expect(restored.nameUrdu, item.nameUrdu);
      expect(restored.sku, item.sku);
      expect(restored.mrp, item.mrp);
      expect(restored.brand, item.brand);
      expect(restored.model, item.model);
      expect(restored.supplierName, item.supplierName);
      expect(restored.batchNo, item.batchNo);
      expect(restored.warranty, item.warranty);
      expect(restored.featured, item.featured);
      expect(restored.trackStock, item.trackStock);
      expect(restored.allowReturn, item.allowReturn);
      expect(restored.stopWhenOut, item.stopWhenOut);
      expect(restored.isArchived, isTrue);
      expect(restored.imagePath, item.imagePath);
    });

    test('legacy maps keep backward-compatible defaults', () {
      final item = StockItem.fromMap({
        'id': 'legacy-item',
        'name': 'Legacy',
      });

      expect(item.sku, isEmpty);
      expect(item.mrp, 0);
      expect(item.warranty, 0);
      expect(item.featured, isFalse);
      expect(item.trackStock, isTrue);
      expect(item.allowReturn, isTrue);
      expect(item.stopWhenOut, isTrue);
      expect(item.isArchived, isFalse);
      expect(item.imagePath, isNull);
    });

    test('copyWith can update and clear the image and policy fields', () {
      final item = StockItem(
        id: 'item-1',
        name: 'Item',
        imagePath: 'https://example.test/item.png',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final updated = item.copyWith(
        sku: 'SKU-2',
        featured: true,
        trackStock: false,
        clearImagePath: true,
        isArchived: true,
      );

      expect(updated.sku, 'SKU-2');
      expect(updated.featured, isTrue);
      expect(updated.trackStock, isFalse);
      expect(updated.isArchived, isTrue);
      expect(updated.imagePath, isNull);
    });
  });
}
