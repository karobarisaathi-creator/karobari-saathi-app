import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026);

  Account account({
    required String id,
    required String name,
    required String category,
  }) {
    return Account(
      id: id,
      name: name,
      phone: '',
      category: category,
      initialBalance: 0,
      balanceType: 'none',
      balance: 0,
      createdAt: date,
      updatedAt: date,
    );
  }

  test('recognizes cash customer accounts by id or legacy label', () {
    expect(
      QuickBillConstants.isCashCustomerAccount(
        account(
          id: QuickBillConstants.cashCustomerAccountId,
          name: 'Cash',
          category: 'customer',
        ),
      ),
      isTrue,
    );
    expect(
      QuickBillConstants.isCashCustomerAccount(
        account(
          id: 'legacy-cash-customer',
          name: 'نقد گاہک',
          category: 'customer',
        ),
      ),
      isTrue,
    );
    expect(
      QuickBillConstants.isCashCustomerAccount(
        account(
          id: 'legacy-cash-customer-en',
          name: 'Cash Customer',
          category: 'customer',
        ),
      ),
      isTrue,
    );
    expect(
      QuickBillConstants.isCashCustomerAccount(
        account(id: 'party-1', name: 'Ali', category: 'customer'),
      ),
      isFalse,
    );
  });
}
