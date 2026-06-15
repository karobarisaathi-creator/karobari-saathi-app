import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/services/version_check_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/services/alert_service.dart'; // Import AlertService
import 'package:account_app/core/models/account_model.dart';
// Screens
import 'package:account_app/features/settings/settings_screen.dart';
import 'package:account_app/features/notifications/notifications_screen.dart';
import 'package:account_app/features/accounts/sms_invitation_screen.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/features/accounts/add_party_screen.dart'; // Import AddPartyScreen
import 'main_navigation_screen.dart'; // Import MainNavigationScreen
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
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
  String _searchQuery = "";
  List<AlertAnalysis> _dashboardAlerts = [];
  Map<String, dynamic>? _updateData;

  @override
  void initState() {
    super.initState();
    // Ensure database is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      
      // Check for app updates
      _checkVersion();

      if (!dbService.isInitialized) {
        setState(() => _isLoading = true);
        dbService.init().then((_) {
          if (mounted) {
            _loadAlerts(); // Load alerts after init
            setState(() => _isLoading = false);
          }
        }).catchError((e) {
          if (mounted) setState(() => _isLoading = false);
        });
      } else {
        _loadAlerts(); // Load alerts if already initialized
      }
    });
  }

  void _checkVersion() async {
    final data = await VersionCheckService().getUpdateData();
    if (mounted) {
      setState(() {
        _updateData = data;
      });
    }
  }

  void _loadAlerts() {
    // بوجھ کم کرنے کے لیے الرٹس کو فیوچر میں منتقل کر دیا گیا ہے
    Future.microtask(() {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final professions = dbService.getProfessions();
      final transactions = dbService.getAllTransactions();
      List<AlertAnalysis> professionAlerts = [];

      for (var prof in professions) {
        final profTransactions = transactions.where((t) => t.professionId == prof.id).toList();
        final previousSeasons = professions.where((p) => p.name == prof.name && p.id != prof.id).toList();

        final analysis = AlertService.analyzeProfessionAlerts(
          prof,
          profTransactions,
          previousSeasons: previousSeasons,
        );

        if (analysis.hasAlerts) {
          professionAlerts.add(analysis);
        }
      }
      
      // Sort alerts by risk level
      professionAlerts.sort((a, b) => b.riskLevel.index.compareTo(a.riskLevel.index));

      if (mounted) {
        setState(() {
          _dashboardAlerts = professionAlerts;
        });
      }
    });
  }


  Future<void> _refreshData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.fetchFromFirebase();
    _loadAlerts(); // Reload alerts on refresh
  }


  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.themeColor, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final authService = Provider.of<AuthService>(context); // Listen to auth changes
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final user = FirebaseAuth.instance.currentUser;
    final dbService = Provider.of<DatabaseService>(context);
    
    // Get updated photo URL from user (after reload)
    final profilePhoto = user?.photoURL;

    final myAccount = dbService.getAccounts().firstWhere(
      (a) => a.phone == (user?.phoneNumber ?? ''),
      orElse: () => Account(
        id: 'me',
        name: user?.displayName ?? (isUrdu ? 'میرا پروفائل' : 'My Profile'),
        phone: user?.phoneNumber ?? '',
        profileImage: profilePhoto, // Use refreshed photo
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

    // If account exists but profile image is old, use the one from FirebaseAuth
    final String? effectivePhoto = (myAccount.id != 'me' && myAccount.profileImage != null) 
        ? myAccount.profileImage 
        : profilePhoto;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        backgroundColor: AppTheme.darkColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
        showBackButton: false,
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GestureDetector(
            onTap: () {
              MainNavigationScreen.of(context)?.onItemTapped(4);
            },
            child: Center(
              child: FittedBox(
                child: ProfileInfoWidget(
                  name: '', 
                  phone: myAccount.phone,
                  profileImage: effectivePhoto,
                  isLarge: false,
                  showText: false, 
                  textColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
        actions: [
          Consumer<NotificationService>(
            builder: (context, notificationService, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(PhosphorIcons.bell()),
                    tooltip: isUrdu ? 'نوٹیفیکیشنز' : 'Notifications',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NotificationsScreen()),
                      );
                    },
                  ),
                  if (notificationService.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          notificationService.unreadCount > 99
                              ? '99+'
                              : notificationService.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SimpleSpinningRing(
                size: 60,
                duration: Duration(seconds: 2),
              ),
            )
          : Consumer<DatabaseService>(
        builder: (context, databaseService, child) {
          final allAccounts = databaseService.getAccounts();
          final parties = allAccounts.where((p) => p.isActive && p.category != 'Partner').toList();
          final professions = databaseService.getProfessions();

          // Calculate Totals from Transactions for Parties (Sum of Taken/Given)
          double totalTaken = 0;
          double totalGiven = 0;

          final partyTransactions = databaseService.getAllTransactions().where((t) {
             // 1. Exclude partnership transactions
             if (t.partnershipId != null) return false;

             final account = databaseService.getAccount(t.accountId);
             if (account == null) return false;

             // Filter by account criteria
             if (!account.isActive) return false;
             if (account.category == 'Shared') return false;
             if (account.category == 'Partner') return false;

             return true;
          }).toList();

          for (var t in partyTransactions) {
             if (t.type == 'income') {
                totalTaken += t.amount;
             } else {
                totalGiven += t.amount; // expense
             }
          }
          double netBalance = totalTaken - totalGiven;
          final bool isPayable = netBalance >= 0;
          final Color balanceCardColor = AppTheme.darkColor;
          final Color balanceTextColor = Colors.white;

          double profIncome = 0;
          double profExpense = 0;
          for (var p in professions) {
            if (p.isActive) {
              profIncome += p.totalIncome;
              profExpense += p.totalExpense;
            }
          }
          double profProfit = profIncome - profExpense;

          return Column(
            children: [
              // Fixed Header Section (Balance Card + Search Bar)
              Container(
                color: AppTheme.lightColor,
                child: Column(
                  children: [
                    Card(
                      elevation: 0,
                      color: balanceCardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(color: AppTheme.darkColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildBalanceItem(
                                    title: isUrdu ? 'کل جمع' : 'Total In',
                                    amount: totalTaken,
                                    color: Colors.white,
                                    valueColor: Colors.white,
                                    icon: PhosphorIcons.arrowDownLeft(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                  ),
                                ),
                                Expanded(
                                  child: _buildBalanceItem(
                                    title: isUrdu ? 'کل بنام' : 'Total Out',
                                    amount: totalGiven,
                                    color: Colors.white,
                                    valueColor: Colors.white,
                                    icon: PhosphorIcons.arrowUpRight(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                  ),
                                ),
                                Expanded(
                                  child: _buildBalanceItem(
                                    title: isUrdu 
                                        ? (netBalance >= 0 ? 'کل بنام' : 'کل جمع')
                                        : (netBalance >= 0 ? 'Total Debit' : 'Total Credit'),
                                    amount: netBalance.abs(),
                                    color: Colors.white,
                                    valueColor: Colors.white,
                                    icon: PhosphorIcons.wallet(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1, thickness: 0.5, color: Colors.white10),

                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildBalanceItem(
                                    title: isUrdu ? 'پیشہ آمدن' : 'Prof. Income',
                                    amount: profIncome,
                                    color: Colors.white,
                                    valueColor: Colors.white,
                                    icon: PhosphorIcons.arrowDownLeft(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                  ),
                                ),
                                Expanded(
                                  child: _buildBalanceItem(
                                    title: isUrdu ? 'پیشہ خرچ' : 'Prof. Expense',
                                    amount: profExpense,
                                    color: Colors.white,
                                    valueColor: Colors.white,
                                    icon: PhosphorIcons.arrowUpRight(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                  ),
                                ),
                                Expanded(
                                  child: _buildBalanceItem(
                                    title: isUrdu ? 'پیشہ منافع' : 'Prof. Profit',
                                    amount: profProfit,
                                    color: Colors.white,
                                    valueColor: Colors.white,
                                    icon: PhosphorIcons.trendUp(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SearchSortBar(
                        hintText: isUrdu ? 'پارٹی تلاش کریں...' : 'Search Party...',
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
                    ),
                  ],
                ),
              ),

              // Scrollable Party List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: Colors.white,
                  backgroundColor: AppTheme.themeColor,
                  child: Builder(
                    builder: (context) {
                      final filteredParties = parties.where((p) {
                        return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                               p.phone.contains(_searchQuery);
                      }).toList();

                      // Sort parties by name
                      filteredParties.sort((a, b) => _isAscending 
                          ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
                          : b.name.toLowerCase().compareTo(a.name.toLowerCase()));

                      if (filteredParties.isEmpty) {
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
                        itemCount: filteredParties.length,
                        itemBuilder: (context, index) {
                          final party = filteredParties[index];
                          
                          // Calculate live balance for this party
                          final partyTransactions = databaseService.getAllTransactions()
                              .where((t) => t.accountId == party.id && t.partnershipId == null)
                              .toList();
                          
                          double totalTaken = 0;
                          double totalGiven = 0;
                          for (var t in partyTransactions) {
                            if (t.type == 'income') {
                              totalTaken += t.amount;
                            } else {
                              totalGiven += t.amount;
                            }
                          }
                          final liveBalance = totalTaken - totalGiven;
                          final updatedParty = party.copyWith(balance: liveBalance);

                          return PartyCard(
                            party: updatedParty,
                            onView: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PartyDetailScreen(party: updatedParty),
                                ),
                              );
                            },
                            onMessage: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BalanceAlertScreen(party: updatedParty),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
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

  Widget _buildBalanceItem({
    required String title,
    required double amount,
    required Color color,
    required Color valueColor,
    required IconData icon,
    required String fontFamily,
    required bool isUrdu
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: valueColor, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: isUrdu ? 15 : 12,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Rs ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: valueColor,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
              fontFamily: ''
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardButton(
      BuildContext context,
      IconData icon,
      String title,
      String fontFamily,
      bool isUrdu,
      Widget screen, {
        int? count,
      }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Card(
        elevation: 2,
        color: AppTheme.themeColor, // Theme Color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(4.0), // Reduced padding to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (count != null)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: AppTheme.darkColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                const SizedBox(height: 10),

              Icon(icon, size: 24, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, // Reduced font size from 12
                  fontFamily: fontFamily,
                  color: Colors.white,
                  fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerBox({required this.width, required this.height});

  @override
  _ShimmerBoxState createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.themeColor, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class InfoTickerWidget extends StatefulWidget {
  @override
  _InfoTickerWidgetState createState() => _InfoTickerWidgetState();
}

class _InfoTickerWidgetState extends State<InfoTickerWidget> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);
    final databaseService = Provider.of<DatabaseService>(context);
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    List<Widget> items = [];

    // 1. Notifications Content
    if (notificationService.notifications.isNotEmpty) {
        // Show top 3 recent unread or read notifications
        for (var i = 0; i < 3 && i < notificationService.notifications.length; i++) {
            final notif = notificationService.notifications[i];
            items.add(_buildInfoCard(
              isUrdu ? 'نوٹیفیکیشن' : 'Notification',
              notif.message, // Showing message instead of count
              PhosphorIcons.bell(),
              Colors.orangeAccent,
              fontFamily
            ));
        }
    } else {
        // If no notifications, show general message
        items.add(_buildInfoCard(
          isUrdu ? 'نوٹیفیکیشنز' : 'Notifications',
          isUrdu ? 'کوئی نیا نوٹیفیکیشن نہیں' : 'No new notifications',
          PhosphorIcons.bell(),
          Colors.white70,
          fontFamily // Applied Urdu font to the message text
        ));
    }

    // 2. Top Receivable
    final parties = databaseService.getAccounts();
    final receivables = parties.where((p) => p.balance > 0).toList();
    receivables.sort((a, b) => b.balance.compareTo(a.balance));

    if (receivables.isNotEmpty) {
       final topReceiver = receivables.first;
       items.add(_buildInfoCard(
         isUrdu ? 'جمع (${topReceiver.name})' : 'Credit (${topReceiver.name})',
         'Rs ${topReceiver.balance.toStringAsFixed(0)}',
         PhosphorIcons.arrowDownLeft(),
         Colors.greenAccent,
         fontFamily
       ));
    }

    // 3. Top Payable
    final payables = parties.where((p) => p.balance < 0).toList();
    payables.sort((a, b) => a.balance.compareTo(b.balance));

    if (payables.isNotEmpty) {
       final topPayer = payables.first;
       items.add(_buildInfoCard(
         isUrdu ? 'بنام (${topPayer.name})' : 'Debit (${topPayer.name})',
         'Rs ${topPayer.balance.abs().toStringAsFixed(0)}',
         PhosphorIcons.arrowUpRight(),
         const Color(0xFFDAAD51), // Gold
         fontFamily
       ));
    }

    final index = items.isEmpty ? 0 : _currentIndex % items.length;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: items.isNotEmpty ? items[index] : Container(),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color iconColor, String fontFamily) {
    bool isNumeric = value.startsWith('Rs') || double.tryParse(value) != null;
    String valueFont = isNumeric ? '' : fontFamily;
    final isUrdu = fontFamily == 'NooriNastaleeq';

    return Card(
      elevation: 2,
      color: AppTheme.themeColor, // Theme Color
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(title,
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: fontFamily,
                      fontSize: 16,
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontFamily: valueFont,
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                fontSize: 14
              ), // Applied font
              textAlign: TextAlign.center,
              maxLines: 2, // Allow 2 lines for message
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
