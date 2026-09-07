import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PartyHistoryScreen extends StatefulWidget {
  final Account party;

  const PartyHistoryScreen({super.key, required this.party});

  @override
  State<PartyHistoryScreen> createState() => _PartyHistoryScreenState();
}

class _PartyHistoryScreenState extends State<PartyHistoryScreen>
    with TickerProviderStateMixin {
  List<model.Transaction> _transactions = [];
  Map<String, List<ItemPriceHistory>> _itemHistory = {};
  late AnimationController _shimmerController;
  String? _remoteProfession;
  String? _remoteAddress;

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
    final db = Provider.of<DatabaseService>(context, listen: false);

    // 1. Find the party's UID via their phone number
    final profile = await db.findPublicProfileByPhone(widget.party.phone);
    if (profile != null) {
      if (mounted) {
        setState(() {
          _remoteProfession = profile['profession'];
          _remoteAddress = profile['address'];
        });
      }
    }
  }

  Future<void> _loadData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final clearedAt = <String, DateTime>{};
    for (final entry
        in preferences.getStringList('rate_history_cleared_at') ?? []) {
      final separator = entry.indexOf('|');
      if (separator > 0) {
        final date = DateTime.tryParse(entry.substring(separator + 1));
        if (date != null) clearedAt[entry.substring(0, separator)] = date;
      }
    }
    final allTx = db
        .getAllTransactions()
        .where((t) => t.accountId == widget.party.id)
        .toList();

    _totalIn = 0;
    _totalOut = 0;
    _totalVolume = 0;
    _totalDeals = 0;
    _firstDeal = null;

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

      // Track item frequency
      for (var item in tx.items) {
        final name = item.description.trim();
        if (name.isNotEmpty && item.rate > 0) {
          itemCount[name] = (itemCount[name] ?? 0) + 1;
        }
      }
    }

    if (itemCount.isNotEmpty) {
      _mostTradedItem =
          itemCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    // Process History: Sort oldest first to detect changes over time
    final chronologicalTx = List.from(allTx)
      ..sort((a, b) => a.date.compareTo(b.date));
    Map<String, List<ItemPriceHistory>> history = {};

    for (var tx in chronologicalTx) {
      // Process both income and expense transactions for rate history
      if (tx.items.isNotEmpty) {
        for (var item in tx.items) {
          // Add to history if it has a rate
          final cleared = clearedAt[item.description.trim()];
          if (item.rate > 0 &&
              (cleared == null || tx.createdAt.isAfter(cleared))) {
            _addItemToHistory(
                history, item.description, item.rate, tx.date, tx.type);
          }
        }
      }
    }

    // Reverse price lists to show newest changes first in UI
    history.forEach((key, value) {
      // Ensure we sort by date descending to have the newest at the top
      value.sort((a, b) => b.date.compareTo(a.date));
      history[key] = value;
    });
    final sortedHistory = Map.fromEntries(history.entries.toList()
      ..sort((a, b) => b.value.first.date.compareTo(a.value.first.date)));

    _totalVolume = _totalIn + _totalOut;

    if (allTx.length > 1) {
      final days = allTx.first.date.difference(allTx.last.date).inDays;
      _avgPaymentDays = (days / allTx.length).toStringAsFixed(1);
    }

    // --- Improved Trust Score Logic (5 Pillars) ---
    double score = 0;

    // 1. Verification Pillar (1.0)
    if (widget.party.isVerified) score += 1.0;

    // 2. Loyalty Pillar (1.0) - How old is the relationship?
    final daysSinceFirstDeal =
        DateTime.now().difference(_firstDeal ?? DateTime.now()).inDays;
    if (daysSinceFirstDeal > 180)
      score += 1.0; // 6+ months
    else if (daysSinceFirstDeal > 30) score += 0.5; // 1+ month

    // 3. Frequency Pillar (1.0) - Number of deals
    if (_totalDeals > 25)
      score += 1.0;
    else if (_totalDeals > 10) score += 0.5;

    // 4. Volume Pillar (1.0) - Total money moved
    if (_totalVolume > 100000)
      score += 1.0;
    else if (_totalVolume > 20000) score += 0.5;

    // 5. Reliability Pillar (1.0) - How much of the total business is cleared?
    // If they move a lot of money but keep a small balance, they are reliable.
    if (_totalVolume > 0) {
      final clearedRatio = 1 - (widget.party.balance.abs() / _totalVolume);
      if (clearedRatio > 0.9)
        score += 1.0; // 90% cleared
      else if (clearedRatio > 0.7) score += 0.5; // 70% cleared
    }

    // Ensure score is between 1 and 5
    _trustScore = score.clamp(1.0, 5.0);

    _transactions = List.from(allTx)..sort((a, b) => b.date.compareTo(a.date));
    _totalDeals = allTx.length;

    setState(() {
      _itemHistory = sortedHistory;
    });
  }

  Future<void> _clearRateHistory(
      String itemName, bool isUrdu, String fontFamily) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isUrdu ? 'ریٹ ہسٹری صاف کریں؟' : 'Clear rate history?',
            style: TextStyle(fontFamily: fontFamily)),
        content: Text(
          isUrdu
              ? 'صرف ریٹ ہسٹری صاف ہوگی، کھاتے کی transaction محفوظ رہے گی۔'
              : 'Only rate history will be cleared. The account transaction will remain.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isUrdu ? 'صاف کریں' : 'Clear',
                style: TextStyle(color: AppTheme.expenseColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList('rate_history_cleared_at') ?? [];
    entries.removeWhere((entry) => entry.startsWith('$itemName|'));
    entries.add('$itemName|${DateTime.now().toIso8601String()}');
    await preferences.setStringList('rate_history_cleared_at', entries);
    if (mounted) await _loadData();
  }

  void _addItemToHistory(Map<String, List<ItemPriceHistory>> history,
      String name, double price, DateTime date, String type) {
    if (name.isEmpty || name == 'دیگر' || name == 'Other') return;

    final cleanName = name.trim();
    if (!history.containsKey(cleanName)) {
      history[cleanName] = [];
      history[cleanName]!
          .add(ItemPriceHistory(price: price, date: date, type: type));
    } else {
      final lastEntry = history[cleanName]!.last;
      final lastRecordedPrice = lastEntry.price;
      if (lastRecordedPrice != price) {
        final double percentage =
            ((price - lastRecordedPrice) / lastRecordedPrice) * 100;
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'تجزیہ و ریکارڈ' : 'Analysis & History',
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Relationship Section - Grouped in a White Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoTile(
                      isUrdu ? 'فون نمبر' : 'Phone Number',
                      widget.party.phone.replaceAll('+92', '0'),
                      PhosphorIcons.phone(),
                      isUrdu,
                      fontFamily),
                  const Divider(height: 1, thickness: 0.5),
                  if ((_remoteProfession != null &&
                          _remoteProfession!.isNotEmpty) ||
                      (isUrdu ? 'پرسنل کھاتہ' : 'Personal Account')
                          .isNotEmpty) ...[
                    _buildInfoTile(
                        isUrdu ? 'پیشہ / نوعیت' : 'Profession / Type',
                        (_remoteProfession != null &&
                                _remoteProfession!.isNotEmpty)
                            ? _remoteProfession!
                            : (isUrdu ? 'پرسنل کھاتہ' : 'Personal Account'),
                        PhosphorIcons.briefcase(),
                        isUrdu,
                        fontFamily),
                    const Divider(height: 1, thickness: 0.5),
                  ],
                  if ((widget.party.address != null &&
                          widget.party.address!.isNotEmpty) ||
                      (_remoteAddress != null &&
                          _remoteAddress!.isNotEmpty)) ...[
                    _buildInfoTile(
                        isUrdu ? 'پتہ' : 'Address',
                        (_remoteAddress != null && _remoteAddress!.isNotEmpty)
                            ? _remoteAddress!
                            : widget.party.address!,
                        PhosphorIcons.mapPin(),
                        isUrdu,
                        fontFamily),
                    const Divider(height: 1, thickness: 0.5),
                  ],
                  _buildInfoTile(
                      isUrdu ? 'پہلا لین دین' : 'First Transaction',
                      _firstDeal != null
                          ? DateFormat('dd MMM yyyy', 'en_US')
                              .format(_firstDeal!)
                          : '-',
                      PhosphorIcons.calendar(),
                      isUrdu,
                      fontFamily),
                  const Divider(height: 1, thickness: 0.5),
                  _buildInfoTile(
                      isUrdu ? 'کل عرصہ تعلق' : 'Relationship Period',
                      _getRelationshipPeriod(),
                      PhosphorIcons.hourglass(),
                      isUrdu,
                      fontFamily),
                  const Divider(height: 1, thickness: 0.5),
                  _buildInfoTile(
                      isUrdu ? 'کل کاروباری حجم' : 'Total Business Volume',
                      'Rs ${_totalVolume.toStringAsFixed(0)}',
                      PhosphorIcons.chartLineUp(),
                      isUrdu,
                      fontFamily),
                  const Divider(height: 1, thickness: 0.5),
                  _buildInfoTile(
                      isUrdu ? 'اوسط لین دین کا وقفہ' : 'Avg. Deal Interval',
                      '$_avgPaymentDays days',
                      PhosphorIcons.clock(),
                      isUrdu,
                      fontFamily),
                  const Divider(height: 1, thickness: 0.5),
                  _buildInfoTile(
                      isUrdu ? 'کل انٹریز' : 'Total Entries',
                      _totalDeals.toString(),
                      PhosphorIcons.listNumbers(),
                      isUrdu,
                      fontFamily),
                  const Divider(height: 1, thickness: 0.5),
                  _buildInfoTile(
                      isUrdu ? 'سب سے زیادہ آئٹم' : 'Top Item',
                      _mostTradedItem,
                      PhosphorIcons.package(),
                      isUrdu,
                      fontFamily),
                  const Divider(height: 1, thickness: 0.5),
                  _buildTrustScoreTile(isUrdu, fontFamily),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Item Rate History Section
            if (_itemHistory.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.chartLineUp(),
                        color: AppTheme.themeColor, size: 22),
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
              ..._itemHistory.entries.map((entry) => _buildItemHistoryCard(
                  entry.key, entry.value, isUrdu, fontFamily)),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemHistoryCard(String itemName, List<ItemPriceHistory> history,
      bool isUrdu, String fontFamily) {
    return GestureDetector(
      onLongPress: () => _clearRateHistory(itemName, isUrdu, fontFamily),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                itemName,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children:
                    history.map((h) => _buildPriceRow(h, isUrdu)).toList(),
              ),
            ),
          ],
        ),
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

  Widget _buildInfoTile(String title, String value, IconData icon, bool isUrdu,
      String fontFamily) {
    // Check if the value contains Urdu characters
    bool hasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(value);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.themeColor.withOpacity(0.7), size: 18),
          const SizedBox(width: 12),
          Text(title,
              style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 13,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          // Force English values (like "2 years") to always show Number first (LTR)
          Directionality(
            textDirection:
                hasUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                    color: AppTheme.darkColor,
                    fontFamily: hasUrdu ? 'NooriNastaleeq' : '')),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustScoreTile(bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(PhosphorIcons.shieldCheck(),
              color: AppTheme.themeColor.withOpacity(0.7), size: 18),
          const SizedBox(width: 12),
          Text(isUrdu ? 'اعتماد کا اسکور' : 'Trust Score',
              style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 13,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          // Always show stars Left-to-Right
          Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < _trustScore
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
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
    final color = history.type == 'income'
        ? (isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor)
        : (isIncrease
            ? AppTheme.expenseColor
            : AppTheme.incomeColor); // Same logic for now, but aware of type

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          // Date & Interval (Darker Color)
          Text(
            DateFormat('dd/MM/yy').format(history.date),
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
                fontFamily: ''),
          ),
          if (history.daysInterval != null) ...[
            const SizedBox(width: 6),
            Text(
              '(${history.daysInterval}d)',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontFamily: ''),
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
                    isIncrease
                        ? PhosphorIcons.arrowUp()
                        : PhosphorIcons.arrowDown(),
                    size: 10,
                    color: color,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${history.changePercentage!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFamily: ''),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Price (Back to its original right-side position)
          Text(
            'Rs ${history.price.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, fontFamily: ''),
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
              _buildShimmerBox(
                  height: 135, margin: const EdgeInsets.all(6), radius: 8),
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

  Widget _buildShimmerBox(
      {double? width, double? height, EdgeInsets? margin, double radius = 4}) {
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
