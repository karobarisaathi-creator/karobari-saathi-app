// lib/features/stock/add_edit_stock_item_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';

class AddEditStockItemScreen extends StatefulWidget {
  final StockItem? initialItem;

  const AddEditStockItemScreen({super.key, this.initialItem});

  @override
  State<AddEditStockItemScreen> createState() => _AddEditStockItemScreenState();
}

class _AddEditStockItemScreenState extends State<AddEditStockItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _nameUrduController;
  late TextEditingController _barcodeController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _wholesalePriceController;
  late TextEditingController _initialQtyController;
  late TextEditingController _minAlertController;
  late TextEditingController _descriptionController;

  String _selectedUnit = 'Pieces';
  String _selectedCategory = 'عام (General)';
  bool _isSaving = false;

  final List<String> _units = [
    'Pieces',
    'Kg',
    'Meter',
    'Liter',
    'Box',
    'Dozen',
    'Sqft',
    'Gram',
    'Packet',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _nameUrduController = TextEditingController(text: item?.nameUrdu ?? '');
    _barcodeController = TextEditingController(text: item?.barcode ?? '');
    _purchasePriceController = TextEditingController(
      text: item != null && item.purchasePrice > 0
          ? item.purchasePrice.toStringAsFixed(0)
          : '',
    );
    _sellingPriceController = TextEditingController(
      text: item != null && item.sellingPrice > 0
          ? item.sellingPrice.toStringAsFixed(0)
          : '',
    );
    _wholesalePriceController = TextEditingController(
      text: item != null && item.wholesalePrice > 0
          ? item.wholesalePrice.toStringAsFixed(0)
          : '',
    );
    _initialQtyController = TextEditingController(
      text: item != null && item.initialQuantity > 0
          ? item.initialQuantity.toStringAsFixed(0)
          : '',
    );
    _minAlertController = TextEditingController(
      text: item?.minStockAlert.toStringAsFixed(0) ?? '5',
    );
    _descriptionController =
        TextEditingController(text: item?.description ?? '');

    if (item != null && _units.contains(item.unit)) {
      _selectedUnit = item.unit;
    }
    if (item != null && item.categoryName.isNotEmpty) {
      _selectedCategory = item.categoryName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameUrduController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _wholesalePriceController.dispose();
    _initialQtyController.dispose();
    _minAlertController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveItem(bool isUrdu) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final stockService = Provider.of<StockService>(context, listen: false);
    final now = DateTime.now();

    final item = StockItem(
      id: widget.initialItem?.id ??
          'item_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      nameUrdu: _nameUrduController.text.trim(),
      barcode: _barcodeController.text.trim(),
      categoryName: _selectedCategory,
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0.0,
      sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
      wholesalePrice: double.tryParse(_wholesalePriceController.text) ?? 0.0,
      initialQuantity: double.tryParse(_initialQtyController.text) ?? 0.0,
      minStockAlert: double.tryParse(_minAlertController.text) ?? 5.0,
      unit: _selectedUnit,
      description: _descriptionController.text.trim(),
      createdAt: widget.initialItem?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (widget.initialItem == null) {
        await stockService.addStockItem(item);
      } else {
        await stockService.updateStockItem(item);
      }

      if (mounted) {
        Navigator.pop(context);
        AppToast.success(
          context,
          isUrdu ? 'آئٹم کامیابی سے محفوظ ہو گئی' : 'Item saved successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.error(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final isEdit = widget.initialItem != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isEdit
            ? (isUrdu ? 'آئٹم میں ترمیم' : 'Edit Stock Item')
            : (isUrdu ? 'نیا آئٹم شامل کریں' : 'Add Stock Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📦 Basic Details Card
              _buildSectionCard(
                title: isUrdu ? 'بنیادی معلومات' : 'Basic Information',
                fontFamily: fontFamily,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'آئٹم کا نام (انگریزی) *' : 'Item Name (English) *',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.package()),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return isUrdu ? 'آئٹم کا نام درج کریں' : 'Enter item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameUrduController,
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'آئٹم کا نام (اردو میں)' : 'Item Name (Urdu)',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.textT()),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'بارکوڈ / آئٹم کوڈ' : 'Barcode / Item Code',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.barcode()),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🏷️ Category & Unit Card
              _buildSectionCard(
                title: isUrdu ? 'یونٹ اور کیٹیگری' : 'Unit & Category',
                fontFamily: fontFamily,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'بنیادی اکائی (Unit) *' : 'Unit *',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.scales()),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _units.map((u) {
                      return DropdownMenuItem(value: u, child: Text(u));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedUnit = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 💰 Prices & Cost Card
              _buildSectionCard(
                title: isUrdu ? 'قیمت اور ریٹ (Pricing)' : 'Pricing & Rates',
                fontFamily: fontFamily,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _purchasePriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'خرید قیمت (Rs.)' : 'Cost Price (Rs.)',
                            labelStyle: TextStyle(fontFamily: fontFamily),
                            prefixIcon: Icon(PhosphorIcons.money()),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sellingPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'فروخت قیمت (Rs.) *' : 'Selling Price (Rs.) *',
                            labelStyle: TextStyle(fontFamily: fontFamily),
                            prefixIcon: Icon(PhosphorIcons.tag()),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isUrdu ? 'فروخت قیمت درج کریں' : 'Enter selling price';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _wholesalePriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'تھوک قیمت (Wholesale Price)' : 'Wholesale Price (Rs.)',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.buildings()),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 📊 Initial Stock & Alert Limit
              _buildSectionCard(
                title: isUrdu ? 'شروعاتی اسٹاک اور الرٹ' : 'Opening Stock & Alerts',
                fontFamily: fontFamily,
                children: [
                  if (!isEdit) ...[
                    TextFormField(
                      controller: _initialQtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'شروعاتی اسٹاک مقدار' : 'Opening Stock Quantity',
                        labelStyle: TextStyle(fontFamily: fontFamily),
                        prefixIcon: Icon(PhosphorIcons.stack()),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _minAlertController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'کم از کم اسٹاک الرٹ حد' : 'Low Stock Alert Limit',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.bellRinging()),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              AppButton(
                text: isEdit
                    ? (isUrdu ? 'ترمیم محفوظ کریں' : 'Update Item')
                    : (isUrdu ? 'آئٹم شامل کریں' : 'Add Item'),
                isLoading: _isSaving,
                onPressed: () => _saveItem(isUrdu),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String fontFamily,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
