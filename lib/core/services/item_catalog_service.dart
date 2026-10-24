import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';

/// ایک آئٹم کا خلاصہ — خریداری، فروخت اور موجودہ سٹاک سب موجودہ
/// ٹرانزیکشنز سے نکالا جاتا ہے، کہیں بھی الگ سے سیو نہیں کیا جاتا۔
class ItemCatalogEntry {
  final String name;
  String? unit;
  String category;
  double boughtQty;
  double soldQty;
  double lastBuyRate;
  double lastSellRate;

  ItemCatalogEntry({
    required this.name,
    this.unit,
    this.category = 'عمومی',
    this.boughtQty = 0,
    this.soldQty = 0,
    this.lastBuyRate = 0,
    this.lastSellRate = 0,
  });

  /// موجودہ سٹاک = کل خریدی گئی مقدار − کل بکی گئی مقدار
  double get currentStock => boughtQty - soldQty;

  /// فی یونٹ منافع = آخری فروخت ریٹ − آخری خرید ریٹ
  double get profitPerUnit => lastSellRate - lastBuyRate;

  /// فروخت کے لیے استعمال ہونے والا ریٹ — اگر فروخت ریٹ نہ ہو تو خرید ریٹ دکھا دیں
  double get effectiveSellRate => lastSellRate > 0 ? lastSellRate : lastBuyRate;
}

class ItemCatalogService {
  /// تمام ٹرانزیکشنز پر سے گزر کر ہر آئٹم کا کیٹلاگ اندراج بناتا ہے۔
  /// [categories] آئٹم کے نام سے زمرے کا نقشہ ہے (settings میں محفوظ)،
  /// تاکہ فوری بل سکریں پر زمرہ وار سلائیڈر دکھایا جا سکے۔
  static Map<String, ItemCatalogEntry> buildCatalog(
    List<Transaction> transactions,
    Map<String, String> categories,
  ) {
    final Map<String, ItemCatalogEntry> catalog = {};
    final Map<String, DateTime> lastBuyDate = {};
    final Map<String, DateTime> lastSellDate = {};

    final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));

    for (final tx in sorted) {
      final List<TransactionItem> lineItems = tx.items.isNotEmpty
          ? tx.items
          : (tx.quantity > 0
              ? [
                  TransactionItem(
                    description: tx.description,
                    quantity: tx.quantity.toDouble(),
                    rate: tx.rate,
                    total: tx.rate * tx.quantity,
                  ),
                ]
              : const <TransactionItem>[]);

      for (final item in lineItems) {
        final name = item.description.trim();
        if (name.isEmpty) continue;

        final entry = catalog.putIfAbsent(
          name,
          () => ItemCatalogEntry(
            name: name,
            unit: item.unit,
            category: categories[name] ?? 'عمومی',
          ),
        );
        entry.unit ??= item.unit;

        if (tx.type == 'expense') {
          entry.boughtQty += item.quantity;
          if (lastBuyDate[name] == null || tx.date.isAfter(lastBuyDate[name]!)) {
            entry.lastBuyRate = item.rate;
            lastBuyDate[name] = tx.date;
          }
        } else if (tx.type == 'income') {
          entry.soldQty += item.quantity;
          if (lastSellDate[name] == null || tx.date.isAfter(lastSellDate[name]!)) {
            entry.lastSellRate = item.rate;
            lastSellDate[name] = tx.date;
          }
        }
      }
    }

    return catalog;
  }

  /// آئٹمز کو ان کے زمرے کے حساب سے گروپ کرتا ہے، فوری بل کے زمرہ سلائیڈر کے لیے۔
  static List<String> categoriesIn(Map<String, ItemCatalogEntry> catalog) {
    final set = <String>{};
    for (final entry in catalog.values) {
      set.add(entry.category);
    }
    final list = set.toList()..sort();
    return list;
  }
}
