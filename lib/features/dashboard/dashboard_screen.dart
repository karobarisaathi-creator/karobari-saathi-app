import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/version_check_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/services/alert_service.dart'; 
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
// Screens
import 'package:account_app/features/notifications/notifications_screen.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/features/accounts/add_party_screen.dart'; 
import 'package:account_app/features/accounts/party_history_screen.dart';
import 'package:account_app/features/accounts/sms_invitation_screen.dart';
import 'package:account_app/features/artisans/artisan_detail_screen.dart';
import 'package:account_app/features/artisans/artisan_work_orders_screen.dart';
import 'package:account_app/features/business_chat/business_chat_list_screen.dart';
import 'main_navigation_screen.dart'; 
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/simple_spinning_ring.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;
  bool _isAscending = true;
  bool _isSearchVisible = false; // سرچ بار کو کنٹرول کرنے کے لیے
  String _searchQuery = "";
  Map<String, dynamic>? _updateData;
  StreamSubscription<ArtisanProfile?>? _artisanSub;
  ArtisanProfile? _myArtisanProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      _checkVersion();
      _setupArtisanListener();

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

  @override
  void dispose() {
    _artisanSub?.cancel();
    super.dispose();
  }

  void _setupArtisanListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _artisanSub = dbService.streamArtisanProfile(user.uid).listen((profile) {
      if (mounted) {
        setState(() {
          _myArtisanProfile = profile;
        });
      }
    });
  }

  Future<void> _toggleAvailability() async {
    if (_myArtisanProfile == null) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final newStatus = _myArtisanProfile!.availability == 'available' ? 'busy' : 'available';
    
    final updatedProfile = _myArtisanProfile!.copyWith(
      availability: newStatus,
      updatedAt: DateTime.now(),
    );

    try {
      await dbService.saveArtisanProfile(updatedProfile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _checkVersion() async {
    final data = await VersionCheckService().getUpdateData();
    if (mounted) {
      setState(() {
        _updateData = data;
      });
    }
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
    final user = FirebaseAuth.instance.currentUser;
    final dbService = Provider.of<DatabaseService>(context);
    
    final profilePhoto = user?.photoURL;
    final myAccount = dbService.getAccounts().firstWhere(
      (a) => a.phone == (user?.phoneNumber ?? ''),
      orElse: () => Account(
        id: 'me',
        name: user?.displayName ?? (isUrdu ? 'میرا پروفائل' : 'My Profile'),
        phone: user?.phoneNumber ?? '',
        profileImage: profilePhoto,
        category: isUrdu ? 'دکاندار' : 'Shopkeeper',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        initialBalance: 0,
        balanceType: 'credit',
        balance: 0,
        isShared: false,
        isActive: true,
      ),
    );

    final String? effectivePhoto = (myAccount.id != 'me' && myAccount.profileImage != null) 
        ? myAccount.profileImage 
        : profilePhoto;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
          style: TextStyle(
            color: Colors.white,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: const SizedBox.shrink(), // Remove the menu icon
        actions: [
          if (_myArtisanProfile != null)
            _buildAvailabilityToggle(isUrdu, fontFamily),
          _buildNotificationAction(),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: SimpleSpinningRing(size: 60, duration: Duration(seconds: 2)))
          : Consumer<DatabaseService>(
        builder: (context, databaseService, child) {
          final allAccounts = databaseService.getAccounts();
          final parties = allAccounts.where((p) => p.isActive && p.category != 'Partner').toList();
          final professions = databaseService.getProfessions();
          
          double totalReceivable = 0; 
          double totalPayable = 0;    

          for (var party in parties) {
            final partyTransactions = databaseService.getAllTransactions()
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
            if (liveBalance > 0) {
              totalPayable += liveBalance;
            } else if (liveBalance < 0) {
              totalReceivable += liveBalance.abs();
            }
          }

          double netBalance = totalPayable - totalReceivable;

          // --- Professions Logic ---
          final activeProfessions = professions.where((p) => p.isActive).toList();
          double profIncome = 0;
          double profExpense = 0;
          for (var p in activeProfessions) {
            profIncome += p.totalIncome;
            profExpense += p.totalExpense;
          }
          double profProfit = profIncome - profExpense;

          return Column(
            children: [
              _buildLargeDarkHeader(
                myAccount: myAccount,
                photo: effectivePhoto,
                receivable: totalReceivable,
                payable: totalPayable,
                netBalance: netBalance,
                profIncome: profIncome,
                profExpense: profExpense,
                profProfit: profProfit,
                showProfessions: activeProfessions.isNotEmpty, // اگر کوئی پیشہ ہے تو دکھائیں
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),

              Expanded(
                child: Container(
                  color: AppTheme.scaffoldBackground,
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: Colors.white,
                    backgroundColor: AppTheme.themeColor,
                    child: _buildPartyList(parties, databaseService, isUrdu, fontFamily),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPartyScreen()),
          );
        },
        backgroundColor: AppTheme.darkColor,
        shape: const CircleBorder(),
        child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildLargeDarkHeader({
    required Account myAccount,
    required String? photo,
    required double receivable,
    required double payable,
    required double netBalance,
    required double profIncome,
    required double profExpense,
    required double profProfit,
    required bool showProfessions,
    required bool isUrdu,
    required String fontFamily,
  }) {
    final balanceLabel = isUrdu 
        ? (netBalance >= 0 ? 'باقی دینے' : 'باقی لینے')
        : (netBalance >= 0 ? 'Net Payable' : 'Net Receivable');

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 55,
        bottom: 10, // فاصلہ کم کر دیا گیا
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          ProfileInfoWidget(
            name: myAccount.name,
            phone: '', 
            profileImage: photo,
            category: (_myArtisanProfile != null && _myArtisanProfile!.professionUrdu.isNotEmpty) 
                ? _myArtisanProfile!.professionUrdu 
                : (isUrdu ? 'پرسنل اکاؤنٹ' : 'Personal Account'),
            address: (_myArtisanProfile != null && _myArtisanProfile!.location.isNotEmpty)
                ? _myArtisanProfile!.location
                : (myAccount.address?.isNotEmpty == true ? myAccount.address : null),
            isLarge: true,
            isVerticalCategory: true,
            textColor: Colors.white,
            subtitleColor: Colors.white70,
            categoryColor: Colors.white,
            customSize: 55,
            borderRadius: 8,
            isVerified: myAccount.isVerified || (_myArtisanProfile?.isVerified ?? false),
          ),
          const SizedBox(height: 16),
          // Party Stats
          Row(
            children: [
              _buildHeaderStatItem(isUrdu ? 'لینے ہیں' : 'To Receive', receivable, AppTheme.incomeColor, fontFamily, PhosphorIcons.arrowDownLeft()),
              _buildStatDivider(),
              _buildHeaderStatItem(isUrdu ? 'دینے ہیں' : 'To Pay', payable, AppTheme.expenseColor, fontFamily, PhosphorIcons.arrowUpRight()),
              _buildStatDivider(),
              _buildHeaderStatItem(balanceLabel, netBalance.abs(), Colors.white, fontFamily, PhosphorIcons.wallet(), isBold: true),
            ],
          ),
          if (showProfessions) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, thickness: 0.5, color: Colors.white10),
            ),
            // Profession Stats
            Row(
              children: [
                _buildHeaderStatItem(isUrdu ? 'پیشہ آمدن' : 'Prof. Income', profIncome, AppTheme.incomeColor, fontFamily, PhosphorIcons.arrowDownLeft()),
                _buildStatDivider(),
                _buildHeaderStatItem(isUrdu ? 'پیشہ خرچ' : 'Prof. Expense', profExpense, AppTheme.expenseColor, fontFamily, PhosphorIcons.arrowUpRight()),
                _buildStatDivider(),
                _buildHeaderStatItem(isUrdu ? 'پیشہ منافع' : 'Prof. Profit', profProfit.abs(), Colors.white, fontFamily, PhosphorIcons.trendUp(), isBold: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, double amount, Color iconColor, String fontFamily, IconData icon, {bool isBold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: fontFamily),
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
                  child: Text(
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

  Widget _buildBusinessCommandCenter(bool isUrdu, String fontFamily) {
    return Container(
      height: 55, 
      margin: const EdgeInsets.only(top: 4), // فاصلہ مزید کم کر دیا گیا
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 0. Search Toggle Button
          _buildCommandCard(
            label: isUrdu ? 'تلاش کریں' : 'Search',
            icon: PhosphorIcons.magnifyingGlass(),
            color: _isSearchVisible ? AppTheme.themeColor : Colors.grey,
            onTap: () => setState(() => _isSearchVisible = !_isSearchVisible),
            fontFamily: fontFamily,
          ),

          // 1. Public Profile Preview
          _buildCommandCard(
            label: isUrdu ? 'پروفائل' : 'Profile',
            icon: PhosphorIcons.userFocus(),
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtisanDetailScreen(
                    artisanId: _myArtisanProfile!.id,
                    initialArtisan: _myArtisanProfile,
                  ),
                ),
              );
            },
            fontFamily: fontFamily,
          ),
          
          // 2. Active Orders
          _buildCommandCard(
            label: isUrdu ? 'آرڈرز' : 'Orders',
            icon: PhosphorIcons.briefcase(),
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtisanWorkOrdersScreen(artisanId: _myArtisanProfile!.id),
                ),
              );
            },
            fontFamily: fontFamily,
          ),

          // 3. Chat List
          _buildCommandCard(
            label: isUrdu ? 'چیٹ لسٹ' : 'Chat List',
            icon: PhosphorIcons.chatCircleDots(),
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BusinessChatListScreen()),
              );
            },
            fontFamily: fontFamily,
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String fontFamily,
  }) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // سائز بڑا کر دیا گیا
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18), // آئی کن بڑا کر دیا گیا
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.darkColor,
                  fontSize: 12, // فونٹ تھوڑا بڑا
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle(bool isUrdu, String fontFamily) {
    final isAvailable = _myArtisanProfile?.availability == 'available';
    final color = isAvailable ? Colors.greenAccent : AppTheme.expenseColor;
    final label = isAvailable 
        ? (isUrdu ? 'دستیاب' : 'Available') 
        : (isUrdu ? 'مصروف' : 'Busy');

    return Center(
      child: InkWell(
        onTap: _toggleAvailability,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.5), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
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
    );
  }

  Widget _buildNotificationAction() {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen()));
              },
            ),
            if (notificationService.unreadCount > 0)
              Positioned(
                right: 8,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.expenseColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.darkColor, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    notificationService.unreadCount > 99 ? '99+' : notificationService.unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPartyList(List<Account> parties, DatabaseService databaseService, bool isUrdu, String fontFamily) {
    final filteredParties = parties.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             p.phone.contains(_searchQuery);
    }).toList();

    filteredParties.sort((a, b) => _isAscending 
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.name.toLowerCase().compareTo(a.name.toLowerCase()));

    // Define scrolling headers
    final List<Widget> headers = [];
    if (_myArtisanProfile != null) {
      headers.add(_buildBusinessCommandCenter(isUrdu, fontFamily));
    }
    if (_isSearchVisible) {
      headers.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SearchSortBar(
            hintText: isUrdu ? 'پارٹی تلاش کریں...' : 'Search Party...',
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            onSortToggled: () => setState(() => _isAscending = !_isAscending),
            isAscending: _isAscending,
          ),
        ),
      );
    }

    if (filteredParties.isEmpty && headers.isEmpty) {
      return ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(PhosphorIcons.users(), size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    isUrdu ? 'کوئی پارٹی نہیں ملی' : 'No Parties Found',
                    style: TextStyle(fontSize: 18, color: AppTheme.darkColor, fontFamily: fontFamily),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 80),
      itemCount: headers.length + filteredParties.length + (filteredParties.isEmpty ? 1 : 0),
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
                  Icon(PhosphorIcons.users(), size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    isUrdu ? 'کوئی پارٹی نہیں ملی' : 'No Parties Found',
                    style: TextStyle(fontSize: 16, color: AppTheme.darkColor, fontFamily: fontFamily),
                  ),
                ],
              ),
            ),
          );
        }

        if (partyIndex >= filteredParties.length) return const SizedBox.shrink();

        final party = filteredParties[partyIndex];
        
        final partyTransactions = databaseService.getAllTransactions()
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
          key: ValueKey(party.id), // یونیک کی شامل کر دی گئی تاکہ اسٹیٹ مکس نہ ہو
          party: updatedParty,
          onView: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PartyDetailScreen(party: updatedParty)),
            );
          },
          onMessage: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BalanceAlertScreen(party: updatedParty)),
            );
          },
        );
      },
    );
  }
}
