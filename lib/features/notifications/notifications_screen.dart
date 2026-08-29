import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/services/database/job_negotiation_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/version_check_service.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/features/artisans/job_detail_screen.dart';
import 'package:account_app/features/artisans/widgets/negotiation_view.dart';
import 'package:account_app/features/artisans/widgets/work_order_list_item.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/notification_card.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  final int initialIndex;
  const NotificationsScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, dynamic>? _updateData;
  late TabController _tabController;
  int _activeIndex = 0;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    final service = Provider.of<NotificationService>(context, listen: false);
    _activeIndex = service.notificationsTabIndex;
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: _activeIndex);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeIndex = _tabController.index);
        Provider.of<NotificationService>(context, listen: false)
            .setNotificationsTabIndex(_tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllNotifications();
      _checkVersion();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    setState(() {
      _isKeyboardVisible = bottomInset > 0;
    });
  }

  void _checkVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDismissed = prefs.getInt('last_update_dismissed') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastDismissed < 24 * 60 * 60 * 1000) return;

    final data = await VersionCheckService().getUpdateData();
    if (mounted) setState(() => _updateData = data);
  }

  void _dismissUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_update_dismissed', DateTime.now().millisecondsSinceEpoch);
    setState(() => _updateData = null);
  }

  Future<void> _loadAllNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      await notificationService.loadFromCloud();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        final notifications = notificationService.notifications;
        final unreadNotifCount = notificationService.unreadCount;
        final unreadNegCount = notificationService.unreadNegotiationCount;

        // Sync local index with service index if they differ
        if (notificationService.notificationsTabIndex != _activeIndex) {
          _activeIndex = notificationService.notificationsTabIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_tabController.index != _activeIndex) {
              _tabController.animateTo(_activeIndex);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFE8EAF0),
          appBar: _isKeyboardVisible
              ? null
              : CustomAppBar(
                  title:
                      isUrdu ? 'اطلاعات اور بات چیت' : 'Notifications & Chats',
                  showBackButton: false,
                  centerTitle: true,
                  bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: TextStyle(
                        fontFamily: fontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    tabs: [
                      Tab(
                        child: _buildTabLabel(
                            isUrdu ? 'نوٹیفیکیشن' : 'Notifications',
                            unreadNotifCount,
                            isUrdu),
                      ),
                      Tab(
                        child: _buildTabLabel(
                            isUrdu ? 'بات چیت' : 'Negotiations',
                            unreadNegCount,
                            isUrdu),
                      ),
                    ],
                  ),
                ),
          body: Column(
            children: [
              if (_updateData != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildUpdateCard(isUrdu, fontFamily),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _NotificationListTab(
                      notifications: notifications,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      onRefresh: _loadAllNotifications,
                    ),
                    _NegotiationsTab(isUrdu: isUrdu, fontFamily: fontFamily),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabLabel(String label, int count, bool isUrdu) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(label),
        if (count > 0)
          Positioned(
            right: isUrdu ? null : -24,
            left: isUrdu ? -24 : null,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.incomeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: ''),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUpdateCard(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.themeColor, const Color(0xFF1E3A8A)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isUrdu ? 'نیا ورژن دستیاب ہے!' : 'New Version Available!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily)),
          const SizedBox(height: 8),
          Text(isUrdu ? _updateData!['message_ur'] : _updateData!['message_en'],
              style: TextStyle(
                  color: Colors.white70, fontSize: 12, fontFamily: fontFamily)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  final url = _updateData?['update_url'] ?? '';
                  if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url)))
                    await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                },
                child: Text(isUrdu ? 'اپ ڈیٹ' : 'Update',
                    style: const TextStyle(color: Colors.white)),
              ),
              TextButton(
                  onPressed: _dismissUpdate,
                  child: Text(isUrdu ? 'بند کریں' : 'Dismiss',
                      style: const TextStyle(color: Colors.white70))),
            ],
          )
        ],
      ),
    );
  }
}

class _NotificationListTab extends StatefulWidget {
  final List<AppNotification> notifications;
  final bool isUrdu;
  final String fontFamily;
  final RefreshCallback onRefresh;

  const _NotificationListTab(
      {required this.notifications,
      required this.isUrdu,
      required this.fontFamily,
      required this.onRefresh});

  @override
  State<_NotificationListTab> createState() => _NotificationListTabState();
}

