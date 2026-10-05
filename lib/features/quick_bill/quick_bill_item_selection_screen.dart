import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/item_catalog_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'quick_bill_preview_screen.dart';

/// فوری بل بنانے کے لیے منتخب آئٹم — ایک قطار جو آئٹم کیٹلاگ سے
/// الگ رکھی جاتی ہے تاکہ منتخب مقدار پریویو سکریں تک محفوظ رہے۔
class QuickBillCartLine {
  final String name;
  final String? unit;
  final double rate;
  final String? stockItemId;
  final String? stockItemName;
  final double? availableStock;
  double quantity;

  QuickBillCartLine({
    required this.name,
    this.unit,
    required this.rate,
    this.stockItemId,
    this.stockItemName,
    this.availableStock,
    this.quantity = 0,
  });

  double get total => rate * quantity;
}

class _QuickBillCatalogItem {
  final String key;
  final String name;
  final String nameUrdu;
  final String? unit;
  final double rate;
  final String category;
  final String? stockItemId;
  final double? availableStock;

  const _QuickBillCatalogItem({
    required this.key,
    required this.name,
    this.nameUrdu = '',
    this.unit,
    required this.rate,
    required this.category,
    this.stockItemId,
    this.availableStock,
  });

  String displayName(bool isUrdu) =>
      isUrdu && nameUrdu.isNotEmpty ? nameUrdu : name;
}

class QuickBillItemSelectionScreen extends StatefulWidget {
  const QuickBillItemSelectionScreen({super.key});

  @override
  State<QuickBillItemSelectionScreen> createState() =>
      _QuickBillItemSelectionScreenState();
}

