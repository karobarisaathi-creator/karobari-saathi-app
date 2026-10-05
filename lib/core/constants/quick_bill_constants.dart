import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';

/// فوری بل سسٹم کے مستقل اصول۔
///
/// نقد گاہک (جس کا کوئی کھاتہ نہیں بنانا) کی فروخت کو بھی ایک اکاؤنٹ ہی
/// سے جوڑنا پڑتا ہے، کیونکہ Transaction ماڈل میں accountId لازمی ہے۔
/// اس لیے ایک مستقل، ہمیشہ ایک ہی آئی ڈی والا "نقد فروخت" اکاؤنٹ رکھا گیا ہے —
/// اسے عام پارٹیوں کی فہرست اور گاہک کے انتخاب میں نہیں دکھایا جاتا۔
class QuickBillConstants {
  static const String cashCustomerAccountId = 'quick_bill_cash_customer';
  static const String cashCustomerName = 'نقد گاہک';

  static const String itemCategoriesSettingKey = 'quick_bill_item_categories';
  static const String defaultCategory = 'عمومی';

  /// "نقد فروخت" اکاؤنٹ موجود نہ ہو تو بنا دیتا ہے، تاکہ نقد گاہک کی
  /// فروخت بھی ایک درست Transaction کے طور پر محفوظ ہو سکے۔
  static Future<Account> ensureCashCustomerAccount(
    DatabaseService databaseService,
  ) async {
    final existing = databaseService.getAccount(cashCustomerAccountId);
    if (existing != null) return existing;

    final account = Account(
      id: cashCustomerAccountId,
      name: cashCustomerName,
      phone: '',
      category: 'نقد گاہک',
      initialBalance: 0.0,
      balanceType: 'receivable',
      balance: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
    );
    await databaseService.addAccount(account);
    return account;
  }
}
