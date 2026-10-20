// lib/core/utils/receipt_dialog_helper.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';

// ═══ نئی تین فائلیں ═══
import 'package:account_app/features/quick_bill/widgets/base_ledger_widget.dart';
import 'package:account_app/features/quick_bill/widgets/incoming_receipt_widget.dart';
import 'package:account_app/features/quick_bill/widgets/outgoing_receipt_widget.dart';

import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/accounts/add_transaction_screen.dart';
import 'package:account_app/features/professions/add_project_transaction_screen.dart';

class ReceiptDialogHelper {
  static Future<void> showReceiptDialog(
    BuildContext context, {
    required Transaction transaction,
    Account? account,
    AppNotification? notification,
    bool isLocalTransaction = true,
    bool showAddButton = false,
    bool showDeleteButton = false,
    VoidCallback? onAddPressed,
    VoidCallback? onDeletePressed,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ReceiptDialogContent(
          transaction: transaction,
          account: account,
          notification: notification,
          isLocalTransaction: isLocalTransaction,
          showAddButton: showAddButton,
          showDeleteButton: showDeleteButton,
          onAddPressed: onAddPressed,
          onDeletePressed: onDeletePressed,
        );
      },
    );
  }
}

class _ReceiptDialogContent extends StatefulWidget {
  final Transaction transaction;
  final Account? account;
  final AppNotification? notification;
  final bool isLocalTransaction;
  final bool showAddButton;
  final bool showDeleteButton;
  final VoidCallback? onAddPressed;
  final VoidCallback? onDeletePressed;

  const _ReceiptDialogContent({
    required this.transaction,
    this.account,
    this.notification,
    required this.isLocalTransaction,
    required this.showAddButton,
    required this.showDeleteButton,
    this.onAddPressed,
    this.onDeletePressed,
  });

  @override
  State<_ReceiptDialogContent> createState() => _ReceiptDialogContentState();
}

class _ReceiptDialogContentState extends State<_ReceiptDialogContent> {
  final ScreenshotController _screenshotController = ScreenshotController();
  String _businessName = '';
  String _businessPhone = '';
  String _businessAddress = '';
  String _billedToName = '';
  String _billedToPhone = '';
  bool _showCounterpartyOnTop = false;
  bool _showSavedEntry = false;
  bool _isSharing = false;
  bool _initialized = false;

  // ═══════════════════════════════════════════════════════════
  // INIT — ناموں کا تعین
  // ═══════════════════════════════════════════════════════════
  void _initReceiptData(BuildContext context) {
    if (_initialized) return;
    _initialized = true;

    final user = FirebaseAuth.instance.currentUser;
    final notificationData = widget.notification?.data;
    final isIncomingNotification =
        !widget.isLocalTransaction && notificationData != null;

    final senderName = notificationData?['senderName']?.toString().trim() ?? '';
    final senderPhone = notificationData?['senderPhone']?.toString() ?? '';
    final userName =
        user?.displayName?.trim() ?? user?.email?.split('@').first ?? '';
    final userPhone = user?.phoneNumber ?? '';

    final db = Provider.of<DatabaseService>(context, listen: false);
    final savedEntry = _savedCounterpartyTransaction(db);
    final targetAccount = widget.account ??
        db.getAccount(widget.transaction.accountId) ??
        (savedEntry == null ? null : db.getAccount(savedEntry.accountId));

    final accountName = targetAccount?.name?.trim() ?? '';
    final accountPhone = targetAccount?.phone ?? '';
    final addedNotification = Provider.of<NotificationService>(
      context,
      listen: false,
    ).notifications.where((notification) {
      final data = notification.data;
      return notification.type == NotificationType.transaction &&
          data?['isAdded'] == true &&
          data?['transactionId']?.toString() == widget.transaction.id;
    }).firstOrNull;
    final addedNotificationData = addedNotification?.data;
    final addedSenderName =
        addedNotificationData?['senderName']?.toString().trim() ?? '';
    final addedSenderPhone =
        addedNotificationData?['senderPhone']?.toString() ?? '';

    // ═══ سمت کا تعین ═══
    _showCounterpartyOnTop = isIncomingNotification ||
        widget.transaction.receiptFromCounterparty ||
        addedNotification != null;
    _showSavedEntry = savedEntry != null &&
        (widget.isLocalTransaction || isIncomingNotification);

    final partyName = isIncomingNotification
        ? senderName
        : (addedSenderName.isNotEmpty ? addedSenderName : accountName);
    final partyPhone = isIncomingNotification
        ? senderPhone
        : (addedSenderPhone.isNotEmpty ? addedSenderPhone : accountPhone);

    // ⭐ اصول: اوپر ہمیشہ میرا نام (Business Name)، نیچے بنام میں پارٹی کا نام
    _businessName = userName;
    _businessPhone = userPhone;
    _businessAddress = '';
    _billedToName = partyName.isNotEmpty
        ? partyName
        : (targetAccount?.name ?? 'Cash Customer');
    _billedToPhone = partyPhone;
  }

