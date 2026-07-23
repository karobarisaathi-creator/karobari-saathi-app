import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'add_transaction_screen.dart';
import 'transaction_receipt_screen.dart';
import 'add_party_screen.dart';
import 'bulk_party_transaction_screen.dart';
import 'party_history_screen.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';

class PartyDetailScreen extends StatefulWidget {
  final Account party;
  final bool isReadOnly;
  final String? highlightTransactionId;

  const PartyDetailScreen({
    required this.party,
    this.isReadOnly = false,
    this.highlightTransactionId,
  });

  @override
  _PartyDetailScreenState createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  List<model.Transaction> _transactions = [];
  Map<String, double> _transactionPriceChanges = {}; // Stores rate change % for each transaction
  bool _isLoading = true;
  bool _isCheckingRemote = false;
  Map<String, String>? _remoteProfile;
  String _selectedFilter = 'all'; // 'all', 'payables', 'receivables'
  String _searchQuery = '';
  bool _isAscending = false;
  final TextEditingController _searchController = TextEditingController();
  String? _highlightId;
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;

  // App Theme Colors (Using Central Theme)
  final Color _darkColor = AppTheme.darkColor;
  final Color _themeColor = AppTheme.themeColor;
  final Color _textSecondary = AppTheme.textSecondary;
  final Color _incomeColor = AppTheme.incomeColor;
  final Color _expenseColor = AppTheme.expenseColor;
  final Color _goldColor = AppTheme.goldColor;


  @override
  void initState() {
    super.initState();
    _highlightId = widget.highlightTransactionId;
    _loadTransactions();
    _checkRemoteProfile();

    // Clear highlight after 3 seconds
    if (_highlightId != null) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _highlightId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkRemoteProfile() async {
    if (widget.party.phone.length < 10) return;
    
    // اگر پہلے ہی اپ ڈیٹ ہو چکا ہے یا تصویر موجود ہے تو بار بار چیک نہ کریں
    if (_remoteProfile != null) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final profile = await dbService.findPublicProfileByPhone(widget.party.phone);
    
    if (mounted && profile != null) {
      // صرف اس صورت میں شو کریں اگر نام یا تصویر مختلف ہو
      if (profile['name'] != widget.party.name || profile['photoUrl'] != widget.party.profileImage) {
        setState(() {
          _remoteProfile = profile;
        });
      }
    }
  }

  Future<void> _syncRemoteProfile() async {
    if (_remoteProfile == null) return;
    
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Gradient
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.themeColor, Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: -40,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(14), // تھوڑا زیادہ تاکہ اندر والا 12 فٹ آئے
                        ),
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (_remoteProfile!['photoUrl'] != null && _remoteProfile!['photoUrl']!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: _remoteProfile!['photoUrl']!, 
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (context, url, error) => Icon(PhosphorIcons.user(), size: 40, color: AppTheme.textSecondary),
                                )
                              : Icon(PhosphorIcons.user(), size: 40, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      isUrdu ? 'پروفائل اپ ڈیٹ دستیاب ہے' : 'Profile Update Available',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily, color: AppTheme.darkColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUrdu 
                        ? 'ہمیں اس نمبر کے لیے ایک نیا پروفائل ملا ہے۔ کیا آپ معلومات اپ ڈیٹ کرنا چاہتے ہیں؟' 
                        : 'We found a public profile for this number. Would you like to update the info?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(isUrdu ? 'نام' : 'Name', _remoteProfile!['name'] ?? '', PhosphorIcons.user(), isUrdu, fontFamily),
                          const Divider(height: 20),
                          _buildInfoRow(isUrdu ? 'فون' : 'Phone', widget.party.phone, PhosphorIcons.phone(), isUrdu, fontFamily),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isUrdu ? 'منسوخ' : 'Cancel', style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isUrdu ? 'اپ ڈیٹ کریں' : 'Update', style: TextStyle(fontFamily: fontFamily, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final updatedAccount = widget.party.copyWith(
        name: _remoteProfile!['name']?.isNotEmpty == true ? _remoteProfile!['name'] : widget.party.name,
        profileImage: _remoteProfile!['photoUrl']?.isNotEmpty == true ? _remoteProfile!['photoUrl'] : widget.party.profileImage,
      );
      await dbService.updateAccount(updatedAccount);
      if (mounted) {
        setState(() {
          _remoteProfile = null; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'معلومات اپ ڈیٹ کر دی گئی ہیں' : 'Profile updated successfully'),
            backgroundColor: AppTheme.incomeColor,
          )
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isUrdu, String fontFamily) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.themeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontFamily: fontFamily),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: fontFamily),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadTransactions() async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    // پارٹی کا تازہ ترین ڈیٹا لوڈ کریں تاکہ بیلنس اپڈیٹ ہو سکے
    final updatedParty = databaseService.getAccount(widget.party.id);
    
    // Get list of managed item names to detect rate changes
    final inventoryItems = databaseService.getInventoryItems();
    final managedNames = inventoryItems.map((e) => e.name.trim().toLowerCase()).toSet();

    final allTransactions = await databaseService.getAllTransactions();
    if (mounted) {
      setState(() {
        _transactions = allTransactions
            .where((t) => t.accountId == widget.party.id && t.partnershipId == null)
            .toList();
        _transactions.sort((a, b) => b.date.compareTo(a.date));

        // Calculate Rate Changes (Percentage Function)
        _transactionPriceChanges = {};
        final chronological = _transactions.reversed.toList();
        Map<String, double> lastRates = {};

        for (var tx in chronological) {
          // Only process 'income' transactions for rate history as per requirement
          if (tx.type != 'income') continue;

          if (tx.items.isNotEmpty) {
            for (var item in tx.items) {
              final name = item.description.trim().toLowerCase();
              if (managedNames.contains(name) && item.rate > 0) {
                if (lastRates.containsKey(name)) {
                  final lastRate = lastRates[name]!;
                  if ((item.rate - lastRate).abs() > 0.01) {
                    final percentage = ((item.rate - lastRate) / lastRate) * 100;
                    _transactionPriceChanges[tx.id] = percentage;
                  }
                }
                lastRates[name] = item.rate;
              }
            }
          } else if (tx.rate > 0) {
            final name = tx.description.trim().toLowerCase();
            if (managedNames.contains(name)) {
              if (lastRates.containsKey(name)) {
                final lastRate = lastRates[name]!;
                if ((tx.rate - lastRate).abs() > 0.01) {
                  final percentage = ((tx.rate - lastRate) / lastRate) * 100;
                  _transactionPriceChanges[tx.id] = percentage;
                }
              }
              lastRates[name] = tx.rate;
            }
          }
        }

        _isLoading = false;
      });
    }
  }

