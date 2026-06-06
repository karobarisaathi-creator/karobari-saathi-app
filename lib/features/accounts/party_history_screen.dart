import 'package:account_app/features/inventory/item_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/product_card.dart';

class PartyHistoryScreen extends StatefulWidget {
  final Account party;

  const PartyHistoryScreen({super.key, required this.party});

  @override
  State<PartyHistoryScreen> createState() => _PartyHistoryScreenState();
}

class _PartyHistoryScreenState extends State<PartyHistoryScreen> with TickerProviderStateMixin {
  List<model.Transaction> _transactions = [];
  Map<String, List<ItemPriceHistory>> _itemHistory = {};
  Map<String, InventoryItem> _managedItemsMap = {};
  bool _isLoadingRemoteItems = false;
  late AnimationController _shimmerController;
  
  double _totalIn = 0;
  double _totalOut = 0;
  double _totalVolume = 0;
  int _totalDeals = 0;
  String _avgPaymentDays = '0';
  DateTime? _firstDeal;
  String _mostTradedItem = '-';
  double _trustScore = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadData();
    _loadRemoteItems();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteItems() async {
    // Clear existing items to prevent data mixing between different parties
    setState(() {
      _managedItemsMap.clear();
      _isLoadingRemoteItems = true;
    });

    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // 1. Find the party's UID via their phone number
    final profile = await db.findPublicProfileByPhone(widget.party.phone);
    if (profile != null && profile['uid'] != null) {
      final uid = profile['uid']!;

      // 2. Load from local cache first (Immediate)
      final cachedItems = db.getRemoteCachedItems(uid);
      if (cachedItems.isNotEmpty && mounted) {
        setState(() {
          for (var item in cachedItems) {
            _managedItemsMap[item.name.trim().toLowerCase()] = item;
          }
          _isLoadingRemoteItems = false; // Stop spinner as we have cached data
        });
      }

      // 3. Fetch fresh items from Firebase in background
      final remoteItems = await db.getRemoteInventoryItems(uid);
      
      if (mounted) {
        setState(() {
          // Filter to ensure only items belonging to this specific party are shown
          final filteredItems = remoteItems.where((item) => item.accountId == uid).toList();
          for (var item in filteredItems) {
            _managedItemsMap[item.name.trim().toLowerCase()] = item;
          }
          _isLoadingRemoteItems = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRemoteItems = false);
    }
  }

  void _loadData() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final allTx = db.getAllTransactions().where((t) => t.accountId == widget.party.id).toList();
    
    // Get list of all managed item names to filter history
    // (This helps us identify which items from transactions should have a rate history)
    final inventoryItems = db.getInventoryItems();
    final managedNames = inventoryItems.map((e) => e.name.trim().toLowerCase()).toSet();
    
    Map<String, int> itemCount = {};

    // General stats calculations
    for (var tx in allTx) {
      if (tx.type == 'income') {
        _totalIn += tx.amount;
      } else {
        _totalOut += tx.amount;
      }
      if (_firstDeal == null || tx.date.isBefore(_firstDeal!)) {
        _firstDeal = tx.date;
      }

      // Track item frequency - Only count managed items with valid rates
      for (var item in tx.items) {
        final name = item.description.trim();
        final nameLower = name.toLowerCase();
        if (name.isNotEmpty && managedNames.contains(nameLower) && item.rate > 0) {
          itemCount[name] = (itemCount[name] ?? 0) + 1;
        }
      }
    }

    if (itemCount.isNotEmpty) {
      _mostTradedItem = itemCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    // Process History: Sort oldest first to detect changes over time
    final chronologicalTx = List.from(allTx)..sort((a, b) => a.date.compareTo(b.date));
    Map<String, List<ItemPriceHistory>> history = {};
    
    for (var tx in chronologicalTx) {
      // Only process 'income' transactions for rate history as per user requirement
      if (tx.type != 'income') continue;

      if (tx.items.isNotEmpty) {
        for (var item in tx.items) {
          // Add to history if it has a rate
          if (item.rate > 0) {
            _addItemToHistory(history, item.description, item.rate, tx.date, tx.type);
          }
        }
      }
    }
    
    // Reverse price lists to show newest changes first in UI
    history.forEach((key, value) {
      history[key] = value.reversed.toList();
    });

    _totalVolume = _totalIn + _totalOut;
    
    if (allTx.length > 1) {
      final days = allTx.first.date.difference(allTx.last.date).inDays;
      _avgPaymentDays = (days / allTx.length).toStringAsFixed(1);
    }

    // Simple Trust Score Logic (1-5)
    double score = 1.0;
    if (allTx.length > 5) score += 1.0;
    if (allTx.length > 15) score += 1.0;
    if (_totalIn + _totalOut > 50000) score += 1.0;
    if (_totalIn + _totalOut > 200000) score += 1.0;
    _trustScore = score;

    _transactions = List.from(allTx)..sort((a, b) => b.date.compareTo(a.date));
    _totalDeals = allTx.length;

    setState(() {
      _itemHistory = history;
    });
  }

  void _addItemToHistory(Map<String, List<ItemPriceHistory>> history, String name, double price, DateTime date, String type) {
    if (name.isEmpty || name == 'دیگر' || name == 'Other') return;
    
    final cleanName = name.trim();
    if (!history.containsKey(cleanName)) {
      history[cleanName] = [];
      history[cleanName]!.add(ItemPriceHistory(price: price, date: date, type: type));
    } else {
      final lastEntry = history[cleanName]!.last;
      final lastRecordedPrice = lastEntry.price;
      if (lastRecordedPrice != price) {
        final double percentage = ((price - lastRecordedPrice) / lastRecordedPrice) * 100;
        final int days = date.difference(lastEntry.date).inDays;
        
        history[cleanName]!.add(ItemPriceHistory(
          price: price, 
          date: date, 
          type: type,
          changePercentage: percentage,
          daysInterval: days,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: isUrdu ? 'تجزیہ و ریکارڈ' : 'Analysis & History',
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Relationship Section - Removed outer container for better edge-to-edge look
            Column(
              children: [
                if (widget.party.address != null && widget.party.address!.isNotEmpty)
                  _buildInfoTile(
                    isUrdu ? 'پتہ' : 'Address',
                    widget.party.address!,
                    PhosphorIcons.mapPin(),
                    isUrdu, fontFamily
                  ),
                _buildInfoTile(
                  isUrdu ? 'پہلا لین دین' : 'First Transaction',
                  _firstDeal != null ? DateFormat('dd MMM yyyy', 'en_US').format(_firstDeal!) : '-',
                  PhosphorIcons.calendar(),
                  isUrdu, fontFamily
                ),
                _buildInfoTile(
                  isUrdu ? 'کل عرصہ تعلق' : 'Relationship Period',
                  _getRelationshipPeriod(),
                  PhosphorIcons.hourglass(),
                  isUrdu, fontFamily
                ),
                _buildInfoTile(
                  isUrdu ? 'کل کاروباری حجم' : 'Total Business Volume',
                  'Rs ${_totalVolume.toStringAsFixed(0)}',
                  PhosphorIcons.chartLineUp(),
                  isUrdu, fontFamily
                ),
                _buildInfoTile(
                  isUrdu ? 'اوسط لین دین کا وقفہ' : 'Avg. Deal Interval',
                  '$_avgPaymentDays days',
                  PhosphorIcons.clock(),
                  isUrdu, fontFamily
                ),
                _buildInfoTile(
                  isUrdu ? 'کل انٹریز' : 'Total Entries',
                  _totalDeals.toString(),
                  PhosphorIcons.listNumbers(),
                  isUrdu, fontFamily
                ),
                _buildInfoTile(
                  isUrdu ? 'سب سے زیادہ آئٹم' : 'Top Item',
                  _mostTradedItem,
                  PhosphorIcons.package(),
                  isUrdu, fontFamily
                ),
                _buildTrustScoreTile(isUrdu, fontFamily),
              ],
            ),

            const SizedBox(height: 24),

            // Item Rate History Section
            if (_itemHistory.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.chartLineUp(), color: AppTheme.themeColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isUrdu ? 'ریٹ کی تبدیلی کی ہسٹری' : 'Item Rate History',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                      ),
                    ),
                  ],
                ),
              ),
              ..._itemHistory.entries.map((entry) => _buildItemHistoryCard(entry.key, entry.value, isUrdu, fontFamily)).toList(),
              const SizedBox(height: 24),
            ],

            // Party's Items Section
            if (_isLoadingRemoteItems)
              const Center(child: CircularProgressIndicator())
            else if (_managedItemsMap.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.shoppingBag(), color: AppTheme.themeColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isUrdu ? '${widget.party.name} کی مصنوعات' : "${widget.party.name}'s Products",
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _managedItemsMap.length,
                itemBuilder: (context, index) {
                  final item = _managedItemsMap.values.toList()[index];
                  return ProductCard(
                    item: item,
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    view: ProductCardView.grid,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item))),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemHistoryCard(String itemName, List<ItemPriceHistory> history, bool isUrdu, String fontFamily) {
    final item = _managedItemsMap[itemName.toLowerCase()];
    if (item == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          ProductCard(
            item: item,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            view: ProductCardView.list,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item))),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: history.map((h) => _buildPriceRow(h, isUrdu)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getRelationshipPeriod() {
    if (_firstDeal == null || _transactions.isEmpty) return '-';
    final lastDeal = _transactions.first.date;
    final diff = lastDeal.difference(_firstDeal!);
    
    if (diff.inDays < 30) {
      return '${diff.inDays} days';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months months';
    } else {
      final years = (diff.inDays / 365).floor();
      final remainingMonths = ((diff.inDays % 365) / 30).floor();
      if (remainingMonths == 0) {
        return '$years years';
      }
      return '$years years $remainingMonths months';
    }
  }

  Widget _buildInfoTile(String title, String value, IconData icon, bool isUrdu, String fontFamily) {
    // Check if the value contains Urdu characters
    bool hasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(value);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.themeColor.withOpacity(0.05), // Light theme color (Blue) background
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.themeColor.withOpacity(0.7), size: 18),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontFamily: fontFamily, fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.bold)),
          const Spacer(),
          // Force English values (like "2 years") to always show Number first (LTR)
          Directionality(
            textDirection: hasUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Text(value, style: TextStyle(
              fontWeight: FontWeight.normal, 
              fontSize: 14, 
              color: AppTheme.darkColor, 
              fontFamily: hasUrdu ? 'NooriNastaleeq' : ''
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustScoreTile(bool isUrdu, String fontFamily) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.themeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.shieldCheck(), color: AppTheme.themeColor.withOpacity(0.7), size: 18),
          const SizedBox(width: 12),
          Text(
            isUrdu ? 'اعتماد کا اسکور' : 'Trust Score', 
            style: TextStyle(fontFamily: fontFamily, fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.bold)
          ),
          const Spacer(),
          // Always show stars Left-to-Right
          Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < _trustScore ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppTheme.themeColor,
                  size: 16,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(ItemPriceHistory history, bool isUrdu) {
    final isIncrease = (history.changePercentage ?? 0) > 0;
    // Rate increase is Red, Rate decrease is Green
    final color = isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          // Date & Interval (Darker Color)
          Text(
            DateFormat('dd/MM/yy').format(history.date),
            style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w500, fontFamily: ''),
          ),
          if (history.daysInterval != null) ...[
            const SizedBox(width: 6),
            Text(
              '(${history.daysInterval}d)',
              style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.bold, fontFamily: ''),
            ),
          ],
          
          const SizedBox(width: 12),

          // Percentage & Arrow (Now on the left side)
          if (history.changePercentage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isIncrease ? PhosphorIcons.arrowUp() : PhosphorIcons.arrowDown(),
                    size: 10,
                    color: color,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${history.changePercentage!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: ''),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Price (Back to its original right-side position)
          Text(
            'Rs ${history.price.toStringAsFixed(0)}', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: ''),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: 220,
          height: 290,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShimmerBox(height: 135, margin: const EdgeInsets.all(6), radius: 8),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(width: 120, height: 15),
                    const SizedBox(height: 8),
                    _buildShimmerBox(width: 180, height: 12),
                    const SizedBox(height: 4),
                    _buildShimmerBox(width: 140, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({double? width, double? height, EdgeInsets? margin, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [
            _shimmerController.value - 0.3,
            _shimmerController.value,
            _shimmerController.value + 0.3,
          ],
          colors: [
            Colors.grey[200]!,
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
        ),
      ),
    );
  }
}

class ItemPriceHistory {
  final double price;
  final DateTime date;
  final String type;
  final double? changePercentage;
  final int? daysInterval;

  ItemPriceHistory({
    required this.price, 
    required this.date, 
    required this.type,
    this.changePercentage,
    this.daysInterval,
  });
}
