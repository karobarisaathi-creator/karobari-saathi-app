import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'activity_receipt_dialog.dart';
import 'home_activity_message.dart';

class HomeActivityFeed extends StatefulWidget {
  const HomeActivityFeed({super.key});

  @override
  State<HomeActivityFeed> createState() => _HomeActivityFeedState();
}

class _HomeActivityFeedState extends State<HomeActivityFeed> {
  final Set<String> _processingIds = {};

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.watch<LanguageService>().isUrdu;
    final notifications = context.watch<NotificationService>().notifications;
    final activities = notifications
        .map(
          (notification) => (
            notification: notification,
            message: HomeActivityMessage.fromNotification(
              notification,
              isUrdu: isUrdu,
            ),
          ),
        )
        .where((entry) => entry.message.isRelevant)
        .toList();
    final notAddedCount =
        activities.where((entry) => entry.message.canAddToLedger).length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: UrduAwareText(
                    isUrdu ? 'حساب کی سرگرمیاں' : 'Ledger activity',
                    style: const TextStyle(
                      color: AppTheme.darkColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: UrduAwareText(
                    isUrdu ? 'باقی $notAddedCount' : '$notAddedCount to add',
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppTheme.themeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Center(
                child: UrduAwareText(
                  isUrdu
                      ? 'ابھی کوئی نئی سرگرمی نہیں۔'
                      : 'No new activity yet.',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...List<Widget>.generate(
              activities.length,
              (index) {
                final entry = activities[index];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildActivityCard(
                        entry.notification,
                        entry.message,
                        isUrdu,
                      ),
                    ),
                    if (index < activities.length - 1)
                      const Divider(
                        height: 12,
                        thickness: 1,
                        color: Colors.black26,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    AppNotification notification,
    HomeActivityMessage activityMessage,
    bool isUrdu,
  ) {
    final data = notification.data ?? const <String, dynamic>{};
    final isProcessing = _processingIds.contains(notification.id);
    final senderName =
        data['senderName']?.toString() ?? (isUrdu ? 'صارف' : 'A user');
    final senderPhone = data['senderPhone']?.toString() ?? '';
    final formattedTime = DateFormat(
      isUrdu ? 'yyyy/MM/dd  hh:mm a' : 'dd MMM yyyy, hh:mm a',
    ).format(notification.timestamp);
    final compactActionStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileInfoWidget(
            name: senderName,
            phone: senderPhone,
            profileImage: data['senderPhotoUrl']?.toString(),
            customSize: 34,
            borderRadius: 8,
            suffix: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: UrduAwareText(
                formattedTime,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          UrduAwareText(
            activityMessage.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.darkColor,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              TextButton(
                style: compactActionStyle,
                onPressed: () => _showDetails(notification, isUrdu),
                child: UrduAwareText(
                  isUrdu ? 'تفصیل دیکھیں' : 'View details',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const Spacer(),
              TextButton(
                style: compactActionStyle,
                onPressed: isProcessing
                    ? null
                    : () => _reportActivity(notification, isUrdu),
                child: UrduAwareText(
                  isUrdu ? 'رپورٹ کریں' : 'Report',
                  style: TextStyle(
                    color: AppTheme.expenseColor,
                    fontSize: 11,
                  ),
                ),
              ),
              TextButton(
                style: compactActionStyle,
                onPressed: isProcessing
                    ? null
                    : () => _dismissActivity(notification, isUrdu),
                child: UrduAwareText(
                  isUrdu ? 'نظر انداز کریں' : 'Dismiss',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addToLedger(
    AppNotification notification,
    bool isUrdu,
  ) async {
    final data = notification.data;
    if (data == null) return;
    final phone = data['senderPhone']?.toString().trim() ?? '';
    if (phone.isEmpty) {
      AppToast.warning(
        context,
        isUrdu
            ? 'متعلقہ پارٹی کا فون نمبر دستیاب نہیں۔'
            : 'The sender phone number is unavailable.',
      );
      return;
    }

    setState(() => _processingIds.add(notification.id));
    try {
      final database = context.read<DatabaseService>();
      final accounts = database.accounts
          .where(
            (account) =>
                account.isActive &&
                account.phone.isNotEmpty &&
                Formatters.phoneNumbersMatch(account.phone, phone),
          )
          .toList();
      Account? account;
      if (accounts.length == 1) {
        account = accounts.single;
      } else if (accounts.length > 1) {
        account = await _chooseAccount(accounts, isUrdu);
      } else {
        account = await _createAccount(
          name: data['senderName']?.toString() ?? (isUrdu ? 'پارٹی' : 'Party'),
          phone: phone,
          profileImage: data['senderPhotoUrl']?.toString(),
          isUrdu: isUrdu,
        );
      }
      if (!mounted || account == null) return;

      final sourceId =
          data['transactionId']?.toString().trim().isNotEmpty == true
              ? data['transactionId'].toString()
              : notification.id;
      final senderUid = data['senderUid']?.toString() ?? 'sender';
      final localTransactionId =
          'receipt_${senderUid}_$sourceId'.replaceAll('/', '_');
      final notificationService = context.read<NotificationService>();
      final exists = database
          .getAllTransactions()
          .any((transaction) => transaction.id == localTransactionId);
      if (!exists) {
        await database.addTransaction(
          _transactionFromActivity(
            notification,
            accountId: account.id,
            transactionId: localTransactionId,
            isUrdu: isUrdu,
          ),
        );
      }
      notificationService.updateNotificationData(
        notification.id,
        {'isAdded': true, 'addedAccountId': account.id},
      );
      await database.recalculateAccountBalance(account.id);
      if (!mounted) return;
      AppToast.success(
        context,
        exists
            ? (isUrdu
                ? 'یہ لین دین پہلے ہی آپ کے کھاتے میں شامل ہے۔'
                : 'This transaction is already in your ledger.')
            : (isUrdu
                ? 'لین دین آپ کے کھاتے میں شامل ہو گیا۔'
                : 'Transaction added to your ledger.'),
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to add home activity to ledger: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'لین دین کھاتے میں شامل نہیں ہو سکا۔ دوبارہ کوشش کریں۔'
              : 'Could not add the transaction. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(notification.id));
    }
  }

  Transaction _transactionFromActivity(
    AppNotification notification, {
    required String accountId,
    required String transactionId,
    required bool isUrdu,
  }) {
    final data = notification.data!;
    final senderType = data['transactionType']?.toString();
    final type = senderType == 'income' ? 'expense' : 'income';
    final amount = _number(data['amount']);
    final pendingAmount = _number(data['pendingAmount']);
    final receivedAmount = _number(data['receivedAmount']);
    final category = data['category']?.toString() ?? 'دیگر';
    final isPartySettlement =
        category == AccountBalanceUtils.partySettlementCategory;
    final isWorkerWagePayment = data['referenceNumber']
            ?.toString()
            .startsWith(Transaction.workerWagePaymentReference) ==
        true;
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => TransactionItem.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <TransactionItem>[];
    final date = DateTime.tryParse(
          data['transactionDate']?.toString() ?? '',
        ) ??
        notification.timestamp;
    final paymentMethod = data['paymentMethod']?.toString() ??
        (pendingAmount > 0
            ? (receivedAmount > 0 ? 'mixed' : 'credit')
            : 'cash');

    return Transaction(
      id: transactionId,
      accountId: accountId,
      amount: isPartySettlement
          ? amount
          : pendingAmount > 0
              ? pendingAmount
              : isWorkerWagePayment
                  ? amount
                  : amount,
      subtotal:
          _number(data['subtotal']) > 0 ? _number(data['subtotal']) : amount,
      discountAmount: _number(data['discountAmount']),
      discountPercent:
          double.tryParse(data['discountPercent']?.toString() ?? ''),
      discountReason: data['discountReason']?.toString(),
      type: type,
      category: category,
      description: isPartySettlement
          ? AccountBalanceUtils.partySettlementDescription(
              type: type,
              paymentMethod: paymentMethod,
              isUrdu: isUrdu,
            )
          : data['description']?.toString() ?? '',
      date: date,
      createdAt: notification.timestamp,
      updatedAt: DateTime.now(),
      items: items,
      receivedAmount: isWorkerWagePayment ? amount : receivedAmount,
      pendingAmount: pendingAmount,
      referenceNumber: data['referenceNumber']?.toString(),
      paymentMethod: paymentMethod,
      isPending: pendingAmount > 0,
      receiptFromCounterparty: true,
    );
  }

  Future<Account?> _chooseAccount(List<Account> accounts, bool isUrdu) {
    return showModalBottomSheet<Account>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: UrduAwareText(
                isUrdu
                    ? 'درست پارٹی کھاتہ منتخب کریں'
                    : 'Choose the matching party account',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final account in accounts)
              ListTile(
                title: Text(account.name),
                subtitle: Text(account.phone),
                onTap: () => Navigator.pop(context, account),
              ),
          ],
        ),
      ),
    );
  }

  Future<Account?> _createAccount({
    required String name,
    required String phone,
    required String? profileImage,
    required bool isUrdu,
  }) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: UrduAwareText(
            isUrdu ? 'پارٹی کھاتہ نہیں ملا' : 'Party account not found'),
        content: UrduAwareText(
          isUrdu
              ? '$name کے لیے نیا کھاتہ بنائیں؟'
              : 'Create a new account for $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: UrduAwareText(isUrdu ? 'کھاتہ بنائیں' : 'Create account'),
          ),
        ],
      ),
    );
    if (create != true || !mounted) return null;

    final now = DateTime.now();
    final account = Account(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
      category: 'Customer',
      initialBalance: 0,
      balanceType: 'none',
      balance: 0,
      profileImage: profileImage,
      createdAt: now,
      updatedAt: now,
    );
    await context.read<DatabaseService>().addAccount(account);
    return account;
  }

  Future<void> _dismissActivity(
    AppNotification notification,
    bool isUrdu,
  ) async {
    setState(() => _processingIds.add(notification.id));
    try {
      await context
          .read<NotificationService>()
          .deleteNotification(notification.id);
    } catch (error, stackTrace) {
      debugPrint('Unable to dismiss home activity: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'سرگرمی ہٹائی نہیں جا سکی۔' : 'Could not dismiss activity.',
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(notification.id));
    }
  }

  Future<void> _reportActivity(
    AppNotification notification,
    bool isUrdu,
  ) async {
    final shouldReport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            UrduAwareText(isUrdu ? 'سرگرمی رپورٹ کریں؟' : 'Report activity?'),
        content: UrduAwareText(
          isUrdu
              ? 'یہ رپورٹ جائزے کے لیے محفوظ کی جائے گی۔'
              : 'This report will be saved for review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: UrduAwareText(isUrdu ? 'رپورٹ' : 'Report'),
          ),
        ],
      ),
    );
    if (shouldReport != true || !mounted) return;

    try {
      await context.read<NotificationService>().reportNotification(
            notificationId: notification.id,
            reason: 'user_reported',
          );
      if (mounted) {
        AppToast.success(
          context,
          isUrdu ? 'رپورٹ محفوظ ہو گئی۔' : 'Report submitted.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to report home activity: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'رپورٹ جمع نہیں ہو سکی۔' : 'Could not submit report.',
        );
      }
    }
  }

  void _showDetails(AppNotification notification, bool isUrdu) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ActivityReceiptDialog(
          notification: notification,
          isUrdu: isUrdu,
          onAddToLedger: () {
            Navigator.pop(context);
            _addToLedger(notification, isUrdu);
          },
        ),
      ),
    );
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
