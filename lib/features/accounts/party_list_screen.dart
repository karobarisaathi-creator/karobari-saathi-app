import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/simple_spinning_ring.dart';
import 'package:account_app/features/accounts/sms_invitation_screen.dart';

class PartyListScreen extends StatefulWidget {
  const PartyListScreen({super.key});

  @override
  State<PartyListScreen> createState() => _PartyListScreenState();
}

class _PartyListScreenState extends State<PartyListScreen> {
  bool _isLoading = false;
  bool _isAscending = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      if (!dbService.isInitialized) {
        setState(() => _isLoading = true);
        dbService.init().then((_) {
          if (mounted) setState(() => _isLoading = false);
        }).catchError((e) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
    });
  }

  Future<void> _refreshData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.fetchFromFirebase();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: UrduAwareText(
          isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
          style: TextStyle(
            color: Colors.white,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon:
                Icon(PhosphorIcons.plusCircle(), color: Colors.white, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPartyScreen()),
              );
            },
            tooltip: isUrdu ? 'پارٹی شامل کریں' : 'Add Party',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  SimpleSpinningRing(size: 60, duration: Duration(seconds: 2)),
            )
          : Consumer<DatabaseService>(
              builder: (context, databaseService, child) {
                final allAccounts = databaseService.getAccounts();
                final parties = allAccounts
                    .where((p) =>
                        p.isActive &&
                        p.category != 'Partner' &&
                        p.id != QuickBillConstants.cashCustomerAccountId)
                    .toList();

                double totalReceivable = 0;
                double totalPayable = 0;

                for (var party in parties) {
                  final transactions = databaseService
                      .getAllTransactions()
                      .where((t) =>
                          t.accountId == party.id && t.partnershipId == null)
                      .toList();
                  final cycleBalance =
                      AccountBalanceUtils.currentCycle(transactions);
                  final liveBalance = cycleBalance.balance;

                  if (liveBalance > 0) {
                    totalPayable += liveBalance;
                  } else if (liveBalance < 0) {
                    totalReceivable += liveBalance.abs();
                  }
                }

                double netBalance = totalPayable - totalReceivable;

                return Column(
                  children: [
                    _buildLargeDarkHeader(
                      receivable: totalReceivable,
                      payable: totalPayable,
                      netBalance: netBalance,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                    Expanded(
                      child: Container(
                        color: AppTheme.backgroundColor,
                        child: RefreshIndicator(
                          onRefresh: _refreshData,
                          color: Colors.white,
                          backgroundColor: AppTheme.themeColor,
                          child: _buildPartyList(
                              parties, databaseService, isUrdu, fontFamily),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildLargeDarkHeader({
    required double receivable,
    required double payable,
    required double netBalance,
    required bool isUrdu,
    required String fontFamily,
  }) {
    final balanceLabel = netBalance == 0
        ? (isUrdu ? 'حساب برابر' : 'Balanced')
        : (netBalance > 0
            ? (isUrdu ? 'دینے ہیں' : 'To Pay')
            : (isUrdu ? 'لینے ہیں' : 'To Receive'));

    final balanceIcon = netBalance == 0
        ? PhosphorIcons.wallet()
        : (netBalance > 0
            ? PhosphorIcons.arrowUpRight()
            : PhosphorIcons.arrowDownLeft());

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      child: Row(
        children: [
          _buildHeaderStatItem(
            isUrdu ? 'کل بنام' : 'Total Banam',
            receivable,
            Colors.white70,
            PhosphorIcons.arrowDownLeft(),
            fontFamily,
          ),
          const SizedBox(width: 8),
          _buildHeaderStatItem(
            isUrdu ? 'کل جمع' : 'Total Jama',
            payable,
            Colors.white70,
            PhosphorIcons.arrowUpRight(),
            fontFamily,
          ),
          const SizedBox(width: 8),
          _buildHeaderStatItem(
            balanceLabel,
            netBalance.abs(),
            Colors.white70,
            balanceIcon,
            fontFamily,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, double amount, Color iconColor,
      IconData icon, String fontFamily,
      {bool isBold = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: UrduAwareText(
                "Rs ${Formatters.formatAmount(amount)}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isBold ? 15 : 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                  fontFamily: '',
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: UrduAwareText(
                    label,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyList(List<Account> parties, DatabaseService databaseService,
      bool isUrdu, String fontFamily) {
    final filteredParties = parties.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.phone.contains(_searchQuery);
    }).toList();

    filteredParties.sort((a, b) => _isAscending
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.name.toLowerCase().compareTo(a.name.toLowerCase()));

    final List<Widget> headers = [];
    headers.add(
      Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: SearchSortBar(
          hintText: isUrdu ? 'پارٹی تلاش کریں...' : 'Search Party...',
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          onSortToggled: () => setState(() => _isAscending = !_isAscending),
          isAscending: _isAscending,
        ),
      ),
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: headers.length +
          filteredParties.length +
          (filteredParties.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < headers.length) {
          return headers[index];
        }

        final partyIndex = index - headers.length;
        if (filteredParties.isEmpty && partyIndex == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(PhosphorIcons.users(),
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  UrduAwareText(
                    isUrdu ? 'کوئی پارٹی نہیں ملی' : 'No Parties Found',
                    style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily),
                  ),
                ],
              ),
            ),
          );
        }

        if (partyIndex >= filteredParties.length) {
          return const SizedBox.shrink();
        }

        final party = filteredParties[partyIndex];

        final partyTransactions = databaseService
            .getAllTransactions()
            .where((t) => t.accountId == party.id && t.partnershipId == null)
            .toList();

        double partyTaken = 0;
        double partyGiven = 0;
        for (var t in partyTransactions) {
          if (t.type == 'income') {
            partyTaken += t.amount;
          } else {
            partyGiven += t.amount;
          }
        }
        final liveBalance = partyTaken - partyGiven;
        final updatedParty = party.copyWith(balance: liveBalance);

        return PartyCard(
          key: ValueKey(party.id),
          party: updatedParty,
          onView: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PartyDetailScreen(party: updatedParty)),
            );
          },
          onMessage: () {
            BalanceAlertDialog.show(context, party: updatedParty);
          },
        );
      },
    );
  }
}