class _QuickBillItemSelectionScreenState
    extends State<QuickBillItemSelectionScreen> {
  static const String _allCategories = '__all__';
  String _activeCategory = _allCategories;
  String _query = '';
  bool _isAscending = true;
  final Map<String, QuickBillCartLine> _cart = {};

  Map<String, String> _loadCategories(DatabaseService db) {
    final raw = db.getSetting(QuickBillConstants.itemCategoriesSettingKey,
        defaultValue: {});
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  Future<void> _editQuantity(
    QuickBillCartLine line,
    bool isUrdu,
  ) async {
    final controller = TextEditingController(
      text: line.quantity.toStringAsFixed(
          line.quantity == line.quantity.roundToDouble() ? 0 : 2),
    );
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isUrdu ? 'مقدار درج کریں' : 'Enter quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: line.unit ?? (isUrdu ? 'مقدار' : 'Quantity')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim()),
            ),
            child: Text(isUrdu ? 'ٹھیک ہے' : 'Apply'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (quantity == null || !mounted) return;
    final maximum = line.availableStock;
    if (quantity < 0 || (maximum != null && quantity > maximum)) {
      AppToast.warning(
        context,
        isUrdu
            ? 'مقدار صفر اور دستیاب اسٹاک کے درمیان ہونی چاہیے'
            : 'Quantity must be between zero and available stock',
      );
      return;
    }
    setState(() => line.quantity = quantity);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final databaseService = Provider.of<DatabaseService>(context);
    final stockService = Provider.of<StockService>(context);

    final historyCatalog = ItemCatalogService.buildCatalog(
      databaseService.getAllTransactions(),
      _loadCategories(databaseService),
    );
    final historyByName = {
      for (final entry in historyCatalog.entries)
        entry.key.trim().toLowerCase(): entry.value,
    };
    final catalog = <String, _QuickBillCatalogItem>{};
    final stockNames = <String>{};

    for (final item in stockService.items) {
      final normalizedName = item.name.trim().toLowerCase();
      stockNames.add(normalizedName);
      final normalizedUrduName = item.nameUrdu.trim().toLowerCase();
      if (normalizedUrduName.isNotEmpty) stockNames.add(normalizedUrduName);
      final history =
          historyByName[normalizedName] ?? historyByName[normalizedUrduName];
      final stock = stockService.calculateCurrentStock(item.id);
      catalog['stock:${item.id}'] = _QuickBillCatalogItem(
        key: 'stock:${item.id}',
        name: item.name,
        nameUrdu: item.nameUrdu,
        unit: item.unit,
        rate: item.sellingPrice > 0
            ? item.sellingPrice
            : (history?.effectiveSellRate ?? 0),
        category: item.categoryName.isNotEmpty
            ? item.categoryName
            : (history?.category ?? QuickBillConstants.defaultCategory),
        stockItemId: item.id,
        availableStock: stock,
      );
    }

    for (final item in historyCatalog.values) {
      if (stockNames.contains(item.name.trim().toLowerCase())) continue;
      catalog['history:${item.name}'] = _QuickBillCatalogItem(
        key: 'history:${item.name}',
        name: item.name,
        unit: item.unit,
        rate: item.effectiveSellRate,
        category: item.category,
      );
    }

    final categories = [
      _allCategories,
      ...catalog.values.map((e) => e.category).toSet().toList()..sort(),
    ];

    final entries = catalog.values.where((e) {
      final inCategory =
          _activeCategory == _allCategories || e.category == _activeCategory;
      final query = _query.toLowerCase();
      final matchesQuery = _query.isEmpty ||
          e.name.toLowerCase().contains(query) ||
          e.nameUrdu.toLowerCase().contains(query);
      return inCategory && matchesQuery;
    }).toList()
      ..sort((a, b) =>
          _isAscending ? a.name.compareTo(b.name) : b.name.compareTo(a.name));

    final selectedLines = _cart.values.where((l) => l.quantity > 0).toList();
    final total = selectedLines.fold<double>(0, (s, l) => s + l.total);

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F5),
      appBar: CustomAppBar(
        title: isUrdu ? 'فوری بل — آئٹم چنیں' : 'Quick bill — select items',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SearchSortBar(
                  hintText: isUrdu ? 'آئٹم تلاش کریں...' : 'Search item...',
                  onSearchChanged: (v) => setState(() => _query = v),
                  onSortToggled: () =>
                      setState(() => _isAscending = !_isAscending),
                  isAscending: _isAscending,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final active = cat == _activeCategory;
                      final label =
                          cat == _allCategories ? (isUrdu ? 'سب' : 'All') : cat;
                      return GestureDetector(
                        onTap: () => setState(() => _activeCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active ? AppTheme.darkColor : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  active ? FontWeight.bold : FontWeight.normal,
                              color: active ? Colors.white : AppTheme.darkColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: stockService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? Center(
                        child: Text(
                          isUrdu ? 'کوئی آئٹم نہیں ملا' : 'No items found',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final line = _cart.putIfAbsent(
                            e.key,
                            () => QuickBillCartLine(
                              name: e.displayName(isUrdu),
                              unit: e.unit,
                              rate: e.rate,
                              stockItemId: e.stockItemId,
                              stockItemName: e.name,
                              availableStock: e.availableStock,
                            ),
                          );
                          final selected = line.quantity > 0;
                          final stockLimitReached =
                              line.availableStock != null &&
                                  line.quantity >= line.availableStock!;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.themeColor
                                    : Colors.black12,
                                width: selected ? 1.5 : 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 21,
                                  backgroundColor:
                                      AppTheme.themeColor.withOpacity(0.12),
                                  child: Text(
                                    e.displayName(isUrdu).isNotEmpty
                                        ? e.displayName(isUrdu)[0]
                                        : '?',
                                    style: TextStyle(
                                        color: AppTheme.darkColor,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.displayName(isUrdu),
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${line.rate.toStringAsFixed(0)} ${isUrdu ? "فی" : "per"} ${e.unit ?? (isUrdu ? "یونٹ" : "unit")}'
                                        '${line.availableStock == null ? '' : ' · ${isUrdu ? 'اسٹاک' : 'Stock'} ${line.availableStock!.toStringAsFixed(0)}'}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.themeColor.withOpacity(0.1)
                                        : const Color(0xFFF1EFE8),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        iconSize: 16,
                                        constraints: const BoxConstraints(
                                            minWidth: 28, minHeight: 28),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(PhosphorIcons.minus(),
                                            color: AppTheme.darkColor),
                                        onPressed: () {
                                          if (line.quantity <= 0) return;
                                          setState(() => line.quantity =
                                              (line.quantity - 1)
                                                  .clamp(0, double.infinity));
                                        },
                                      ),
                                      SizedBox(
                                        width: 24,
                                        child: InkWell(
                                          onTap: () =>
                                              _editQuantity(line, isUrdu),
                                          child: Text(
                                            line.quantity ==
                                                    line.quantity
                                                        .roundToDouble()
                                                ? line.quantity
                                                    .toInt()
                                                    .toString()
                                                : line.quantity
                                                    .toStringAsFixed(2),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w500
                                                  : FontWeight.normal,
                                              color: selected
                                                  ? AppTheme.darkColor
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        iconSize: 16,
                                        constraints: const BoxConstraints(
                                            minWidth: 28, minHeight: 28),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(PhosphorIcons.plus(),
                                            color: AppTheme.darkColor),
                                        onPressed: stockLimitReached
                                            ? null
                                            : () => setState(
                                                () => line.quantity += 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (selectedLines.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuickBillPreviewScreen(
                          lines: selectedLines,
                          onBillCompleted: () {
                            if (!mounted) return;
                            setState(() {
                              for (final line in _cart.values) {
                                line.quantity = 0;
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedLines.length} ${isUrdu ? "آئٹمز منتخب" : "items selected"}',
                          style: const TextStyle(
                              color: Color(0xFFCFE0EC), fontSize: 13),
                        ),
                        Row(
                          children: [
                            Text(
                              '${isUrdu ? "بل دیکھیں" : "View bill"} — ${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            Icon(PhosphorIcons.arrowLeft(),
                                color: Colors.white, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
