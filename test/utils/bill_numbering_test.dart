import 'package:account_app/core/utils/bill_numbering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillNumbering.increment', () {
    test('increments a trailing number', () {
      expect(BillNumbering.increment('INV-9'), 'INV-10');
    });

    test('preserves leading zeroes', () {
      expect(BillNumbering.increment('INV-009'), 'INV-010');
    });

    test('adds a numeric suffix when the bill number has none', () {
      expect(BillNumbering.increment('MANUAL'), 'MANUAL-1');
    });
  });
}
