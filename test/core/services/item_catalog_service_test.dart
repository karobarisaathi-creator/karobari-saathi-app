import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/item_catalog_service.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';

void main() {
  test('does not treat party settlements as catalog items', () {
    final settlement = Transaction(
      id: 'settlement',
      accountId: 'party',
      amount: 500,
      type: 'expense',
      category: AccountBalanceUtils.partySettlementCategory,
      description: 'پارٹی کو ادائیگی - بینک',
      date: DateTime(2026, 11, 17),
      quantity: 1,
      rate: 500,
      createdAt: DateTime(2026, 11, 17),
      updatedAt: DateTime(2026, 11, 17),
    );

    final catalog = ItemCatalogService.buildCatalog([settlement], const {});

    expect(catalog, isEmpty);
  });
}
