import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    hide Transaction; // Firebase
import 'package:firebase_auth/firebase_auth.dart'; // Firebase
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/version_check_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:account_app/core/utils/formatters.dart';

import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Color _goldColor = const Color(0xFFDAAD51);

  bool _isLoading = true;
  List<AppNotification> _notifications = [];
  Map<String, dynamic>? _updateData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllNotifications();
      _checkVersion();
    });
  }

  void _checkVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDismissed = prefs.getInt('last_update_dismissed') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 24 hours = 24 * 60 * 60 * 1000 milliseconds
    if (now - lastDismissed < 24 * 60 * 60 * 1000) {
      return; // Don't show if dismissed within 24 hours
    }

    final data = await VersionCheckService().getUpdateData();
    if (mounted) {
      setState(() {
        _updateData = data;
      });
    }
  }

  void _dismissUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_update_dismissed', DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _updateData = null;
    });
  }

  Future<void> _loadAllNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final notificationService =
        Provider.of<NotificationService>(context, listen: false);

    // Force a fresh fetch/listener restart
    await notificationService.loadFromCloud();

    // Give it a moment to sync from Firestore before hiding spinner
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final notificationService = Provider.of<NotificationService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    
    final notifications = notificationService.notifications;
    final unreadCount = notificationService.unreadCount;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'نوٹیفیکیشن' : 'Notifications',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        elevation: 1,
        actions: [
          if (unreadCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    color: AppTheme.lightColor,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(PhosphorIcons.dotsThreeVertical()),
            onPressed: () => _showActionMenu(
                context, isUrdu, fontFamily, notificationService),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.themeColor))
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.darkColor.withOpacity(0.05))),
                        child: Icon(PhosphorIcons.bellSlash(),
                            size: 48,
                            color: AppTheme.darkColor.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 24),
                      Text(isUrdu ? 'کوئی نوٹیفیکیشن نہیں' : 'No Notifications',
                          style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.darkColor,
                              fontWeight:
                                  isUrdu ? FontWeight.bold : FontWeight.normal,
                              fontFamily: fontFamily)),
                      const SizedBox(height: 8),
                      Text(
                          isUrdu
                              ? 'تمام نوٹیفیکیشنز یہاں نظر آئیں گی'
                              : 'All notifications will appear here',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontFamily: fontFamily)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllNotifications,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    children: [
                      if (_updateData != null) ...[
                        _buildUpdateCard(isUrdu, fontFamily),
                        const SizedBox(height: 16),
                      ],
                      ...notifications
                          .map((n) => _buildNotificationCard(
                              n, isUrdu, fontFamily, notificationService))
                          .toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildUpdateCard(bool isUrdu, String fontFamily) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.themeColor, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.themeColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
              size: 100,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          PhosphorIcons.rocketLaunch(PhosphorIconsStyle.fill),
                          color: Colors.white,
                          size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isUrdu ? 'نیا ورژن دستیاب ہے!' : 'New Version Available!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isUrdu
                      ? _updateData!['message_ur']
                      : _updateData!['message_en'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.4,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final url = _updateData?['update_url'] ?? '';
                        if (url.isNotEmpty) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.themeColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                      child: Text(
                        isUrdu ? 'ابھی اپ ڈیٹ کریں' : 'Update Now',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _dismissUpdate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70, width: 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                      child: Text(
                        isUrdu ? 'بند کریں' : 'Dismiss',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, bool isUrdu,
      String fontFamily, NotificationService notificationService) {
    return NotificationCard(
      notification: notification,
      isUrdu: isUrdu,
      fontFamily: fontFamily,
      onAddPressed: () => _addToLedger(notification),
      onDeletePressed: () => _deleteNotification(
          notification.id, isUrdu, fontFamily, notificationService),
      onTap: () {
        if (!notification.isRead)
          notificationService.markAsRead(notification.id);
        _handleNotificationClick(context, notification);
      },
    );
  }

  String _getTransactionMessage(Map<String, dynamic> data, bool isUrdu) {
    // This is now handled inside NotificationCard, but we can keep it for any other needs
    // or remove it if not used elsewhere in this file.
    return "";
  }

  void _handleNotificationClick(
      BuildContext context, AppNotification notification) async {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final langService = Provider.of<LanguageService>(context, listen: false);
    Account? account;

    String? accountId = notification.data?['accountId'];
    String? senderId = notification.data?['senderId'];

    if (accountId != null) {
      account = databaseService.getAccount(accountId);
    }

    if (notification.type == NotificationType.share &&
        account == null &&
        accountId != null) {
      if (senderId != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(langService.isUrdu
              ? 'آن لائن تلاش کیا جا رہا ہے...'
              : 'Fetching online...'),
          duration: Duration(seconds: 1),
        ));
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .collection('accounts')
              .doc(accountId)
              .get();
          if (doc.exists && doc.data() != null) {
            Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
            data['id'] = accountId;
            final fetchedAccount = Account.fromMap(data);
            account = fetchedAccount;
          }
        } catch (e) {
          print("Error fetching shared account from cloud: $e");
        }
      }
    }

    if (account != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartyDetailScreen(
              party: account!,
              isReadOnly: notification.type == NotificationType.share),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          langService.isUrdu
              ? 'متعلقہ کھاتہ موجود نہیں ہے (ID: $accountId)'
              : 'Related account not found (ID: $accountId).',
          style: TextStyle(
              fontFamily: langService.isUrdu ? 'NooriNastaleeq' : 'NotoSans'),
        ),
        backgroundColor: AppTheme.themeColor,
      ));
    }
  }

  Widget _buildTransactionActionRow(AppNotification notification, bool isUrdu,
      String fontFamily, NotificationService notificationService) {
    final data = notification.data!;
    final type = data['transactionType'] ?? 'income';
    final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final isIncome = type == 'income';
    final accentColor = isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isUrdu
                        ? (isIncome ? 'آپ نے رقم لی' : 'آپ نے رقم دی')
                        : (isIncome ? 'You Received' : 'You Paid'),
                    style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 12,
                        color: AppTheme.textSecondary),
                  ),
                  Text(
                    Formatters.formatCurrency(amount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: accentColor),
                  ),
                ],
              ),
              if (data['description'] != null &&
                  data['description'].toString().isNotEmpty) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Icon(PhosphorIcons.note(),
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data['description'],
                        style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _addToLedger(notification),
                icon: Icon(PhosphorIcons.plusCircle(), size: 18),
                label: Text(isUrdu ? 'کھاتے میں شامل کریں' : 'Add to Ledger',
                    style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _deleteNotification(
                  notification.id, isUrdu, fontFamily, notificationService),
              icon: Icon(PhosphorIcons.trash(),
                  color: AppTheme.expenseColor, size: 22),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addToLedger(AppNotification notification) async {
    final data = notification.data;
    if (data == null) return;

    final db = Provider.of<DatabaseService>(context, listen: false);
    final lang = Provider.of<LanguageService>(context, listen: false);
    final isUrdu = lang.isUrdu;

    String senderPhone = data['senderPhone'] ?? '';
    if (senderPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isUrdu ? 'فون نمبر موجود نہیں ہے' : 'Phone number not found')));
      return;
    }

    // Normalize phone number for lookup
    String lookupPhone = senderPhone.replaceAll(RegExp(r'\D'), '');
    if (lookupPhone.startsWith('92'))
      lookupPhone = '0' + lookupPhone.substring(2);

    final accounts = await db.getAccounts();
    Account? targetAccount;

    try {
      targetAccount = accounts.firstWhere((a) {
        String p = a.phone.replaceAll(RegExp(r'\D'), '');
        if (p.startsWith('92')) p = '0' + p.substring(2);
        return p == lookupPhone;
      });
    } catch (e) {
      // Account not found
    }

    if (targetAccount == null) {
      _showCreateAccountDialog(
          notification, senderPhone, data['senderName'] ?? 'Unknown');
      return;
    }

    await _processTransactionAddition(notification, targetAccount);
  }

  Future<void> _processTransactionAddition(
      AppNotification notification, Account account) async {
    final data = notification.data!;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final lang = Provider.of<LanguageService>(context, listen: false);
    final isUrdu = lang.isUrdu;

    // Reverse the type: if they paid, I received. If they received, I paid.
    String originalType = data['transactionType'] ?? 'income';
    String myType = originalType == 'income' ? 'expense' : 'income';
    double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;

    List<TransactionItem> items = [];
    if (data['items'] != null && data['items'] is List) {
      for (var itemMap in (data['items'] as List)) {
        items.add(TransactionItem.fromMap(Map<String, dynamic>.from(itemMap)));
      }
    }

    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: account.id,
      amount: amount,
      type: myType,
      category: 'دیگر',
      description: data['description'] ?? '',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: items,
      pendingAmount: amount, // رقم کو پینڈنگ میں ڈالیں تاکہ بیلنس اپڈیٹ ہو
      isPending: true,
    );

    try {
      await db.addTransaction(transaction);

      // بیلنس اپڈیٹ ہونے کا تھوڑا انتظار کریں تاکہ حساب کتاب مکمل ہو جائے
      await db.recalculateAccountBalance(account.id);

      // ڈیٹا بیس سے تازہ ترین اکاؤنٹ حاصل کریں
      final updatedAccount = db.getAccount(account.id) ?? account;

      // نوٹیفیکیشن کو اپ ڈیٹ کریں اور اسے پڑھا ہوا (Read) مارک کریں تاکہ کاؤنٹ کم ہو جائے
      final notifService =
          Provider.of<NotificationService>(context, listen: false);
      notifService.updateNotificationData(notification.id, {'isAdded': true});
      notifService.markAsRead(notification.id);

      // ڈیٹیل سکرین پر جائیں
      if (mounted) {
        Navigator.pushReplacement(
          // pushReplacement استعمال کریں تاکہ پیچھے آنے پر ڈیٹا پرانا نہ ہو
          context,
          MaterialPageRoute(
            builder: (context) => PartyDetailScreen(
              party: updatedAccount,
              highlightTransactionId: transaction.id,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreateAccountDialog(
      AppNotification notification, String phone, String name) {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final isUrdu = lang.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? 'اکاؤنٹ نہیں ملا' : 'Account Not Found',
            style: TextStyle(fontFamily: fontFamily)),
        content: Text(
          isUrdu
              ? 'کیا آپ $name ($phone) کے نام سے نیا کھاتہ بنانا چاہتے ہیں؟'
              : 'Would you like to create a new account for $name ($phone)?',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'کینسل' : 'Cancel',
                style: TextStyle(fontFamily: fontFamily)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = Provider.of<DatabaseService>(context, listen: false);
              final newAccount = Account(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                phone: phone,
                address: '',
                category: 'Customer',
                initialBalance: 0,
                balanceType: 'none',
                balance: 0,
                profileImage: notification
                    .data?['senderPhotoUrl'], // بھیجنے والے کی تصویر شامل کی
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await db.addAccount(newAccount);
              await _processTransactionAddition(notification, newAccount);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.themeColor),
            child: Text(isUrdu ? 'بنائیں اور شامل کریں' : 'Create & Add',
                style: TextStyle(fontFamily: fontFamily, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getLast10(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length > 10) return clean.substring(clean.length - 10);
    return clean;
  }

  void _showActionMenu(BuildContext context, bool isUrdu, String fontFamily,
      NotificationService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(PhosphorIcons.envelopeOpen(),
                  color: AppTheme.themeColor),
              title: Text(isUrdu ? 'سب پڑھ لیں' : 'Mark all as read',
                  style: TextStyle(
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold)),
              onTap: () {
                service.markAllAsRead();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading:
                  Icon(PhosphorIcons.broom(), color: AppTheme.expenseColor),
              title: Text(isUrdu ? 'سب حذف کریں' : 'Delete all',
                  style: TextStyle(
                      color: AppTheme.expenseColor,
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAllConfirmDialog(
                    context, isUrdu, fontFamily, service);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNotification(
      String id, bool isUrdu, String fontFamily, NotificationService service) {
    service.deleteNotification(id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(isUrdu ? 'نوٹیفیکیشن حذف ہو گئی' : 'Notification deleted'),
        duration: Duration(seconds: 1),
        backgroundColor: _goldColor));
  }

  void _showDeleteAllConfirmDialog(BuildContext context, bool isUrdu,
      String fontFamily, NotificationService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? 'سب حذف کریں؟' : 'Delete All?',
            style: TextStyle(
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold)),
        content: Text(
            isUrdu
                ? 'کیا آپ واقعی تمام نوٹیفیکیشنز حذف کرنا چاہتے ہیں؟'
                : 'Are you sure you want to delete all notifications?',
            style: TextStyle(
                color: AppTheme.textSecondary, fontFamily: fontFamily)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'نہیں' : 'No',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontFamily: fontFamily))),
          TextButton(
              onPressed: () {
                service.clearAll();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isUrdu
                        ? 'تمام نوٹیفیکیشنز حذف ہو گئیں'
                        : 'All notifications deleted')));
              },
              child: Text(isUrdu ? 'ہاں' : 'Yes',
                  style: TextStyle(
                      color: AppTheme.expenseColor,
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0)
      return DateFormat('MMM d').format(timestamp);
    else if (diff.inHours > 0)
      return '${diff.inHours}h ago';
    else if (diff.inMinutes > 0)
      return '${diff.inMinutes}m ago';
    else
      return 'Just now';
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.transaction:
        return PhosphorIcons.arrowsLeftRight();
      case NotificationType.reminder:
        return PhosphorIcons.clockAfternoon();
      case NotificationType.system:
        return PhosphorIcons.info();
      case NotificationType.share:
        return PhosphorIcons.shareNetwork();
      case NotificationType.report:
        return PhosphorIcons.chartLineUp();
      default:
        return PhosphorIcons.bell();
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.transaction:
        return Colors.blue;
      case NotificationType.reminder:
        return Colors.orange;
      case NotificationType.system:
        return AppTheme.darkColor;
      case NotificationType.share:
        return Colors.purple;
      case NotificationType.report:
        return Colors.teal;
      default:
        return AppTheme.themeColor;
    }
  }

  String _getNotificationTypeText(NotificationType type, bool isUrdu) {
    switch (type) {
      case NotificationType.transaction:
        return isUrdu ? 'لین دین' : 'Transaction';
      case NotificationType.reminder:
        return isUrdu ? 'یاد دہانی' : 'Reminder';
      case NotificationType.system:
        return isUrdu ? 'سسٹم' : 'System';
      case NotificationType.share:
        return isUrdu ? 'شیئرنگ' : 'Sharing';
      case NotificationType.report:
        return isUrdu ? 'رپورٹ' : 'Report';
      default:
        return isUrdu ? 'عام' : 'General';
    }
  }
}