  Transaction? _savedCounterpartyTransaction(DatabaseService db) {
    if (widget.transaction.receiptFromCounterparty) {
      return widget.transaction;
    }
    final saved = db.getTransaction(widget.transaction.id);
    return saved?.receiptFromCounterparty == true ? saved : null;
  }

  Transaction _originalTransaction(Transaction savedEntry) {
    return Transaction(
      id: savedEntry.id,
      accountId: savedEntry.accountId,
      amount: savedEntry.amount,
      subtotal: savedEntry.subtotal,
      discountAmount: savedEntry.discountAmount,
      discountPercent: savedEntry.discountPercent,
      discountReason: savedEntry.discountReason,
      type: savedEntry.type == 'income' ? 'expense' : 'income',
      category: savedEntry.category,
      description: savedEntry.description,
      date: savedEntry.date,
      billImage: savedEntry.billImage,
      quantity: savedEntry.quantity,
      rate: savedEntry.rate,
      receivedAmount: savedEntry.receivedAmount,
      pendingAmount: savedEntry.pendingAmount,
      referenceNumber: savedEntry.referenceNumber,
      paymentMethod: savedEntry.paymentMethod,
      isPending: savedEntry.isPending,
      createdAt: savedEntry.createdAt,
      updatedAt: savedEntry.updatedAt,
      professionId: savedEntry.professionId,
      professionName: savedEntry.professionName,
      partnershipId: savedEntry.partnershipId,
      voiceNote: savedEntry.voiceNote,
      items: savedEntry.items,
    );
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _loadBusinessProfile(user.uid);
  }

