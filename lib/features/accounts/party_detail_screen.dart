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
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/utils/party_summary_utils.dart';
import 'package:account_app/core/utils/receipt_dialog_helper.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/profile_update_dialog.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/item_rate_history_card_widget.dart';
import 'package:account_app/features/accounts/add_transaction_screen.dart';
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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
          appBar: ScreenAppBar(
            title: isUrdu ? 'پارٹی ڈیٹیل' : 'Party Detail',
            isUrdu: isUrdu,
            actions: [
              IconButton(
                icon: Icon(
                  _showSearch
                      ? PhosphorIcons.x()
                      : PhosphorIcons.magnifyingGlass(),
                ),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),
            ],
          ),
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
                tabController: _tabController,
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
  final TabController tabController;

  const _CombinedHeader({
    required this.party,
    required this.isReadOnly,
    required this.isUrdu,
    required this.fontFamily,
    required this.onRefresh,
    required this.showSearch,
    required this.onToggleSearch,
    this.remoteProfileMap,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseService>(
      builder: (context, dbService, _) {
        final allTx = dbService
            .getAllTransactions()
            .where((t) => t.accountId == party.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final openingBalance = PartySummaryUtils.openingBalanceFor(party);

        final cycle = AccountBalanceUtils.currentCycle(
          allTx,
          initialBalance: openingBalance,
        );
        final double totalCredit = cycle.credit;
        final double totalDebit = cycle.debit;

        double currentBalance = totalDebit - totalCredit;
        final bool isReceivable = currentBalance > 0;
        final bool isSettled = currentBalance.abs() < 0.01;
        final settlementType = isSettled
            ? (AccountBalanceUtils.isSupplierCategory(party.category)
                ? 'expense'
                : 'income')
            : (isReceivable ? 'income' : 'expense');

        final remoteName = remoteProfileMap?['name']?.trim() ?? '';
        final localName = party.name.trim();
        final remotePhoto = remoteProfileMap?['photoUrl']?.trim() ?? '';
        final localPhoto = (party.profileImage ?? '').trim();
        final remoteProf = remoteProfileMap?['profession']?.trim() ?? '';
        final localProf = (party.profession ?? '').trim();
        final remoteAddress = remoteProfileMap?['address']?.trim() ?? '';
        final localAddress = (party.address ?? '').trim();

        final bool hasUpdate = remoteProfileMap != null &&
            ((remoteName.isNotEmpty && remoteName != localName) ||
                (remotePhoto.isNotEmpty && remotePhoto != localPhoto) ||
                (remoteProf != localProf &&
                    (remoteProf.isNotEmpty || localProf.isNotEmpty)) ||
                (remoteAddress.isNotEmpty && remoteAddress != localAddress));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Slate Gradient Card (With generous top padding for Profile Picture & Name)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.slateColor, AppTheme.verifiedGold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.slateColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Column(
                    children: [
                      // Profile Info
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
                        customSize: 42,
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

                      const SizedBox(height: 10),

                      // ═══ Stats Row (Credit | Debit | Balance) ═══
                      Row(
                        children: [
                          _buildStatItem(
                            isUrdu ? 'جمع' : 'Credit',
                            totalCredit,
                            AppTheme.incomeColor,
                            PhosphorIcons.arrowDownLeft(),
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            isUrdu ? 'بنام' : 'Debit',
                            totalDebit,
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

                      const SizedBox(height: 10),

                      // ═══ Action Buttons (Call | Remind | Settle) ═══
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
                          if (!isReadOnly) ...[
                            const SizedBox(width: 6),
                            _buildActionButton(
                              icon: settlementType == 'income'
                                  ? PhosphorIcons.arrowDownLeft()
                                  : PhosphorIcons.arrowUpRight(),
                              label: settlementType == 'income'
                                  ? (isUrdu ? 'وصولی' : 'Receive')
                                  : (isUrdu ? 'ادائیگی' : 'Pay'),
                              onTap: () => _onSettlement(
                                context,
                                settlementType,
                                currentBalance.abs(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ═══ Bottom White Card Section for Button Tabs (Matching ContractDetailScreen Design) ═══
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.lightColor,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
              ),
              child: Row(
                children: [
                  // Tab 0: Transactions ("لین دین")
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        tabController.animateTo(0);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: tabController.index == 0
                              ? AppTheme.slateColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            UrduAwareText(
                              isUrdu ? 'لین دین' : 'Transactions',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: tabController.index == 0
                                    ? Colors.white
                                    : AppTheme.darkColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tabController.index == 0
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : AppTheme.slateColor
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: UrduAwareText(
                                '${allTx.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tabController.index == 0
                                      ? Colors.white
                                      : AppTheme.slateColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Tab 1: Tools & History ("ٹولز اور ہسٹری")
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        tabController.animateTo(1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: tabController.index == 1
                              ? AppTheme.slateColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            UrduAwareText(
                              isUrdu ? 'ٹولز اور ہسٹری' : 'Tools & History',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: tabController.index == 1
                                    ? Colors.white
                                    : AppTheme.darkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    "${Formatters.formatAmountWithCurrency(amount)}",
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

  Future<void> _onSettlement(
    BuildContext context,
    String transactionType,
    double outstandingAmount,
  ) async {
    final transaction = await Navigator.push<model.Transaction>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          account: party,
          initialAmount: outstandingAmount > 0.01 ? outstandingAmount : null,
          fixedTransactionType: transactionType,
          mode: AddTransactionMode.partySettlement,
        ),
      ),
    );

    if (!context.mounted || transaction == null) return;
    onRefresh();
    await ReceiptDialogHelper.showReceiptDialog(
      context,
      transaction: transaction,
      account: party,
    );
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
        .where((t) => t.accountId == widget.party.id)
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
              backgroundColor: AppTheme.slateColor,
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
                widget.isUrdu ? 'دیا / بنام' : 'Debit',
                PhosphorIcons.arrowUpRight(),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _labelWithIcon(
                widget.isUrdu ? 'لیا / جمع' : 'Credit',
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
        .where((t) => t.accountId == widget.party.id)
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
    double cycleCredit = 0, cycleDebit = 0;
    double cycleBalance = openingBalance;
    DateTime? cycleStart;

    for (var tx in chronological) {
      cycleStart ??= tx.date;
      currentCycleTxs.add(tx);
      final columns = AccountBalanceUtils.transactionColumns(tx);
      cycleDebit += columns.debit;
      cycleCredit += columns.credit;
      cycleBalance += columns.debit - columns.credit;

      if (cycleBalance.abs() < 0.01) {
        cycles.add({
          'id': tx.id,
          'transactions': List<model.Transaction>.from(currentCycleTxs),
          'isSettled': true,
          'totalCredit': cycleCredit,
          'totalDebit': cycleDebit,
          'startDate': cycleStart,
          'endDate': tx.date,
          'days': tx.date.difference(cycleStart).inDays,
        });
        currentCycleTxs.clear();
        cycleCredit = 0;
        cycleDebit = 0;
        cycleBalance = 0;
        cycleStart = null;
      }
    }
    if (currentCycleTxs.isNotEmpty) {
      cycles.add({
        'id': 'active',
        'transactions': List<model.Transaction>.from(currentCycleTxs),
        'isSettled': false,
        'totalCredit': cycleCredit,
        'totalDebit': cycleDebit,
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

  Future<void> _editSettlementNote(
    String cycleId,
    Account party,
    String currentNote,
  ) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    try {
      final note = await showDialog<String>(
        context: context,
        builder: (_) => _SettlementNoteEditorDialog(
          initialNote: currentNote,
          isUrdu: isUrdu,
          fontFamily: fontFamily,
        ),
      );

      if (note == null || !mounted) return;

      final settlementNotes =
          Map<String, String>.from(party.settlementNotes ?? const {});
      if (note.isEmpty) {
        settlementNotes.remove(cycleId);
      } else {
        settlementNotes[cycleId] = note;
      }

      final updatedParty = party.copyWith(settlementNotes: settlementNotes);
      await Provider.of<DatabaseService>(context, listen: false)
          .updateAccount(updatedParty);
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      debugPrint('Failed to save settlement note: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'نوٹ محفوظ نہیں ہو سکا' : 'Could not save note',
        );
      }
    }
  }

  Widget _buildSettlementCard(Map<String, dynamic> data, bool expanded) {
    final df = DateFormat('dd MMM yyyy');
    final start = df.format(data['startDate']);
    final end = df.format(data['endDate']);
    final days = data['days'];
    final id = data['id'] as String;
    final totalCredit = (data['totalCredit'] as num?)?.toDouble() ?? 0;
    final totalDebit = (data['totalDebit'] as num?)?.toDouble() ?? 0;
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final currentParty =
        databaseService.getAccount(widget.party.id) ?? widget.party;
    final settlementNote = currentParty.settlementNotes?[id]?.trim() ?? '';

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
      onLongPress: widget.isReadOnly
          ? null
          : () => _editSettlementNote(id, currentParty, settlementNote),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.themeColor.withValues(alpha: expanded ? 0.12 : 0.06),
              AppTheme.themeColor.withValues(alpha: expanded ? 0.06 : 0.03),
            ],
          ),
          borderRadius: BorderRadius.zero,
          border: Border(
            top: BorderSide(
              color:
                  AppTheme.themeColor.withValues(alpha: expanded ? 0.35 : 0.2),
              width: 1.5,
            ),
            bottom: BorderSide(
              color:
                  AppTheme.themeColor.withValues(alpha: expanded ? 0.35 : 0.2),
              width: 1.5,
            ),
          ),
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
                Expanded(
                  child: UrduAwareText(
                    settlementNote.isEmpty
                        ? (widget.isUrdu ? "حساب برابر" : "Balanced")
                        : settlementNote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: widget.fontFamily,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ),
                // Edit button and days count removed from header
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
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: UrduAwareText(
                      "$start → $end  ($days ${widget.isUrdu ? 'دن' : 'days'})",
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (totalDebit > 0)
                        UrduAwareText(
                          '${widget.isUrdu ? "بنام:" : "Debit:"} ${Formatters.formatAmountWithCurrency(totalDebit)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.expenseColor,
                          ),
                        ),
                      if (totalDebit > 0 && totalCredit > 0)
                        const SizedBox(width: 10),
                      if (totalCredit > 0)
                        UrduAwareText(
                          '${widget.isUrdu ? "جمع:" : "Credit:"} ${Formatters.formatAmountWithCurrency(totalCredit)}',
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
                      fontWeight: FontWeight.normal,
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
                        if (!t.isWorkerPayrollTransaction &&
                            t.referenceNumber != null &&
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
                          "${Formatters.formatAmount(runningBalance.abs())}",
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
                  columns.debit > 0
                      ? Formatters.formatAmount(columns.debit)
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
                  columns.credit > 0
                      ? Formatters.formatAmount(columns.credit)
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

    final tradeTransactions =
        allTx.where((transaction) => !transaction.isWorkerPayrollTransaction);
    for (var tx in tradeTransactions) {
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
    _totalDeals = tradeTransactions.length;
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
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
        child: Column(
          children: [
            PartyToolsGridWidget(
              party: widget.party,
              isUrdu: widget.isUrdu,
              fontFamily: widget.fontFamily,
              onRefresh: _loadData,
            ),
            const SizedBox(height: 8),
            _build3Stats(),
            const SizedBox(height: 8),
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
    return Column(
      children: [
        _fullWidthStatCard(
          _getRelationshipPeriod(),
          widget.isUrdu ? 'تعلق کے دن/دورانیہ' : 'Relationship Duration',
          PhosphorIcons.calendar(),
        ),
        const SizedBox(height: 8),
        _fullWidthStatCard(
          _formatVolume(_totalVolume),
          widget.isUrdu ? 'کل کاروبار کا حجم' : 'Total Business Volume',
          PhosphorIcons.chartBar(),
        ),
      ],
    );
  }

  Widget _fullWidthStatCard(String value, String label, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AppTheme.themeColor,
                ),
              ),
              const SizedBox(width: 12),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontFamily: widget.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          UrduAwareText(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
            ),
          ),
        ],
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

class _SettlementNoteEditorDialog extends StatefulWidget {
  final String initialNote;
  final bool isUrdu;
  final String? fontFamily;

  const _SettlementNoteEditorDialog({
    required this.initialNote,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  State<_SettlementNoteEditorDialog> createState() =>
      _SettlementNoteEditorDialogState();
}

class _SettlementNoteEditorDialogState
    extends State<_SettlementNoteEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: UrduAwareText(
        widget.isUrdu ? 'لین دین کا نوٹ' : 'Transaction note',
        style: TextStyle(fontFamily: widget.fontFamily),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        style: TextStyle(fontFamily: widget.fontFamily),
        decoration: InputDecoration(
          hintText: widget.isUrdu
              ? 'یہ لین دین کس کام کے لیے تھا؟'
              : 'What was this transaction for?',
          hintStyle: TextStyle(fontFamily: widget.fontFamily),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: UrduAwareText(widget.isUrdu ? 'منسوخ' : 'Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: UrduAwareText(widget.isUrdu ? 'محفوظ کریں' : 'Save'),
        ),
      ],
    );
  }
}
