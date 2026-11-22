// lib/features/quick_bill/quick_bill_item_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/features/quick_bill/widgets/quick_bill_item_grid_card.dart';
import 'quick_bill_preview_screen.dart';

// ═══════════════════════════════════════════════════════════════
// QuickBillCartLine — Model
// ═══════════════════════════════════════════════════════════════
class QuickBillCartLine {
  final String name;
  final String? unit;
  final double rate;
  final double? oldRate;
  final String? stockItemId;
  final String? stockItemName;
  double? availableStock;
  bool stopWhenOut;
  double quantity;

  final bool isManual;
  final String? manualType;

  QuickBillCartLine({
    required this.name,
    this.unit,
    required this.rate,
    this.oldRate,
    this.stockItemId,
    this.stockItemName,
    this.availableStock,
    this.stopWhenOut = true,
    this.quantity = 0,
    this.isManual = false,
    this.manualType,
  });

  double get total => rate * quantity;

  String get cartKey => isManual
      ? 'manual:${identityHashCode(this)}'
      : (stockItemId != null
          ? 'stock:$stockItemId'
          : 'history:${name.trim().toLowerCase()}');
}

// ═══════════════════════════════════════════════════════════════
// Internal Catalog Item
// ═══════════════════════════════════════════════════════════════
class _QuickBillCatalogItem {
  final String key;
  final String name;
  final String nameUrdu;
  final String? unit;
  final double rate;
  final double? oldRate;
  final String category;
  final String? stockItemId;
  final double? availableStock;
  final bool stopWhenOut;
  final bool featured;
  final String? imageUrl;

  const _QuickBillCatalogItem({
    required this.key,
    required this.name,
    this.nameUrdu = '',
    this.unit,
    required this.rate,
    this.oldRate,
    required this.category,
    this.stockItemId,
    this.availableStock,
    this.stopWhenOut = true,
    this.featured = false,
    this.imageUrl,
  });

  String displayName(bool isUrdu) => name;
}

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════
class QuickBillItemSelectionScreen extends StatefulWidget {
  final Transaction? transactionToEdit;

  const QuickBillItemSelectionScreen({
    super.key,
    this.transactionToEdit,
  });

  @override
  State<QuickBillItemSelectionScreen> createState() =>
      _QuickBillItemSelectionScreenState();
}

