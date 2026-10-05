// lib/features/stock/stock_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
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
      appBar: CustomAppBar(
        title: isUrdu ? 'اسٹاک اور انوینٹری' : 'Stock & Inventory',
        showBackButton: false,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
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
      body: Column(
        children: [
          // 📊 Top Valuation Summary Header
          _buildSummaryHeader(summary, isUrdu, fontFamily),

          // 🔍 Search Bar
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
                _buildItemListTab(stockService, isUrdu, fontFamily, filterLowStock: false),
                _buildItemListTab(stockService, isUrdu, fontFamily, filterLowStock: true),
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
    final totalSalesPotentialValue = summary['totalSalesPotentialValue'] as double? ?? 0.0;
    final lowStockCount = summary['lowStockCount'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
              Icon(icon, size: 12, color: isWarning ? const Color(0xFFFBBF24) : Colors.white70),
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
        final nameMatches = i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            i.nameUrdu.contains(_searchQuery);
        final codeMatches = i.barcode.contains(_searchQuery);
        return nameMatches || codeMatches;
      }).toList();
    }

    if (filterLowStock) {
      items = items.where((i) {
        final stock = stockService.calculateCurrentStock(i.id);
        return stock <= i.minStockAlert;
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
                    ? (isUrdu ? 'تمام اسٹاک تسلی بخش ہے' : 'No low stock alerts!')
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              m.stockItemName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: fontFamily,
              ),
            ),
            subtitle: Text(
              '${m.type.name.toUpperCase()} • ${m.reason}',
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
}