  Future<void> _loadBusinessProfile(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!mounted) return;
      final profile = snapshot.data();
      setState(() {
        final profileName = (profile?['displayName'] ??
                profile?['name'] ??
                profile?['businessName'] ??
                '')
            .toString()
            .trim();
        final profilePhone = (profile?['phoneNumber'] ?? '').toString();
        final profileAddress =
            (profile?['businessAddress'] ?? '').toString().trim();

        // ⭐ ہمیشہ اوپر میرا نام (profileName) رہے گا
        if (profileName.isNotEmpty) _businessName = profileName;
        if (profilePhone.isNotEmpty) _businessPhone = profilePhone;
        if (profileAddress.isNotEmpty && _businessAddress.isEmpty) {
          _businessAddress = profileAddress;
        }

        if (widget.account != null && _billedToName.isEmpty) {
          _billedToName = widget.account!.name;
          _billedToPhone = widget.account!.phone ?? '';
        }
      });
    } catch (error) {
      debugPrint('Failed to load receipt business profile: $error');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Share
  // ═══════════════════════════════════════════════════════════
  Future<void> _shareReceipt(bool isUrdu) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final imageBytes = await _screenshotController.capture();
      if (imageBytes == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles([XFile(file.path)],
          text: isUrdu ? 'رسید' : 'Receipt');
    } catch (e) {
      debugPrint('Error sharing receipt: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Edit
  // ═══════════════════════════════════════════════════════════
  void _onEditPressed(BuildContext context) {
    Navigator.of(context).pop();

    if (widget.transaction.isQuickBill) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuickBillItemSelectionScreen(
            transactionToEdit: widget.transaction,
          ),
        ),
      );
      return;
    }

    if (widget.transaction.accountId == 'default_account' &&
        widget.transaction.professionId != null) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final profession = db.getProfession(widget.transaction.professionId!);
      if (profession != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProjectTransactionScreen(
              profession: profession,
              transactionToEdit: widget.transaction,
            ),
          ),
        );
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          transactionToEdit: widget.transaction,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    _initReceiptData(context);
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final db = Provider.of<DatabaseService>(context, listen: false);
    final savedEntry = _savedCounterpartyTransaction(db);
    final targetAccount = widget.account ??
        db.getAccount(widget.transaction.accountId) ??
        (savedEntry == null ? null : db.getAccount(savedEntry.accountId));
    final showSavedEntry = savedEntry != null && _showSavedEntry;
    final originalTransaction = savedEntry == null
        ? widget.transaction
        : _originalTransaction(savedEntry);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══ Header — لیبل + "کھاتے میں شامل کریں" ایک لائن میں ═══
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: UrduAwareText(
                        _showCounterpartyOnTop &&
                                widget.notification?.data?['senderName'] != null
                            ? (isUrdu
                                ? 'بل کی رسید (از: ${widget.notification!.data!['senderName']})'
                                : 'Transaction Receipt (From: ${widget.notification!.data!['senderName']})')
                            : (targetAccount != null && _showCounterpartyOnTop
                                ? (isUrdu
                                    ? 'بل کی رسید (از: ${targetAccount.name})'
                                    : 'Transaction Receipt (From: ${targetAccount.name})')
                                : (isUrdu ? 'بل کی رسید' : 'Transaction Receipt')),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const Spacer(),

                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: AppTheme.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ═══ رسید ═══
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: savedEntry == null
                        // کوئی کھاتے کی انٹری نہیں → Base (Outgoing)
                        ? BaseLedgerWidget(
                            transaction: widget.transaction,
                            account: targetAccount,
                            businessName: _businessName,
                            businessPhone: _businessPhone,
                            businessAddress: _businessAddress,
                            billedToName: _billedToName,
                            billedToPhone: _billedToPhone,
                            isIncomingReceipt: _showCounterpartyOnTop,
                          )
                        : showSavedEntry
                            // کھاتے کی انٹری — Incoming (پارٹی کی طرف)
                            ? IncomingReceiptWidget(
                                transaction: savedEntry,
                                account: targetAccount,
                                businessName: _businessName,
                                businessPhone: _businessPhone,
                                businessAddress: _businessAddress,
                                billedToName: _billedToName,
                                billedToPhone: _billedToPhone,
                              )
                            // اصل ٹرانزیکشن — Outgoing (میری طرف)
                            : OutgoingReceiptWidget(
                                transaction: originalTransaction,
                                account: null,
                                businessName: _businessName,
                                businessPhone: _businessPhone,
                                businessAddress: _businessAddress,
                                billedToName: _billedToName,
                                billedToPhone: _billedToPhone,
                              ),
                  ),
                ),
              ),

              // ═══ Bottom buttons ═══
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    if (widget.showAddButton) ...[
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          text: isUrdu ? 'کھاتے میں شامل کریں' : 'Add to Khata',
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onAddPressed?.call();
                          },
                          icon: PhosphorIcons.plusCircle(),
                          color: AppTheme.themeColor,
                          size: AppButtonSize.small,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        if (widget.isLocalTransaction) ...[
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'ایڈٹ کریں' : 'Edit',
                              onPressed: () => _onEditPressed(context),
                              icon: PhosphorIcons.pencilLine(),
                              color: Colors.blueGrey,
                              size: AppButtonSize.small,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'شیئر کریں' : 'Share',
                              onPressed:
                              _isSharing ? null : () => _shareReceipt(isUrdu),
                              icon: PhosphorIcons.shareNetwork(),
                              color: AppTheme.themeColor,
                              size: AppButtonSize.small,
                            ),
                          ),
                        ] else ...[
                          if (widget.showDeleteButton)
                            Expanded(
                              child: AppButton(
                                text: isUrdu ? 'حذف کریں' : 'Delete',
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onDeletePressed?.call();
                                },
                                icon: PhosphorIcons.trash(),
                                color: AppTheme.expenseColor,
                                size: AppButtonSize.small,
                              ),
                            ),
                          if (widget.showDeleteButton) const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'شیئر کریں' : 'Share',
                              onPressed:
                              _isSharing ? null : () => _shareReceipt(isUrdu),
                              icon: PhosphorIcons.shareNetwork(),
                              color: AppTheme.themeColor,
                              size: AppButtonSize.small,
                            ),
                          ),
                        ],
                      ],
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
