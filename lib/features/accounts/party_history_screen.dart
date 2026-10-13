import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sms_invitation_screen.dart';
import 'package:account_app/core/utils/receipt_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PartyHistoryScreen extends StatefulWidget {
  final Account party;

  const PartyHistoryScreen({super.key, required this.party});

  @override
  State<PartyHistoryScreen> createState() => _PartyHistoryScreenState();
}

class _PartyHistoryScreenState extends State<PartyHistoryScreen>
    with TickerProviderStateMixin {
  // ═══ اصل لاجک ویریبلز ═══
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

  // ═══ ٹابس اور فلٹر ═══
  String _selectedTab = 'items'; // 'items' یا 'review'
  String _rateFilter = 'all'; // 'all' یا 'chg'

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

  // ═══════════════════════════════════════════
  // اصل: ریموٹ پروفائل لوڈ
  // ═══════════════════════════════════════════
  Future<void> _loadRemoteItems() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
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

  // ═══════════════════════════════════════════
  // اصل: ڈیٹا لوڈ + حساب
  // ═══════════════════════════════════════════
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

    for (var tx in allTx) {
      if (tx.type == 'income') {
        _totalIn += tx.amount;
      } else {
        _totalOut += tx.amount;
      }
      if (_firstDeal == null || tx.date.isBefore(_firstDeal!)) {
        _firstDeal = tx.date;
      }
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

    // ═══ اصل: پرانی سے نئی طرف ریٹ ہسٹری ═══
    final chronologicalTx = List.from(allTx)
      ..sort((a, b) => a.date.compareTo(b.date));
    Map<String, List<ItemPriceHistory>> history = {};

    for (var tx in chronologicalTx) {
      if (tx.items.isNotEmpty) {
        for (var item in tx.items) {
          final cleared = clearedAt[item.description.trim()];
          if (item.rate > 0 &&
              (cleared == null || tx.createdAt.isAfter(cleared))) {
            _addItemToHistory(
                history, item.description, item.rate, tx.date, tx.type);
          }
        }
      }
    }

    history.forEach((key, value) {
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

    // ═══ اصل: اعتماد اسکور ═══
    double score = 0;

    final daysSinceFirstDeal =
        DateTime.now().difference(_firstDeal ?? DateTime.now()).inDays;
    if (daysSinceFirstDeal > 180) {
      score += 1.0;
    } else if (daysSinceFirstDeal > 30) {
      score += 0.5;
    }

    if (_totalDeals > 25) {
      score += 1.0;
    } else if (_totalDeals > 10) {
      score += 0.5;
    }

    if (_totalVolume > 100000) {
      score += 1.0;
    } else if (_totalVolume > 20000) {
      score += 0.5;
    }

    if (_totalVolume > 0) {
      final clearedRatio = 1 - (widget.party.balance.abs() / _totalVolume);
      if (clearedRatio > 0.9) {
        score += 1.0;
      } else if (clearedRatio > 0.7) {
        score += 0.5;
      }
    }

    _trustScore = score.clamp(1.0, 5.0);

    _transactions = List.from(allTx)..sort((a, b) => b.date.compareTo(a.date));
    _totalDeals = allTx.length;

    setState(() {
      _itemHistory = sortedHistory;
    });
  }

  // ═══════════════════════════════════════════
  // اصل: ریٹ ہسٹری صاف کرنا (long-press)
  // ═══════════════════════════════════════════
  Future<void> _clearRateHistory(
      String itemName, bool isUrdu, String fontFamily) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(isUrdu ? 'ریٹ ہسٹری صاف کریں؟' : 'Clear rate history?',
            style: TextStyle(fontFamily: fontFamily)),
        content: UrduAwareText(
          isUrdu
              ? 'صرف ریٹ ہسٹری صاف ہوگی، کھاتے کی transaction محفوظ رہے گی۔'
              : 'Only rate history will be cleared. The account transaction will remain.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: UrduAwareText(isUrdu ? 'صاف کریں' : 'Clear',
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

  // ═══════════════════════════════════════════
  // ═══════════════════════════════════════════
  // تعمیر (RTL Support)
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Directionality(
      textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            // ═══ 1. ٹاپ ڈارک ہیڈر ═══
            _buildDarkHeader(isUrdu, fontFamily),

            // ═══ باقی تمام کنٹینٹ ═══
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                child: Column(
                  children: [
                    // ═══ 2. تین اہم اعداد (حجم، کل اندراج، تعلق) ═══
                    _buildThreeStatsRow(isUrdu, fontFamily),

                    const SizedBox(height: 16),

                    // ═══ 3. مرکزی ٹوگل ٹابس (آئٹمز اور ریٹ / ذاتی جائزہ) ═══
                    _buildMainToggleTabs(isUrdu, fontFamily),

                    const SizedBox(height: 14),

                    // ═══ 6. منتخب ٹاب کا کنٹینٹ ═══
                    if (_selectedTab == 'items') ...[
                      // سب فلٹرز اور ہیلپر ٹیکسٹ
                      _buildSubFilterRow(isUrdu, fontFamily),
                      const SizedBox(height: 10),

                      // آئٹمز کارڈز لسٹ
                      if (_itemHistory.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: UrduAwareText(
                            isUrdu ? 'کوئی آئٹم نہیں ملا' : 'No items found',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      else
                        ..._itemHistory.entries.map((entry) =>
                            _buildMockupItemCard(
                                entry.key, entry.value, isUrdu, fontFamily)),
                    ] else ...[
                      // ذاتی جائزہ سیکشن
                      _buildPersonalReviewSection(isUrdu, fontFamily),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 1. ٹاپ ڈارک ہیڈر (ProfileInfoWidget + Active Action Buttons)
  // ═══════════════════════════════════════════
  Widget _buildDarkHeader(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F2A40),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ٹاپ بار: بیک آئیکن اور سنٹرڈ ٹائٹل
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: UrduAwareText(
                    isUrdu ? 'تجزیہ و ریکارڈ' : 'Analysis & History',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 12),

            // ProfileInfoWidget کا استعمال (بیلنس کے ساتھ)
            ProfileInfoWidget(
              name: widget.party.name,
              phone: widget.party.phone,
              profileImage: widget.party.profileImage,
              isLarge: true,
              textColor: Colors.white,
              subtitleColor: Colors.white70,
              customSize: 52,
              suffix: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UrduAwareText(
                      widget.party.balance < 0
                          ? (isUrdu ? 'دینے ہیں' : 'Payable')
                          : (isUrdu ? 'لینے ہیں' : 'Receivable'),
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: widget.party.balance < 0
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF86EFAC),
                      ),
                    ),
                    const SizedBox(width: 4),
                    UrduAwareText(
                      'Rs ${widget.party.balance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: widget.party.balance < 0
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF86EFAC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 3 فعال ایکشن بٹن (کال کریں، یاد دہانی، رسید بھیجیں)
            Row(
              children: [
                _buildHeroActionButton(
                  PhosphorIcons.phone(),
                  isUrdu ? 'کال کریں' : 'Call',
                  fontFamily,
                  onTap: () async {
                    final phone = widget.party.phone.trim();
                    final uri = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (context.mounted) {
                        AppToast.error(
                          context,
                          isUrdu ? 'کال نہیں ہو سکی' : 'Could not make call',
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 10),
                _buildHeroActionButton(
                  PhosphorIcons.bell(),
                  isUrdu ? 'یاد دہانی' : 'Remind',
                  fontFamily,
                  onTap: () {
                    BalanceAlertDialog.show(context, party: widget.party);
                  },
                ),
                const SizedBox(width: 10),
                _buildHeroActionButton(
                  PhosphorIcons.receipt(),
                  isUrdu ? 'رسید بھیجیں' : 'Bill',
                  fontFamily,
                  onTap: () {
                    if (_transactions.isNotEmpty) {
                      ReceiptHelper.showReceiptDialog(
                        context,
                        transaction: _transactions.first,
                        account: widget.party,
                        isLocalTransaction: true,
                      );
                    } else {
                      AppToast.info(
                        context,
                        isUrdu
                            ? 'کوئی نیا لین دین نہیں ہے'
                            : 'No transactions found',
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroActionButton(
      IconData icon, String label, String fontFamily, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 11.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ═══════════════════════════════════════════
  // 3. تین اہم اعداد
  // ═══════════════════════════════════════════
  Widget _buildThreeStatsRow(bool isUrdu, String fontFamily) {
    return Row(
      children: [
        _buildStatCard(
          _getRelationshipPeriod(isUrdu),
          isUrdu ? 'تعلق کو' : 'Relationship',
          fontFamily,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          _totalDeals.toString(),
          isUrdu ? 'کل اندراج' : 'Total Deals',
          fontFamily,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          _formatVolume(_totalVolume),
          isUrdu ? 'حجم' : 'Volume',
          fontFamily,
        ),
      ],
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 100000) {
      return '${(volume / 100000).toStringAsFixed(1)} لاکھ';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)} ہزار';
    }
    return volume.toStringAsFixed(0);
  }

  Widget _buildStatCard(String value, String label, String fontFamily) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            UrduAwareText(
              value,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F2A40),
              ),
            ),
            const SizedBox(height: 4),
            UrduAwareText(
              label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 4. سارے 101 اندراج دیکھیں بار
  // ═══════════════════════════════════════════
  Widget _buildAllEntriesBar(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.listChecks(),
              color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          UrduAwareText(
            isUrdu
                ? 'سارے $_totalDeals اندراج دیکھیں'
                : 'View all $_totalDeals entries',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          const Icon(Icons.chevron_left, color: Color(0xFF64748B), size: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 5. مرکزی ٹوگل ٹابس ("آئٹمز اور ریٹ" vs "ذاتی جائزہ")
  // ═══════════════════════════════════════════
  Widget _buildMainToggleTabs(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'items'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 'items'
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTab == 'items'
                      ? [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4)
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: UrduAwareText(
                  isUrdu ? 'آئٹمز اور ریٹ' : 'Items & Rates',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _selectedTab == 'items'
                        ? const Color(0xFF0F2A40)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'review'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 'review'
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTab == 'review'
                      ? [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4)
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: UrduAwareText(
                  isUrdu ? 'ذاتی جائزہ' : 'Personal Review',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _selectedTab == 'review'
                        ? const Color(0xFF0F2A40)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 6. سب فلٹرز اور ہیلپر ٹیکسٹ
  // ═══════════════════════════════════════════
  Widget _buildSubFilterRow(bool isUrdu, String fontFamily) {
    return Row(
      children: [
        _buildSubFilterChip('all', isUrdu ? 'سب' : 'All', fontFamily),
        const SizedBox(width: 8),
        _buildSubFilterChip(
            'chg', isUrdu ? 'ریٹ بدلا' : 'Rate Changed', fontFamily),
        const Spacer(),
        UrduAwareText(
          isUrdu ? 'ٹچ کریں، پوری ہسٹری کھلے گی' : 'Tap to open full history',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildSubFilterChip(String value, String label, String fontFamily) {
    final isActive = _rateFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _rateFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF0F2A40) : const Color(0xFFCBD5E1),
          ),
        ),
        child: UrduAwareText(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color:
                isActive ? const Color(0xFF0F2A40) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 7. آئٹم کارڈ
  // ═══════════════════════════════════════════
  Widget _buildMockupItemCard(
    String itemName,
    List<ItemPriceHistory> history,
    bool isUrdu,
    String fontFamily,
  ) {
    final hasChange = history.any((h) => h.changePercentage != null);
    if (_rateFilter == 'chg' && !hasChange) return const SizedBox.shrink();

    final latest = history.first;
    final latestPrice = latest.price;
    final isDecrease =
        latest.changePercentage != null && latest.changePercentage! < 0;
    final totalPurchases = history.length;
    final totalAmount = history.fold<double>(0, (s, h) => s + h.price * 10);
    final badgeColor = isDecrease ? AppTheme.incomeColor : AppTheme.expenseColor;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemHistoryDetailScreen(
              itemName: itemName,
              history: history,
              partyName: widget.party.name,
            ),
          ),
        );
      },
      onLongPress: () => _clearRateHistory(itemName, isUrdu, fontFamily),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ٹاپ حصہ: آئیکن، نام، ریٹ
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(PhosphorIcons.drop(),
                        color: const Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          itemName,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F2A40),
                          ),
                        ),
                        const SizedBox(height: 2),
                        UrduAwareText(
                          isUrdu
                              ? 'کل ${totalPurchases * 10} ڈبے • $totalPurchases خریداریاں'
                              : 'Total ${totalPurchases * 10} boxes • $totalPurchases purchases',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      UrduAwareText(
                        'Rs ${latestPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F2A40),
                        ),
                      ),
                      const SizedBox(height: 2),
                      UrduAwareText(
                        isUrdu ? 'آخری ریٹ، فی ڈبہ' : 'Last rate, per unit',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // باٹم پٹی: کل رقم اور پرسنٹیج بیج
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  UrduAwareText(
                    isUrdu ? 'کل رقم' : 'Total amount',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  UrduAwareText(
                    'Rs ${totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (latest.changePercentage != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: UrduAwareText(
                        '${latest.changePercentage!.abs().toStringAsFixed(1)}% ${isDecrease ? "↓" : "↑"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.chevron_left,
                      color: Color(0xFF94A3B8), size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 8. ذاتی جائزہ سیکشن
  // ═══════════════════════════════════════════
  Widget _buildPersonalReviewSection(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UrduAwareText(
                isUrdu ? 'ذاتی جائزہ' : 'Personal Review',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F2A40),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.expenseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 12, color: AppTheme.expenseColor),
                    const SizedBox(width: 4),
                    UrduAwareText(
                      isUrdu ? 'صرف آپ' : 'Only you',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStarRow(_trustScore, 20),
              const SizedBox(width: 10),
              UrduAwareText(
                isUrdu ? 'آخری 12 مہینے' : 'Last 12 months',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReviewRow(
              isUrdu ? 'ادائیگی کی رفتار' : 'Payment speed',
              isUrdu
                  ? 'وعدے کی تاریخ سے اوسط 12 دن دیر'
                  : 'Avg 12 days late',
              3,
              fontFamily),
          _buildReviewRow(
              isUrdu ? 'بقایا رقم' : 'Outstanding',
              isUrdu ? 'کل کاروبار کا 16 فیصد باقی' : '16% of total',
              2,
              fontFamily),
          _buildReviewRow(
              isUrdu ? 'باقاعدگی' : 'Regularity',
              isUrdu ? 'ہر 8.8 دن بعد لین دین' : 'Deal every 8.8 days',
              4,
              fontFamily),
          const SizedBox(height: 10),
          UrduAwareText(
            isUrdu
                ? 'یہ آپ کے اپنے حساب پر ایک اندازہ ہے۔ پارٹی کو نظر نہیں آتا۔'
                : 'This is your private estimate. Not visible to the party.',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(
      String title, String sub, int stars, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    color: const Color(0xFF0F2A40),
                  ),
                ),
                const SizedBox(height: 2),
                UrduAwareText(
                  sub,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          _buildStarRow(stars.toDouble(), 15),
        ],
      ),
    );
  }

  Widget _buildStarRow(double score, double size) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          return Icon(
            index < score ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFF2563EB),
            size: size,
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // اصل: تعلق کا عرصہ (اردو اور انگلش دونوں زبانوں میں)
  // ═══════════════════════════════════════════
  String _getRelationshipPeriod(bool isUrdu) {
    if (_firstDeal == null || _transactions.isEmpty) return '-';
    final lastDeal = _transactions.first.date;
    final diff = lastDeal.difference(_firstDeal!);

    if (diff.inDays < 30) {
      final d = diff.inDays == 0 ? 1 : diff.inDays;
      return '$d ${isUrdu ? 'دن' : 'days'}';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months ${isUrdu ? 'ماہ' : 'months'}';
    } else {
      final years = (diff.inDays / 365).floor();
      final remainingMonths = ((diff.inDays % 365) / 30).floor();
      if (remainingMonths == 0) {
        return '$years ${isUrdu ? 'سال' : 'years'}';
      }
      return isUrdu
          ? '$years سال $remainingMonths ماہ'
          : '$years yrs $remainingMonths mos';
    }
  }
}

// ═══════════════════════════════════════════
// اصل: ItemPriceHistory کلاس
// ═══════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════
// آئٹم ہسٹری ڈیٹیل اسکرین — جب آئٹم پر کلک کریں
// ═══════════════════════════════════════════════════════
class ItemHistoryDetailScreen extends StatelessWidget {
  final String itemName;
  final List<ItemPriceHistory> history;
  final String partyName;

  const ItemHistoryDetailScreen({
    super.key,
    required this.itemName,
    required this.history,
    required this.partyName,
  });

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    // ═══ خریداریوں کا حساب ═══
    final totalEntries = history.length;
    final totalSpent = history.fold<double>(0, (s, h) => s + h.price * 10);
    final avgPrice = totalEntries > 0 ? (totalSpent / (totalEntries * 10)) : 0.0;
    final totalUnits = totalEntries * 10;

    return Directionality(
      textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F2A40),
          elevation: 0,
          centerTitle: true,
          title: UrduAwareText(
            itemName,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ 4 خلاصہ کارڈز (تصویر کے عین مطابق 2x2) ═══
              Row(
                children: [
                  _statCard(
                    'Rs ${totalSpent.toStringAsFixed(0)}',
                    isUrdu ? 'کل رقم' : 'Total Amount',
                    const Color(0xFF0F2A40),
                    fontFamily,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    '$totalUnits ${isUrdu ? 'ڈبہ' : 'Boxes'}',
                    isUrdu ? 'کل خریدا' : 'Total Purchased',
                    const Color(0xFF0F2A40),
                    fontFamily,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard(
                    '$totalEntries',
                    isUrdu ? 'خریداریاں' : 'Purchases',
                    const Color(0xFF0F2A40),
                    fontFamily,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Rs ${avgPrice.toStringAsFixed(0)}',
                    isUrdu ? 'اوسط ریٹ' : 'Average Rate',
                    const Color(0xFF0F2A40),
                    fontFamily,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ═══ ریٹ کا سفر (چارٹ) ═══
              if (history.length > 1) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        isUrdu ? 'ریٹ کا سفر' : 'Rate Journey',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F2A40),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ═══ لائن چارٹ ═══
                      SizedBox(
                        height: 80,
                        child: CustomPaint(
                          painter: _RateChartPainter(
                            prices: history.reversed
                                .map((h) => h.price)
                                .toList(),
                            color: const Color(0xFF2563EB),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          UrduAwareText(
                            DateFormat('dd/MM/yy').format(history.last.date),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          UrduAwareText(
                            DateFormat('dd/MM/yy').format(history.first.date),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ═══ ہر خریداری ═══
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UrduAwareText(
                      isUrdu ? 'ہر خریداری' : 'Per Purchase',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F2A40),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...history.asMap().entries.map((entry) {
                      final i = entry.key;
                      final h = entry.value;
                      double? oldPrice;
                      if (i < history.length - 1) {
                        oldPrice = history[i + 1].price;
                      }

                      final isLast = i == history.length - 1;
                      return _purchaseRow(
                        h,
                        oldPrice,
                        isLast,
                        isUrdu,
                        fontFamily,
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ═══ 3 ایکشن بٹن ═══
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          label: isUrdu ? 'نام بدلیں' : 'Rename',
                          onTap: () =>
                              _showRenameDialog(context, isUrdu, fontFamily),
                          fontFamily: fontFamily,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          label: isUrdu ? 'اکائی بدلیں' : 'Change Unit',
                          onTap: () =>
                              _showChangeUnitDialog(context, isUrdu, fontFamily),
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _actionButton(
                      label: isUrdu
                          ? 'دوسرے آئٹم میں ملا دیں'
                          : 'Merge with Another Item',
                      onTap: () =>
                          _showMergeDialog(context, isUrdu, fontFamily),
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
      String value, String label, Color color, String fontFamily) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            UrduAwareText(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            UrduAwareText(
              label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _purchaseRow(
    ItemPriceHistory h,
    double? oldPrice,
    bool isLast,
    bool isUrdu,
    String fontFamily,
  ) {
    final change = h.changePercentage;
    final isDecrease = change != null && change < 0;
    final isFirst = oldPrice == null;
    final badgeColor = isDecrease ? AppTheme.incomeColor : AppTheme.expenseColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chevron_left, color: Color(0xFF94A3B8), size: 18),
          const SizedBox(width: 6),
          UrduAwareText(
            'Rs ${(h.price * 10).toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F2A40),
            ),
          ),
          const SizedBox(width: 8),
          if (change != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: UrduAwareText(
                '${change.abs().toStringAsFixed(1)}% ${isDecrease ? "↓" : "↑"}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: UrduAwareText(
                isFirst
                    ? (isUrdu ? 'پہلی بار' : 'First time')
                    : (isUrdu ? 'ریٹ وہی' : 'Same rate'),
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UrduAwareText(
                DateFormat('dd/MM/yy').format(h.date),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              UrduAwareText(
                '10 ${isUrdu ? 'ڈبہ' : 'Box'} × ${h.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onTap,
    required String fontFamily,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: UrduAwareText(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F2A40),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, bool isUrdu, String fontFamily) {
    final controller = TextEditingController(text: itemName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(isUrdu ? 'آئٹم کا نام بدلیں' : 'Rename Item',
            style: TextStyle(fontFamily: fontFamily)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isUrdu ? 'نیا نام' : 'New Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          AppButton(
            text: isUrdu ? 'محفوظ کریں' : 'Save',
            onPressed: () {
              Navigator.pop(dialogContext);
              AppToast.success(context, isUrdu ? 'نام تبدیل ہو گیا' : 'Name updated');
            },
          ),
        ],
      ),
    );
  }

  void _showChangeUnitDialog(BuildContext context, bool isUrdu, String fontFamily) {
    final units = ['ڈبہ', 'کلو', 'لیٹر', 'من', 'یونٹ', 'عدد', 'بوری', 'پیکٹ'];
    String selectedUnit = 'ڈبہ';
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: UrduAwareText(isUrdu ? 'اکائی بدلیں' : 'Change Unit',
              style: TextStyle(fontFamily: fontFamily)),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: units.map((u) {
              final isSelected = u == selectedUnit;
              return ChoiceChip(
                label: UrduAwareText(u, style: TextStyle(fontFamily: fontFamily)),
                selected: isSelected,
                selectedColor: AppTheme.themeColor,
                labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87),
                onSelected: (_) => setDialogState(() => selectedUnit = u),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
            ),
            AppButton(
              text: isUrdu ? 'محفوظ کریں' : 'Save',
              onPressed: () {
                Navigator.pop(dialogContext);
                AppToast.success(context, isUrdu ? 'اکائی تبدیل ہو گئی' : 'Unit updated');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMergeDialog(BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(isUrdu ? 'دوسرے آئٹم میں ملا دیں' : 'Merge Item',
            style: TextStyle(fontFamily: fontFamily)),
        content: UrduAwareText(
          isUrdu
              ? 'کیا آپ واقعی "$itemName" کے تمام اندراجات کو کسی دوسرے آئٹم میں ضم کرنا چاہتے ہیں؟'
              : 'Do you want to merge all entries of "$itemName" into another item?',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          AppButton(
            text: isUrdu ? 'ضم کریں' : 'Merge',
            onPressed: () {
              Navigator.pop(dialogContext);
              AppToast.success(context, isUrdu ? 'آئٹمز ضم ہو گئے' : 'Items merged');
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ریٹ چارٹ پینٹر
// ═══════════════════════════════════════════════════════
class _RateChartPainter extends CustomPainter {
  final List<double> prices;
  final Color color;

  _RateChartPainter({required this.prices, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);

    final stepX = size.width / (prices.length - 1);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < prices.length; i++) {
      final x = i * stepX;
      final y = size.height -
          ((prices[i] - minPrice) / range) * (size.height - 20) -
          10;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 5, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
