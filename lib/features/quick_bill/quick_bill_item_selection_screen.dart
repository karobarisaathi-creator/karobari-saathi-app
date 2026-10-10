// lib/features/quick_bill/quick_bill_item_selection_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'quick_bill_preview_screen.dart';

// ═══════════════════════════════════════════════════════════════
// QuickBillCartLine — Model
// ═══════════════════════════════════════════════════════════════
class QuickBillCartLine {
  final String name;
  final String? unit;
  final double rate;
  final String? stockItemId;
  final String? stockItemName;
  final double? availableStock;
  double quantity;

  final bool isManual;
  final String? manualType;

  QuickBillCartLine({
    required this.name,
    this.unit,
    required this.rate,
    this.stockItemId,
    this.stockItemName,
    this.availableStock,
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
  final String category;
  final String? stockItemId;
  final double? availableStock;
  final bool featured;

  const _QuickBillCatalogItem({
    required this.key,
    required this.name,
    this.nameUrdu = '',
    this.unit,
    required this.rate,
    required this.category,
    this.stockItemId,
    this.availableStock,
    this.featured = false,
  });

  String displayName(bool isUrdu) =>
      isUrdu && nameUrdu.isNotEmpty ? nameUrdu : name;
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

  String _activeCategory = _allCategories;
  String _query = '';
  bool _showSearch = false;
  final Map<String, QuickBillCartLine> _cart = {};

  // Manual items list
  final List<QuickBillCartLine> _manualItems = [];

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
        title: Text(isUrdu ? 'مقدار درج کریں' : 'Enter quantity'),
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
          isUrdu ? 'کسٹم آئٹم اپڈیٹ ہو گیا' : 'Custom item updated',
        );
      } else {
        _manualItems.add(result);
        AppToast.success(
          context,
          isUrdu ? 'کسٹم آئٹم شامل ہو گیا' : 'Custom item added',
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
    final manualWithQty =
    _manualItems.where((l) => l.quantity > 0).toList();
    final allLines = [...selectedLines, ...manualWithQty];

    if (allLines.isEmpty) {
      AppToast.warning(
        context,
        isUrdu ? 'پہلے کوئی آئٹم منتخب کریں' : 'Select at least one item',
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
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final stockService = Provider.of<StockService>(context);

    // Build catalog strictly from managed stock items
    final catalog = <String, _QuickBillCatalogItem>{};

    for (final item in stockService.items) {
      catalog['stock:${item.id}'] = _QuickBillCatalogItem(
        key: 'stock:${item.id}',
        name: item.name,
        nameUrdu: item.nameUrdu,
        unit: item.unit,
        rate: item.sellingPrice,
        category: item.categoryName.isNotEmpty
            ? item.categoryName
            : QuickBillConstants.defaultCategory,
        stockItemId: item.id,
        availableStock: item.trackStock && item.stopWhenOut
            ? stockService.availableStockForTransaction(
                item.id,
                excludingTransactionId: widget.transactionToEdit?.id,
              )
            : null,
        featured: item.featured,
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
      ..sort((a, b) {
        final featuredOrder = (b.featured ? 1 : 0) - (a.featured ? 1 : 0);
        if (featuredOrder != 0) return featuredOrder;
        return a.name.compareTo(b.name);
      });

    final stockSelected =
        _cart.values.where((l) => l.quantity > 0).toList();
    final manualSelected =
        _manualItems.where((l) => l.quantity > 0).toList();
    final totalSelectedCount = stockSelected.length + manualSelected.length;
    final total = [
      ...stockSelected,
      ...manualSelected,
    ].fold<double>(0, (s, l) => s + l.total);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'فوری بل — آئٹم چنیں' : 'Quick bill — select items',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(
              _showSearch
                  ? PhosphorIcons.x()
                  : PhosphorIcons.magnifyingGlass(),
              color: Colors.white,
            ),
            tooltip: isUrdu ? 'تلاش' : 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _query = '';
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // ═══ Search Bar (Conditional) ═══
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showSearch
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: _buildSearchBar(isUrdu, fontFamily),
                  )
                : const SizedBox.shrink(),
          ),

          // ═══ Category Chips ═══
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final active = cat == _activeCategory;
                  final label = cat == _allCategories
                      ? (isUrdu ? 'سب' : 'All')
                      : cat;
                  return _buildCategoryChip(
                    label: label,
                    isActive: active,
                    fontFamily: fontFamily,
                    onTap: () => setState(() => _activeCategory = cat),
                  );
                },
              ),
            ),
          ),

