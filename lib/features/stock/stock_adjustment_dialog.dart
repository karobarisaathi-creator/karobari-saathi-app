// lib/features/stock/stock_adjustment_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';

class StockAdjustmentDialog extends StatefulWidget {
  final StockItem item;
  final StockMovementType initialType;

  const StockAdjustmentDialog({
    super.key,
    required this.item,
    this.initialType = StockMovementType.adjustment,
  });

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late StockMovementType _selectedType;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedReason = 'Manual Audit';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _priceController.text = widget.item.purchasePrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit(bool isUrdu) async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? widget.item.purchasePrice;

    if (qty <= 0) return;

    final stockService = Provider.of<StockService>(context, listen: false);

    final movement = StockMovement(
      id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
      stockItemId: widget.item.id,
      stockItemName: widget.item.name,
      type: _selectedType,
      quantity: qty,
      unitPrice: price,
      reason: _selectedReason,
      note: _noteController.text.trim(),
      timestamp: DateTime.now(),
    );

    await stockService.recordMovement(movement);

    if (mounted) {
      Navigator.pop(context, true);
      AppToast.success(
        context,
        isUrdu ? 'اسٹاک ہسٹری اپڈیٹ ہوگئی' : 'Stock entry recorded',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isUrdu ? 'اسٹاک اینٹری / ایڈجسٹمنٹ' : 'Record Stock Movement',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
          color: AppTheme.darkColor,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.themeColor,
                ),
              ),
              const SizedBox(height: 16),

              // Movement Type Selector
              DropdownButtonFormField<StockMovementType>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'اینٹری کی قسم' : 'Movement Type',
                  labelStyle: TextStyle(fontFamily: fontFamily),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: StockMovementType.purchase,
                    child: Text(isUrdu ? 'خریداری (Stock In +)' : 'Stock In / Purchase'),
                  ),
                  DropdownMenuItem(
                    value: StockMovementType.sale,
                    child: Text(isUrdu ? 'فروخت (Stock Out -)' : 'Stock Out / Sale'),
                  ),
                  DropdownMenuItem(
                    value: StockMovementType.customerReturn,
                    child: Text(isUrdu ? 'گاہک کی واپسی (+)' : 'Customer Return (+)'),
                  ),
                  DropdownMenuItem(
                    value: StockMovementType.supplierReturn,
                    child: Text(isUrdu ? 'سپلاٸر کو واپسی (-)' : 'Supplier Return (-)'),
                  ),
                  DropdownMenuItem(
                    value: StockMovementType.adjustment,
                    child: Text(isUrdu ? 'ایڈجسٹمنٹ / ڈیمیج' : 'Manual Adjustment'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 12),

              // Quantity Field
              TextFormField(
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isUrdu
                      ? 'مقدار (${widget.item.unit})'
                      : 'Quantity (${widget.item.unit})',
                  labelStyle: TextStyle(fontFamily: fontFamily),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return isUrdu ? 'مقدار درج کریں' : 'Enter quantity';
                  }
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) {
                    return isUrdu ? 'درست مقدار درج کریں' : 'Valid quantity required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Unit Price Field
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isUrdu ? 'فی یونٹ قیمت (Rs.)' : 'Unit Price (Rs.)',
                  labelStyle: TextStyle(fontFamily: fontFamily),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Notes / Reason
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'وجہ / تفصیل (نوٹ)' : 'Reason / Note',
                  labelStyle: TextStyle(fontFamily: fontFamily),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            isUrdu ? 'کینسل' : 'Cancel',
            style: TextStyle(fontFamily: fontFamily, color: Colors.grey[700]),
          ),
        ),
        AppButton(
          text: isUrdu ? 'محفوظ کریں' : 'Save Entry',
          onPressed: () => _submit(isUrdu),
        ),
      ],
    );
  }
}
