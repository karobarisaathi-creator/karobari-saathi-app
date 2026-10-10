// lib/core/utils/receipt_helper.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/features/quick_bill/widgets/receipt_widget.dart';
import 'package:account_app/features/quick_bill/quick_bill_item_selection_screen.dart';
import 'package:account_app/features/accounts/add_transaction_screen.dart';
import 'package:account_app/features/professions/add_project_transaction_screen.dart';

class ReceiptHelper {
  /// خوبصورت راؤنڈڈ کونوں (BorderRadius: 24) کے ساتھ رسید کا پوپ اپ ڈائیلاگ
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
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final notificationData = widget.notification?.data;
    final isIncomingNotification =
        !widget.isLocalTransaction && notificationData != null;
    _businessName = isIncomingNotification
        ? notificationData['senderName']?.toString().trim() ?? ''
        : user?.displayName?.trim() ?? '';
    _businessPhone = isIncomingNotification
        ? notificationData['senderPhone']?.toString() ?? ''
        : user?.phoneNumber ?? '';
    if (isIncomingNotification) {
      _billedToName = user?.displayName?.trim() ?? '';
      _billedToPhone = user?.phoneNumber ?? '';
    }
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
        final profileName = (profile?['displayName'] ?? profile?['name'] ?? '')
            .toString()
            .trim();
        final profilePhone = (profile?['phoneNumber'] ?? '').toString();
        if (!widget.isLocalTransaction && widget.notification != null) {
          if (_billedToName.isEmpty) _billedToName = profileName;
          if (_billedToPhone.isEmpty) _billedToPhone = profilePhone;
        } else {
          if (profileName.isNotEmpty) _businessName = profileName;
          if (profilePhone.isNotEmpty) _businessPhone = profilePhone;
          _businessAddress =
              (profile?['businessAddress'] ?? '').toString().trim();
        }
      });
    } catch (error) {
      debugPrint('Failed to load receipt business profile: $error');
    }
  }

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

  void _onEditPressed(BuildContext context) {
    Navigator.of(context).pop(); // Close dialog first

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

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final db = Provider.of<DatabaseService>(context, listen: false);
    final targetAccount =
        widget.account ?? db.getAccount(widget.transaction.accountId);

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
              // Dialog Header with Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isUrdu ? 'بل کی رسید' : 'Transaction Receipt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily,
                      ),
                    ),
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

              // Printable / Screenshot Area
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: ReceiptWidget(
                      transaction: widget.transaction,
                      account: targetAccount,
                      businessName: _businessName,
                      businessPhone: _businessPhone,
                      businessAddress: _businessAddress,
                      billedToName: _billedToName,
                      billedToPhone: _billedToPhone,
                      isIncomingReceipt: !widget.isLocalTransaction &&
                          widget.notification != null,
                    ),
                  ),
                ),
              ),

              // Action Buttons Section
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Add to Khata Button (if notification transaction)
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

                    // Action buttons row
                    Row(
                      children: [
                        // Local transaction: Show Edit + Share
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
                              onPressed: _isSharing
                                  ? null
                                  : () => _shareReceipt(isUrdu),
                              icon: PhosphorIcons.shareNetwork(),
                              color: AppTheme.themeColor,
                              size: AppButtonSize.small,
                            ),
                          ),
                        ]
                        // Incoming / Remote transaction: NO Edit button!
                        else ...[
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
                          if (widget.showDeleteButton)
                            const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              text: isUrdu ? 'شیئر کریں' : 'Share',
                              onPressed: _isSharing
                                  ? null
                                  : () => _shareReceipt(isUrdu),
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
