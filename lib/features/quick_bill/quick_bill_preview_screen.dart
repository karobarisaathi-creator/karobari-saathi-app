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
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/features/accounts/transaction_receipt_screen.dart';
import 'quick_bill_item_selection_screen.dart';
import 'widgets/customer_picker_sheet.dart';

enum _PayMode { full, partial, none }

class QuickBillPreviewScreen extends StatefulWidget {
  final List<QuickBillCartLine> lines;
  final VoidCallback? onBillCompleted;
  const QuickBillPreviewScreen({
    super.key,
    required this.lines,
    this.onBillCompleted,
  });

  @override
  State<QuickBillPreviewScreen> createState() => _QuickBillPreviewScreenState();
}

class _QuickBillPreviewScreenState extends State<QuickBillPreviewScreen> {
  _PayMode _mode = _PayMode.full;
  final TextEditingController _partialController = TextEditingController();
  Account? _selectedAccount;
  bool _isCashCustomer = true;
  bool _saving = false;

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
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final result = await showCustomerPickerSheet(context);
    if (result == null) return;
    setState(() {
      if (result.isCashCustomer) {
        _isCashCustomer = true;
        _selectedAccount = null;
      } else {
        _isCashCustomer = false;
        _selectedAccount = result.account;
      }
    });
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final stockService = Provider.of<StockService>(context, listen: false);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    for (final line in widget.lines) {
      if (line.stockItemId == null) continue;
      final currentStock = stockService.availableStockForTransaction(
        line.stockItemId!,
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
      if (_isCashCustomer || _selectedAccount == null) {
        account =
            await QuickBillConstants.ensureCashCustomerAccount(databaseService);
      } else {
        account = _selectedAccount!;
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
      final transaction = Transaction(
        id: now.millisecondsSinceEpoch.toString(),
        accountId: account.id,
        amount: _total,
        type: 'income',
        category: isUrdu ? 'فروخت' : 'Sale',
        description: isUrdu ? 'فوری بل' : 'Quick bill',
        date: now,
        quantity: items.length,
        rate: 0,
        receivedAmount: _receivedAmount,
        pendingAmount: _pendingAmount,
        paymentMethod: _mode == _PayMode.full
            ? 'cash'
            : (_mode == _PayMode.none ? 'credit' : 'mixed'),
        isPending: _pendingAmount > 0,
        createdAt: now,
        updatedAt: now,
        items: items,
      );

      await databaseService.addTransaction(transaction);

      if (!mounted) return;

      if (_pendingAmount > 0 &&
          !_isCashCustomer &&
          _selectedAccount != null &&
          _selectedAccount!.phone.isNotEmpty) {
        final notifService =
            Provider.of<NotificationService>(context, listen: false);
        await notifService.notifyPartyByPhone(
          partyPhoneNumber: _selectedAccount!.phone,
          amount: _pendingAmount,
          transactionType: 'income',
          description:
              isUrdu ? 'فوری بل (بقایا ادھار)' : 'Quick Bill (Credit Balance)',
          items: items.map((i) => i.toMap()).toList(),
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
          isUrdu ? 'بل محفوظ نہیں ہو سکا: $error' : 'Could not save bill: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F5),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.darkColor, Color(0xFF0F2A40)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(PhosphorIcons.arrowRight(),
                        color: Colors.white70, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      isUrdu ? 'بل کا جائزہ' : 'Bill review',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isUrdu ? 'آئٹمز' : 'Items',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 6),
                      ...widget.lines.map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      '${l.quantity.toStringAsFixed(l.quantity == l.quantity.roundToDouble() ? 0 : 1)} ${l.unit ?? ""} × ${l.rate.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.black54),
                                    ),
                                  ],
                                ),
                                Text(l.total.toStringAsFixed(0),
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          )),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isUrdu ? 'کل رقم' : 'Total',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(_total.toStringAsFixed(0),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(isUrdu ? 'گاہک' : 'Customer',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
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
                          style: BorderStyle.solid),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.userPlus(),
                            size: 16, color: AppTheme.darkColor),
                        const SizedBox(width: 8),
                        Text(
                          _isCashCustomer
                              ? (isUrdu ? 'نقد گاہک' : 'Cash customer')
                              : (_selectedAccount?.name ??
                                  (isUrdu
                                      ? 'پارٹی چنیں یا نقد گاہک رکھیں'
                                      : 'Pick a party or keep cash customer')),
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.darkColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(isUrdu ? 'ادائیگی' : 'Payment',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _payTab(isUrdu ? 'نقد — پورا وصول' : 'Cash — paid in full',
                        _PayMode.full),
                    const SizedBox(width: 8),
                    _payTab(isUrdu ? 'کچھ ادھار' : 'Partly credit',
                        _PayMode.partial),
                    const SizedBox(width: 8),
                    _payTab(
                        isUrdu ? 'مکمل ادھار' : 'Fully credit', _PayMode.none),
                  ],
                ),
                if (_mode == _PayMode.partial) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isUrdu ? 'گاہک نے دیے' : 'Customer paid',
                            style: const TextStyle(fontSize: 13)),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _partialController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.left,
                            decoration: const InputDecoration(
                                hintText: '0', isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _mode == _PayMode.full
                      ? (isUrdu
                          ? 'پوری رقم وصول شمار ہوگی'
                          : 'The full amount counts as received')
                      : _mode == _PayMode.none
                          ? '${isUrdu ? "پوری رقم ادھار میں شامل ہوگی" : "The full amount goes to credit"}: ${_total.toStringAsFixed(0)}'
                          : '${isUrdu ? "باقی ادھار میں شامل ہوگا" : "Remaining goes to credit"}: ${_pendingAmount.toStringAsFixed(0)}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF633806)),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
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
                        : (isUrdu
                            ? 'او کے — رسید بنائیں'
                            : 'OK — create receipt'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payTab(String label, _PayMode mode) {
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
                fontSize: 12.5, color: active ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}
