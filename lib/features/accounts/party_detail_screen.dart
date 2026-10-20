import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/utils/receipt_dialog_helper.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/profile_update_dialog.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/item_rate_history_card_widget.dart';
import 'package:account_app/features/accounts/add_transaction_screen.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/accounts/bulk_party_transaction_screen.dart';
import 'package:account_app/features/accounts/sms_invitation_screen.dart';
import 'package:account_app/features/accounts/widgets/party_tools_grid_widget.dart';
import 'package:account_app/features/dashboard/app_shell_screen.dart';
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
  Map<String, String>? _remoteProfileMap;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (widget.party.phone.length < 10) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    try {
      final profile =
          await dbService.findPublicProfileByPhone(widget.party.phone);
      if (mounted && profile != null) {
        setState(() {
          _remoteProfileMap = profile;
        });
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'party detail screen',
          context: ErrorDescription('while loading the party public profile'),
        ),
      );
    }
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
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            AppShellScreen.switchTab(1);
          }
        },
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
              onRefresh: () {
                _checkForUpdate();
                setState(() {});
              },
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
              remoteProfileMap: _remoteProfileMap,
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
                  Tab(text: isUrdu ? 'ٹولز اور ہسٹری' : 'Tools & History'),
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
                        onSearchChanged: (v) =>
                            setState(() => _searchQuery = v),
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
  final Map<String, String>? remoteProfileMap;

  const _CombinedHeader({
    required this.party,
    required this.isReadOnly,
    required this.isUrdu,
    required this.fontFamily,
    required this.onRefresh,
    required this.showSearch,
    required this.onToggleSearch,
    this.remoteProfileMap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseService>(
      builder: (context, dbService, _) {
        final allTx = dbService
            .getAllTransactions()
            .where((t) => t.accountId == party.id && t.partnershipId == null)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final openingBalance = party.balanceType.toLowerCase() == 'payable'
            ? -party.initialBalance
            : party.initialBalance;

        final cycle = AccountBalanceUtils.currentCycle(allTx);
        double totalIncome = cycle.income; // 🟢 جمع (Credit) Total
        double totalExpense = cycle.expense; // 🔴 بنام (Debit) Total

        if (allTx.isEmpty) {
          if (openingBalance > 0) {
            totalExpense += openingBalance; // پرانا بقایا (لینے ہیں) -> بنام 🔴
          } else if (openingBalance < 0) {
            totalIncome += openingBalance.abs(); // پرانا بقایا (دینے ہیں) -> جمع 🟢
          }
        }

        double currentBalance = totalExpense - totalIncome;
        final bool isReceivable = currentBalance > 0;
        final bool isSettled = currentBalance.abs() < 0.01;

        final remoteName = remoteProfileMap?['name']?.trim() ?? '';
        final localName = party.name.trim();
        final remotePhoto = remoteProfileMap?['photoUrl']?.trim() ?? '';
        final localPhoto = (party.profileImage ?? '').trim();
        final remoteProf = remoteProfileMap?['profession']?.trim() ?? '';
        final localProf = (isUrdu ? 'پرسنل کھاتہ' : 'Personal Account').trim();
        final remoteAddress = remoteProfileMap?['address']?.trim() ?? '';
        final localAddress = (party.address ?? '').trim();

        final bool hasUpdate = remoteProfileMap != null &&
            ((remoteName.isNotEmpty && remoteName != localName) ||
                (remotePhoto.isNotEmpty && remotePhoto != localPhoto) ||
                (remoteProf.isNotEmpty &&
                    remoteProf != party.category &&
                    remoteProf != localProf) ||
                (remoteAddress.isNotEmpty && remoteAddress != localAddress));

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
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 24),
                        onPressed: () {
                          AppShellScreen.switchTab(1);
                          Navigator.pop(context);
                        },
                      ),
                      Expanded(
                        child: UrduAwareText(
                          isUrdu ? 'پارٹی ڈیٹیل' : 'Party Detail',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: isUrdu ? 20 : 18,
                            fontWeight:
                                isUrdu ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // سرچ آئیکن بٹن (تین ڈاٹ کے سامنے)
                      IconButton(
                        icon: Icon(
                          showSearch
                              ? PhosphorIcons.x()
                              : PhosphorIcons.magnifyingGlass(),
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: onToggleSearch,
                        tooltip: isUrdu ? 'تلاش' : 'Search',
                      ),
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
                        hasUpdate: hasUpdate,
                        onAvatarTap: (hasUpdate && remoteProfileMap != null)
                            ? () {
                                ProfileUpdateDialog.show(
                                  context,
                                  party: party,
                                  remoteProfile: remoteProfileMap!,
                                  onUpdated: onRefresh,
                                );
                              }
                            : null,
                      ),

                      const SizedBox(height: 8),

                      // ═══ Stats Row (جمع | بنام | لینا/دینا) ═══
                      Row(
                        children: [
                          _buildStatItem(
                            isUrdu ? 'جمع' : 'In',
                            totalIncome,
                            AppTheme.incomeColor,
                            PhosphorIcons.arrowDownLeft(),
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            isUrdu ? 'بنام' : 'Out',
                            totalExpense,
                            AppTheme.expenseColor,
                            PhosphorIcons.arrowUpRight(),
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            isUrdu
                                ? (isSettled
                                    ? 'حساب صاف'
                                    : (isReceivable ? 'لینے ہیں' : 'دینے ہیں'))
                                : (isSettled
                                    ? 'Settled'
                                    : (isReceivable
                                        ? 'Receivable'
                                        : 'Payable')),
                            currentBalance.abs(),
                            isReceivable
                                ? AppTheme.incomeColor
                                : AppTheme.expenseColor,
                            isReceivable
                                ? PhosphorIcons.arrowDownLeft()
                                : PhosphorIcons.arrowUpRight(),
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
          UrduAwareText(
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
                  child: UrduAwareText(
                    "Rs ${Formatters.formatAmount(amount)}",
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
              UrduAwareText(
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
  Future<void> _onCall(BuildContext context) async {
    final phone = party.phone.trim();
    if (phone.isEmpty) {
      AppToast.warning(
        context,
        isUrdu ? 'نمبر موجود نہیں' : 'No phone number',
      );
      return;
    }
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
  }

  void _onRemind(BuildContext context) {
    BalanceAlertDialog.show(context, party: party);
  }

  void _onReceipt(BuildContext context, List<model.Transaction> txs) {
    if (txs.isEmpty) {
      AppToast.info(
        context,
        isUrdu ? 'کوئی لین دین نہیں' : 'No transactions',
      );
      return;
    }
    ReceiptDialogHelper.showReceiptDialog(
      context,
      transaction: txs.first,
      account: party,
      isLocalTransaction: true,
    );
  }



  Future<void> _confirmDelete(BuildContext context) async {
    final isUrdu = this.isUrdu;
    final fontFamily = this.fontFamily;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: UrduAwareText(
          isUrdu ? 'پارٹی ختم کریں؟' : 'Delete Party?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: UrduAwareText(
          isUrdu
              ? 'کیا آپ واقعی اس پارٹی کو ختم کرنا چاہتے ہیں؟ تمام ریکارڈ مٹ جائے گا۔'
              : 'Are you sure you want to delete this party? All records will be lost.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: UrduAwareText(
              isUrdu ? 'منسوخ' : 'Cancel',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontFamily: fontFamily),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: UrduAwareText(
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
    if (!mounted) return;
    await _dbService.recalculateAccountBalance(widget.party.id);
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final txs = _dbService
        .getAllTransactions()
        .where((t) => t.accountId == widget.party.id && t.partnershipId == null)
        .toList()
      ..sort((a, b) => _compareTransactions(b, a));
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  }

  int _compareTransactions(model.Transaction first, model.Transaction second) {
    final dateOrder = first.date.compareTo(second.date);
    if (dateOrder != 0) return dateOrder;

    final createdOrder = first.createdAt.compareTo(second.createdAt);
    if (createdOrder != 0) return createdOrder;

    return first.id.compareTo(second.id);
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
      ..sort((a, b) => widget.isAscending
          ? _compareTransactions(a, b)
          : _compareTransactions(b, a));

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
                if (!mounted) return;
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
          UrduAwareText(
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
            flex: 6,
            child: UrduAwareText(
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: _labelWithIcon(
                widget.isUrdu ? 'دیا / بنام' : 'Credits',
                PhosphorIcons.arrowUpRight(),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _labelWithIcon(
                widget.isUrdu ? 'لیا / جمع' : 'Debits',
                PhosphorIcons.arrowDownLeft(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelWithIcon(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.themeColor),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: UrduAwareText(
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
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final allAccountTxs = dbService
        .getAllTransactions()
        .where((t) => t.accountId == widget.party.id && t.partnershipId == null)
        .toList()
      ..sort(_compareTransactions);

    double openingBalance = widget.party.initialBalance;
    if (widget.party.balanceType.toLowerCase() == 'payable') {
      openingBalance = -openingBalance;
    }

    final txBalances = AccountBalanceUtils.runningBalances(
      allAccountTxs,
      initialBalance: openingBalance,
    );

    final chronological = allAccountTxs;

    final cycles = <Map<String, dynamic>>[];
    var currentCycleTxs = <model.Transaction>[];
    double cycleIn = 0, cycleOut = 0;
    double cycleBalance = openingBalance;
    DateTime? cycleStart;

    for (var tx in chronological) {
      cycleStart ??= tx.date;
      currentCycleTxs.add(tx);
      final columns = AccountBalanceUtils.transactionColumns(tx);
      cycleOut += columns.firstColumn;
      cycleIn += columns.secondColumn;
      cycleBalance += columns.firstColumn - columns.secondColumn;

      if (cycleBalance.abs() < 0.01) {
        cycles.add({
          'id': tx.id,
          'transactions': List<model.Transaction>.from(currentCycleTxs),
          'isSettled': true,
          'totalIn': cycleIn,
          'totalOut': cycleOut,
          'startDate': cycleStart,
          'endDate': tx.date,
          'days': tx.date.difference(cycleStart).inDays,
        });
        currentCycleTxs.clear();
        cycleIn = 0;
        cycleOut = 0;
        cycleBalance = 0;
        cycleStart = null;
      }
    }
    if (currentCycleTxs.isNotEmpty) {
      cycles.add({
        'id': 'active',
        'transactions': List<model.Transaction>.from(currentCycleTxs),
        'isSettled': false,
        'totalIn': cycleIn,
        'totalOut': cycleOut,
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
          final list =
              (c['display'] as List).whereType<model.Transaction>().toList();
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
              if (expanded) _buildSubList(list.reversed.toList(), txBalances),
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
    final totalIn = (data['totalIn'] as num?)?.toDouble() ?? 0;
    final totalOut = (data['totalOut'] as num?)?.toDouble() ?? 0;

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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.themeColor.withValues(alpha: expanded ? 0.12 : 0.06),
              AppTheme.themeColor.withValues(alpha: expanded ? 0.06 : 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.themeColor.withValues(alpha: expanded ? 0.35 : 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.themeColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.themeColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                UrduAwareText(
                  widget.isUrdu ? "حساب برابر" : "Balanced",
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppTheme.darkColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: UrduAwareText(
                    "$days ${widget.isUrdu ? 'دن' : 'days'}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.themeColor,
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              Container(
                  height: 1,
                  color: AppTheme.themeColor.withValues(alpha: 0.15)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  UrduAwareText("$start → $end",
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      if (totalOut > 0)
                        UrduAwareText(
                          '${widget.isUrdu ? "بنام:" : "Out:"} Rs ${Formatters.formatAmount(totalOut)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.expenseColor,
                          ),
                        ),
                      if (totalOut > 0 && totalIn > 0)
                        const SizedBox(width: 10),
                      if (totalIn > 0)
                        UrduAwareText(
                          '${widget.isUrdu ? "جمع:" : "In:"} Rs ${Formatters.formatAmount(totalIn)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.incomeColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(model.Transaction t, double runningBalance) {
    final isHighlighted = _highlightId == t.id;
    final columns = AccountBalanceUtils.transactionColumns(t);

    return InkWell(
      onLongPress: widget.isReadOnly ? null : () => _showDeleteConfirm(t),
      onTap: widget.isReadOnly
          ? null
          : () async {
              await ReceiptDialogHelper.showReceiptDialog(
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
                  UrduAwareText(
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
                        UrduAwareText(
                          DateFormat('dd MMM').format(t.date),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (t.referenceNumber != null &&
                            t.referenceNumber!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          UrduAwareText(
                            "${widget.isUrdu ? 'بل' : 'Bill'} ${t.referenceNumber}",
                            style: TextStyle(
                              color: AppTheme.themeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily:
                                  widget.isUrdu ? widget.fontFamily : null,
                            ),
                          ),
                        ],
                        if (t.professionName != null &&
                            t.professionName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          UrduAwareText(
                            t.professionName!,
                            style: TextStyle(
                              color: AppTheme.purpleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: widget.fontFamily,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        UrduAwareText(
                          "Rs ${Formatters.formatAmount(runningBalance.abs())}",
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
                child: UrduAwareText(
                  columns.firstColumn > 0
                      ? Formatters.formatAmount(columns.firstColumn)
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
                child: UrduAwareText(
                  columns.secondColumn > 0
                      ? Formatters.formatAmount(columns.secondColumn)
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
          Icon(PhosphorIcons.receipt(), size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          UrduAwareText(
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
    final parentContext = context;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: UrduAwareText(
          widget.isUrdu ? 'ڈیلیٹ کریں؟' : 'Delete?',
          style: TextStyle(
            fontFamily: widget.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: UrduAwareText(
          widget.isUrdu
              ? 'کیا آپ واقعی یہ ٹرانزیکشن ڈیلیٹ کرنا چاہتے ہیں؟'
              : 'Are you sure you want to delete this transaction?',
          style: TextStyle(fontFamily: widget.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(
              widget.isUrdu ? 'منسوخ' : 'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontFamily: widget.fontFamily,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await dbService.deleteTransaction(t.id);
              _load();
              if (parentContext.mounted) {
                AppToast.success(
                  parentContext,
                  widget.isUrdu ? 'ڈیلیٹ ہو گیا' : 'Deleted',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
            ),
            child: UrduAwareText(
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
        .where((t) => t.accountId == widget.party.id && t.partnershipId == null)
        .toList();

    _totalIn = 0;
    _totalOut = 0;
    _totalDeals = 0;
    _firstDeal = null;

    final itemCount = <String, int>{};

    for (var tx in allTx) {
      if (tx.isQuickBill) {
        final subtotal = tx.subtotal > 0 ? tx.subtotal : tx.amount;
        final billTotal =
            (subtotal - tx.discountAmount).clamp(0, subtotal).toDouble();
        if (tx.type == 'income') {
          _totalIn += billTotal;
          _totalOut += tx.receivedAmount;
        } else {
          _totalOut += billTotal;
          _totalIn += tx.receivedAmount;
        }
      } else if (tx.type == 'income') {
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

    final chron = List<model.Transaction>.from(allTx)
      ..sort((a, b) => a.date.compareTo(b.date));
    final history = <String, List<ItemPriceHistory>>{};

    for (var tx in chron) {
      for (var item in tx.items) {
        final cleared = clearedAt[item.description.trim()];
        if (item.rate > 0 &&
            (cleared == null || tx.createdAt.isAfter(cleared))) {
          final qty = item.quantity > 0 ? item.quantity : 1.0;
          final total = item.total > 0 ? item.total : (item.rate * qty);
          _addToHistory(
            history,
            item.description,
            item.rate,
            qty,
            total,
            item.unit,
            tx.date,
            tx.type,
          );
        }
      }
    }
    history.forEach((k, v) => v.sort((a, b) => b.date.compareTo(a.date)));
    final sorted = Map.fromEntries(history.entries.toList()
      ..sort((a, b) => b.value.first.date.compareTo(a.value.first.date)));

    _totalVolume = _totalIn + _totalOut;
    _totalDeals = allTx.length;
    final openingBalance = widget.party.balanceType.toLowerCase() == 'payable'
        ? -widget.party.initialBalance
        : widget.party.initialBalance;
    final currentBalance = AccountBalanceUtils.ledgerBalance(
      allTx,
      initialBalance: openingBalance,
    );

    double score = 0;
    final days = DateTime.now().difference(_firstDeal ?? DateTime.now()).inDays;
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
      final ratio = 1 - (currentBalance.abs() / _totalVolume);
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
    double quantity,
    double total,
    String? unit,
    DateTime date,
    String type,
  ) {
    if (name.isEmpty || name == 'دیگر' || name == 'Other') return;
    final clean = name.trim();
    final entryTotal = total > 0 ? total : (price * quantity);
    if (!h.containsKey(clean)) {
      h[clean] = [
        ItemPriceHistory(
          price: price,
          quantity: quantity,
          total: entryTotal,
          unit: unit,
          date: date,
          type: type,
        ),
      ];
    } else {
      final last = h[clean]!.last;
      final pct = last.price > 0 && last.price != price
          ? (((price - last.price) / last.price) * 100)
          : null;
      final days = date.difference(last.date).inDays;
      h[clean]!.add(ItemPriceHistory(
        price: price,
        quantity: quantity,
        total: entryTotal,
        unit: unit,
        date: date,
        type: type,
        changePercentage: pct != 0 ? pct : null,
        daysInterval: days,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
        child: Column(
          children: [
            PartyToolsGridWidget(
              party: widget.party,
              isUrdu: widget.isUrdu,
              fontFamily: widget.fontFamily,
              onRefresh: _loadData,
            ),
            const SizedBox(height: 12),
            _build3Stats(),
            const SizedBox(height: 14),
            _buildSubFilter(),
            const SizedBox(height: 10),
            if (_itemHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: UrduAwareText(
                  widget.isUrdu ? 'کوئی آئٹم نہیں' : 'No items',
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              ..._itemHistory.entries.map((e) {
                final cardHistory = e.value
                    .map((h) => ItemPriceHistory(
                          price: h.price,
                          quantity: h.quantity,
                          total: h.total,
                          date: h.date,
                          type: h.type,
                          unit: h.unit,
                          changePercentage: h.changePercentage,
                          daysInterval: h.daysInterval,
                        ))
                    .toList();

                return ItemRateHistoryCardWidget(
                  itemName: e.key,
                  partyName: widget.party.name,
                  history: cardHistory,
                  isUrdu: widget.isUrdu,
                  fontFamily: widget.fontFamily,
                  onItemUpdated: _loadData,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _build3Stats() {
    return Row(
      children: [
        _statCard(_getRelationshipPeriod(),
            widget.isUrdu ? 'تعلق کو' : 'Relationship'),
        const SizedBox(width: 10),
        _statCard('$_totalDeals', widget.isUrdu ? 'کل اندراج' : 'Total Deals'),
        const SizedBox(width: 10),
        _statCard(
            _formatVolume(_totalVolume), widget.isUrdu ? 'حجم' : 'Volume'),
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
            UrduAwareText(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 4),
            UrduAwareText(
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

  Widget _buildSubFilter() {
    return Row(
      children: [
        _subChip('all', widget.isUrdu ? 'سب' : 'All'),
        const SizedBox(width: 8),
        _subChip('chg', widget.isUrdu ? 'ریٹ بدلا' : 'Rate Changed'),
        const Spacer(),
        Flexible(
          child: UrduAwareText(
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
        child: UrduAwareText(
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

  String _formatVolume(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)} لاکھ';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} ہزار';
    return v.toStringAsFixed(0);
  }
}
