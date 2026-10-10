import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/receipt_helper.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/features/accounts/add_transaction_screen.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/accounts/bulk_party_transaction_screen.dart';
import 'package:account_app/features/accounts/party_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
/// PartyDetailScreen / PartyCombinedScreen
/// ═══════════════════════════════════════════════════════════
class PartyDetailScreen extends StatelessWidget {
  final Account party;
  final bool isReadOnly;
  final String? highlightTransactionId;

  const PartyDetailScreen({
    super.key,
    required this.party,
    this.isReadOnly = false,
    this.highlightTransactionId,
  });

  @override
  Widget build(BuildContext context) {
    return PartyCombinedScreen(
      party: party,
      isReadOnly: isReadOnly,
      highlightTransactionId: highlightTransactionId,
    );
  }
}

class PartyCombinedScreen extends StatefulWidget {
  final Account party;
  final bool isReadOnly;
  final String? highlightTransactionId;

  const PartyCombinedScreen({
    super.key,
    required this.party,
    this.isReadOnly = false,
    this.highlightTransactionId,
  });

  @override
  State<PartyCombinedScreen> createState() => _PartyCombinedScreenState();
}

class _PartyCombinedScreenState extends State<PartyCombinedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showSearch = false;
  bool _isAscending = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final currentParty = dbService.getAccount(widget.party.id) ?? widget.party;

    return Directionality(
      textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        body: Column(
          children: [
            // ═══════════════════════════════════════════
            // SHARED DARK HEADER (Radius 15 کے ساتھ)
            // ═══════════════════════════════════════════
            _CombinedHeader(
              party: currentParty,
              isReadOnly: widget.isReadOnly,
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              onRefresh: () => setState(() {}),
              showSearch: _showSearch,
              onToggleSearch: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),

            // ═══════════════════════════════════════════
            // TAB BAR (بالکل اسٹاک اسکرین جیسا)
            // ═══════════════════════════════════════════
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.darkColor,
                labelColor: AppTheme.darkColor,
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: isUrdu ? 'لین دین' : 'Transactions'),
                  Tab(text: isUrdu ? 'تجزیہ' : 'Analysis'),
                ],
              ),
            ),

            // ═══════════════════════════════════════════
            // SEARCH BAR (ٹیب کے نیچے Conditional)
            // ═══════════════════════════════════════════
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _showSearch
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                      child: SearchSortBar(
                        controller: _searchController,
                        hintText: isUrdu ? 'تلاش کریں...' : 'Search...',
                        onSearchChanged: (v) => setState(() => _searchQuery = v),
                        onSortToggled: () =>
                            setState(() => _isAscending = !_isAscending),
                        isAscending: _isAscending,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ═══════════════════════════════════════════
            // TAB CONTENT
            // ═══════════════════════════════════════════
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ═══ Tab 1: لین دین ═══
                  _TransactionsTab(
                    party: currentParty,
                    isReadOnly: widget.isReadOnly,
                    highlightTransactionId: widget.highlightTransactionId,
                    searchQuery: _searchQuery,
                    isAscending: _isAscending,
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),

                  // ═══ Tab 2: تجزیہ ═══
                  _AnalysisTab(
                    party: currentParty,
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED HEADER (Radius 15)
// ═══════════════════════════════════════════════════════════
class _CombinedHeader extends StatelessWidget {
  final Account party;
  final bool isReadOnly;
  final bool isUrdu;
  final String? fontFamily;
  final VoidCallback onRefresh;
  final bool showSearch;
  final VoidCallback onToggleSearch;

  const _CombinedHeader({
    required this.party,
    required this.isReadOnly,
    required this.isUrdu,
    required this.fontFamily,
    required this.onRefresh,
    required this.showSearch,
    required this.onToggleSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseService>(
      builder: (context, dbService, _) {
        final allTx = dbService
            .getAllTransactions()
            .where((t) =>
                t.accountId == party.id && t.partnershipId == null)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final cycleBalance = AccountBalanceUtils.currentCycle(allTx);
        final currentBalance = cycleBalance.balance;
        final isPayable = currentBalance >= 0;

        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.darkColor,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ═══ TOP ROW: Back + Title + Search Icon + Menu ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          isUrdu ? 'پارٹی' : 'Party',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // سرچ آئیکن بٹن (تین ڈاٹ کے سامنے)
                      IconButton(
                        icon: Icon(
                          showSearch ? PhosphorIcons.x() : PhosphorIcons.magnifyingGlass(),
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: onToggleSearch,
                        tooltip: isUrdu ? 'تلاش' : 'Search',
                      ),
                      _buildMenuButton(context),
                    ],
                  ),
                ),

                // ═══ PROFILE + STATS (مختصر اونچائی) ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                  child: Column(
                    children: [
                      // Profile
                      ProfileInfoWidget(
                        name: party.name,
                        phone: party.phone,
                        profileImage: party.profileImage,
                        category: party.category,
                        address: party.address,
                        isLarge: false,
                        isVerticalCategory: false,
                        textColor: Colors.white,
                        subtitleColor: Colors.white70,
                        categoryColor: Colors.white,
                        customSize: 38,
                        borderRadius: 8,
                      ),

                      const SizedBox(height: 8),

                      // ═══ Stats Row (جمع | بنام | لینا/دینا) ═══
                      Row(
                        children: [
                          _buildStatItem(
                            isUrdu ? 'جمع' : 'In',
                            cycleBalance.income,
                            AppTheme.incomeColor,
                            PhosphorIcons.arrowDownLeft(),
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            isUrdu ? 'بنام' : 'Out',
                            cycleBalance.expense,
                            AppTheme.expenseColor,
                            PhosphorIcons.arrowUpRight(),
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            isUrdu
                                ? (isPayable ? 'دینا ہے' : 'لینا ہے')
                                : (isPayable ? 'Payable' : 'Receivable'),
                            currentBalance.abs(),
                            isPayable
                                ? AppTheme.expenseColor
                                : AppTheme.incomeColor,
                            isPayable
                                ? PhosphorIcons.arrowUpRight()
                                : PhosphorIcons.arrowDownLeft(),
                            isBold: true,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ═══ Action Buttons (Call | Remind | Bill) ═══
                      Row(
                        children: [
                          _buildActionButton(
                            icon: PhosphorIcons.phone(),
                            label: isUrdu ? 'کال' : 'Call',
                            onTap: () => _onCall(context),
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: PhosphorIcons.bell(),
                            label: isUrdu ? 'یاد دہانی' : 'Remind',
                            onTap: () => _onRemind(context),
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: PhosphorIcons.receipt(),
                            label: isUrdu ? 'رسید' : 'Bill',
                            onTap: () => _onReceipt(context, allTx),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 16,
      width: 1,
      color: Colors.white12,
    );
  }

  Widget _buildStatItem(
    String label,
    double amount,
    Color color,
    IconData icon, {
    bool isBold = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontFamily: fontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Rs ${amount.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isBold ? 14.5 : 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: '',
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 10.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══ Actions ═══
  void _onCall(BuildContext context) {
    if (party.phone.trim().isEmpty) {
      AppToast.warning(
        context,
        isUrdu ? 'نمبر موجود نہیں' : 'No phone number',
      );
      return;
    }
    AppToast.info(
      context,
      isUrdu ? 'کالنگ ${party.phone}' : 'Calling ${party.phone}',
    );
  }

  void _onRemind(BuildContext context) {
    AppToast.info(
      context,
      isUrdu ? 'یاد دہانی بھیجیں' : 'Send reminder',
    );
  }

  void _onReceipt(BuildContext context, List<model.Transaction> txs) {
    if (txs.isEmpty) {
      AppToast.info(
        context,
        isUrdu ? 'کوئی لین دین نہیں' : 'No transactions',
      );
      return;
    }
    ReceiptHelper.showReceiptDialog(
      context,
      transaction: txs.first,
      account: party,
      isLocalTransaction: true,
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    final isUrdu = this.isUrdu;
    final fontFamily = this.fontFamily;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      onSelected: (value) async {
        if (value == 'bulk_entry') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BulkPartyTransactionScreen(party: party),
            ),
          ).then((_) => onRefresh());
        } else if (value == 'history') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartyHistoryScreen(party: party),
            ),
          );
        } else if (value == 'pdf') {
          final pdfService = Provider.of<PdfService>(context, listen: false);
          final db = Provider.of<DatabaseService>(context, listen: false);
          final txs = db
              .getAllTransactions()
              .where((t) => t.accountId == party.id)
              .toList();
          await pdfService.generateAccountStatement(
            account: party,
            transactions: txs,
            isUrdu: isUrdu,
          );
        } else if (value == 'edit') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPartyScreen(partyToEdit: party),
            ),
          );
          onRefresh();
        } else if (value == 'delete') {
          _confirmDelete(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'bulk_entry',
          child: _menuItem(
            PhosphorIcons.listBullets(),
            isUrdu ? 'پیج انٹری' : 'Bulk Entry',
            fontFamily,
          ),
        ),
        PopupMenuItem(
          value: 'history',
          child: _menuItem(
            PhosphorIcons.clockCounterClockwise(),
            isUrdu ? 'مکمل تجزیہ' : 'Full Analysis',
            fontFamily,
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: _menuItem(
            PhosphorIcons.filePdf(),
            isUrdu ? 'PDF رپورٹ' : 'PDF Report',
            fontFamily,
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: _menuItem(
            PhosphorIcons.pencilLine(),
            isUrdu ? 'ایڈٹ' : 'Edit',
            fontFamily,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(
            PhosphorIcons.trash(),
            isUrdu ? 'ڈیلیٹ' : 'Delete',
            fontFamily,
            color: AppTheme.expenseColor,
          ),
        ),
      ],
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    String? fontFamily, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.darkColor, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final isUrdu = this.isUrdu;
    final fontFamily = this.fontFamily;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isUrdu ? 'پارٹی ختم کریں؟' : 'Delete Party?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی اس پارٹی کو ختم کرنا چاہتے ہیں؟ تمام ریکارڈ مٹ جائے گا۔'
              : 'Are you sure you want to delete this party? All records will be lost.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              isUrdu ? 'منسوخ' : 'Cancel',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontFamily: fontFamily),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isUrdu ? 'ختم کریں' : 'Delete',
              style: TextStyle(
                  color: AppTheme.expenseColor, fontFamily: fontFamily),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await Provider.of<DatabaseService>(context, listen: false)
          .deleteAccount(party.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 1: لین دین
// ═══════════════════════════════════════════════════════════
class _TransactionsTab extends StatefulWidget {
  final Account party;
  final bool isReadOnly;
  final String? highlightTransactionId;
  final String searchQuery;
  final bool isAscending;
  final bool isUrdu;
  final String? fontFamily;

  const _TransactionsTab({
    required this.party,
    required this.isReadOnly,
    this.highlightTransactionId,
    required this.searchQuery,
    required this.isAscending,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  late final DatabaseService _dbService;
  List<model.Transaction> _transactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String? _highlightId;
  bool _isFabVisible = true;
  final Set<String> _expandedCycleIds = {};

  @override
  void initState() {
    super.initState();
    _dbService = Provider.of<DatabaseService>(context, listen: false);
    _dbService.addListener(_refresh);
    _highlightId = widget.highlightTransactionId;
    _load();

    if (_highlightId != null) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _highlightId = null);
      });
    }
  }

  @override
  void dispose() {
    _dbService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _load() async {
    await _dbService.recalculateAccountBalance(widget.party.id);
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final txs = _dbService
        .getAllTransactions()
        .where((t) =>
            t.accountId == widget.party.id && t.partnershipId == null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.trim().toLowerCase();
    final filtered = _transactions.where((t) {
      final matchesFilter = _selectedFilter == 'all' ||
          (_selectedFilter == 'payables' && t.type == 'expense') ||
          (_selectedFilter == 'receivables' && t.type == 'income');
      final matchesSearch = query.isEmpty ||
          t.description.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList()
      ..sort((a, b) =>
          widget.isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

    return Stack(
      children: [
        Column(
          children: [
            // ═══ FILTER CHIPS ═══
            _buildFilterChips(),

            // ═══ LIST LABELS ═══
            _buildListLabels(),

            // ═══ TRANSACTIONS LIST ═══
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.themeColor,
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : _buildTransactionList(filtered),
            ),
          ],
        ),

        // ═══ FAB ═══
        if (!widget.isReadOnly)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _isFabVisible ? 20 : -80,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'combined_fab',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(
                      account: widget.party,
                    ),
                  ),
                );
                _load();
              },
              backgroundColor: AppTheme.darkColor,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
      ],
    );
  }

  // ═══ Filter Chips ═══
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _filterChip('all', widget.isUrdu ? 'سب' : 'All'),
          const SizedBox(width: 28),
          _filterChip(
            'payables',
            widget.isUrdu ? 'واجب الادا' : 'Payables',
          ),
          const SizedBox(width: 28),
          _filterChip(
            'receivables',
            widget.isUrdu ? 'واجب الوصول' : 'Receivables',
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.darkColor : AppTheme.textSecondary,
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: widget.fontFamily,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 24,
              color: AppTheme.darkColor,
            ),
        ],
      ),
    );
  }

  // ═══ List Labels ═══
  Widget _buildListLabels() {
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
              widget.isUrdu ? "تفصیل" : "Details",
              style: TextStyle(
                color: AppTheme.themeColor,
                fontSize: 13,
                fontFamily: widget.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _labelWithIcon(
              widget.isUrdu ? 'دیا / بنام' : 'Credits',
              PhosphorIcons.arrowUpRight(),
            ),
          ),
          Expanded(
            flex: 2,
            child: _labelWithIcon(
              widget.isUrdu ? 'لیا / جمع' : 'Debits',
              PhosphorIcons.arrowDownLeft(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelWithIcon(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.themeColor),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.themeColor,
                fontSize: 12,
                fontFamily: widget.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══ Transactions List ═══
  Widget _buildTransactionList(List<model.Transaction> txs) {
    final chronological = [..._transactions]
      ..sort((a, b) => a.date.compareTo(b.date));

    final txBalances = <String, double>{};
    final cycles = <Map<String, dynamic>>[];
    var currentCycleTxs = <model.Transaction>[];
    double runningIn = 0, runningOut = 0;
    DateTime? cycleStart;

    for (var tx in chronological) {
      cycleStart ??= tx.date;
      currentCycleTxs.add(tx);
      if (tx.type == 'income') {
        runningIn += tx.accountBalanceAmount;
      } else {
        runningOut += tx.accountBalanceAmount;
      }
      txBalances[tx.id] = runningIn - runningOut;

      if ((runningIn - runningOut).abs() < 0.01) {
        cycles.add({
          'id': tx.id,
          'transactions': List<model.Transaction>.from(currentCycleTxs),
          'isSettled': true,
          'totalIn': runningIn,
          'totalOut': runningOut,
          'startDate': cycleStart,
          'endDate': tx.date,
          'days': tx.date.difference(cycleStart).inDays,
        });
        currentCycleTxs.clear();
        runningIn = 0;
        runningOut = 0;
        cycleStart = null;
      }
    }
    if (currentCycleTxs.isNotEmpty) {
      cycles.add({
        'id': 'active',
        'transactions': List<model.Transaction>.from(currentCycleTxs),
        'isSettled': false,
        'totalIn': runningIn,
        'totalOut': runningOut,
      });
    }

    final filteredIds = txs.map((t) => t.id).toSet();
    var display = <Map<String, dynamic>>[];
    for (var c in cycles) {
      final list = (c['transactions'] as List)
          .whereType<model.Transaction>()
          .where((t) => filteredIds.contains(t.id))
          .toList();
      if (list.isNotEmpty) {
        display.add({...c, 'display': list});
      }
    }
    if (!widget.isAscending) display = display.reversed.toList();

    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        if (n.direction == ScrollDirection.reverse && _isFabVisible) {
          setState(() => _isFabVisible = false);
        } else if (n.direction == ScrollDirection.forward && !_isFabVisible) {
          setState(() => _isFabVisible = true);
        }
        return true;
      },
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: display.length,
        itemBuilder: (context, i) {
          final c = display[i];
          final list = (c['display'] as List).whereType<model.Transaction>().toList();
          final settled = c['isSettled'] as bool;
          final id = c['id'] as String;
          final expanded = _expandedCycleIds.contains(id);

          if (!settled ||
              _selectedFilter != 'all' ||
              widget.searchQuery.isNotEmpty) {
            return _buildSubList(
              widget.isAscending ? list : list.reversed.toList(),
              txBalances,
            );
          }

          return Column(
            children: [
              _buildSettlementCard(c, expanded),
              if (expanded)
                _buildSubList(list.reversed.toList(), txBalances),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubList(
    List<model.Transaction> txs,
    Map<String, double> balances,
  ) {
    return Column(
      children: txs.map((t) {
        return Column(
          children: [
            _buildTransactionItem(t, balances[t.id] ?? 0),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSettlementCard(Map<String, dynamic> data, bool expanded) {
    final df = DateFormat('dd MMM yyyy');
    final start = df.format(data['startDate']);
    final end = df.format(data['endDate']);
    final days = data['days'];
    final id = data['id'];

    return InkWell(
      onTap: () {
        setState(() {
          if (expanded) {
            _expandedCycleIds.remove(id);
          } else {
            _expandedCycleIds.add(id);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: expanded ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.check,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isUrdu
                      ? "حساب برابر (ٹیپ کریں)"
                      : "Balanced (Tap)",
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: Colors.green.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  "$days ${widget.isUrdu ? 'دن' : 'days'}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$start → $end",
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(model.Transaction t, double runningBalance) {
    final isIncome = t.type == 'income';
    final isHighlighted = _highlightId == t.id;

    return InkWell(
      onLongPress: widget.isReadOnly
          ? null
          : () => _showDeleteConfirm(t),
      onTap: widget.isReadOnly
          ? null
          : () async {
              await ReceiptHelper.showReceiptDialog(
                context,
                transaction: t,
                account: widget.party,
                isLocalTransaction: true,
              );
              _load();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isHighlighted
            ? AppTheme.themeColor.withValues(alpha: 0.15)
            : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.description.isNotEmpty
                        ? t.description
                        : (widget.isUrdu ? 'نقد لین دین' : 'Cash'),
                    style: TextStyle(
                      color: AppTheme.darkColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: widget.fontFamily,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          DateFormat('dd MMM').format(t.date),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (t.referenceNumber != null &&
                            t.referenceNumber!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            "${widget.isUrdu ? 'بل' : 'Bill'} ${t.referenceNumber}",
                            style: TextStyle(
                              color: AppTheme.themeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: widget.isUrdu
                                  ? widget.fontFamily
                                  : null,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          "Rs ${runningBalance.abs().toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
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
                  !isIncome || t.isQuickBill
                      ? t.amount.toStringAsFixed(0)
                      : "-",
                  style: const TextStyle(
                    color: AppTheme.expenseColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
                  isIncome
                      ? (t.isQuickBill
                          ? t.receivedAmount.toStringAsFixed(0)
                          : t.amount.toStringAsFixed(0))
                      : "-",
                  style: const TextStyle(
                    color: AppTheme.incomeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.receipt(),
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            widget.isUrdu ? 'کوئی لین دین نہیں' : 'No transactions',
            style: TextStyle(
              fontFamily: widget.fontFamily,
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(model.Transaction t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.isUrdu ? 'ڈیلیٹ کریں؟' : 'Delete?',
          style: TextStyle(
            fontFamily: widget.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          widget.isUrdu
              ? 'کیا آپ واقعی یہ ٹرانزیکشن ڈیلیٹ کرنا چاہتے ہیں؟'
              : 'Are you sure you want to delete this transaction?',
          style: TextStyle(fontFamily: widget.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.isUrdu ? 'منسوخ' : 'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontFamily: widget.fontFamily,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<DatabaseService>(context, listen: false)
                  .deleteTransaction(t.id);
              _load();
              if (context.mounted) {
                AppToast.success(
                  context,
                  widget.isUrdu ? 'ڈیلیٹ ہو گیا' : 'Deleted',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
            ),
            child: Text(
              widget.isUrdu ? 'ڈیلیٹ' : 'Delete',
              style: TextStyle(
                color: Colors.white,
                fontFamily: widget.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 2: تجزیہ
// ═══════════════════════════════════════════════════════════
class _AnalysisTab extends StatefulWidget {
  final Account party;
  final bool isUrdu;
  final String? fontFamily;

  const _AnalysisTab({
    required this.party,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  State<_AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<_AnalysisTab> {
  List<model.Transaction> _transactions = [];
  Map<String, List<ItemPriceHistory>> _itemHistory = {};
  double _totalIn = 0, _totalOut = 0, _totalVolume = 0;
  int _totalDeals = 0;
  DateTime? _firstDeal;
  double _trustScore = 0;

  String _selectedTab = 'items';
  String _rateFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final clearedAt = <String, DateTime>{};
    for (final e in prefs.getStringList('rate_history_cleared_at') ?? []) {
      final sep = e.indexOf('|');
      if (sep > 0) {
        final d = DateTime.tryParse(e.substring(sep + 1));
        if (d != null) clearedAt[e.substring(0, sep)] = d;
      }
    }

    final allTx = db
        .getAllTransactions()
        .where((t) => t.accountId == widget.party.id)
        .toList();

    _totalIn = 0;
    _totalOut = 0;
    _totalDeals = 0;
    _firstDeal = null;

    final itemCount = <String, int>{};

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

    final chron = List.from(allTx)..sort((a, b) => a.date.compareTo(b.date));
    final history = <String, List<ItemPriceHistory>>{};

    for (var tx in chron) {
      for (var item in tx.items) {
        final cleared = clearedAt[item.description.trim()];
        if (item.rate > 0 &&
            (cleared == null || tx.createdAt.isAfter(cleared))) {
          _addToHistory(history, item.description, item.rate, tx.date, tx.type);
        }
      }
    }
    history.forEach((k, v) => v.sort((a, b) => b.date.compareTo(a.date)));
    final sorted = Map.fromEntries(history.entries.toList()
      ..sort((a, b) => b.value.first.date.compareTo(a.value.first.date)));

    _totalVolume = _totalIn + _totalOut;
    _totalDeals = allTx.length;

    double score = 0;
    final days = DateTime.now()
        .difference(_firstDeal ?? DateTime.now())
        .inDays;
    if (days > 180) {
      score += 1.0;
    } else if (days > 30) {
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
      final ratio = 1 - (widget.party.balance.abs() / _totalVolume);
      if (ratio > 0.9) {
        score += 1.0;
      } else if (ratio > 0.7) {
        score += 0.5;
      }
    }
    _trustScore = score.clamp(1.0, 5.0);

    _transactions = List.from(allTx)..sort((a, b) => b.date.compareTo(a.date));

    setState(() => _itemHistory = sorted);
  }

  void _addToHistory(
    Map<String, List<ItemPriceHistory>> h,
    String name,
    double price,
    DateTime date,
    String type,
  ) {
    if (name.isEmpty || name == 'دیگر' || name == 'Other') return;
    final clean = name.trim();
    if (!h.containsKey(clean)) {
      h[clean] = [
        ItemPriceHistory(price: price, date: date, type: type),
      ];
    } else {
      final last = h[clean]!.last;
      if (last.price != price) {
        final pct = ((price - last.price) / last.price) * 100;
        final days = date.difference(last.date).inDays;
        h[clean]!.add(ItemPriceHistory(
          price: price,
          date: date,
          type: type,
          changePercentage: pct,
          daysInterval: days,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      child: Column(
        children: [
          _build3Stats(),
          const SizedBox(height: 14),
          _buildToggleTabs(),
          const SizedBox(height: 14),
          if (_selectedTab == 'items') ...[
            _buildSubFilter(),
            const SizedBox(height: 10),
            if (_itemHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  widget.isUrdu ? 'کوئی آئٹم نہیں' : 'No items',
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              ..._itemHistory.entries.map(
                (e) => _buildItemCard(e.key, e.value),
              ),
          ] else
            _buildPersonalReview(),
        ],
      ),
    );
  }

  Widget _build3Stats() {
    return Row(
      children: [
        _statCard(_getRelationshipPeriod(), widget.isUrdu ? 'تعلق کو' : 'Relationship'),
        const SizedBox(width: 10),
        _statCard('$_totalDeals', widget.isUrdu ? 'کل اندراج' : 'Total Deals'),
        const SizedBox(width: 10),
        _statCard(_formatVolume(_totalVolume), widget.isUrdu ? 'حجم' : 'Volume'),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.backgroundColor),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: widget.fontFamily,
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleBtn(
              'items',
              widget.isUrdu ? 'آئٹمز اور ریٹ' : 'Items & Rates',
            ),
          ),
          Expanded(
            child: _toggleBtn(
              'review',
              widget.isUrdu ? 'ذاتی جائزہ' : 'Personal Review',
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String key, String label) {
    final active = _selectedTab == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: widget.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: active ? AppTheme.darkColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSubFilter() {
    return Row(
      children: [
        _subChip('all', widget.isUrdu ? 'سب' : 'All'),
        const SizedBox(width: 8),
        _subChip('chg', widget.isUrdu ? 'ریٹ بدلا' : 'Rate Changed'),
        const Spacer(),
        Flexible(
          child: Text(
            widget.isUrdu ? 'ٹچ کریں، ہسٹری کھلے گی' : 'Tap to see history',
            style: TextStyle(
              fontFamily: widget.fontFamily,
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _subChip(String val, String label) {
    final active = _rateFilter == val;
    return GestureDetector(
      onTap: () => setState(() => _rateFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppTheme.darkColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: widget.fontFamily,
            fontSize: 11.5,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? AppTheme.darkColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(String name, List<ItemPriceHistory> history) {
    final hasChange = history.any((h) => h.changePercentage != null);
    if (_rateFilter == 'chg' && !hasChange) return const SizedBox.shrink();

    final latest = history.first;
    final isDecrease = latest.changePercentage != null &&
        latest.changePercentage! < 0;
    final totalAmount = history.fold<double>(0, (s, h) => s + h.price * 10);
    final badgeColor =
        isDecrease ? AppTheme.incomeColor : AppTheme.expenseColor;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemHistoryDetailScreen(
              itemName: name,
              history: history,
              partyName: widget.party.name,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.backgroundColor),
        ),
        child: Column(
          children: [
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
                    child: const Icon(
                      Icons.local_drink,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: widget.fontFamily,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${history.length} ${widget.isUrdu ? "خریداریاں" : "purchases"}',
                          style: TextStyle(
                            fontFamily: widget.fontFamily,
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs ${latest.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkColor,
                        ),
                      ),
                      Text(
                        widget.isUrdu ? 'آخری ریٹ' : 'Last rate',
                        style: TextStyle(
                          fontFamily: widget.fontFamily,
                          fontSize: 10.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    widget.isUrdu ? 'کل' : 'Total',
                    style: TextStyle(
                      fontFamily: widget.fontFamily,
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rs ${totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  if (latest.changePercentage != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${latest.changePercentage!.abs().toStringAsFixed(1)}% ${isDecrease ? "↓" : "↑"}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalReview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.isUrdu ? 'ذاتی جائزہ' : 'Personal Review',
                style: TextStyle(
                  fontFamily: widget.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.expenseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock,
                        size: 11, color: AppTheme.expenseColor),
                    const SizedBox(width: 4),
                    Text(
                      widget.isUrdu ? 'صرف آپ' : 'Only you',
                      style: TextStyle(
                        fontFamily: widget.fontFamily,
                        fontSize: 10.5,
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
              _stars(_trustScore, 18),
              const SizedBox(width: 8),
              Text(
                widget.isUrdu ? 'آخری 12 مہینے' : 'Last 12 months',
                style: TextStyle(
                  fontFamily: widget.fontFamily,
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _reviewRow(
            widget.isUrdu ? 'ادائیگی کی رفتار' : 'Payment speed',
            widget.isUrdu ? 'اوسط 12 دن دیر' : 'Avg 12 days late',
            3,
          ),
          _reviewRow(
            widget.isUrdu ? 'بقایا رقم' : 'Outstanding',
            widget.isUrdu ? '16% باقی' : '16% remaining',
            2,
          ),
          _reviewRow(
            widget.isUrdu ? 'باقاعدگی' : 'Regularity',
            widget.isUrdu ? 'ہر 8.8 دن' : 'Every 8.8 days',
            4,
          ),
          const SizedBox(height: 10),
          Text(
            widget.isUrdu
                ? 'یہ آپ کے اپنے حساب پر اندازہ ہے۔ پارٹی کو نہیں دکھتا۔'
                : 'Your private estimate. Not visible to the party.',
            style: TextStyle(
              fontFamily: widget.fontFamily,
              fontSize: 10.5,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String title, String sub, int stars) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: 13.5,
                    color: AppTheme.darkColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _stars(stars.toDouble(), 14),
        ],
      ),
    );
  }

  Widget _stars(double score, double size) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return Icon(
            i < score ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFF2563EB),
            size: size,
          );
        }),
      ),
    );
  }

  String _formatVolume(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)} لاکھ';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} ہزار';
    return v.toStringAsFixed(0);
  }

  String _getRelationshipPeriod() {
    if (_firstDeal == null || _transactions.isEmpty) return '-';
    final last = _transactions.first.date;
    final diff = last.difference(_firstDeal!);
    if (diff.inDays < 30) {
      return '${diff.inDays == 0 ? 1 : diff.inDays} ${widget.isUrdu ? "دن" : "days"}';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} ${widget.isUrdu ? "ماہ" : "months"}';
    } else {
      return '${(diff.inDays / 365).floor()} ${widget.isUrdu ? "سال" : "years"}';
    }
  }
}
