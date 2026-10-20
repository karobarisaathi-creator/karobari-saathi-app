// lib/features/quick_bill/quick_bill_preview_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/utils/bill_numbering.dart';
import 'package:account_app/core/utils/receipt_dialog_helper.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'quick_bill_item_selection_screen.dart';
import 'widgets/customer_picker_sheet.dart';

enum _PayMode { full, partial, none }

enum _DiscountType { percentage, amount }

class QuickBillPreviewScreen extends StatefulWidget {
  final List<QuickBillCartLine> lines;
  final VoidCallback? onBillCompleted;
  final Transaction? transactionToEdit;

  const QuickBillPreviewScreen({
    super.key,
    required this.lines,
    this.onBillCompleted,
    this.transactionToEdit,
  });

  @override
  State<QuickBillPreviewScreen> createState() => _QuickBillPreviewScreenState();
}

class _QuickBillPreviewScreenState extends State<QuickBillPreviewScreen> {
  late final String _transactionId;
  late final TextEditingController _billNumberController;
  final TextEditingController _partialController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _discountReasonController =
      TextEditingController();

  _PayMode _mode = _PayMode.full;
  _DiscountType _discountType = _DiscountType.percentage;
  Account? _selectedAccount;
  bool _isCashCustomer = true;
  bool _saving = false;
  bool _didInitializeEditState = false;
  bool _didInitializeBillNumber = false;
  bool _isDiscountExpanded = false;

  // Discount presets
  static const List<double> _discountPresets = [0, 5, 10, 15, 20, 25, 50];

  @override
  void initState() {
    super.initState();
    final original = widget.transactionToEdit;
    _transactionId =
        original?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final existingBillNumber = original?.referenceNumber?.trim() ?? '';
    final billNum = existingBillNumber.isNotEmpty
        ? (existingBillNumber.startsWith('QB-') ? existingBillNumber : 'QB-$existingBillNumber')
        : 'QB-1';
    _billNumberController = TextEditingController(text: billNum);

    // Initialize discount from existing transaction
    if (original != null && original.discountAmount > 0) {
      // If discount percent is available, use percentage mode
      if (original.discountPercent != null && original.discountPercent! > 0) {
        _discountType = _DiscountType.percentage;
        _discountController.text = original.discountPercent!.toStringAsFixed(0);
      } else {
        _discountType = _DiscountType.amount;
        _discountController.text = original.discountAmount.toStringAsFixed(0);
      }
      _discountReasonController.text = original.discountReason ?? '';
    }
  }

  // ═════════════════════════════════════════════════════════
  // CALCULATIONS
  // ═════════════════════════════════════════════════════════

  /// Subtotal (before discount)
  double get _subtotal => widget.lines.fold<double>(0, (s, l) => s + l.total);

  /// Discount value entered by user
  double get _discountInputValue =>
      double.tryParse(_discountController.text.trim()) ?? 0;

  /// Discount amount in Rs
  double get _discountAmount {
    final value = _discountInputValue;
    if (value <= 0) return 0;

    if (_discountType == _DiscountType.percentage) {
      // Clamp to 0-100
      final percent = value.clamp(0, 100);
      return (_subtotal * percent) / 100;
    } else {
      // Amount — clamp to subtotal
      return value.clamp(0, _subtotal);
    }
  }

  /// Discount percentage (for display)
  double get _discountPercent {
    if (_discountType == _DiscountType.percentage) {
      return _discountInputValue.clamp(0, 100);
    }
    if (_subtotal <= 0) return 0;
    return (_discountAmount / _subtotal) * 100;
  }

  /// Total after discount
  double get _total => (_subtotal - _discountAmount).clamp(0, _subtotal);

  /// Amount received from customer
  double get _receivedAmount {
    switch (_mode) {
      case _PayMode.full:
        return _total;
      case _PayMode.none:
        return 0;
      case _PayMode.partial:
        final given = double.tryParse(_partialController.text) ?? 0;
        return given.clamp(0, _total);
    }
  }

  /// Amount pending (credit)
  double get _pendingAmount => (_total - _receivedAmount).clamp(0, _total);

  // ═════════════════════════════════════════════════════════