class _NotificationListTabState extends State<_NotificationListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notificationService = Provider.of<NotificationService>(context);
    const hiddenTypes = {
      'artisan_request',
      'artisan_response',
      'negotiation_message',
      'quote_received',
      'bid_status',
      'new_bid',
    };
    final allNotifications = widget.notifications
        .where((n) => !hiddenTypes.contains(n.data?['type']))
        .toList();

    if (allNotifications.isEmpty)
      return Center(
          child: Text(
              widget.isUrdu ? 'کوئی نوٹیفیکیشن نہیں' : 'No notifications',
              style: TextStyle(
                  color: Colors.grey, fontFamily: widget.fontFamily)));

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: allNotifications.length,
        itemBuilder: (context, index) {
          final n = allNotifications[index];
          return NotificationCard(
            notification: n,
            isUrdu: widget.isUrdu,
            fontFamily: widget.fontFamily,
            onAddPressed: () => _addToLedger(n),
            onDeletePressed: () => notificationService.deleteNotification(n.id),
            onTap: () {
              if (!n.isRead) notificationService.markAsRead(n.id);
              _handleClick(n);
            },
          );
        },
      ),
    );
  }

  void _handleClick(AppNotification n) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final accountId = n.data?['accountId'];
    if (accountId != null) {
      final account = db.getAccount(accountId);
      if (account != null)
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PartyDetailScreen(party: account)));
    }
  }

  Future<void> _addToLedger(AppNotification n) async {
    final data = n.data;
    if (data == null) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final phone = data['senderPhone'] ?? '';
    if (phone.isEmpty) return;

    final accounts = await db.getAccounts();
    String normalize(String p) => p.replaceAll(RegExp(r'\D'), '').length >= 10
        ? p
            .replaceAll(RegExp(r'\D'), '')
            .substring(p.replaceAll(RegExp(r'\D'), '').length - 10)
        : p;

    final lookup = normalize(phone);
    Account? target;
    try {
      target = accounts.firstWhere((a) => normalize(a.phone) == lookup);
    } catch (_) {}

    if (target == null)
      _showCreateAccountDialog(n, phone, data['senderName'] ?? 'Unknown');
    else
      _processAddition(n, target);
  }

  void _processAddition(AppNotification n, Account account) async {
    final data = n.data!;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final type = data['transactionType'] == 'income' ? 'expense' : 'income';
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;

    List<TransactionItem> items = [];
    if (data['items'] != null && data['items'] is List) {
      for (var itemMap in (data['items'] as List)) {
        items.add(TransactionItem.fromMap(Map<String, dynamic>.from(itemMap)));
      }
    }

    final tx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: account.id,
      amount: amount,
      type: type,
      category: 'دیگر',
      description: data['description'] ?? '',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: items,
      pendingAmount: amount,
      isPending: true,
    );

    await db.addTransaction(tx);
    await db.recalculateAccountBalance(account.id);
    Provider.of<NotificationService>(context, listen: false)
        .updateNotificationData(n.id, {'isAdded': true});
    if (mounted)
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  PartyDetailScreen(party: db.getAccount(account.id)!)));
  }

  void _showCreateAccountDialog(AppNotification n, String phone, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isUrdu ? 'نیا اکاؤنٹ؟' : 'Create Account?'),
        content: Text(widget.isUrdu
            ? '$name کے لیے اکاؤنٹ بنائیں؟'
            : 'Create account for $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isUrdu ? 'کینسل' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = Provider.of<DatabaseService>(context, listen: false);
              final acc = Account(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  phone: phone,
                  address: '',
                  category: 'Customer',
                  initialBalance: 0,
                  balanceType: 'none',
                  balance: 0,
                  profileImage: n.data?['senderPhotoUrl'],
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now());
              await db.addAccount(acc);
              _processAddition(n, acc);
            },
            child: Text(widget.isUrdu ? 'بنائیں' : 'Create'),
          )
        ],
      ),
    );
  }
}

class _NegotiationsTab extends StatefulWidget {
  final bool isUrdu;
  final String fontFamily;
  const _NegotiationsTab({required this.isUrdu, required this.fontFamily});

  @override
  _NegotiationsTabState createState() => _NegotiationsTabState();
}

