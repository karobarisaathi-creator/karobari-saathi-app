// lib/features/stock/stock_list_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/stock_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'add_edit_stock_item_screen.dart';
import 'stock_detail_screen.dart';
import 'stock_adjustment_dialog.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isAscending = true;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final summary = stockService.getStockSummary();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isUrdu ? 'اسٹاک اور انوینٹری' : 'Stock & Inventory',
          style: TextStyle(
            color: Colors.white,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: isUrdu ? 'پیچھے جائیں' : 'Back',
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off : PhosphorIcons.magnifyingGlass(),
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                }
              });
            },
            tooltip: isUrdu ? 'تلاش' : 'Search',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 📊 Top Valuation Summary Header
          _buildSummaryHeader(summary, isUrdu, fontFamily),

          // TabBar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.themeColor,
              labelColor: AppTheme.darkColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: isUrdu ? 'میری آئٹمز' : 'My Items'),
                Tab(text: isUrdu ? 'کم اسٹاک' : 'Low Stock'),
                Tab(text: isUrdu ? 'اسٹاک ہسٹری' : 'History Log'),
              ],
            ),
          ),

          // 🔍 Search Bar (Conditional)
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SearchSortBar(
                hintText: isUrdu ? 'آئٹم تلاش کریں...' : 'Search stock item...',
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                onSortToggled: () => setState(() => _isAscending = !_isAscending),
                isAscending: _isAscending,
              ),
            ),

          // 📄 Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildItemListTab(stockService, isUrdu, fontFamily,
                    filterLowStock: false),
                _buildItemListTab(stockService, isUrdu, fontFamily,
                    filterLowStock: true),
                _buildHistoryTab(stockService, isUrdu, fontFamily),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditStockItemScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.darkColor,
        icon: Icon(PhosphorIcons.plus(), color: Colors.white),
        label: Text(
          isUrdu ? 'نیا آئٹم' : 'Add Item',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(
    Map<String, dynamic> summary,
    bool isUrdu,
    String fontFamily,
  ) {
    final totalPurchaseValue = summary['totalPurchaseValue'] as double? ?? 0.0;
    final totalSalesPotentialValue =
        summary['totalSalesPotentialValue'] as double? ?? 0.0;
    final lowStockCount = summary['lowStockCount'] as int? ?? 0;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          _buildSummaryItem(
            isUrdu ? 'خرید مالیت' : 'Purchase Value',
            'Rs. ${totalPurchaseValue.toStringAsFixed(0)}',
            PhosphorIcons.arrowDownLeft(),
            fontFamily,
          ),
          _buildDivider(),
          _buildSummaryItem(
            isUrdu ? 'فروخت مالیت' : 'Sales Value',
            'Rs. ${totalSalesPotentialValue.toStringAsFixed(0)}',
            PhosphorIcons.arrowUpRight(),
            fontFamily,
          ),
          _buildDivider(),
          _buildSummaryItem(
            isUrdu ? 'کم اسٹاک الرٹس' : 'Low Stock',
            '$lowStockCount ${isUrdu ? 'آئٹمز' : 'items'}',
            PhosphorIcons.bellRinging(),
            fontFamily,
            isWarning: lowStockCount > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    String fontFamily, {
    bool isWarning = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isWarning ? const Color(0xFFFBBF24) : Colors.white70,
              fontSize: 11,
              fontFamily: fontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 12,
                  color: isWarning ? const Color(0xFFFBBF24) : Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 20, width: 1, color: Colors.white12);
  }

  Widget _buildItemListTab(
    StockService stockService,
    bool isUrdu,
    String fontFamily, {
    required bool filterLowStock,
  }) {
    var items = stockService.items;

    if (_searchQuery.isNotEmpty) {
      items = items.where((i) {
        final nameMatches =
            i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                i.nameUrdu.contains(_searchQuery);
        final codeMatches = i.barcode.contains(_searchQuery) ||
            i.sku.toLowerCase().contains(_searchQuery.toLowerCase());
        return nameMatches || codeMatches;
      }).toList();
    }

    if (filterLowStock) {
      items = items.where((i) {
        if (!i.trackStock) return false;
        final stock = stockService.calculateCurrentStock(i.id);
        return stock > 0 && stock <= i.minStockAlert;
      }).toList();
    }

    items.sort((a, b) => _isAscending
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.name.toLowerCase().compareTo(a.name.toLowerCase()));

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.package(), size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                filterLowStock
                    ? (isUrdu
                        ? 'تمام اسٹاک تسلی بخش ہے'
                        : 'No low stock alerts!')
                    : (isUrdu ? 'کوئی آئٹم نہیں ملی' : 'No stock items found'),
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return StockCard(
          item: item,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockDetailScreen(item: item),
              ),
            );
          },
          onQuickAdd: () {
            showDialog(
              context: context,
              builder: (context) => StockAdjustmentDialog(
                item: item,
                initialType: StockMovementType.purchase,
              ),
            );
          },
          onQuickRemove: () {
            showDialog(
              context: context,
              builder: (context) => StockAdjustmentDialog(
                item: item,
                initialType: StockMovementType.sale,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(
    StockService stockService,
    bool isUrdu,
    String fontFamily,
  ) {
    final movements = stockService.movements;

    if (movements.isEmpty) {
      return Center(
        child: Text(
          isUrdu ? 'کوئی اسٹاک ہسٹری موجود نہیں' : 'No history movements yet',
          style: TextStyle(color: Colors.grey[600], fontFamily: fontFamily),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final m = movements[index];
        StockItem? stockItem;
        if (m.stockItemId.isNotEmpty) {
          stockItem = stockService.items
              .where((item) => item.id == m.stockItemId)
              .firstOrNull;
        }

        String typeLabel;
        switch (m.type) {
          case StockMovementType.purchase:
          case StockMovementType.customerReturn:
            typeLabel = m.type == StockMovementType.purchase
                ? (isUrdu ? 'خریداری (Stock In)' : 'Purchase')
                : (isUrdu ? 'گاہک کی واپسی' : 'Customer Return');
            break;
          case StockMovementType.sale:
          case StockMovementType.supplierReturn:
            typeLabel = m.type == StockMovementType.sale
                ? (isUrdu ? 'فروخت (Stock Out)' : 'Sale')
                : (isUrdu ? 'سپلاٸر کو واپسی' : 'Supplier Return');
            break;
          case StockMovementType.adjustment:
            typeLabel = isUrdu ? 'ایڈجسٹمنٹ' : 'Adjustment';
            break;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                color: AppTheme.themeColor.withValues(alpha: 0.1),
                child: _buildMovementAvatar(stockItem, m, isUrdu),
              ),
            ),
            title: Text(
              m.stockItemName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: fontFamily,
              ),
            ),
            subtitle: Text(
              '$typeLabel • ${m.reason}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: Text(
              '${m.quantity} x Rs. ${m.unitPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovementAvatar(
      StockItem? stockItem, StockMovement m, bool isUrdu) {
    final path = stockItem?.imagePath;
    if (path == null || path.isEmpty) {
      return Center(
        child: Text(
          m.stockItemName.isNotEmpty ? m.stockItemName[0] : '?',
          style: TextStyle(
              color: AppTheme.darkColor,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      );
    }
    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return isRemote
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                m.stockItemName.isNotEmpty ? m.stockItemName[0] : '?',
                style: TextStyle(
                    color: AppTheme.darkColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          )
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                m.stockItemName.isNotEmpty ? m.stockItemName[0] : '?',
                style: TextStyle(
                    color: AppTheme.darkColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          );
  }
}