  @override
  void dispose() {
    _partialController.dispose();
    _billNumberController.dispose();
    _discountController.dispose();
    _discountReasonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final transaction = widget.transactionToEdit;
    if (!_didInitializeBillNumber) {
      _didInitializeBillNumber = true;
      if (transaction == null) {
        _loadNextBillNumber(
          Provider.of<DatabaseService>(context, listen: false),
        );
      }
    }
    if (_didInitializeEditState || transaction == null) return;

    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final cashCustomerId = QuickBillConstants.cashCustomerAccountId;
    _isCashCustomer = transaction.accountId == cashCustomerId;
    _selectedAccount = _isCashCustomer
        ? null
        : databaseService.getAccount(transaction.accountId);

    if (transaction.pendingAmount <= 0) {
      _mode = _PayMode.full;
    } else if (transaction.receivedAmount <= 0) {
      _mode = _PayMode.none;
    } else {
      _mode = _PayMode.partial;
      _partialController.text = transaction.receivedAmount.toStringAsFixed(0);
    }
    _didInitializeEditState = true;
  }

  void _loadNextBillNumber(DatabaseService databaseService) {
    final nextNumber = BillNumbering.loadNextNumber(databaseService);
    if (nextNumber != null) {
      final billNum = nextNumber.startsWith('QB-') ? nextNumber : 'QB-$nextNumber';
      _billNumberController.text = billNum;
    }
  }

  void _updateDiscountState(
    VoidCallback update, {
    StateSetter? popupSetState,
  }) {
    setState(update);
    popupSetState?.call(() {});
  }

  void _selectDiscountPreset(
    double percent, {
    StateSetter? popupSetState,
  }) {
    _updateDiscountState(() {
      _discountType = _DiscountType.percentage;
      _discountController.text = percent.toStringAsFixed(0);
    }, popupSetState: popupSetState);
  }

  // (removed _showDiscountDialog in favor of inline expansion)