  void _generatePdf() async {
    final pdfService = Provider.of<PdfService>(context, listen: false);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    await pdfService.generateAccountStatement(
      account: widget.party,
      transactions: _transactions,
      isUrdu: isUrdu,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    // حساب کتاب کے لیے ٹرانزیکشنز کو پرانی سے نئی ترتیب میں لائیں
    final sortedChronological = [..._transactions];
    sortedChronological.sort((a, b) => a.date.compareTo(b.date));

    double currentCycleIn = 0;
    double currentCycleOut = 0;
    double totalRunningIn = 0;
    double totalRunningOut = 0;

    for (var tx in sortedChronological) {
      if (tx.type == 'income') {
        totalRunningIn += tx.amount;
        currentCycleIn += tx.amount;
      } else {
        totalRunningOut += tx.amount;
        currentCycleOut += tx.amount;
      }

      // اگر حساب برابر ہو گیا ہے تو کرنٹ سائیکل کو ری سیٹ کرنے کی تیاری کریں
      // لیکن ہم اسے صرف تب ری سیٹ کریں گے جب اگلی کوئی انٹری آئے گی
      if ((totalRunningIn - totalRunningOut).abs() < 0.01) {
        currentCycleIn = 0;
        currentCycleOut = 0;
      }
    }

    // اگر ابھی کوئی بھی انٹری نہیں ہوئی یا حساب برابر ہونے کے بعد کچھ نہیں ہوا
    // تو ہم آخری مکمل ہونے والے سائیکل کا ڈیٹا دکھائیں گے (اگر لسٹ خالی نہیں ہے)
    if (currentCycleIn == 0 && currentCycleOut == 0 && _transactions.isNotEmpty) {
      double tempIn = 0;
      double tempOut = 0;
      for (var tx in sortedChronological) {
        if (tx.type == 'income') tempIn += tx.amount;
        else tempOut += tx.amount;
        
        if ((tempIn - tempOut).abs() < 0.01) {
          currentCycleIn = tempIn;
          currentCycleOut = tempOut;
          tempIn = 0;
          tempOut = 0;
        }
      }
    }

    final currentBalance = currentCycleIn - currentCycleOut;

    final filteredTransactions = _transactions.where((t) {
      final matchesFilter = _selectedFilter == 'all' ||
          (_selectedFilter == 'payables' && t.type == 'expense') ||
          (_selectedFilter == 'receivables' && t.type == 'income');

      final matchesSearch = t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList();

    // Sort transactions
    filteredTransactions.sort((a, b) => _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

    // Determine accent color based on balance
    final databaseService = Provider.of<DatabaseService>(context);
    final currentParty = (databaseService.getAccount(widget.party.id) ?? widget.party).copyWith(balance: currentBalance);
    final bool isPayable = currentParty.balance >= 0;
    final Color accentColor = isPayable ? _expenseColor : _incomeColor;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        centerTitle: true,
        title: const SizedBox.shrink(),
        actions: [
          Center(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PartyHistoryScreen(party: currentParty),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.chartBar(), color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      isUrdu ? 'تجزیہ و ریکارڈ' : 'Analysis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(PhosphorIcons.dotsThreeVertical()),
            onSelected: (value) async {
              if (value == 'history') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PartyHistoryScreen(party: currentParty),
                  ),
                );
              } else if (value == 'pdf') {
                _generatePdf();
              } else if (value == 'edit') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPartyScreen(partyToEdit: currentParty),
                  ),
                );
                _loadTransactions(); // Reload after edit
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(isUrdu ? 'پارٹی ختم کریں؟' : 'Delete Party?', style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                    content: Text(isUrdu
                      ? 'کیا آپ واقعی اس پارٹی کو ختم کرنا چاہتے ہیں؟ تمام ریکارڈ مٹ جائے گا۔'
                      : 'Are you sure you want to delete this party? All records will be lost.',
                      style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isUrdu ? 'منسوخ' : 'Cancel', style: TextStyle(color: AppTheme.textSecondary, fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal))),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: Text(isUrdu ? 'ختم کریں' : 'Delete', style: TextStyle(color: AppTheme.expenseColor, fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Provider.of<DatabaseService>(context, listen: false).deleteAccount(currentParty.id);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'history',
                child: ListTile(
                  leading: Icon(PhosphorIcons.clockCounterClockwise(), color: AppTheme.darkColor),
                  title: Text(isUrdu ? 'مکمل ریکارڈ و تجزیہ' : 'Full History & Analysis', style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem<String>(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(PhosphorIcons.filePdf(), color: AppTheme.darkColor),
                  title: Text(isUrdu ? 'پی ڈی ایف رپورٹ' : 'PDF Report', style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(PhosphorIcons.pencilLine(), color: AppTheme.darkColor),
                  title: Text(isUrdu ? 'ایڈٹ پارٹی' : 'Edit Party', style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(PhosphorIcons.trash(), color: AppTheme.expenseColor),
                  title: Text(isUrdu ? 'ڈیلیٹ کریں' : 'Delete', style: TextStyle(color: AppTheme.expenseColor, fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: AppTheme.lightColor,
        child: Column(
          children: [
            // Paid/Received Summary Card (Updated Layout based on your image)
            _buildSummaryCard(currentParty, currentCycleOut, currentCycleIn, isUrdu, fontFamily, accentColor),

            // Search & Filter Bar
            SearchSortBar(
              controller: _searchController,
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onSortToggled: () {
                setState(() {
                  _isAscending = !_isAscending;
                });
              },
              isAscending: _isAscending,
            ),

            // Filter Chips (All, Payables, Receivables)
            _buildFilterChips(isUrdu, fontFamily),

            // Transaction List Header (Labels)
            _buildListLabels(isUrdu, fontFamily),

            // Transactions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
                  : filteredTransactions.isEmpty
                      ? _buildEmptyState(isUrdu, fontFamily)
                      : _buildTransactionList(filteredTransactions, isUrdu, fontFamily),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: _isFabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          heroTag: 'party_detail_fab',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddTransactionScreen(account: currentParty)),
            );
            _loadTransactions();
          },
          backgroundColor: AppTheme.darkColor,
          shape: const CircleBorder(),
          elevation: 4,
          child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildDateSelector(Account party, bool isUrdu, String fontFamily) {
    // اکاؤنٹ بننے کی تاریخ
    final String createdDateStr = DateFormat('dd MMM yyyy').format(party.createdAt);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Icon(PhosphorIcons.calendar(), size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            isUrdu ? "کھاتہ شروع:" : "Account Started:",
            style: TextStyle(fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal, fontFamily: fontFamily, fontSize: 13, color: AppTheme.darkColor),
          ),
          const SizedBox(width: 8),
          Text(
            createdDateStr,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: ''),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Account party, double paid, double received, bool isUrdu, String fontFamily, Color accentColor) {
    final netBalance = party.balance;
    final isPayable = netBalance >= 0;
    
    // Labels and Arrows
    final receivedLabel = isUrdu ? "لیا / جمع" : "Received / In";
    final paidLabel = isUrdu ? "دیا / بنام" : "Paid / Out";
    final balanceText = isUrdu
        ? (isPayable ? "کل دینا" : "کل لینا")
        : (isPayable ? "Payable" : "Receivable");

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Info (Matching the image)
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: _remoteProfile != null ? _syncRemoteProfile : null,
                  child: ProfileInfoWidget(
                    name: party.name,
                    phone: party.phone,
                    profileImage: party.profileImage,
                    category: party.category,
                    isLarge: false,
                    isVerticalCategory: true,
                    hasUpdate: _remoteProfile != null,
                    isVerified: party.isVerified,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Transaction Summary
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildSummaryRow(receivedLabel, received, _incomeColor, fontFamily, PhosphorIcons.arrowDownLeft()),
                    const SizedBox(height: 12),
                    _buildSummaryRow(paidLabel, paid, _expenseColor, fontFamily, PhosphorIcons.arrowUpRight()),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1, color: Colors.black12),
          ),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Align(
                  alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                  child: _buildPageEntryButton(isUrdu, fontFamily, party),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _buildSummaryRow(balanceText, netBalance.abs(), accentColor, fontFamily,
                  isPayable ? PhosphorIcons.arrowUpRight() : PhosphorIcons.arrowDownLeft(),
                  isTotal: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageEntryButton(bool isUrdu, String fontFamily, Account party) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BulkPartyTransactionScreen(party: party),
          ),
        ).then((_) => _loadTransactions());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _goldColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.listBullets(), color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              isUrdu ? 'پیج انٹری' : 'Page Entry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color, String fontFamily, IconData icon, {bool isTotal = false}) {
    final isUrdu = fontFamily == 'NooriNastaleeq';
    return Row(
      children: [
        // Label part
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black : AppTheme.darkColor,
              fontSize: isTotal ? 14 : 12,
              fontWeight: isUrdu ? FontWeight.bold : (isTotal ? FontWeight.bold : FontWeight.normal),
              fontFamily: fontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        // Amount and Icon part
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, size: isTotal ? 16 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              amount.toStringAsFixed(0),
              style: TextStyle(
                color: color,
                fontSize: 15, // Same as other amounts
                fontWeight: FontWeight.bold,
                fontFamily: '',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChips(bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(isUrdu ? "سب" : "All", 'all', fontFamily),
            const SizedBox(width: 30),
            _filterChip(isUrdu ? "واجب الادا" : "Payables Due", 'payables', fontFamily),
            const SizedBox(width: 30),
            _filterChip(isUrdu ? "واجب الوصول" : "Receivables Due", 'receivables', fontFamily),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String filterValue, String fontFamily) {
    bool isSelected = _selectedFilter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterValue;
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? _darkColor : Colors.grey.shade600,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: fontFamily,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 24,
              color: _darkColor,
            ),
        ],
      ),
    );
  }

  Widget _buildListLabels(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              isUrdu ? "تفصیل" : "Details", 
              style: TextStyle(color: _themeColor, fontSize: 14, fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.arrowUpRight(), size: 14, color: _themeColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isUrdu ? "دیا / بنام" : "Credits", style: TextStyle(color: _themeColor, fontSize: 13, fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.arrowDownLeft(), size: 14, color: _themeColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isUrdu ? "لیا / جمع" : "Debits", style: TextStyle(color: _themeColor, fontSize: 13, fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<model.Transaction> txs, bool isUrdu, String fontFamily) {
    final sortedChronological = [..._transactions];
    sortedChronological.sort((a, b) => a.date.compareTo(b.date));

    Map<String, Map<String, dynamic>> settlementData = {};
    Map<String, double> runningBalances = {};
    double runningIn = 0;
    double runningOut = 0;
    double currentBal = 0;
    DateTime? cycleStartDate;

    for (var tx in sortedChronological) {
      if (cycleStartDate == null) cycleStartDate = tx.date;
      
      if (tx.type == 'income') {
        runningIn += tx.amount;
        currentBal += tx.amount;
      } else {
        runningOut += tx.amount;
        currentBal -= tx.amount;
      }
      
      runningBalances[tx.id] = currentBal;

      if ((runningIn - runningOut).abs() < 0.01) {
        settlementData[tx.id] = {
          'totalIn': runningIn,
          'totalOut': runningOut,
          'startDate': cycleStartDate,
          'endDate': tx.date,
          'days': tx.date.difference(cycleStartDate).inDays,
        };
        runningIn = 0;
        runningOut = 0;
        cycleStartDate = null;
      }
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.reverse) {
          if (_isFabVisible) setState(() => _isFabVisible = false);
        } else if (notification.direction == ScrollDirection.forward) {
          if (!_isFabVisible) setState(() => _isFabVisible = true);
        }
        return true;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: txs.length,
        itemBuilder: (context, index) {
          final t = txs[index];
          final bool showDateHeader = index == 0 ||
              DateFormat('yyyy-MM-dd').format(txs[index - 1].date) !=
                  DateFormat('yyyy-MM-dd').format(t.date);

          final settlement = settlementData[t.id];
          final runningBalance = runningBalances[t.id] ?? 0;

          return Column(
            children: [
              // اگر ترتیب نئی سے پرانی ہے تو پٹی انٹری کے اوپر دکھانی ہے
              if (!_isAscending && settlement != null)
                _buildSettlementDivider(isUrdu, fontFamily, settlement),
              
              if (showDateHeader)
                _buildDateHeader(t.date, isUrdu, fontFamily, runningBalance),
              
              _buildTransactionItem(t, isUrdu, fontFamily),
              
              // اگر ترتیب پرانی سے نئی ہے تو پٹی انٹری کے نیچے دکھانی ہے
              if (_isAscending && settlement != null)
                _buildSettlementDivider(isUrdu, fontFamily, settlement),
              
              if (settlement == null)
                Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettlementDivider(bool isUrdu, String fontFamily, Map<String, dynamic> data) {
    final df = DateFormat('dd/MM/yy');
    final start = df.format(data['startDate']);
    final end = df.format(data['endDate']);
    final days = data['days'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.goldColor.withOpacity(0.08),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                isUrdu ? "حساب برابر ہو گیا" : "Account Balanced",
                style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.themeColor),
              ),
              const Spacer(),
              Text(
                "$start - $end",
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontFamily: ''),
              ),
              const SizedBox(width: 12),
              Text(
                "$days ${isUrdu ? 'دن' : 'days'}",
                style: TextStyle(fontFamily: fontFamily, fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactStat(isUrdu ? "کل جمع" : "Total In", data['totalIn'], AppTheme.incomeColor, isUrdu, fontFamily),
              _buildCompactStat(isUrdu ? "کل بنام" : "Total Out", data['totalOut'], AppTheme.expenseColor, isUrdu, fontFamily),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, double amount, Color color, bool isUrdu, String fontFamily) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: fontFamily)),
        Text(
          "Rs ${amount.toStringAsFixed(0)}",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color, fontFamily: ''),
        ),
      ],
    );
  }

  Widget _buildDateHeader(DateTime date, bool isUrdu, String fontFamily, double balance) {
    String dateStr = DateFormat('dd/MM/yyyy').format(date);
    String dayLabel = "";
    final now = DateTime.now();
    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now)) {
      dayLabel = isUrdu ? "آج" : "Today";
    } else if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)))) {
      dayLabel = isUrdu ? "کل" : "Yesterday";
    } else {
      dayLabel = dateStr;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              color: _themeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              fontFamily: (dayLabel == dateStr) ? '' : fontFamily,
            ),
          ),
          const Spacer(),
          Text(
            isUrdu ? "بیلنس: " : "Bal ",
            style: TextStyle(
              color: _themeColor.withOpacity(0.6),
              fontSize: 11,
              fontFamily: fontFamily,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "Rs ${balance.abs().toStringAsFixed(0)}",
            style: TextStyle(
              color: _themeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              fontFamily: '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(model.Transaction t, bool isUrdu, String fontFamily) {
    final isIncome = t.type == 'income';
    final isHighlighted = _highlightId == t.id;

    return InkWell(
      onLongPress: widget.isReadOnly ? null : () => _showDeleteConfirmation(t),
      onTap: widget.isReadOnly ? null : () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionReceiptScreen(
              transaction: t,
            ),
          ),
        );
        _loadTransactions();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isHighlighted ? AppTheme.themeColor.withOpacity(0.15) : Colors.white,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.description.isNotEmpty ? t.description : (isUrdu ? 'نقد لین دین' : 'Cash Transaction'),
                    style: TextStyle(
                      color: AppTheme.darkColor,
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                      fontFamily: fontFamily,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (t.referenceNumber != null && t.referenceNumber!.isNotEmpty) ...[
                        Text(
                          "${isUrdu ? 'بل نمبر  ' : 'Bill NO'} ${t.referenceNumber}",
                          style: TextStyle(
                            color: AppTheme.themeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: isUrdu ? fontFamily : '',
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(
                        DateFormat('dd/MM/yyyy').format(t.date),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: '',
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      if (_transactionPriceChanges.containsKey(t.id)) ...[
                        const SizedBox(width: 8),
                        _buildPriceChangeBadge(_transactionPriceChanges[t.id]!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  !isIncome ? t.amount.toStringAsFixed(0) : "-",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: AppTheme.expenseColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: '',
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isIncome ? t.amount.toStringAsFixed(0) : "-",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: AppTheme.incomeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: '',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(model.Transaction t) {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isUrdu ? 'ٹرانزیکشن ڈیلیٹ کریں؟' : 'Delete Transaction?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی اس ٹرانزیکشن کو ڈیلیٹ کرنا چاہتے ہیں؟ اس سے بیلنس اپ ڈیٹ ہو جائے گا۔'
              : 'Are you sure you want to delete this transaction? This will update the balance.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isUrdu ? 'منسوخ' : 'Cancel',
              style: TextStyle(color: Colors.grey, fontFamily: fontFamily),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await Provider.of<DatabaseService>(context, listen: false).deleteTransaction(t.id);
              
              if (mounted) {
                _loadTransactions();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(isUrdu ? 'ٹرانزیکشن ڈیلیٹ کر دی گئی ہے' : 'Transaction deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              isUrdu ? 'ڈیلیٹ' : 'Delete',
              style: TextStyle(color: Colors.white, fontFamily: fontFamily),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.receipt(), size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی لین دین موجود نہیں' : 'No transactions found',
            style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChangeBadge(double percentage) {
    final isIncrease = percentage > 0;
    final color = isIncrease ? AppTheme.expenseColor : AppTheme.incomeColor;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isIncrease ? PhosphorIcons.arrowUp() : PhosphorIcons.arrowDown(),
          size: 12,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '${percentage.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: color, 
            fontFamily: ''
          ),
        ),
      ],
    );
  }
}
