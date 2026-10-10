import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/version_check_service.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/core/utils/receipt_helper.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/transaction_card.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/notification_card.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  final int initialIndex;
  const NotificationsScreen({Key? key, this.initialIndex = 0})
      : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, dynamic>? _updateData;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllNotifications();
      _checkVersion();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
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
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: _isKeyboardVisible
              ? null
              : CustomAppBar(
                  title: isUrdu ? 'اطلاعات' : 'Notifications',
                  showBackButton: false,
                  centerTitle: true,
                ),
          body: Column(
            children: [
              if (_updateData != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildUpdateCard(isUrdu, fontFamily),
                ),
              Expanded(
                child: _NotificationListTab(
                  notifications: notifications,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  onRefresh: _loadAllNotifications,
                ),
              ),
            ],
          ),
        );
      },
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
    final allNotifications = widget.notifications;

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
          if (n.type == NotificationType.transaction && n.data != null) {
            final data = n.data!;
            List<TransactionItem> items = [];
            if (data['items'] != null && data['items'] is List) {
              for (var itemMap in (data['items'] as List)) {
                items.add(TransactionItem.fromMap(
                    Map<String, dynamic>.from(itemMap)));
              }
            }

            final transaction = _transactionFromNotification(n);

            final isAdded = data['isAdded'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ProfileInfoWidget(
                          name: data['senderName'] ??
                              (widget.isUrdu ? 'صارف' : 'User'),
                          phone: data['senderPhone'] ?? '',
                          profileImage: data['senderPhotoUrl'],
                          customSize: 36,
                          borderRadius: 6,
                        ),
                      ),
                      Text(
                        _formatTime(n.timestamp),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TransactionCard(
                    transaction: transaction,
                    onTap: () {
                      if (!n.isRead) notificationService.markAsRead(n.id);
                      _handleClick(n);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AppButton(
                        text: isAdded
                            ? (widget.isUrdu ? 'کھاتے میں شامل ہے' : 'Added')
                            : (widget.isUrdu
                                ? 'کھاتے میں شامل کریں'
                                : 'Add to Ledger'),
                        variant: AppButtonVariant.outlined,
                        size: AppButtonSize.small,
                        color: isAdded ? Colors.grey : AppTheme.themeColor,
                        onPressed: isAdded ? null : () => _addToLedger(n),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _confirmDelete(n),
                        icon: Icon(PhosphorIcons.trash(),
                            color: Colors.red.shade300, size: 20),
                        tooltip: widget.isUrdu ? 'حذف کریں' : 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return NotificationCard(
            notification: n,
            isUrdu: widget.isUrdu,
            fontFamily: widget.fontFamily,
            onAddPressed: () => _addToLedger(n),
            onDeletePressed: () => _confirmDelete(n),
            onTap: () {
              if (!n.isRead) notificationService.markAsRead(n.id);
              _handleClick(n);
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(AppNotification n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            widget.isUrdu ? 'نوٹیفیکیشن حذف کریں؟' : 'Delete Notification?'),
        content: Text(
          widget.isUrdu
              ? 'کیا آپ واقعی اس نوٹیفیکیشن کو حذف کرنا چاہتے ہیں؟'
              : 'Are you sure you want to delete this notification?',
          style: TextStyle(fontFamily: widget.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<NotificationService>(context, listen: false)
                  .deleteNotification(n.id);
            },
            child: Text(
              widget.isUrdu ? 'حذف کریں' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return widget.isUrdu ? 'ابھی' : 'Just now';
    if (difference.inHours < 1) {
      return widget.isUrdu
          ? '${difference.inMinutes} منٹ پہلے'
          : '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) return DateFormat('hh:mm a').format(timestamp);
    return DateFormat('dd MMM').format(timestamp);
  }

  Transaction _transactionFromNotification(AppNotification notification) {
    final data = notification.data!;
    final items = (data['items'] as List?)
            ?.map((item) =>
                TransactionItem.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList() ??
        <TransactionItem>[];
    final amount = double.tryParse(data['amount']?.toString() ?? '') ?? 0;

    return Transaction(
      id: data['transactionId']?.toString() ?? notification.id,
      accountId: data['senderUid']?.toString() ?? 'remote_user',
      amount: amount,
      subtotal: double.tryParse(data['subtotal']?.toString() ?? '') ?? amount,
      discountAmount:
          double.tryParse(data['discountAmount']?.toString() ?? '') ?? 0,
      discountPercent:
          double.tryParse(data['discountPercent']?.toString() ?? ''),
      discountReason: data['discountReason']?.toString(),
      type: data['transactionType']?.toString() ?? 'income',
      category: data['category']?.toString() ?? 'فروخت',
      paymentMethod: data['paymentMethod']?.toString() ?? 'cash',
      description: data['description']?.toString() ?? '',
      date: DateTime.tryParse(data['transactionDate']?.toString() ?? '') ??
          notification.timestamp,
      quantity: items.length,
      rate: 0,
      receivedAmount:
          double.tryParse(data['receivedAmount']?.toString() ?? '') ?? 0,
      pendingAmount:
          double.tryParse(data['pendingAmount']?.toString() ?? '') ?? 0,
      isPending:
          (double.tryParse(data['pendingAmount']?.toString() ?? '') ?? 0) > 0,
      items: items,
      referenceNumber: data['referenceNumber']?.toString(),
      createdAt: notification.timestamp,
      updatedAt: notification.timestamp,
    );
  }

  void _handleClick(AppNotification n) async {
    if (n.type == NotificationType.transaction && n.data != null) {
      final data = n.data!;
      final transaction = _transactionFromNotification(n);

      final isAdded = data['isAdded'] == true;
      ReceiptHelper.showReceiptDialog(
        context,
        transaction: transaction,
        notification: n,
        isLocalTransaction:
            false, // Notification transaction from external sender
        showAddButton: !isAdded,
        showDeleteButton: true,
        onAddPressed: () => _addToLedger(n),
        onDeletePressed: () => _confirmDelete(n),
      );
      return;
    }

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
    final receivedAmount =
        double.tryParse(data['receivedAmount']?.toString() ?? '0') ?? 0;
    final pendingAmount =
        double.tryParse(data['pendingAmount']?.toString() ?? '') ?? amount;
    final transactionDate =
        DateTime.tryParse(data['transactionDate']?.toString() ?? '') ??
            n.timestamp;

    List<TransactionItem> items = [];
    if (data['items'] != null && data['items'] is List) {
      for (var itemMap in (data['items'] as List)) {
        items.add(TransactionItem.fromMap(Map<String, dynamic>.from(itemMap)));
      }
    }

    final tx = Transaction(
      id: data['transactionId'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: account.id,
      amount: amount,
      subtotal: double.tryParse(data['subtotal']?.toString() ?? '') ?? amount,
      discountAmount:
          double.tryParse(data['discountAmount']?.toString() ?? '') ?? 0,
      discountPercent:
          double.tryParse(data['discountPercent']?.toString() ?? ''),
      discountReason: data['discountReason']?.toString(),
      type: type,
      category: data['category']?.toString() ?? 'دیگر',
      description: data['description'] ?? '',
      date: transactionDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: items,
      receivedAmount: receivedAmount,
      pendingAmount: pendingAmount,
      referenceNumber: data['referenceNumber']?.toString(),
      paymentMethod: data['paymentMethod']?.toString() ??
          (pendingAmount > 0
              ? (receivedAmount > 0 ? 'mixed' : 'credit')
              : 'cash'),
      isPending: pendingAmount > 0,
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
