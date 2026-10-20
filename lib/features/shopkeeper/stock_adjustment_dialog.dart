// lib/features/shopkeeper/stock_adjustment_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';

class StockAdjustmentDialog extends StatefulWidget {
  final StockItem item;
  final StockMovementType initialType;
  final bool? showTypeSelector;

  const StockAdjustmentDialog({
    super.key,
    required this.item,
    this.initialType = StockMovementType.adjustment,
    this.showTypeSelector,
  });

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late StockMovementType _selectedType;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedPartyId;
  bool _isSaving = false;

  bool get _isReturn =>
      _selectedType == StockMovementType.customerReturn ||
      _selectedType == StockMovementType.supplierReturn;

  String get _returnTransactionType =>
      _selectedType == StockMovementType.customerReturn ? 'income' : 'expense';

  List<model.Transaction> _matchingReturnTransactions(
    DatabaseService databaseService, {
    String? partyId,
  }) {
    final transactions = databaseService
        .getAllTransactions()
        .where(
          (transaction) =>
              transaction.type == _returnTransactionType &&
              (partyId == null || transaction.accountId == partyId) &&
              transaction.items.any(
                (line) =>
                    line.stockItemId == widget.item.id && line.quantity > 0,
              ),
        )
        .toList()
      ..sort((a, b) {
        final dateOrder = b.date.compareTo(a.date);
        return dateOrder != 0 ? dateOrder : b.createdAt.compareTo(a.createdAt);
      });
    return transactions;
  }

  double _returnableQuantity(model.Transaction transaction) {
    return transaction.items
        .where(
          (line) => line.stockItemId == widget.item.id && line.quantity > 0,
        )
        .fold<double>(0, (total, line) => total + line.quantity);
  }

  model.Transaction _reduceItemFromTransaction(
    model.Transaction transaction,
    double quantityToReturn,
  ) {
    const epsilon = 0.000001;
    var remainingToReturn = quantityToReturn;
    var removedSubtotal = 0.0;
    final updatedItemsReversed = <TransactionItem>[];

    for (final line in transaction.items.reversed) {
      if (line.stockItemId != widget.item.id ||
          line.quantity <= 0 ||
          remainingToReturn <= epsilon) {
        updatedItemsReversed.add(line);
        continue;
      }

      final removedQuantity =
          remainingToReturn < line.quantity ? remainingToReturn : line.quantity;
      final oldLineTotal =
          line.total > 0 ? line.total : line.quantity * line.rate;
      final remainingQuantity = line.quantity - removedQuantity;
      final remainingLineTotal = remainingQuantity <= epsilon
          ? 0.0
          : oldLineTotal * (remainingQuantity / line.quantity);
      removedSubtotal += oldLineTotal - remainingLineTotal;
      remainingToReturn -= removedQuantity;

      if (remainingQuantity > epsilon) {
        updatedItemsReversed.add(
          TransactionItem(
            description: line.description,
            quantity: remainingQuantity,
            rate: line.rate,
            total: remainingLineTotal,
            unit: line.unit,
            stockItemId: line.stockItemId,
          ),
        );
      }
    }

    if (remainingToReturn > epsilon) {
      throw StateError(
          'Return quantity exceeds the latest transaction quantity.');
    }

    final updatedItems = updatedItemsReversed.reversed.toList();
    final oldSubtotal = transaction.subtotal > 0
        ? transaction.subtotal
        : transaction.items.fold<double>(
            0,
            (total, line) =>
                total +
                (line.total > 0 ? line.total : line.quantity * line.rate),
          );
    final discountReduction = oldSubtotal > 0 && transaction.discountAmount > 0
        ? (transaction.discountAmount * (removedSubtotal / oldSubtotal))
            .clamp(0.0, transaction.discountAmount)
            .toDouble()
        : 0.0;
    final amountReduction = removedSubtotal - discountReduction;
    final updatedAmount =
        (transaction.amount - amountReduction).clamp(0.0, double.infinity);
    final updatedSubtotal =
        (oldSubtotal - removedSubtotal).clamp(0.0, double.infinity);
    final updatedDiscount = (transaction.discountAmount - discountReduction)
        .clamp(0.0, double.infinity);
    final updatedPending = (updatedAmount - transaction.receivedAmount)
        .clamp(0.0, double.infinity);

    return model.Transaction(
      id: transaction.id,
      accountId: transaction.accountId,
      amount: updatedAmount,
      type: transaction.type,
      category: transaction.category,
      description: transaction.description,
      date: transaction.date,
      billImage: transaction.billImage,
      quantity: transaction.quantity,
      rate: transaction.rate,
      receivedAmount: transaction.receivedAmount,
      pendingAmount: updatedPending,
      referenceNumber: transaction.referenceNumber,
      paymentMethod: transaction.paymentMethod,
      isPending: updatedPending > epsilon,
      createdAt: transaction.createdAt,
      updatedAt: DateTime.now(),
      professionId: transaction.professionId,
      professionName: transaction.professionName,
      partnershipId: transaction.partnershipId,
      voiceNote: transaction.voiceNote,
      items: updatedItems,
      subtotal: updatedSubtotal,
      discountAmount: updatedDiscount,
      discountPercent: transaction.discountPercent,
      discountReason: transaction.discountReason,
      receiptFromCounterparty: transaction.receiptFromCounterparty,
    );
  }

