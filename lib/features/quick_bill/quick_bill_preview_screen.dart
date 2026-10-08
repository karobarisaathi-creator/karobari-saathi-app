import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
import 'package:account_app/features/accounts/transaction_receipt_screen.dart';
import 'quick_bill_item_selection_screen.dart';
import 'widgets/customer_picker_sheet.dart';

enum _PayMode { full, partial, none }

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
  _PayMode _mode = _PayMode.full;
  final TextEditingController _partialController = TextEditingController();
  Account? _selectedAccount;
  bool _isCashCustomer = true;
  bool _saving = false;
  bool _didInitializeEditState = false;
  bool _didInitializeBillNumber = false;

  @override
  void initState() {
    super.initState();
    final original = widget.transactionToEdit;
    _transactionId =
        original?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final existingBillNumber = original?.referenceNumber?.trim() ?? '';
    final billNumber = existingBillNumber.isNotEmpty
        ? existingBillNumber
        : 'QB-$_transactionId';
    _billNumberController = TextEditingController(text: billNumber);
  }

  double get _total => widget.lines.fold<double>(0, (s, l) => s + l.total);

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

  double get _pendingAmount => (_total - _receivedAmount).clamp(0, _total);

  @override
  void dispose() {
    _partialController.dispose();
    _billNumberController.dispose();
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
      _billNumberController.text = nextNumber;
    }
  }

  Future<void> _pickCustomer() async {
    final result = await showCustomerPickerSheet(context);
    if (result == null) return;
    setState(() {
      _isCashCustomer = false;
      _selectedAccount = result;
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

    for (final line in widget.lines) {
      if (line.stockItemId == null) continue;
      final stockItem = stockService.items
          .where((item) => item.id == line.stockItemId)
          .firstOrNull;
      if (stockItem == null) {
        AppToast.warning(
          context,
          isUrdu
              ? 'منتخب اسٹاک آئٹم اب دستیاب نہیں۔ آئٹمز دوبارہ منتخب کریں۔'
              : 'A selected stock item is no longer available. Please select items again.',
        );
        return;
      }
      if (!stockItem.trackStock || !stockItem.stopWhenOut) {
        continue;
      }
      final currentStock = stockService.availableStockForTransaction(
        line.stockItemId!,
        excludingTransactionId: widget.transactionToEdit?.id,
      );
      if (line.quantity > currentStock) {
        AppToast.warning(
          context,
          isUrdu
              ? 'اسٹاک بدل چکا ہے۔ دستیاب مقدار ${currentStock.toStringAsFixed(1)} ہے۔'
              : 'Stock changed. Only ${currentStock.toStringAsFixed(1)} is available.',
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);

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
      final transaction = Transaction(
        id: originalTransaction?.id ?? _transactionId,
        accountId: account.id,
        amount: _total,
        type: 'income',
        category: isUrdu ? 'فروخت' : 'Sale',
        description: isUrdu ? 'فوری بل' : 'Quick bill',
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
        referenceNumber: _billNumberController.text.trim(),
        professionId: originalTransaction?.professionId,
        professionName: originalTransaction?.professionName,
        partnershipId: originalTransaction?.partnershipId,
        voiceNote: originalTransaction?.voiceNote,
        items: items,
      );

      if (originalTransaction == null) {
        await databaseService.addTransaction(transaction);
        await BillNumbering.saveNextNumber(
          databaseService,
          _billNumberController.text,
        );
      } else {
        await databaseService.updateTransaction(transaction);
      }

      if (!mounted) return;

      if (_pendingAmount > 0 &&
          !_isCashCustomer &&
          _selectedAccount != null &&
          account.id != QuickBillConstants.cashCustomerAccountId &&
          _selectedAccount!.phone.isNotEmpty) {
        final notifService =
            Provider.of<NotificationService>(context, listen: false);
        await notifService.notifyPartyByPhone(
          partyPhoneNumber: _selectedAccount!.phone,
          amount: _total,
          transactionType: 'income',
          description:
              isUrdu ? 'فوری بل' : 'Quick Bill',
          items: items.map((i) => i.toMap()).toList(),
          receivedAmount: _receivedAmount,
          pendingAmount: _pendingAmount,
          transactionId: transaction.id,
        );
      }

      if (!mounted) return;
      widget.onBillCompleted?.call();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => TransactionReceiptScreen(transaction: transaction)),
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
        elevation: 0,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isUrdu ? 'بل نمبر' : 'Bill number',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: TextField(
                                controller: _billNumberController,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontFamily: '',
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  hintText: isUrdu
                                      ? 'بل نمبر درج کریں'
                                      : 'Enter bill number',
                                  hintStyle: const TextStyle(
                                    fontFamily: '',
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Text(
                          isUrdu ? 'آئٹمز' : 'Items',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 11,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...widget.lines.map((l) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.name,
                                        style: TextStyle(
                                          fontFamily: fontFamily,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text.rich(
                                        TextSpan(
                                          text:
                                              '${l.quantity.toStringAsFixed(l.quantity == l.quantity.roundToDouble() ? 0 : 1)} ${l.unit ?? ""} × ${l.rate.toStringAsFixed(0)}',
                                        ),
                                        style: const TextStyle(
                                          fontFamily: '',
                                          fontSize: 11,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    l.total.toStringAsFixed(0),
                                    style: const TextStyle(
                                      fontFamily: '',
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isUrdu ? 'کل رقم' : 'Total',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              _total.toStringAsFixed(0),
                              style: const TextStyle(
                                fontFamily: '',
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        if (_mode == _PayMode.partial) ...[
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isUrdu ? 'گاہک نے دیے' : 'Customer paid',
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _partialController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: const InputDecoration(
                                    hintText: '0',
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              '${isUrdu ? 'باقی ادھار میں شامل ہوگا' : 'Remaining due'}: ${_pendingAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_mode != _PayMode.full) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      isUrdu ? 'پارٹی منتخب کریں' : 'Select party',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedAccount != null && !_isCashCustomer)
                    PartyCard(
                      party: _selectedAccount!,
                      onView: _pickCustomer,
                      onMessage: () {},
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: InkWell(
                        onTap: _pickCustomer,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black26,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.userPlus(),
                                size: 16,
                                color: AppTheme.darkColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isUrdu
                                      ? 'ادھار کے لیے پارٹی منتخب کریں'
                                      : 'Choose a party for credit',
                                  style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: 13,
                                    color: AppTheme.darkColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    _mode == _PayMode.full
                        ? (isUrdu
                            ? 'پوری رقم وصول شمار ہوگی'
                            : 'The full amount counts as received')
                        : _mode == _PayMode.none
                            ? '${isUrdu ? "پوری رقم ادھار میں شامل ہوگی" : "The full amount goes to credit"}: ${_total.toStringAsFixed(0)}'
                            : '${isUrdu ? "باقی ادھار میں شامل ہوگا" : "Remaining goes to credit"}: ${_pendingAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isUrdu ? 'ادائیگی' : 'Payment',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _payTab(
                        isUrdu ? 'پورا وصول' : 'Fully received',
                        _PayMode.full,
                        fontFamily,
                      ),
                      const SizedBox(width: 8),
                      _payTab(
                        isUrdu ? 'کچھ ادھار' : 'Partly credit',
                        _PayMode.partial,
                        fontFamily,
                      ),
                      const SizedBox(width: 8),
                      _payTab(
                        isUrdu ? 'مکمل ادھار' : 'Fully credit',
                        _PayMode.none,
                        fontFamily,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185FA5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _saving
                            ? (isUrdu ? 'محفوظ ہو رہا ہے...' : 'Saving...')
                            : widget.transactionToEdit != null
                                ? (isUrdu
                                    ? 'تبدیلیاں محفوظ کریں'
                                    : 'Save changes')
                                : (isUrdu
                                    ? 'او کے — رسید بنائیں'
                                    : 'OK — create receipt'),
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payTab(String label, _PayMode mode, [String? fontFamily]) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppTheme.darkColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border:
                active ? null : Border.all(color: Colors.black12, width: 0.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12.5,
              color: active ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