          // ═══ Items List ═══
          Expanded(
            child: stockService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (entries.isEmpty && _manualItems.isEmpty)
                ? _buildEmptyState(isUrdu, fontFamily)
                : ListView.builder(
              padding:
              const EdgeInsets.fromLTRB(14, 6, 14, 10),
              itemCount: 1 + _manualItems.length + entries.length,
              itemBuilder: (context, index) {
                // Custom Item Card at index 0
                if (index == 0) {
                  return _buildCustomItemCard(
                    isUrdu,
                    fontFamily,
                  );
                }
                // Manual Items
                if (index <= _manualItems.length) {
                  final manualItem = _manualItems[index - 1];
                  return _buildManualItemCard(
                    manualItem,
                    isUrdu,
                    fontFamily,
                  );
                }
                // Stock Catalog Items
                final e = entries[index - 1 - _manualItems.length];
                return _buildItemCard(
                  e,
                  stockService,
                  isUrdu,
                  fontFamily,
                );
              },
            ),
          ),

          // ═══ Bottom Bar ═══
          if (totalSelectedCount > 0)
            _buildBottomBar(
              totalSelectedCount,
              total,
              isUrdu,
              fontFamily,
                  () => _openPreview(stockSelected, isUrdu),
            ),
        ],
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openManualEntryDialog(isUrdu, fontFamily, editLine: line),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    PhosphorIcons.wrench(),
                    size: 20,
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 10),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              line.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF92400E),
                                fontFamily: fontFamily,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${line.quantity == line.quantity.roundToDouble() ? line.quantity.toInt() : line.quantity}x @ Rs ${line.rate.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${line.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Delete Button only
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _manualItems.remove(line);
                      });
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppTheme.expenseColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        PhosphorIcons.trash(),
                        size: 16,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // CUSTOM ITEM CARD — List کا سب سے اوپر
  // ═════════════════════════════════════════════════════════════
  Widget _buildCustomItemCard(bool isUrdu, String? fontFamily) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openManualEntryDialog(isUrdu, fontFamily),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD97706),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isUrdu ? 'اضافی سروس / مزدوری' : 'Extra Service / Labour',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                              fontFamily: fontFamily,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'MANUAL',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUrdu
                          ? 'مزدوری، ڈیلیوری، اضافی سروس'
                          : 'Labour, delivery, extra service',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E)
                            .withValues(alpha: 0.75),
                        fontFamily: fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Plus Icon Box
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: const Color(0xFFD97706),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  PhosphorIcons.plus(),
                  size: 18,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Search Bar
  // ═════════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isUrdu, String? fontFamily) {
    return SearchSortBar(
      padding: EdgeInsets.zero,
      hintText: isUrdu ? 'آئٹم تلاش کریں...' : 'Search item...',
      onSearchChanged: (v) => setState(() => _query = v),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Category Chip
  // ═════════════════════════════════════════════════════════════
  Widget _buildCategoryChip({
    required String label,
    required bool isActive,
    required String? fontFamily,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.darkColor : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? AppTheme.darkColor
                  : AppTheme.backgroundColor,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              color: isActive ? Colors.white : AppTheme.darkColor,
              fontFamily: fontFamily,
              letterSpacing: 0.1,
            ),
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
      StockService stockService,
      bool isUrdu,
      String? fontFamily,
      ) {
    final originalLine = widget.transactionToEdit?.items
        .where((item) {
      if (item.stockItemId != null && item.stockItemId!.isNotEmpty) {
        return item.stockItemId == e.stockItemId;
      }
      final oldName = item.description.trim().toLowerCase();
      return oldName == e.name.trim().toLowerCase() ||
          (e.nameUrdu.isNotEmpty &&
              oldName == e.nameUrdu.trim().toLowerCase());
    })
        .firstOrNull;

    final line = _cart.putIfAbsent(
      e.key,
          () => QuickBillCartLine(
        name: originalLine?.description ?? e.displayName(isUrdu),
        unit: e.unit,
        rate: originalLine?.rate ?? e.rate,
        stockItemId: e.stockItemId,
        stockItemName: e.name,
        availableStock: e.availableStock,
        quantity: originalLine?.quantity ?? 0,
      ),
    );

    final selected = line.quantity > 0;
    final stockLimitReached = line.availableStock != null &&
        line.quantity >= line.availableStock!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.themeColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.themeColor : AppTheme.backgroundColor,
          width: selected ? 1 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.themeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppTheme.themeColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: _buildItemAvatar(e, stockService, isUrdu),
            ),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.displayName(isUrdu),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Rs ${line.rate.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkColor,
                        ),
                      ),
                      if (line.availableStock != null) ...[
                        Text(
                          '  /  ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final remainingStock =
                                (line.availableStock! - line.quantity)
                                    .clamp(0.0, double.infinity);
                            final formattedStock =
                                remainingStock == remainingStock.roundToDouble()
                                    ? remainingStock.toInt().toString()
                                    : remainingStock.toStringAsFixed(1);
                            final isZero = remainingStock <= 0;
                            final stockColor = isZero
                                ? AppTheme.expenseColor
                                : AppTheme.textSecondary;

                            return Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: isUrdu ? 'اسٹاک: ' : 'Stock: ',
                                    style: TextStyle(
                                      fontFamily: fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: stockColor,
                                    ),
                                  ),
                                  TextSpan(
                                    text: formattedStock,
                                    style: TextStyle(
                                      fontFamily: null,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: stockColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ═══ Quantity Stepper — Big Full Pill (مکمل گول) ═══
            Container(
              decoration: BoxDecoration(
                // ہلکا نیلا بیک گراؤنڈ (جب selected ہو)
                // ورنہ ہلکا گرے
                color: selected
                    ? const Color(0xFFEEF4FF)
                    : const Color(0xFFF5F7FA),
                // مکمل گول کنارے
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppTheme.themeColor
                      : AppTheme.backgroundColor,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ═══ Minus Button ═══
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: line.quantity > 0
                          ? () {
                              setState(() => line.quantity =
                                  (line.quantity - 1).clamp(0, double.infinity));
                            }
                          : null,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: line.quantity > 0
                              ? Colors.white
                              : const Color(0xFFEEF1F5),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: line.quantity > 0
                              ? [
                                  BoxShadow(
                                    color: AppTheme.darkColor.withValues(alpha: 0.06),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          PhosphorIcons.minus(),
                          size: 16,
                          color: line.quantity > 0
                              ? AppTheme.themeColor
                              : AppTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),

                  // ═══ Value (Tap to edit) ═══
                  InkWell(
                    onTap: () => _editQuantity(line, isUrdu),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 42),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      child: Text(
                        line.quantity == line.quantity.roundToDouble()
                            ? line.quantity.toInt().toString()
                            : line.quantity.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? AppTheme.themeColor
                              : AppTheme.darkColor,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),

                  // ═══ Plus Button ═══
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: stockLimitReached
                          ? null
                          : () {
                              setState(() => line.quantity += 1);
                            },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: stockLimitReached
                              ? const Color(0xFFEEF1F5)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: !stockLimitReached
                              ? [
                                  BoxShadow(
                                    color: AppTheme.darkColor.withValues(alpha: 0.06),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          PhosphorIcons.plus(),
                          size: 16,
                          color: stockLimitReached
                              ? AppTheme.textSecondary.withValues(alpha: 0.5)
                              : AppTheme.themeColor,
                        ),
                      ),
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

  // ═════════════════════════════════════════════════════════════
  // Quantity Button — background color کے ساتھ
  // ═════════════════════════════════════════════════════════════
  Widget _buildQtyBtn({
    required IconData icon,
    required bool enabled,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? bgColor
                : AppTheme.backgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 13,
            color: enabled
                ? iconColor
                : AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Bottom Bar — سادہ، بغیر gradient
  // ═════════════════════════════════════════════════════════════
  Widget _buildBottomBar(
      int count,
      double total,
      bool isUrdu,
      String? fontFamily,
      VoidCallback onViewBill,
      ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onViewBill,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Count badge
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isUrdu ? 'آئٹمز منتخب' : 'items selected',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xD9FFFFFF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rs ${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // View Bill button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.themeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isUrdu ? 'بل دیکھیں' : 'View Bill',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: fontFamily,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            PhosphorIcons.arrowRight(),
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Empty State
  // ═════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isUrdu, String? fontFamily) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      children: [
        _buildCustomItemCard(isUrdu, fontFamily),
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
              Text(
                isUrdu ? 'کوئی آئٹم نہیں ملا' : 'No items found',
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

  // ═════════════════════════════════════════════════════════════
  // Item Avatar
  // ═════════════════════════════════════════════════════════════
  Widget _buildItemAvatar(
      _QuickBillCatalogItem e,
      StockService stockService,
      bool isUrdu,
      ) {
    StockItem? stockItem;
    if (e.stockItemId != null) {
      stockItem = stockService.items
          .where((item) => item.id == e.stockItemId)
          .firstOrNull;
    }
    final path = stockItem?.imagePath;

    final fallback = Center(
      child: Text(
        e.displayName(isUrdu).isNotEmpty ? e.displayName(isUrdu)[0] : '?',
        style: const TextStyle(
          color: AppTheme.themeColor,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );

    if (path == null || path.isEmpty) return fallback;

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: isRemote
          ? Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      )
          : Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
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
                        Text(
                          widget.editLine != null
                              ? (isUrdu ? 'کسٹم آئٹم اپڈیٹ کریں' : 'Update Custom Item')
                              : (isUrdu ? 'کسٹم آئٹم شامل کریں' : 'Add Custom Item'),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
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
                        _buildSectionLabel(isUrdu ? 'تفصیل *' : 'DESCRIPTION *'),
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
                          Text(
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
    return Text(
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
              color: isActive
                  ? const Color(0xFFD97706)
                  : AppTheme.backgroundColor,
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
              Text(
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
              child: Text(
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