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
import 'package:account_app/features/accounts/sms_invitation_screen.dart';
import 'main_navigation_screen.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/simple_spinning_ring.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainNavigationScreen.of(context)?.openDrawer(),
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
                  SimpleSpinningRing(size: 60, duration: Duration(seconds: 2)))
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
                  final liveBalance = party.balance;
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
    final balanceLabel = isUrdu
        ? (netBalance >= 0 ? 'باقی دینے' : 'باقی لینے')
        : (netBalance >= 0 ? 'Net Payable' : 'Net Receivable');

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
          _buildHeaderStatItem(isUrdu ? 'لینے ہیں' : 'To Receive', receivable,
              Colors.white70, fontFamily, PhosphorIcons.arrowDownLeft()),
          _buildStatDivider(),
          _buildHeaderStatItem(isUrdu ? 'دینے ہیں' : 'To Pay', payable,
              Colors.white70, fontFamily, PhosphorIcons.arrowUpRight()),
          _buildStatDivider(),
          _buildHeaderStatItem(balanceLabel, netBalance.abs(), Colors.white70,
              fontFamily, PhosphorIcons.wallet(),
              isBold: true),
        ],
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, double amount, Color iconColor,
      String fontFamily, IconData icon,
      {bool isBold = false}) {
    return Expanded(
      child: Column(
        children: [
          UrduAwareText(
            label,
            style: TextStyle(
                color: Colors.white70, fontSize: 11, fontFamily: fontFamily),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: UrduAwareText(
                    "Rs ${amount.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isBold ? 16 : 14,
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

  Widget _buildStatDivider() {
    return Container(height: 20, width: 1, color: Colors.white12);
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

    // Define scrolling headers
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

    if (filteredParties.isEmpty && headers.isEmpty) {
      return ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(PhosphorIcons.users(),
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  UrduAwareText(
                    isUrdu ? 'کوئی پارٹی نہیں ملی' : 'No Parties Found',
                    style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: headers.length +
          filteredParties.length +
          (filteredParties.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Render headers first
        if (index < headers.length) {
          return headers[index];
        }

        // Render empty state if no parties after headers
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

        if (partyIndex >= filteredParties.length)
          return const SizedBox.shrink();

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
          key: ValueKey(
              party.id), // یونیک کی شامل کر دی گئی تاکہ اسٹیٹ مکس نہ ہو
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