class _NegotiationsTabState extends State<_NegotiationsTab>
    with AutomaticKeepAliveClientMixin {
  String? _expandedOrderId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  String _formatTime(DateTime timestamp, bool isUrdu) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return isUrdu ? 'ابھی' : 'Just now';
    if (difference.inHours < 1)
      return isUrdu
          ? '${difference.inMinutes} منٹ پہلے'
          : '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return DateFormat('hh:mm a').format(timestamp);
    return DateFormat('dd MMM').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final notificationService = Provider.of<NotificationService>(context);
    if (notificationService.targetExpandOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _expandedOrderId = notificationService.targetExpandOrderId;
          });
          notificationService.setTargetExpandOrderId(null);
        }
      });
    }

    final artisanService = ArtisanWorkOrderService();

    return StreamBuilder<List<ArtisanWorkOrder>>(
      stream: artisanService.getArtisanWorkOrders(user.uid),
      builder: (context, artisanSnapshot) {
        return StreamBuilder<List<ArtisanWorkOrder>>(
          stream: artisanService.streamCustomerWorkOrders(user.uid),
          builder: (context, customerSnapshot) {
            final artisanOrders = artisanSnapshot.data ?? [];
            final customerOrders = customerSnapshot.data ?? [];

            final allOrders = [...artisanOrders, ...customerOrders]
                .where((o) => o.status == 'negotiating' || o.status == 'quoted')
                .toList();

            final Map<String, ArtisanWorkOrder> uniqueOrders = {};
            for (var o in allOrders) {
              uniqueOrders[o.id] = o;
            }

            final sortedOrders = uniqueOrders.values.toList();
            sortedOrders.sort((a, b) {
              final aTime = a.updatedAt ?? a.createdAt;
              final bTime = b.updatedAt ?? b.createdAt;
              return bTime.compareTo(aTime);
            });

            final unreadNegotiations = notificationService.notifications
                .where((n) =>
                    !n.isRead && n.data?['type'] == 'negotiation_message')
                .toList();

            if (sortedOrders.isEmpty) {
              if (artisanSnapshot.connectionState == ConnectionState.waiting ||
                  customerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }
              return Center(
                  child: Text(
                      widget.isUrdu ? 'کوئی بات چیت نہیں' : 'No negotiations',
                      style: TextStyle(
                          color: Colors.grey, fontFamily: widget.fontFamily)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sortedOrders.length,
              itemBuilder: (context, index) {
                final order = sortedOrders[index];
                final isExpanded = _expandedOrderId == order.id;
                final bool isIArtisan = order.artisanId == user.uid;

                final orderUnread = unreadNegotiations
                    .where((n) => n.data?['orderId'] == order.id)
                    .toList();
                final bool hasUnread = orderUnread.isNotEmpty;
                final int unreadCount = orderUnread.length;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isExpanded
                            ? AppTheme.themeColor.withValues(alpha: 0.3)
                            : (hasUnread
                                ? AppTheme.themeColor.withValues(alpha: 0.2)
                                : AppTheme.darkColor.withValues(alpha: 0.05))),
                    boxShadow: [
                      BoxShadow(
                        color: hasUnread
                            ? AppTheme.themeColor.withOpacity(0.05)
                            : Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onLongPress: () => _showDeleteChatDialog(
                            order, widget.isUrdu, widget.fontFamily),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: isIArtisan
                            ? ProfileInfoWidget(
                                name: order.customerName,
                                phone: '',
                                address:
                                    isExpanded ? null : order.workDescription,
                                isAddressBold: hasUnread,
                                addressColor: hasUnread ? Colors.black : null,
                                categorySuffix:
                                    hasUnread ? _buildUnreadBadge(unreadCount) : null,
                                suffix: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isIArtisan) ...[
                                      _buildBillButton(order, isIArtisan, widget.isUrdu, widget.fontFamily),
                                      const SizedBox(width: 8),
                                    ],
                                    if (order.lastMessageSenderId == user.uid) ...[
                                      Icon(
                                        order.isLastMessageRead
                                            ? PhosphorIcons.envelopeOpen()
                                            : PhosphorIcons.envelope(),
                                        size: 11,
                                        color: order.isLastMessageRead
                                            ? Colors.blue
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      _formatTime(
                                          order.updatedAt ?? order.createdAt,
                                          widget.isUrdu),
                                      style: TextStyle(
                                        color: hasUnread
                                            ? AppTheme.themeColor
                                            : AppTheme.darkColor
                                                .withValues(alpha: 0.7),
                                        fontSize: 10,
                                        fontFamily: widget.isUrdu
                                            ? widget.fontFamily
                                            : '',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                profileImage: null,
                                customSize: 42,
                                borderRadius: 6,
                                verticalSpacing: 2,
                              )
                            : FutureBuilder<ArtisanProfile?>(
                                future:
                                    ArtisanService().getProfile(order.artisanId),
                                builder: (context, snapshot) {
                                  final profile = snapshot.data;
                                  // ترجیح: 1. آرڈر میں موجود نام، 2. پروفائل سے ملا نام، 3. ڈیفالٹ
                                  final String displayName =
                                      (order.artisanName != null && order.artisanName!.isNotEmpty)
                                          ? order.artisanName!
                                          : (profile?.name ??
                                              (widget.isUrdu
                                                  ? 'کاریگر'
                                                  : 'Artisan'));
                                  return ProfileInfoWidget(
                                    name: displayName,
                                    phone: '',
                                    category: widget.isUrdu ? profile?.professionUrdu : profile?.profession,
                                    isVerticalCategory: true,
                                    address: isExpanded
                                        ? null
                                        : order.workDescription,
                                    isAddressBold: hasUnread,
                                    addressColor:
                                        hasUnread ? Colors.black : null,
                                    categorySuffix: hasUnread
                                        ? _buildUnreadBadge(unreadCount)
                                        : null,
                                    suffix: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isIArtisan) ...[
                                          _buildBillButton(order, isIArtisan, widget.isUrdu, widget.fontFamily),
                                          const SizedBox(width: 8),
                                        ],
                                        if (order.lastMessageSenderId ==
                                            user.uid) ...[
                                          Icon(
                                            order.isLastMessageRead
                                                ? PhosphorIcons.envelopeOpen()
                                                : PhosphorIcons.envelope(),
                                            size: 11,
                                            color: order.isLastMessageRead
                                                ? Colors.blue
                                                : Colors.grey[400],
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          _formatTime(
                                              order.updatedAt ??
                                                  order.createdAt,
                                              widget.isUrdu),
                                          style: TextStyle(
                                            color: hasUnread
                                                ? AppTheme.themeColor
                                                : AppTheme.darkColor
                                                    .withValues(alpha: 0.7),
                                            fontSize: 10,
                                            fontFamily: widget.isUrdu
                                                ? widget.fontFamily
                                                : '',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    profileImage: snapshot.data?.profileImage,
                                    customSize: 42,
                                    borderRadius: 6,
                                    verticalSpacing: 2,
                                  );
                                },
                              ),
                        onTap: () {
                          setState(() {
                            _expandedOrderId = isExpanded ? null : order.id;
                          });
                        },
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: NegotiationView(
                              workOrder: order,
                              isArtisanMode: isIArtisan,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBillButton(ArtisanWorkOrder order, bool isArtisan, bool isUrdu, String fontFamily) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: WorkOrderListItem(
                order: order,
                isArtisanMode: isArtisan,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                onChatTap: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.themeColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(PhosphorIcons.receipt(), size: 16, color: AppTheme.themeColor),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.themeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: '',
        ),
      ),
    );
  }

  void _showDeleteChatDialog(
      ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'مکمل گفتگو حذف کریں؟' : 'Delete Entire Chat?',
            style: TextStyle(fontFamily: fontFamily)),
        content: Text(
            isUrdu
                ? 'کیا آپ واقعی اس کاریگر/گاہک کے ساتھ تمام بات چیت حذف کرنا چاہتے ہیں؟'
                : 'Are you sure you want to delete all conversation with this artisan/customer?',
            style: TextStyle(fontFamily: fontFamily, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'نہیں' : 'No')),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await JobNegotiationService().deleteDirectConversation(
                    jobId: order.id,
                    artisanId: order.artisanId,
                  );
                  await ArtisanWorkOrderService()
                      .deleteWorkOrder(order.artisanId, order.id);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(isUrdu
                              ? 'گفتگو حذف کر دی گئی ہے'
                              : 'Conversation deleted')),
                    );
                  }
                } catch (e) {
                  debugPrint('Error deleting chat: $e');
                }
              },
              child: Text(isUrdu ? 'ہاں' : 'Yes',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