  Future<void> _pickCustomer() async {
    final result = await showCustomerPickerSheet(context);
    if (result == null) return;
    if (!result.isCashCustomer && result.account == null) return;
    setState(() {
      _isCashCustomer = result.isCashCustomer;
      _selectedAccount = result.account;
    });
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final isUrdu = languageService.isUrdu;
    if (_billNumberController.text.trim().isEmpty) {
      AppToast.warning(
        context,
        isUrdu ? 'بل نمبر درج کریں۔' : 'Enter a bill number.',
      );
      return;
    }
    if (_pendingAmount > 0 && (_isCashCustomer || _selectedAccount == null)) {
      AppToast.warning(
        context,
        isUrdu
            ? 'ادھار یا جزوی وصولی کے لیے پارٹی منتخب کریں۔'
            : 'Select a party when any bill amount remains due.',
      );
      return;
    }

    final stockService = Provider.of<StockService>(context, listen: false);
    final previouslyLinkedItemIds = widget.transactionToEdit?.items
            .map((item) => item.stockItemId)
            .whereType<String>()
            .toSet() ??
        <String>{};

    final stockQuantities = <String, double>{};
    for (final line in widget.lines) {
      if (line.stockItemId == null) continue;
      final stockItem = stockService.items
          .where((item) => item.id == line.stockItemId)
          .firstOrNull;
      if (stockItem == null ||
          (stockItem.isArchived &&
              !previouslyLinkedItemIds.contains(stockItem.id))) {
        AppToast.warning(
          context,
          isUrdu
              ? 'منتخب اسٹاک آئٹم اب دستیاب نہیں۔ آئٹمز دوبارہ منتخب کریں۔'
              : 'A selected stock item is no longer available. Please select items again.',
        );
        return;
      }
      if (!stockItem.trackStock) continue;
      stockQuantities.update(
        stockItem.id,
        (quantity) => quantity + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    for (final entry in stockQuantities.entries) {
      final stockItem =
          stockService.items.firstWhere((item) => item.id == entry.key);
      final currentStock = stockService.availableStockForTransaction(
        stockItem.id,
        excludingTransactionId: widget.transactionToEdit?.id,
      );
      if (!StockService.canSellQuantity(
        availableStock: currentStock,
        quantity: entry.value,
        stopWhenOut: stockItem.stopWhenOut,
      )) {
        AppToast.warning(
          context,
          isUrdu
              ? '${stockItem.name} کے لیے اسٹاک بدل چکا ہے۔ دستیاب مقدار ${currentStock.toStringAsFixed(1)} ہے۔'
              : 'Stock changed for ${stockItem.name}. Only ${currentStock.toStringAsFixed(1)} is available.',
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      var stockSynced = true;

      Account account;
      if (_pendingAmount <= 0 && _isCashCustomer) {
        account =
            await QuickBillConstants.ensureCashCustomerAccount(databaseService);
      } else if (_selectedAccount != null) {
        account = _selectedAccount!;
      } else {
        throw StateError('A party must be selected when bill payment is due.');
      }

      final items = widget.lines
          .map((l) => TransactionItem(
                description: l.name,
                quantity: l.quantity,
                rate: l.rate,
                total: l.total,
                unit: l.unit,
                stockItemId: l.stockItemId,
              ))
          .toList();

      final now = DateTime.now();
      final originalTransaction = widget.transactionToEdit;

      // Create item names summary for description
      final itemNames = widget.lines
          .map((l) => l.name.trim())
          .where((name) => name.isNotEmpty)
          .join(', ');
      final defaultDesc = isUrdu ? 'فوری بل' : 'Quick bill';
      final tag = isUrdu ? '(فوری بل)' : '(Quick bill)';
      final transactionDescription =
          itemNames.isNotEmpty ? '$itemNames $tag' : defaultDesc;

      final transaction = Transaction(
        id: originalTransaction?.id ?? _transactionId,
        accountId: account.id,
        amount: _pendingAmount, // ← Effective amount (pending balance)
        subtotal: _subtotal, // ← NEW: Before discount
        discountAmount: _discountAmount, // ← NEW
        discountPercent:
            _discountType == _DiscountType.percentage ? _discountPercent : null,
        discountReason: _discountReasonController.text.trim().isEmpty
            ? null
            : _discountReasonController.text.trim(),
        type: 'income',
        category: isUrdu ? 'فروخت' : 'Sale',
        description: transactionDescription,
        date: originalTransaction?.date ?? now,
        quantity: items.length,
        rate: 0,
        receivedAmount: _receivedAmount,
        pendingAmount: _pendingAmount,
        paymentMethod: _mode == _PayMode.full
            ? 'cash'
            : (_mode == _PayMode.none ? 'credit' : 'mixed'),
        isPending: _pendingAmount > 0,
        createdAt: originalTransaction?.createdAt ?? now,
        updatedAt: now,
        billImage: originalTransaction?.billImage,
        referenceNumber: () {
          final raw = _billNumberController.text.trim();
          return raw.isEmpty
              ? 'QB-1'
              : (raw.startsWith('QB-') ? raw : 'QB-$raw');
        }(),
        professionId: originalTransaction?.professionId,
        professionName: originalTransaction?.professionName,
        partnershipId: originalTransaction?.partnershipId,
        voiceNote: originalTransaction?.voiceNote,
        receiptFromCounterparty:
            originalTransaction?.receiptFromCounterparty ?? false,
        items: items,
      );

      final followUpFailures = <String>[];
      if (originalTransaction == null) {
        stockSynced = await databaseService.addTransaction(transaction);
        try {
          final raw = _billNumberController.text.trim();
          final fullNum =
              raw.isEmpty ? 'QB-1' : (raw.startsWith('QB-') ? raw : 'QB-$raw');
          await BillNumbering.saveNextNumber(
            databaseService,
            fullNum,
          );
        } catch (error) {
          followUpFailures.add(
            isUrdu
                ? 'اگلا بل نمبر محفوظ نہیں ہو سکا: $error'
                : 'Could not save the next bill number: $error',
          );
        }
      } else {
        stockSynced = await databaseService.updateTransaction(transaction);
      }

      if (!stockSynced && mounted) {
        final retry = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: UrduAwareText(
                isUrdu ? 'اسٹاک اپڈیٹ نہیں ہوا' : 'Stock was not updated'),
            content: UrduAwareText(
              isUrdu
                  ? 'بل محفوظ ہوگیا ہے، مگر اس کا اسٹاک ریکارڈ اپڈیٹ نہیں ہوا۔ دوبارہ کوشش کریں؟'
                  : 'The bill was saved, but its stock movement was not updated. Retry now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: UrduAwareText(isUrdu ? 'بعد میں' : 'Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: UrduAwareText(isUrdu ? 'دوبارہ کوشش' : 'Retry'),
              ),
            ],
          ),
        );
        if (retry == true) {
          stockSynced =
              await databaseService.retryTransactionStockSync(transaction);
        }
        if (!stockSynced) {
          followUpFailures.add(
            isUrdu
                ? 'اس بل کا اسٹاک ریکارڈ ابھی بھی اپڈیٹ نہیں ہوا؛ نیٹ ورک بحال ہونے پر اسی بل کو دوبارہ محفوظ کریں۔'
                : 'Stock for this bill is still not updated. Re-save the bill after the network is restored.',
          );
        }
      }

      if (!mounted) return;

      if (_pendingAmount > 0 &&
          !_isCashCustomer &&
          _selectedAccount != null &&
          account.id != QuickBillConstants.cashCustomerAccountId &&
          _selectedAccount!.phone.isNotEmpty) {
        try {
          final notifService =
              Provider.of<NotificationService>(context, listen: false);
          await notifService.notifyPartyByPhone(
            partyPhoneNumber: _selectedAccount!.phone,
            amount: _total,
            transactionType: 'income',
            category: transaction.category,
            paymentMethod: transaction.paymentMethod,
            description: transactionDescription,
            items: items.map((i) => i.toMap()).toList(),
            receivedAmount: _receivedAmount,
            pendingAmount: _pendingAmount,
            transactionId: transaction.id,
            transactionDate: transaction.date,
            referenceNumber: transaction.referenceNumber,
            subtotal: transaction.subtotal,
            discountAmount: transaction.discountAmount,
            discountPercent: transaction.discountPercent,
            discountReason: transaction.discountReason,
          );
        } catch (error) {
          followUpFailures.add(
            isUrdu
                ? 'پارٹی کو اطلاع نہیں بھیجی جا سکی: $error'
                : 'Could not notify the party: $error',
          );
        }
      }

      if (!mounted) return;
      if (followUpFailures.isNotEmpty) {
        AppToast.warning(
          context,
          isUrdu
              ? 'بل محفوظ ہو گیا، لیکن کچھ اضافی کام مکمل نہیں ہوئے۔ ${followUpFailures.join(' ')}'
              : 'Bill saved, but some follow-up tasks failed. ${followUpFailures.join(' ')}',
        );
      }
      widget.onBillCompleted?.call();
      Navigator.of(context).pop();
      ReceiptDialogHelper.showReceiptDialog(
        context,
        transaction: transaction,
        account: _selectedAccount,
        isLocalTransaction: true,
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'بل محفوظ نہیں ہو سکا: $error'
              : 'Could not save bill: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: widget.transactionToEdit != null
            ? (isUrdu ? 'بل میں ترمیم' : 'Edit bill')
            : (isUrdu ? 'بل کا جائزہ' : 'Bill review'),
        showBackButton: true,
        backgroundColor: AppTheme.darkColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                // 1. BILL NUMBER CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildBillNumberCard(isUrdu, fontFamily),
                ),
                const SizedBox(height: 12),

                // 2. PARTY SELECTION CARD (if _mode != _PayMode.full)
                if (_mode != _PayMode.full) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          isUrdu ? 'پارٹی منتخب کریں' : 'Select party',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedAccount != null && !_isCashCustomer)
                          PartyCard(
                            party: _selectedAccount!,
                            onView: _pickCustomer,
                            onMessage: () {},
                            showActions: false,
                            margin: EdgeInsets.zero,
                          )
                        else
                          _buildPickPartyPlaceholder(isUrdu, fontFamily),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. MAIN ITEMS CARD (Items + Totals + Customer Paid at bottom)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildMainBillCard(isUrdu, fontFamily),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _buildBottomSection(isUrdu, fontFamily),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Bill Number Card
  // ═════════════════════════════════════════════════════════
  Widget _buildBillNumberCard(bool isUrdu, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E5EC), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.receipt(),
            size: 14,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          UrduAwareText(
            isUrdu ? 'بل نمبر' : 'Bill number',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          _BillNumberFieldWidget(
            controller: _billNumberController,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // MAIN BILL CARD — Items + Subtotal + Discount + Total + Customer Paid
  // ═════════════════════════════════════════════════════════
  Widget _buildMainBillCard(bool isUrdu, String? fontFamily) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E5EC), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Items list
          ...widget.lines.map((line) => _buildItemRow(line, fontFamily)),

          // ═══ TOTALS SECTION (Subtotal + Discount + Total) ═══
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              border:
                  Border(top: BorderSide(color: Color(0xFFE1E5EC), width: 2)),
            ),
            child: Column(
              children: [
                // Subtotal
                _buildTotalLine(
                  label: isUrdu ? 'کل رقم' : 'Subtotal',
                  value: Formatters.formatAmount(_subtotal),
                  fontFamily: fontFamily,
                ),

                // Discount (if > 0)
                if (_discountAmount > 0) _buildDiscountLine(isUrdu, fontFamily),

                // Grand Total
                _buildGrandTotalLine(isUrdu, fontFamily),

                // Customer Paid Row (if _mode == _PayMode.partial) — AT THE VERY BOTTOM OF TOTALS
                if (_mode == _PayMode.partial) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFEEF1F5))),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.money(),
                          size: 14,
                          color: AppTheme.themeColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: UrduAwareText(
                            isUrdu ? 'گاہک نے دیے' : 'Customer paid',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFC9D0D8), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _partialController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.start,
                                  textDirection: TextDirection.ltr,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.darkColor,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 4),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: '0',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const UrduAwareText(
                                'Rs',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(QuickBillCartLine line, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  line.name,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 1)} ${line.unit ?? ""} × Rs ${line.rate.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          UrduAwareText(
            Formatters.formatAmount(line.total),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalLine({
    required String label,
    required String value,
    String? fontFamily,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                fontFamily: fontFamily,
              ),
            ),
          ),
          UrduAwareText(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountLine(bool isUrdu, String? fontFamily) {
    final displayPercent = _discountType == _DiscountType.percentage
        ? _discountPercent.toStringAsFixed(0)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.tag(),
            size: 13,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: UrduAwareText(
              displayPercent != null
                  ? (isUrdu
                      ? 'رعایت ($displayPercent%)'
                      : 'Discount ($displayPercent%)')
                  : (isUrdu ? 'رعایت' : 'Discount'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFD97706),
                fontFamily: fontFamily,
              ),
            ),
          ),
          UrduAwareText(
            '− ${Formatters.formatAmount(_discountAmount)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFFD97706),
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotalLine(bool isUrdu, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.incomeColor.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(
            color: AppTheme.incomeColor.withValues(alpha: 0.20),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: UrduAwareText(
              isUrdu ? 'کل خالص' : 'TOTAL',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
                letterSpacing: -0.3,
              ),
            ),
          ),
          UrduAwareText(
            Formatters.formatAmount(_total),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.incomeColor,
              letterSpacing: -0.6,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Discount Edit Card
  // ═════════════════════════════════════════════════════════
  Widget _buildDiscountCard(
    bool isUrdu,
    String? fontFamily, {
    StateSetter? popupSetState,
  }) {
    return Column(
      children: [
        // Type toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDiscountTypeBtn(
                    label: isUrdu ? 'فیصد (%)' : 'Percentage',
                    icon: PhosphorIcons.percent(),
                    isActive: _discountType == _DiscountType.percentage,
                    onTap: () => _updateDiscountState(
                      () => _discountType = _DiscountType.percentage,
                      popupSetState: popupSetState,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDiscountTypeBtn(
                    label: isUrdu ? 'رقم (Rs)' : 'Amount (Rs)',
                    icon: PhosphorIcons.money(),
                    isActive: _discountType == _DiscountType.amount,
                    onTap: () => _updateDiscountState(
                      () => _discountType = _DiscountType.amount,
                      popupSetState: popupSetState,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Presets (only in percentage mode)
        if (_discountType == _DiscountType.percentage)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: _discountPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final preset = _discountPresets[index];
                final isActive = _discountInputValue == preset &&
                    _discountType == _DiscountType.percentage;
                return GestureDetector(
                  onTap: () => _selectDiscountPreset(
                    preset,
                    popupSetState: popupSetState,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFD97706) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFD97706)
                            : const Color(0xFFD97706).withValues(alpha: 0.30),
                        width: 1.5,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD97706)
                                    .withValues(alpha: 0.30),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: UrduAwareText(
                      '${preset.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color:
                            isActive ? Colors.white : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Custom input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIcons.pencilSimple(),
                    size: 13,
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  UrduAwareText(
                    isUrdu ? 'اپنی مرضی' : 'Custom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD97706),
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _discountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                onChanged: (_) => _updateDiscountState(
                  () {},
                  popupSetState: popupSetState,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD97706),
                  letterSpacing: -0.3,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFD97706),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFD97706),
                      width: 2,
                    ),
                  ),
                  hintText: '0',
                  hintStyle: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  suffixText:
                      _discountType == _DiscountType.percentage ? '%' : 'Rs',
                  suffixStyle: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountTypeBtn({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color:
                  isActive ? const Color(0xFFD97706) : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            UrduAwareText(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color:
                    isActive ? const Color(0xFFD97706) : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Bill Number Field Widget (with subtle focus background)
  // ═════════════════════════════════════════════════════════
  Widget _buildPickPartyPlaceholder(bool isUrdu, String? fontFamily) {
    return InkWell(
      onTap: _pickCustomer,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFB0B8C1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.themeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PhosphorIcons.userPlus(),
                size: 18,
                color: AppTheme.themeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    isUrdu ? 'پارٹی منتخب کریں' : 'Select a party',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  UrduAwareText(
                    isUrdu ? 'ادھار کے لیے' : 'For credit',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.arrowRight(),
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Bottom Section
  // ═════════════════════════════════════════════════════════
  Widget _buildBottomSection(bool isUrdu, String? fontFamily) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE1E5EC), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expanded discount card (opens upwards)
              if (_isDiscountExpanded) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5EC),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFD97706).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: _buildDiscountCard(isUrdu, fontFamily),
                ),
              ],

              // Discount control
              InkWell(
                onTap: () =>
                    setState(() => _isDiscountExpanded = !_isDiscountExpanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.tag(),
                        size: 14,
                        color: const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      UrduAwareText(
                        isUrdu ? 'ڈسکاونٹ' : 'Discount',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                      if (_discountAmount > 0) ...[
                        const SizedBox(width: 6),
                        UrduAwareText(
                          _discountType == _DiscountType.percentage
                              ? '${_discountPercent.toStringAsFixed(0)}%'
                              : 'Rs ${_discountAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(
                        _isDiscountExpanded
                            ? PhosphorIcons.caretUp()
                            : PhosphorIcons.caretDown(),
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Pay tabs
              Row(
                children: [
                  _buildPayTab(
                    label: isUrdu ? 'پورا وصول' : 'Fully Paid',
                    icon: PhosphorIcons.checkCircle(),
                    mode: _PayMode.full,
                    activeColor: AppTheme.incomeColor,
                    fontFamily: fontFamily,
                  ),
                  const SizedBox(width: 6),
                  _buildPayTab(
                    label: isUrdu ? 'کچھ ادھار' : 'Partly Credit',
                    icon: PhosphorIcons.clock(),
                    mode: _PayMode.partial,
                    activeColor: const Color(0xFFD97706),
                    fontFamily: fontFamily,
                  ),
                  const SizedBox(width: 6),
                  _buildPayTab(
                    label: isUrdu ? 'مکمل ادھار' : 'Fully Credit',
                    icon: PhosphorIcons.warningCircle(),
                    mode: _PayMode.none,
                    activeColor: AppTheme.expenseColor,
                    fontFamily: fontFamily,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_saving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.check_rounded, size: 18),
                      const SizedBox(width: 8),
                      UrduAwareText(
                        _saving
                            ? (isUrdu ? 'محفوظ ہو رہا ہے...' : 'Saving...')
                            : widget.transactionToEdit != null
                                ? (isUrdu
                                    ? 'تبدیلیاں محفوظ کریں'
                                    : 'Save changes')
                                : (isUrdu
                                    ? 'ٹھیک ہے — رسید بنائیں'
                                    : 'OK — create receipt'),
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayTab({
    required String label,
    required IconData icon,
    required _PayMode mode,
    required Color activeColor,
    String? fontFamily,
  }) {
    final active = _mode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? activeColor : const Color(0xFFEEF1F5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              UrduAwareText(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillNumberFieldWidget extends StatefulWidget {
  final TextEditingController controller;
  final bool isUrdu;
  final String? fontFamily;

  const _BillNumberFieldWidget({
    required this.controller,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  State<_BillNumberFieldWidget> createState() => _BillNumberFieldWidgetState();
}

class _BillNumberFieldWidgetState extends State<_BillNumberFieldWidget> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
    widget.controller.addListener(_ensurePrefix);
  }

  void _ensurePrefix() {
    final text = widget.controller.text;
    if (!text.startsWith('QB-')) {
      final newText = 'QB-$text';
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_ensurePrefix);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isFocused ? const Color(0xFFE2E8F0) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: 110,
        child: TextField(
          focusNode: _focusNode,
          controller: widget.controller,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.darkColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'QB-1',
            hintStyle: TextStyle(
              fontFamily: widget.fontFamily,
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