  bool get _shouldShowTypeSelector {
    return widget.showTypeSelector ??
        (widget.initialType == StockMovementType.customerReturn ||
            widget.initialType == StockMovementType.supplierReturn);
  }

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    if (_selectedType == StockMovementType.adjustment) {
      final stockService = Provider.of<StockService>(context, listen: false);
      _qtyController.text =
          stockService.calculateCurrentStock(widget.item.id).toString();
    }
    final initialPrice = (_selectedType == StockMovementType.sale &&
            widget.item.sellingPrice > 0)
        ? widget.item.sellingPrice
        : widget.item.purchasePrice;
    _priceController.text = initialPrice > 0 ? initialPrice.toString() : '';
    _qtyController.addListener(_onQtyChanged);
  }

  void _onQtyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onQtyChanged);
    _qtyController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════
  bool get _isIncrease {
    return _selectedType == StockMovementType.purchase ||
        _selectedType == StockMovementType.customerReturn;
  }

  bool get _isDecrease {
    return _selectedType == StockMovementType.sale ||
        _selectedType == StockMovementType.supplierReturn;
  }

  double get _currentQty {
    return double.tryParse(_qtyController.text.trim()) ?? 0;
  }

  double _getAvailableStock(BuildContext context) {
    final stockService = Provider.of<StockService>(context, listen: false);
    return stockService.calculateCurrentStock(widget.item.id);
  }

  void _incrementQty() {
    final current = _currentQty;
    _qtyController.text = (current + 1).toString();
  }

  void _decrementQty() {
    final current = _currentQty;
    if (current > 1) {
      _qtyController.text = (current - 1).toString();
    }
  }

  void _selectType(StockMovementType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _selectedPartyId = null;
    });
  }

  // ═════════════════════════════════════════════
  // Submit
  // ═════════════════════════════════════════════
  Future<void> _submit(bool isUrdu) async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    Account? selectedParty;
    model.Transaction? latestMatchingTransaction;
    if (_isReturn) {
      final eligibleTransactions = _matchingReturnTransactions(databaseService,
          partyId: _selectedPartyId);
      latestMatchingTransaction =
          eligibleTransactions.isEmpty ? null : eligibleTransactions.first;
      selectedParty = databaseService
          .getAccounts()
          .where(
            (account) =>
                account.id == _selectedPartyId &&
                account.isActive &&
                latestMatchingTransaction != null,
          )
          .firstOrNull;
      if (selectedParty == null) {
        AppToast.warning(
          context,
          isUrdu
              ? 'اس آئٹم کے متعلقہ تازہ ترین لین دین والی پارٹی منتخب کریں'
              : 'Select a party with a matching transaction for this item',
        );
        return;
      }
      final returnableQuantity =
          _returnableQuantity(latestMatchingTransaction!);
      if (_currentQty > returnableQuantity + 0.000001) {
        AppToast.warning(
          context,
          isUrdu
              ? 'تازہ ترین لین دین میں صرف ${returnableQuantity.toStringAsFixed(1)} ${widget.item.unit} باقی ہیں'
              : 'Only ${returnableQuantity.toStringAsFixed(1)} ${widget.item.unit} remain in the latest transaction',
        );
        return;
      }
    }

    final stockService = Provider.of<StockService>(context, listen: false);
    final enteredQuantity = double.tryParse(_qtyController.text) ?? 0.0;
    final available = stockService.calculateCurrentStock(widget.item.id);
    if (!available.isFinite) {
      AppToast.error(
        context,
        isUrdu
            ? 'موجودہ اسٹاک کی مقدار درست نہیں ہے۔ پہلے اسٹاک ریکارڈ درست کریں۔'
            : 'The current stock value is invalid. Correct the stock record first.',
      );
      return;
    }
    final qty = _selectedType == StockMovementType.adjustment
        ? StockService.stockAdjustmentDelta(
            currentStock: available,
            targetStock: enteredQuantity,
          )
        : enteredQuantity;
    if (_selectedType == StockMovementType.adjustment && qty == 0) {
      AppToast.warning(
        context,
        isUrdu
            ? 'گنی گئی مقدار موجودہ اسٹاک کے برابر ہے؛ کوئی تبدیلی نہیں کی گئی۔'
            : 'The counted quantity matches current stock; no adjustment was made.',
      );
      return;
    }
    final price =
        double.tryParse(_priceController.text) ?? widget.item.purchasePrice;

    String reason = _noteController.text.trim();
    if (reason.isEmpty) {
      switch (_selectedType) {
        case StockMovementType.purchase:
          reason = isUrdu ? 'خریداری' : 'Purchase';
          break;
        case StockMovementType.sale:
          reason = isUrdu ? 'فروخت' : 'Sale';
          break;
        case StockMovementType.customerReturn:
          reason = isUrdu ? 'گاہک کی واپسی' : 'Customer Return';
          break;
        case StockMovementType.supplierReturn:
          reason = isUrdu ? 'سپلائر کو واپسی' : 'Supplier Return';
          break;
        case StockMovementType.adjustment:
          reason = isUrdu ? 'اسٹاک ایڈجسٹمنٹ' : 'Stock Adjustment';
          break;
      }
    }

    final movement = StockMovement(
      id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
      stockItemId: widget.item.id,
      stockItemName: widget.item.name,
      type: _selectedType,
      quantity: qty,
      unitPrice: price,
      reason: reason,
      note: _noteController.text.trim(),
      partyId: selectedParty?.id ?? '',
      partyName: selectedParty?.name ?? '',
      timestamp: DateTime.now(),
    );

    if (!StockService.canApplyMovement(
      availableStock: available,
      movement: movement,
    )) {
      AppToast.warning(
        context,
        isUrdu
            ? 'اسٹاک کم کرنے کی مقدار موجودہ ${available.toStringAsFixed(1)} سے زیادہ نہیں ہو سکتی'
            : 'Cannot reduce stock by more than the current ${available.toStringAsFixed(1)}',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isReturn) {
        final updatedTransaction = _reduceItemFromTransaction(
          latestMatchingTransaction!,
          enteredQuantity,
        );
        final stockSynced =
            await databaseService.updateTransaction(updatedTransaction);

        if (mounted) {
          Navigator.pop(context, true);
          if (stockSynced) {
            AppToast.success(
              context,
              isUrdu
                  ? 'واپسی درج ہوگئی؛ تازہ ترین لین دین اپڈیٹ ہوگیا'
                  : 'Return recorded; latest transaction updated',
            );
          } else {
            AppToast.warning(
              context,
              isUrdu
                  ? 'لین دین محفوظ ہوگیا، مگر اسٹاک سنک مکمل نہیں ہوا'
                  : 'Transaction saved, but stock sync did not complete',
            );
          }
        }
      } else {
        await stockService.recordMovement(movement);

        if (mounted) {
          Navigator.pop(context, true);
          AppToast.success(
            context,
            isUrdu ? 'اسٹاک ہسٹری اپڈیٹ ہوگئی' : 'Stock entry recorded',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.error(
          context,
          isUrdu
              ? 'اسٹاک محفوظ نہیں ہو سکا: $error'
              : 'Could not save stock entry: $error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══ Header ═══
              _buildHeader(isUrdu, fontFamily),

              // ═══ Content ═══
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Movement Type
                        if (_shouldShowTypeSelector) ...[
                          _buildTypeSelector(isUrdu, fontFamily),
                          const SizedBox(height: 20),
                        ],

                        // 2. Quantity Stepper + Preview
                        _buildQuantitySection(isUrdu, fontFamily, context),
                        const SizedBox(height: 20),

                        // 3. Unit Price
                        _buildUnitPrice(isUrdu, fontFamily),
                        const SizedBox(height: 16),

                        // 4. Note
                        _buildNote(isUrdu, fontFamily),
                      ],
                    ),
                  ),
                ),
              ),

              // ═══ Footer ═══
              _buildFooter(isUrdu, fontFamily),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════
  Widget _buildHeader(bool isUrdu, String? fontFamily) {
    IconData iconData = PhosphorIcons.stack();
    List<Color> gradientColors = const [AppTheme.themeColor, Color(0xFF4A8FE3)];
    String titleText = isUrdu ? 'اسٹاک اینٹری' : 'Record Stock Movement';

    if (!_shouldShowTypeSelector) {
      switch (_selectedType) {
        case StockMovementType.purchase:
          iconData = PhosphorIcons.plusCircle();
          gradientColors = const [AppTheme.incomeColor, Color(0xFF6B7A1F)];
          titleText = isUrdu ? 'سامان خریدا (+)' : 'Stock In (+)';
          break;
        case StockMovementType.sale:
          iconData = PhosphorIcons.minusCircle();
          gradientColors = const [AppTheme.expenseColor, Color(0xFFE04B36)];
          titleText = isUrdu ? 'سامان بیچا (−)' : 'Stock Out (−)';
          break;
        case StockMovementType.customerReturn:
          iconData = PhosphorIcons.arrowClockwise();
          gradientColors = const [AppTheme.incomeColor, Color(0xFF6B7A1F)];
          titleText = isUrdu ? 'گاہک کی واپسی (+)' : 'Customer Return (+)';
          break;
        case StockMovementType.supplierReturn:
          iconData = PhosphorIcons.arrowCounterClockwise();
          gradientColors = const [AppTheme.expenseColor, Color(0xFFE04B36)];
          titleText = isUrdu ? 'سپلائر کو واپسی (−)' : 'Supplier Return (−)';
          break;
        case StockMovementType.adjustment:
          iconData = PhosphorIcons.sliders();
          gradientColors = const [Color(0xFFD97706), Color(0xFFF59E0B)];
          titleText = isUrdu ? 'اسٹاک ایڈجسٹمنٹ' : 'Stock Adjustment';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFAFCFF)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE1E5EC), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              iconData,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),

          // Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  titleText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                UrduAwareText(
                  widget.item.name,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Close
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // 1. Type Selector
  // ═════════════════════════════════════════════
  Widget _buildTypeSelector(bool isUrdu, String? fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          icon: PhosphorIcons.checkSquare(),
          text: isUrdu ? 'واپسی کی قسم' : 'RETURN TYPE',
        ),
        const SizedBox(height: 10),

        // Customer Return + Supplier Return
        Row(
          children: [
            Expanded(
              child: _buildTypePill(
                type: StockMovementType.customerReturn,
                icon: PhosphorIcons.arrowClockwise(),
                label: isUrdu ? 'گاہک واپسی' : 'Customer Return',
                color: AppTheme.incomeColor,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTypePill(
                type: StockMovementType.supplierReturn,
                icon: PhosphorIcons.arrowCounterClockwise(),
                label: isUrdu ? 'سپلائر واپسی' : 'Supplier Return',
                color: AppTheme.expenseColor,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPartySelector(isUrdu, fontFamily),
      ],
    );
  }

  Widget _buildPartySelector(bool isUrdu, String? fontFamily) {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final matchingTransactions = _matchingReturnTransactions(databaseService);
    final matchingPartyIds = matchingTransactions
        .map((transaction) => transaction.accountId)
        .toSet();
    final parties = databaseService
        .getAccounts()
        .where((account) =>
            account.isActive && matchingPartyIds.contains(account.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selectedPartyId = parties.any((party) => party.id == _selectedPartyId)
        ? _selectedPartyId
        : null;
    final selectedLatestTransaction = selectedPartyId == null
        ? null
        : matchingTransactions
            .where((transaction) => transaction.accountId == selectedPartyId)
            .firstOrNull;
    final isCustomerReturn = _selectedType == StockMovementType.customerReturn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          icon: PhosphorIcons.user(),
          text: isUrdu
              ? (isCustomerReturn ? 'گاہک منتخب کریں' : 'سپلائر منتخب کریں')
              : (isCustomerReturn ? 'SELECT CUSTOMER' : 'SELECT SUPPLIER'),
          fontFamily: fontFamily,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedType),
          initialValue: selectedPartyId,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.backgroundColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: AppTheme.backgroundColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppTheme.themeColor, width: 1.5),
            ),
          ),
          hint: UrduAwareText(
            isUrdu
                ? (parties.isEmpty
                    ? (isCustomerReturn
                        ? 'اس آئٹم کی کوئی فروخت موجود نہیں'
                        : 'اس آئٹم کی کوئی خریداری موجود نہیں')
                    : 'پارٹی منتخب کریں')
                : (parties.isEmpty
                    ? (isCustomerReturn
                        ? 'No sale transaction for this item'
                        : 'No purchase transaction for this item')
                    : 'Select a party'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          items: parties
              .map(
                (party) => DropdownMenuItem<String>(
                  value: party.id,
                  child: UrduAwareText(
                    party.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.darkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: parties.isEmpty
              ? null
              : (partyId) => setState(() => _selectedPartyId = partyId),
          validator: (partyId) {
            if (partyId == null || partyId.isEmpty) {
              return isUrdu
                  ? (isCustomerReturn
                      ? 'گاہک منتخب کرنا ضروری ہے'
                      : 'سپلائر منتخب کرنا ضروری ہے')
                  : (isCustomerReturn
                      ? 'Select a customer'
                      : 'Select a supplier');
            }
            return null;
          },
        ),
        if (selectedLatestTransaction != null) ...[
          const SizedBox(height: 8),
          UrduAwareText(
            isUrdu
                ? 'واپسی تازہ ترین لین دین سے ہوگی؛ باقی مقدار: ${_returnableQuantity(selectedLatestTransaction).toStringAsFixed(1)} ${widget.item.unit}'
                : 'Return will be applied to the latest transaction; remaining: ${_returnableQuantity(selectedLatestTransaction).toStringAsFixed(1)} ${widget.item.unit}',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontFamily: fontFamily,
            ),
          ),
        ],
        if (parties.isEmpty) ...[
          const SizedBox(height: 6),
          UrduAwareText(
            isUrdu
                ? (isCustomerReturn
                    ? 'اس آئٹم کی کوئی گاہک والی فروخت موجود نہیں'
                    : 'اس آئٹم کی کوئی سپلائر سے خریداری موجود نہیں')
                : (isCustomerReturn
                    ? 'No sale transaction for this item is available'
                    : 'No purchase transaction for this item is available'),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.expenseColor,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTypePill({
    required StockMovementType type,
    required IconData icon,
    required String label,
    required Color color,
    String? fontFamily,
    bool full = false,
  }) {
    final isActive = _selectedType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectType(type),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: full
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : AppTheme.backgroundColor,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: full
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPillIcon(icon, color, isActive, size: 26),
                    const SizedBox(width: 10),
                    UrduAwareText(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isActive ? color : AppTheme.darkColor,
                        fontFamily: fontFamily,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildPillIcon(icon, color, isActive),
                    const SizedBox(height: 6),
                    UrduAwareText(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isActive ? color : AppTheme.darkColor,
                        fontFamily: fontFamily,
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPillIcon(
    IconData icon,
    Color color,
    bool isActive, {
    double size = 30,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive ? color : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: isActive ? Colors.white : AppTheme.textSecondary,
      ),
    );
  }

  // ═════════════════════════════════════════════
  // 2. Quantity Section
  // ═════════════════════════════════════════════
  Widget _buildQuantitySection(
    bool isUrdu,
    String? fontFamily,
    BuildContext context,
  ) {
    final availableStock = _getAvailableStock(context);
    final qty = _currentQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          icon: PhosphorIcons.stack(),
          text: _selectedType == StockMovementType.adjustment
              ? (isUrdu ? 'گنی گئی کل مقدار' : 'COUNTED STOCK')
              : (isUrdu ? 'مقدار' : 'QUANTITY'),
        ),
        const SizedBox(height: 10),

        // Stepper hero
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F7FA), Color(0xFFFAFCFF)],
            ),
            border: Border.all(color: AppTheme.backgroundColor, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // Minus
              _buildStepperButton(
                icon: PhosphorIcons.minus(),
                color: AppTheme.expenseColor,
                onTap: _decrementQty,
              ),
              const SizedBox(width: 10),

              // Value
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _qtyController,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkColor,
                        letterSpacing: -1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return isUrdu ? 'مقدار' : 'Required';
                        }
                        final n = double.tryParse(val);
                        if (n == null ||
                            !n.isFinite ||
                            (_selectedType == StockMovementType.adjustment
                                ? n < 0
                                : n <= 0)) {
                          return isUrdu ? 'درست' : 'Invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 2),
                    UrduAwareText(
                      widget.item.unit.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Plus
              _buildStepperButton(
                icon: PhosphorIcons.plus(),
                color: AppTheme.incomeColor,
                onTap: _incrementQty,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Live Preview
        _buildLivePreview(qty, availableStock, isUrdu, fontFamily),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildLivePreview(
    double qty,
    double availableStock,
    bool isUrdu,
    String? fontFamily,
  ) {
    // Determine preview state
    bool isIncreasePreview = _isIncrease;
    bool isDecreasePreview = _isDecrease;
    bool isWarning = false;

    double newStock = availableStock;

    if (isIncreasePreview) {
      newStock = availableStock + qty;
    } else if (isDecreasePreview) {
      newStock = availableStock - qty;
      if (newStock < 0) {
        isWarning = true;
      }
    } else {
      // adjustment — treat qty as new absolute value
      newStock = qty;
    }

    String formatQuantity(double value) => value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();

    // Colors
    Color color;
    Color bg;
    Color border;
    IconData icon;
    String message;

    if (isWarning) {
      color = const Color(0xFFD97706);
      bg = const Color(0xFFD97706).withValues(alpha: 0.08);
      border = const Color(0xFFD97706).withValues(alpha: 0.25);
      icon = PhosphorIcons.warning(PhosphorIconsStyle.fill);
      message = isUrdu
          ? 'اتنا اسٹاک موجود نہیں! صرف ${formatQuantity(availableStock)} ${widget.item.unit}'
          : 'Not enough stock! Only ${formatQuantity(availableStock)} ${widget.item.unit} available';
    } else if (isIncreasePreview) {
      color = AppTheme.incomeColor;
      bg = AppTheme.incomeColor.withValues(alpha: 0.06);
      border = AppTheme.incomeColor.withValues(alpha: 0.20);
      icon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
      message = isUrdu
          ? 'اسٹاک بڑھے گا: ${formatQuantity(availableStock)} → ${formatQuantity(newStock)} ${widget.item.unit}'
          : 'Stock will increase: ${formatQuantity(availableStock)} → ${formatQuantity(newStock)} ${widget.item.unit}';
    } else if (isDecreasePreview) {
      color = AppTheme.expenseColor;
      bg = AppTheme.expenseColor.withValues(alpha: 0.06);
      border = AppTheme.expenseColor.withValues(alpha: 0.20);
      icon = PhosphorIcons.arrowDown();
      message = isUrdu
          ? 'اسٹاک کم ہوگا: ${formatQuantity(availableStock)} → ${formatQuantity(newStock)} ${widget.item.unit}'
          : 'Stock will decrease: ${formatQuantity(availableStock)} → ${formatQuantity(newStock)} ${widget.item.unit}';
    } else {
      color = AppTheme.themeColor;
      bg = AppTheme.themeColor.withValues(alpha: 0.06);
      border = AppTheme.themeColor.withValues(alpha: 0.20);
      icon = PhosphorIcons.sliders();
      message = isUrdu
          ? 'اسٹاک ایڈجسٹ ہوگا: ${formatQuantity(availableStock)} → ${formatQuantity(newStock)} ${widget.item.unit}'
          : 'Stock will adjust: ${formatQuantity(availableStock)} → ${formatQuantity(newStock)} ${widget.item.unit}';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: UrduAwareText(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // 3. Unit Price
  // ═════════════════════════════════════════════
  Widget _buildUnitPrice(bool isUrdu, String? fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel(
              icon: PhosphorIcons.money(),
              text: isUrdu ? 'فی یونٹ قیمت' : 'UNIT PRICE',
              fontFamily: fontFamily,
            ),
            const Spacer(),
            UrduAwareText(
              isUrdu ? 'اختیاری' : 'OPTIONAL',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _priceController,
          hintText: '0',
          icon: PhosphorIcons.money(),
          suffix: 'Rs.',
          isNumber: true,
          fontFamily: fontFamily,
          isUrdu: isUrdu,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // 4. Note
  // ═════════════════════════════════════════════
  Widget _buildNote(bool isUrdu, String? fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel(
              icon: PhosphorIcons.notePencil(),
              text: isUrdu ? 'وجہ / تفصیل' : 'REASON / NOTE',
              fontFamily: fontFamily,
            ),
            const Spacer(),
            UrduAwareText(
              isUrdu ? 'اختیاری' : 'OPTIONAL',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _noteController,
          hintText: isUrdu
              ? 'اس اینٹری کی وجہ لکھیں...'
              : 'Add a note for this movement...',
          icon: PhosphorIcons.notePencil(),
          maxLines: 2,
          fontFamily: fontFamily,
          isUrdu: isUrdu,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // Shared: Section Label
  // ═════════════════════════════════════════════
  Widget _buildSectionLabel({
    required IconData icon,
    required String text,
    String? fontFamily,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        UrduAwareText(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // Shared: Input Field
  // ═════════════════════════════════════════════
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? suffix,
    bool isNumber = false,
    int maxLines = 1,
    String? fontFamily,
    bool isUrdu = false,
  }) {
    final effectiveIsLtr = isNumber || !isUrdu;
    final textDir = effectiveIsLtr ? TextDirection.ltr : TextDirection.rtl;
    final textAlign = isUrdu ? TextAlign.right : TextAlign.left;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: maxLines > 1 ? 14 : 0,
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: isNumber
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.multiline,
              textDirection: textDir,
              textAlign: textAlign,
              style: TextStyle(
                fontFamily: isNumber ? 'Inter' : fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintTextDirection: textDir,
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontFamily: fontFamily,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            UrduAwareText(
              suffix,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Footer
  // ═════════════════════════════════════════════
  Widget _buildFooter(bool isUrdu, String? fontFamily) {
    // Submit button color based on type
    Color submitColor = AppTheme.themeColor;
    Color submitColor2 = const Color(0xFF4A8FE3);
    if (_selectedType == StockMovementType.adjustment) {
      submitColor = AppTheme.verifiedGold;
      submitColor2 = const Color(0xFFF59E0B);
    } else if (_isIncrease) {
      submitColor = AppTheme.incomeColor;
      submitColor2 = const Color(0xFF6B7A1F);
    } else if (_isDecrease) {
      submitColor = AppTheme.expenseColor;
      submitColor2 = const Color(0xFFE04B36);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE1E5EC), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Cancel
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: UrduAwareText(
                  isUrdu ? 'کینسل' : 'Cancel',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Submit
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSaving ? null : () => _submit(isUrdu),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [submitColor, submitColor2],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: submitColor.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: UrduAwareText(
                          _isSaving
                              ? (isUrdu ? 'محفوظ ہو رہا...' : 'Saving...')
                              : (isUrdu ? 'محفوظ کریں' : 'Save Entry'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: fontFamily,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