class _QuickBillItemSelectionScreenState
    extends State<QuickBillItemSelectionScreen> {
  static const String _allCategories = '__all__';

  static const Map<String, String> _categoryNamesUrdu = {
    'General': 'عمومی',
    'Grocery': 'کریانہ',
    'Food': 'خوراک',
    'Beverages': 'مشروبات',
    'Clothing': 'کپڑے',
    'Electronics': 'الیکٹرانکس',
    'Household': 'گھریلو سامان',
    'Personal Care': 'ذاتی استعمال',
    'Medicine': 'ادویات',
    'Other': 'دیگر',
    'Mobiles': 'موبائل',
    'Vehicles': 'گاڑیاں',
    'Real Estate': 'رئیل اسٹیٹ',
    'Agriculture': 'زراعت',
    'Livestock': 'مویشی',
    'Furniture': 'فرنیچر',
    'Stationery': 'سٹیشنری',
    'Hardware': 'ہارڈ ویئر',
    'Construction': 'تعمیرات',
    'Services': 'خدمات',
    'Transport': 'ٹرانسپورٹ',
    'Raw Material': 'خام مال',
    'Assets': 'اثاثہ جات',
    'Construction & Hardware': 'تعمیرات اور ہارڈویئر',
    'IT & Software': 'آئی ٹی اور سافٹ ویئر',
    'Repair & Mechanics': 'مرمت اور میکینکس',
    'Agriculture & Livestock': 'زراعت اور لائیو سٹاک',
    'Beauty & Wellness': 'خوبصورتی اور صحت',
    'Food & Hospitality': 'کھانا اور مہمان نوازی',
    'Transport & Logistics': 'ٹرانسپورٹ اور لاجسٹکس',
    'Education & Arts': 'تعلیم اور فنون',
    'Other Services': 'دیگر خدمات',
    'Custom Service': 'مزدوری / کسٹم',
    'عام (General)': 'عمومی',
    'عام': 'عمومی',
  };

  String _formatCategoryLabel(String cat, bool isUrdu) {
    if (cat == _allCategories) {
      return isUrdu ? 'سب' : 'All';
    }
    if (isUrdu) {
      return _categoryNamesUrdu[cat.trim()] ?? cat;
    }
    return cat;
  }

  String _activeCategory = _allCategories;
  String _query = '';
  bool _showSearch = false;
  bool _isCustomItemExpanded = false;
  final UrduAwareTextEditingController _customNameCtrl =
      UrduAwareTextEditingController();
  final UrduAwareTextEditingController _customRateCtrl =
      UrduAwareTextEditingController();
  String? _customUnit;
  final Map<String, QuickBillCartLine> _cart = {};

  // Manual items list
  final List<QuickBillCartLine> _manualItems = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customRateCtrl.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════
  // Quantity Editing
  // ═════════════════════════════════════════════════════════════
  Future<void> _editQuantity(QuickBillCartLine line, bool isUrdu) async {
    final controller = TextEditingController(
      text: line.quantity.toStringAsFixed(
          line.quantity == line.quantity.roundToDouble() ? 0 : 2),
    );
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: UrduAwareText(isUrdu ? 'مقدار درج کریں' : 'Enter quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: line.unit ?? (isUrdu ? 'مقدار' : 'Quantity'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim()),
            ),
            child: UrduAwareText(isUrdu ? 'ٹھیک ہے' : 'Apply'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (quantity == null || !mounted) return;

    if (line.isManual) {
      if (quantity < 0) {
        AppToast.warning(
          context,
          isUrdu ? 'مقدار منفی نہیں ہو سکتی' : 'Quantity cannot be negative',
        );
        return;
      }
      setState(() => line.quantity = quantity);
      return;
    }

    final maximum = line.availableStock;
    if (quantity < 0 ||
        (line.stopWhenOut && maximum != null && quantity > maximum)) {
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

  // ═════════════════════════════════════════════════════════════
  // Manual Entry
  // ═════════════════════════════════════════════════════════════
  Future<void> _openManualEntryDialog(
    bool isUrdu,
    String? fontFamily, {
    QuickBillCartLine? editLine,
  }) async {
    final result = await showDialog<QuickBillCartLine>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _ManualEntryDialog(
        isUrdu: isUrdu,
        fontFamily: fontFamily,
        editLine: editLine,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (editLine != null) {
        final index = _manualItems.indexOf(editLine);
        if (index != -1) {
          _manualItems[index] = result;
        }
        AppToast.success(
          context,
          isUrdu ? 'کسٹم اشیاء اپڈیٹ ہو گئیں' : 'Custom item updated',
        );
      } else {
        _manualItems.add(result);
        AppToast.success(
          context,
          isUrdu ? 'کسٹم اشیاء شامل ہو گئیں' : 'Custom item added',
        );
      }
    });
  }

  // ═════════════════════════════════════════════════════════════
  // Navigation
  // ═════════════════════════════════════════════════════════════
  void _openPreview(
    List<QuickBillCartLine> selectedLines,
    bool isUrdu,
  ) async {
    final manualWithQty = _manualItems.where((l) => l.quantity > 0).toList();
    final allLines = [...selectedLines, ...manualWithQty];

    if (allLines.isEmpty) {
      AppToast.warning(
        context,
        isUrdu ? 'پہلے کوئی اشیاء منتخب کریں' : 'Select at least one item',
      );
      return;
    }

    final previewRoute = MaterialPageRoute(
      builder: (_) => QuickBillPreviewScreen(
        lines: allLines,
        transactionToEdit: widget.transactionToEdit,
        onBillCompleted: () {
          if (!mounted) return;
          setState(() {
            for (final line in _cart.values) {
              line.quantity = 0;
            }
            _manualItems.clear();
          });
        },
      ),
    );

    if (widget.transactionToEdit != null) {
      Navigator.of(context).pushReplacement(previewRoute);
      return;
    }

    await Navigator.of(context).push(previewRoute);
  }

  // ═════════════════════════════════════════════════════════════
  // MEMOIZED CATALOG & FILTER CACHE
  // ═════════════════════════════════════════════════════════════
  List<StockItem>? _cachedStockItems;
  List<StockMovement>? _cachedStockMovements;
  List<_QuickBillCatalogItem>? _cachedCatalogList;
  List<String>? _cachedCategories;
  String? _cachedQuery;
  String? _cachedActiveCategory;
  List<_QuickBillCatalogItem>? _cachedFilteredEntries;

  List<_QuickBillCatalogItem> _getOrBuildCatalog(StockService stockService) {
    if (_cachedCatalogList != null &&
        identical(_cachedStockItems, stockService.items) &&
        identical(_cachedStockMovements, stockService.movements)) {
      return _cachedCatalogList!;
    }

    _cachedStockItems = stockService.items;
    _cachedStockMovements = stockService.movements;
    final list = <_QuickBillCatalogItem>[];

    for (final item in stockService.items) {
      if (item.isArchived) continue;
      final currentStock = item.trackStock
          ? stockService.availableStockForTransaction(
              item.id,
              excludingTransactionId: widget.transactionToEdit?.id,
            )
          : null;
      list.add(_QuickBillCatalogItem(
        key: 'stock:${item.id}',
        name: item.name,
        nameUrdu: item.nameUrdu,
        unit: item.unit,
        rate: item.sellingPrice,
        oldRate: item.mrp > item.sellingPrice ? item.mrp : null,
        category: item.categoryName.isNotEmpty
            ? item.categoryName
            : QuickBillConstants.defaultCategory,
        stockItemId: item.id,
        availableStock: currentStock == null
            ? null
            : currentStock.isFinite
                ? currentStock.clamp(0.0, double.infinity).toDouble()
                : 0,
        stopWhenOut: item.stopWhenOut,
        featured: item.featured,
        imageUrl: item.imagePath,
      ));
    }

    _cachedCatalogList = list;
    _cachedCategories = null;
    _cachedFilteredEntries = null;
    return list;
  }

  List<String> _getCategories(List<_QuickBillCatalogItem> catalogList) {
    if (_cachedCategories != null) return _cachedCategories!;
    final set = <String>{_allCategories};
    for (final item in catalogList) {
      set.add(item.category);
    }
    final sorted = set.toList()
      ..sort((a, b) {
        if (a == _allCategories) return -1;
        if (b == _allCategories) return 1;
        return a.compareTo(b);
      });
    _cachedCategories = sorted;
    return sorted;
  }

  List<_QuickBillCatalogItem> _getFilteredEntries(
      List<_QuickBillCatalogItem> catalogList) {
    if (_cachedFilteredEntries != null &&
        _cachedQuery == _query &&
        _cachedActiveCategory == _activeCategory) {
      return _cachedFilteredEntries!;
    }

    _cachedQuery = _query;
    _cachedActiveCategory = _activeCategory;
    final queryLower = _query.trim().toLowerCase();

    final filtered = catalogList.where((e) {
      final inCategory =
          _activeCategory == _allCategories || e.category == _activeCategory;
      final matchesQuery = queryLower.isEmpty ||
          e.name.toLowerCase().contains(queryLower) ||
          e.nameUrdu.toLowerCase().contains(queryLower);
      return inCategory && matchesQuery;
    }).toList()
      ..sort((a, b) {
        final featuredOrder = (b.featured ? 1 : 0) - (a.featured ? 1 : 0);
        if (featuredOrder != 0) return featuredOrder;
        return a.name.compareTo(b.name);
      });

    _cachedFilteredEntries = filtered;
    return filtered;
  }

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final stockService = Provider.of<StockService>(context);

    final catalogList = _getOrBuildCatalog(stockService);
    for (final item in catalogList) {
      final line = _cart[item.key];
      if (line == null) continue;

      line.availableStock = item.availableStock;
      line.stopWhenOut = item.stopWhenOut;
      if (line.stopWhenOut && item.availableStock != null) {
        line.quantity = line.quantity.clamp(0.0, item.availableStock!);
      }
    }
    final categories = _getCategories(catalogList);
    final entries = _getFilteredEntries(catalogList);

    final stockSelected = _cart.values.where((l) => l.quantity > 0).toList();
    final manualSelected = _manualItems.where((l) => l.quantity > 0).toList();
    final totalSelectedCount = stockSelected.length + manualSelected.length;
    final total = [
      ...stockSelected,
      ...manualSelected,
    ].fold<double>(0, (s, l) => s + l.total);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ScreenAppBar(
        title: isUrdu ? 'فوری بل' : 'Quick Bill',
        isUrdu: isUrdu,
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: _isCustomItemExpanded
                ? (isUrdu ? 'بند کریں' : 'Close custom item')
                : (isUrdu ? 'کسٹم آئٹم شامل کریں' : 'Add custom item'),
            icon: Icon(
              _isCustomItemExpanded
                  ? Icons.close_rounded
                  : Icons.add_circle_outline_rounded,
            ),
            onPressed: () {
              setState(() {
                if (_isCustomItemExpanded) {
                  _customNameCtrl.clear();
                  _customRateCtrl.clear();
                  _customUnit = null;
                }
                _isCustomItemExpanded = !_isCustomItemExpanded;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            // ═══ Slide-Down Custom Item Card Panel (AddEditStockItemScreen style) ═══
            if (_isCustomItemExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppTheme.verifiedGold, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.themeColor.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.handyman_rounded,
                              color: AppTheme.themeColor, size: 20),
                          const SizedBox(width: 8),
                          UrduAwareText(
                            isUrdu
                                ? 'نیا کسٹم اشیاء / مزدوری شامل کریں'
                                : 'Add Custom Item / Labor',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() {
                              _customNameCtrl.clear();
                              _customRateCtrl.clear();
                              _customUnit = null;
                              _isCustomItemExpanded = false;
                            }),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _customNameCtrl,
                              style: TextStyle(fontFamily: fontFamily),
                              decoration: InputDecoration(
                                labelText: isUrdu
                                    ? 'اشیاء یا سروس کا نام'
                                    : 'Item or Service Name',
                                labelStyle: TextStyle(fontFamily: fontFamily),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _customRateCtrl,
                              style: TextStyle(fontFamily: fontFamily),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isUrdu ? 'ریٹ (روپے)' : 'Rate (Rs)',
                                labelStyle: TextStyle(fontFamily: fontFamily),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      UrduAwareText(
                        isUrdu ? 'اکائی منتخب کریں:' : 'Select Unit:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'ڈبہ',
                            'کلو',
                            'لیٹر',
                            'من',
                            'یونٹ',
                            'عدد',
                            'بوری',
                            'پیکٹ'
                          ].map((u) {
                            final isSelected = u == _customUnit;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: UrduAwareText(u,
                                    style: TextStyle(
                                        fontFamily: fontFamily, fontSize: 11)),
                                selected: isSelected,
                                selectedColor: AppTheme.themeColor,
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87),
                                onSelected: (_) {
                                  setState(() {
                                    if (_customUnit == u) {
                                      _customUnit = null;
                                    } else {
                                      _customUnit = u;
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      UrduAwareText(
                        isUrdu
                            ? 'فوری ٹیگز / خدمات:'
                            : 'Quick Services / Tags:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: (isUrdu
                                  ? [
                                      'مزدوری',
                                      'سروس',
                                      'ڈلیوری',
                                      'کرایہ',
                                      'کمیشن',
                                      'پیکنگ'
                                    ]
                                  : [
                                      'Labor',
                                      'Service',
                                      'Delivery',
                                      'Rent',
                                      'Commission',
                                      'Packing'
                                    ])
                              .map((tag) {
                            final isSelected =
                                _customNameCtrl.text.trim() == tag;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: UrduAwareText(tag,
                                    style: TextStyle(
                                        fontFamily: fontFamily, fontSize: 11)),
                                selected: isSelected,
                                selectedColor: AppTheme.verifiedGold,
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87),
                                onSelected: (_) {
                                  setState(() {
                                    if (_customNameCtrl.text.trim() == tag) {
                                      _customNameCtrl.clear();
                                    } else {
                                      _customNameCtrl.text = tag;
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() {
                                _customNameCtrl.clear();
                                _customRateCtrl.clear();
                                _customUnit = null;
                                _isCustomItemExpanded = false;
                              }),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final name = _customNameCtrl.text.trim();
                                final rate =
                                    double.tryParse(_customRateCtrl.text) ??
                                        0.0;
                                const qty = 1.0;
                                if (name.isEmpty || rate <= 0) {
                                  AppToast.warning(
                                      context,
                                      isUrdu
                                          ? 'درست نام اور ریٹ درج کریں'
                                          : 'Enter valid name and rate');
                                  return;
                                }
                                setState(() {
                                  _manualItems.add(QuickBillCartLine(
                                    name: name,
                                    rate: rate,
                                    quantity: qty,
                                    unit: _customUnit,
                                    stockItemId: null,
                                    stockItemName: name,
                                  ));
                                  _customNameCtrl.clear();
                                  _customRateCtrl.clear();
                                  _customUnit = null;
                                  _isCustomItemExpanded = false;
                                });
                                AppToast.success(
                                    context,
                                    isUrdu
                                        ? 'کسٹم اشیاء شامل ہو گئیں'
                                        : 'Custom item added');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.verifiedGold,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child:
                                  UrduAwareText(isUrdu ? 'محفوظ کریں' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ═══ Search Bar (Conditional) ═══
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: _buildSearchBar(isUrdu, fontFamily),
              ),

            // ═══ Category Strip ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _buildCategoryStrip(categories, catalogList, isUrdu, fontFamily),
            ),
            const SizedBox(height: 7),

            // ═══ Items List ═══
            stockService.isLoading
                ? _buildShimmerItemList(entries.length + _manualItems.length)
                : (entries.isEmpty && _manualItems.isEmpty)
                    ? _buildEmptyState(isUrdu, fontFamily)
                    : ((_manualItems.length + entries.length) <= 2
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _manualItems.length + entries.length,
                            itemBuilder: (context, index) {
                              if (index < _manualItems.length) {
                                final manualItem = _manualItems[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: _buildManualItemCard(
                                      manualItem,
                                      isUrdu,
                                      fontFamily,
                                    ),
                                  ),
                                );
                              }
                              final e = entries[index - _manualItems.length];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: _buildItemCard(
                                    e,
                                    isUrdu,
                                  ),
                                ),
                              );
                            },
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.74,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _manualItems.length + entries.length,
                            itemBuilder: (context, index) {
                              // Manual / Custom Items
                              if (index < _manualItems.length) {
                                final manualItem = _manualItems[index];
                                return _buildManualItemCard(
                                  manualItem,
                                  isUrdu,
                                  fontFamily,
                                );
                              }
                              // Stock Catalog Items
                              final e = entries[index - _manualItems.length];
                              return _buildItemCard(
                                e,
                                isUrdu,
                              );
                            },
                          )),
          ],
        ),
      ),
      floatingActionButton: totalSelectedCount > 0
          ? FloatingActionButton.extended(
              heroTag: 'quickBillCart',
              onPressed: () => _openPreview(stockSelected, isUrdu),
              backgroundColor: AppTheme.slateColor,
              elevation: 6,
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: UrduAwareText(
                  '$totalSelectedCount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              label: UrduAwareText(
                Formatters.formatAmountWithCurrency(total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  // ═════════════════════════════════════════════════════════════
  // MANUAL ITEM CARD — کسٹم اینٹری لسٹ کارڈ
  // ═════════════════════════════════════════════════════════════
  Widget _buildManualItemCard(
    QuickBillCartLine line,
    bool isUrdu,
    String? fontFamily,
  ) {
    return QuickBillItemGridCard(
      name: line.name,
      imageUrl: null,
      rate: line.rate,
      unit: line.unit ?? '',
      stock: 1000000000,
      quantity: line.quantity,
      stopWhenOut: false,
      accentColor: AppTheme.verifiedGold,
      onIncrement: () {
        setState(() => line.quantity += 1);
      },
      onDecrement: () {
        setState(() {
          line.quantity = (line.quantity - 1).clamp(0, double.infinity);
          if (line.quantity <= 0) {
            _manualItems.remove(line);
          }
        });
      },
      onQuantityTap: () =>
          _openManualEntryDialog(isUrdu, fontFamily, editLine: line),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Search Bar
  // ═════════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isUrdu, String? fontFamily) {
    return SearchSortBar(
      padding: EdgeInsets.zero,
      hintText: isUrdu ? 'اشیاء تلاش کریں...' : 'Search item...',
      onSearchChanged: (v) => setState(() => _query = v),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Category Strip (Connected Segmented Bar)
  // ═════════════════════════════════════════════════════════════
  Widget _buildCategoryStrip(
    List<String> categories,
    List<_QuickBillCatalogItem> catalogList,
    bool isUrdu,
    String? fontFamily,
  ) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < categories.length; i++) ...[
                  if (i > 0)
                    Container(width: 1, color: const Color(0xFFE2E8F0)),
                  _buildCategorySegment(
                    label: _formatCategoryLabel(categories[i], isUrdu),
                    count: categories[i] == _allCategories
                        ? catalogList.length
                        : catalogList.where((x) => x.category == categories[i]).length,
                    isActive: categories[i] == _activeCategory,
                    fontFamily: fontFamily,
                    onTap: () =>
                        setState(() => _activeCategory = categories[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySegment({
    required String label,
    required int count,
    required bool isActive,
    required String? fontFamily,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive ? AppTheme.slateColor : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppTheme.darkColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: UrduAwareText(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Item Card
  // ═════════════════════════════════════════════════════════════
  Widget _buildItemCard(
    _QuickBillCatalogItem e,
    bool isUrdu,
  ) {
    final originalLine = widget.transactionToEdit?.items.where((item) {
      if (item.stockItemId != null && item.stockItemId!.isNotEmpty) {
        return item.stockItemId == e.stockItemId;
      }
      final oldName = item.description.trim().toLowerCase();
      return oldName == e.name.trim().toLowerCase() ||
          (e.nameUrdu.isNotEmpty && oldName == e.nameUrdu.trim().toLowerCase());
    }).firstOrNull;
    final line = _cart.putIfAbsent(
      e.key,
      () => QuickBillCartLine(
        name: originalLine?.description ?? e.displayName(isUrdu),
        unit: e.unit,
        rate: originalLine?.rate ?? e.rate,
        oldRate: e.oldRate,
        stockItemId: e.stockItemId,
        stockItemName: e.name,
        availableStock: e.availableStock,
        stopWhenOut: e.stopWhenOut,
        quantity: originalLine?.quantity ?? 0,
      ),
    );
    final maximum = line.availableStock;
    return QuickBillItemGridCard(
      name: e.displayName(isUrdu),
      imageUrl: e.imageUrl,
      rate: line.rate,
      unit: e.unit ?? '',
      stock: maximum ?? 1000000000,
      quantity: line.quantity,
      stopWhenOut: line.stopWhenOut,
      accentColor: AppTheme.slateColor,
      onIncrement: () {
        setState(() {
          line.quantity = !line.stopWhenOut || maximum == null
              ? line.quantity + 1
              : (line.quantity + 1).clamp(0.0, maximum);
        });
      },
      onDecrement: () {
        setState(() =>
            line.quantity = (line.quantity - 1).clamp(0.0, double.infinity));
      },
      onQuantityTap: () => _editQuantity(line, isUrdu),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Empty State
  // ═════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isUrdu, String? fontFamily) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  PhosphorIcons.package(),
                  size: 40,
                  color: AppTheme.themeColor,
                ),
              ),
              const SizedBox(height: 20),
              UrduAwareText(
                isUrdu ? 'کوئی اشیاء نہیں ملیں' : 'No items found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerItemList([int count = 0]) {
    if (count > 0 && count <= 2) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: count,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    child: SkeletonShimmer(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 12,
                    ),
                  ),
                  SizedBox(height: 10),
                  SkeletonShimmer(width: 140, height: 16, borderRadius: 6),
                  SizedBox(height: 8),
                  SkeletonShimmer(width: 90, height: 14, borderRadius: 6),
                  SizedBox(height: 10),
                  SkeletonShimmer(
                    width: double.infinity,
                    height: 36,
                    borderRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.74,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SkeletonShimmer(width: double.infinity, height: 90, borderRadius: 12),
            SizedBox(height: 7),
            SkeletonShimmer(width: 100, height: 13, borderRadius: 6),
            SizedBox(height: 6),
            SkeletonShimmer(width: 60, height: 12, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Manual Entry Dialog
// ═══════════════════════════════════════════════════════════════
class _ManualEntryDialog extends StatefulWidget {
  final bool isUrdu;
  final String? fontFamily;
  final QuickBillCartLine? editLine;

  const _ManualEntryDialog({
    required this.isUrdu,
    this.fontFamily,
    this.editLine,
  });

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _rateController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');

  String _selectedType = 'labour';

  @override
  void initState() {
    super.initState();
    if (widget.editLine != null) {
      final line = widget.editLine!;
      _selectedType = line.manualType ?? 'other';
      if (_selectedType == 'other') {
        _descController.text = line.name;
      } else {
        if (line.name == (widget.isUrdu ? 'مزدوری' : 'Labour')) {
          _selectedType = 'labour';
        } else if (line.name == (widget.isUrdu ? 'سروس' : 'Service')) {
          _selectedType = 'service';
        } else if (line.name == (widget.isUrdu ? 'ڈیلیوری' : 'Delivery')) {
          _selectedType = 'delivery';
        } else {
          _selectedType = 'other';
          _descController.text = line.name;
        }
      }
      _rateController.text = line.rate == line.rate.roundToDouble()
          ? line.rate.toInt().toString()
          : line.rate.toStringAsFixed(2);
      _qtyController.text = line.quantity == line.quantity.roundToDouble()
          ? line.quantity.toInt().toString()
          : line.quantity.toStringAsFixed(2);
    }
  }

  String _getTypeLabel(String key, bool isUrdu) {
    switch (key) {
      case 'labour':
        return isUrdu ? 'مزدوری' : 'Labour';
      case 'service':
        return isUrdu ? 'سروس' : 'Service';
      case 'delivery':
        return isUrdu ? 'ڈیلیوری' : 'Delivery';
      case 'other':
      default:
        return isUrdu ? 'دیگر' : 'Other';
    }
  }

  IconData _getTypeIcon(String key) {
    switch (key) {
      case 'labour':
        return PhosphorIcons.wrench();
      case 'service':
        return PhosphorIcons.package();
      case 'delivery':
        return PhosphorIcons.truck();
      default:
        return PhosphorIcons.info();
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _rateController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final rate = double.tryParse(_rateController.text.trim()) ?? 0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 1;

    final String name;
    if (_selectedType == 'other') {
      name = _descController.text.trim();
    } else {
      name = _getTypeLabel(_selectedType, widget.isUrdu);
    }

    final line = QuickBillCartLine(
      name: name,
      rate: rate,
      quantity: qty,
      isManual: true,
      manualType: _selectedType,
    );

    Navigator.pop(context, line);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.isUrdu;
    final fontFamily = widget.fontFamily;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE1E5EC), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      PhosphorIcons.wrench(),
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          widget.editLine != null
                              ? (isUrdu
                                  ? 'کسٹم اشیاء اپڈیٹ کریں'
                                  : 'Update Custom Item')
                              : (isUrdu
                                  ? 'کسٹم اشیاء شامل کریں'
                                  : 'Add Custom Item'),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        UrduAwareText(
                          isUrdu
                              ? 'مزدوری، ڈیلیوری، اضافی سروس'
                              : 'Labour, delivery, extra service',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type chips
                      _buildSectionLabel(isUrdu ? 'قسم' : 'TYPE'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildTypeChip(
                            key: 'labour',
                            label: isUrdu ? 'مزدوری' : 'Labour',
                            icon: _getTypeIcon('labour'),
                            fontFamily: fontFamily,
                          ),
                          _buildTypeChip(
                            key: 'service',
                            label: isUrdu ? 'سروس' : 'Service',
                            icon: _getTypeIcon('service'),
                            fontFamily: fontFamily,
                          ),
                          _buildTypeChip(
                            key: 'delivery',
                            label: isUrdu ? 'ڈیلیوری' : 'Delivery',
                            icon: _getTypeIcon('delivery'),
                            fontFamily: fontFamily,
                          ),
                          _buildTypeChip(
                            key: 'other',
                            label: isUrdu ? 'دیگر' : 'Other',
                            icon: _getTypeIcon('other'),
                            fontFamily: fontFamily,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description input field - ONLY shown when 'other' is selected
                      if (_selectedType == 'other') ...[
                        _buildSectionLabel(
                            isUrdu ? 'تفصیل *' : 'DESCRIPTION *'),
                        const SizedBox(height: 8),
                        _buildInputField(
                          controller: _descController,
                          hint: isUrdu
                              ? 'تفصیل لکھیں...'
                              : 'Enter description...',
                          icon: PhosphorIcons.notePencil(),
                          fontFamily: fontFamily,
                          validator: (v) {
                            if (_selectedType == 'other') {
                              if (v == null || v.trim().isEmpty) {
                                return isUrdu
                                    ? 'تفصیل لکھیں'
                                    : 'Enter description';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Rate / Amount
                      _buildSectionLabel(isUrdu ? 'رقم / ریٹ *' : 'RATE *'),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _rateController,
                        hint: '0',
                        icon: PhosphorIcons.money(),
                        suffix: 'Rs.',
                        isNumber: true,
                        fontFamily: fontFamily,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return isUrdu ? 'ریٹ / رقم لکھیں' : 'Enter rate';
                          }
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) {
                            return isUrdu ? 'درست رقم' : 'Invalid rate';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Quantity
                      Row(
                        children: [
                          _buildSectionLabel(isUrdu ? 'مقدار' : 'QUANTITY'),
                          const Spacer(),
                          UrduAwareText(
                            isUrdu ? 'اختیاری' : 'OPTIONAL',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _qtyController,
                        hint: '1',
                        icon: PhosphorIcons.stack(),
                        suffix: '×',
                        isNumber: true,
                        fontFamily: fontFamily,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) {
                            return isUrdu ? 'درست مقدار' : 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer using AppButton
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE1E5EC), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Cancel
                  Expanded(
                    child: AppButton(
                      text: isUrdu ? 'کینسل' : 'Cancel',
                      variant: AppButtonVariant.outlined,
                      color: AppTheme.textSecondary,
                      isFullWidth: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Submit
                  Expanded(
                    child: AppButton(
                      text: widget.editLine != null
                          ? (isUrdu ? 'اپڈیٹ کریں' : 'Update')
                          : (isUrdu ? 'بل میں شامل کریں' : 'Add to Bill'),
                      icon: widget.editLine != null
                          ? PhosphorIcons.check()
                          : PhosphorIcons.plus(),
                      variant: AppButtonVariant.primary,
                      color: const Color(0xFFD97706),
                      isFullWidth: true,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return UrduAwareText(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTypeChip({
    required String key,
    required String label,
    required IconData icon,
    String? fontFamily,
  }) {
    final isActive = _selectedType == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedType = key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFD97706) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isActive ? const Color(0xFFD97706) : AppTheme.backgroundColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isActive ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? suffix,
    bool isNumber = false,
    String? fontFamily,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(
              icon,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: isNumber
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              validator: validator,
              style: TextStyle(
                fontFamily: isNumber ? null : fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (suffix != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: UrduAwareText(
                suffix,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
