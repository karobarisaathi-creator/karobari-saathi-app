// lib/features/shopkeeper/add_edit_stock_item_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  // ═══ کنٹرولرز ═══
  late TextEditingController _nameController;
  late TextEditingController _nameUrduController;
  late TextEditingController _barcodeController;
  late TextEditingController _skuController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _wholesalePriceController;
  late TextEditingController _mrpController;
  late TextEditingController _initialQtyController;
  late TextEditingController _minAlertController;
  late TextEditingController _descriptionController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _supplierNameController;
  late TextEditingController _batchNoController;
  late TextEditingController _warrantyController;

  // ═══ حالت ═══
  String _selectedUnit = 'Pieces';
  String _selectedCategory = 'General';
  String? _imagePath;
  bool _isSaving = false;

  // ٹوگلز
  bool _featured = false;
  bool _trackStock = true;
  bool _allowReturn = true;
  bool _stopWhenOut = true;

  // ═══ یونٹ اور کیٹیگری کے لیبل ═══
  static const Map<String, String> _unitLabels = {
    'Pieces': 'عدد',
    'Kg': 'کلو',
    'Gram': 'گرام',
    'Liter': 'لیٹر',
    'Meter': 'میٹر',
    'Sqft': 'مربع فٹ',
    'Dozen': 'درجن',
    'Box': 'ڈبہ',
    'Bag': 'بوری',
    'Maund': 'من',
    'Bottle': 'بوتل',
    'Packet': 'پیکٹ',
    'Tola': 'تولہ',
    'Other': 'دیگر',
  };

  static const Map<String, String> _categoryLabels = {
    'General': 'عمومی',
    'Grocery': 'کریانہ',
    'Food': 'خوراک',
    'Beverages': 'مشروبات',
    'Clothing': 'کپڑے',
    'Electronics': 'الیکٹرانکس',
    'Household': 'گھریلو سامان',
    'Personal Care': 'ذاتی استعمال',
    'Medicine': 'ادویات',
    'Other': 'دیگر',
  };

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _nameUrduController = TextEditingController(text: item?.nameUrdu ?? '');
    _barcodeController = TextEditingController(text: item?.barcode ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');
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
    _mrpController = TextEditingController(
      text: item != null && item.mrp > 0 ? item.mrp.toStringAsFixed(0) : '',
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
    _brandController = TextEditingController(text: item?.brand ?? '');
    _modelController = TextEditingController(text: item?.model ?? '');
    _supplierNameController =
        TextEditingController(text: item?.supplierName ?? '');
    _batchNoController = TextEditingController(text: item?.batchNo ?? '');
    _warrantyController = TextEditingController(
      text: item != null && item.warranty > 0 ? item.warranty.toString() : '',
    );
    _imagePath = item?.imagePath;
    _featured = item?.featured ?? false;
    _trackStock = item?.trackStock ?? true;
    _allowReturn = item?.allowReturn ?? true;
    _stopWhenOut = item?.stopWhenOut ?? true;

    if (item != null && item.unit.isNotEmpty) {
      _selectedUnit = item.unit;
    }
    if (item != null && item.categoryName.isNotEmpty) {
      _selectedCategory =
          item.categoryName == 'عام (General)' ? 'General' : item.categoryName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameUrduController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _wholesalePriceController.dispose();
    _mrpController.dispose();
    _initialQtyController.dispose();
    _minAlertController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _supplierNameController.dispose();
    _batchNoController.dispose();
    _warrantyController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // محفوظ کریں
  // ═══════════════════════════════════════════
  void _saveItem(bool isUrdu) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final stockService = Provider.of<StockService>(context, listen: false);
    final now = DateTime.now();
    final itemId = widget.initialItem?.id ??
        'item_${DateTime.now().millisecondsSinceEpoch}';

    try {
      var imagePath = _imagePath;
      final imageUri = imagePath == null ? null : Uri.tryParse(imagePath);
      if (imagePath != null &&
          (imageUri == null ||
              (imageUri.scheme != 'https' && imageUri.scheme != 'http'))) {
        imagePath =
            await stockService.uploadStockImage(File(imagePath), itemId);
      }

      final item = StockItem(
        id: itemId,
        name: _nameController.text.trim(),
        nameUrdu: _nameUrduController.text.trim(),
        barcode: _barcodeController.text.trim(),
        sku: _skuController.text.trim(),
        categoryName: _selectedCategory,
        purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0.0,
        sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
        wholesalePrice: double.tryParse(_wholesalePriceController.text) ?? 0.0,
        mrp: double.tryParse(_mrpController.text) ?? 0.0,
        initialQuantity: double.tryParse(_initialQtyController.text) ?? 0.0,
        minStockAlert: double.tryParse(_minAlertController.text) ?? 5.0,
        unit: _selectedUnit,
        description: _descriptionController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        supplierName: _supplierNameController.text.trim(),
        batchNo: _batchNoController.text.trim(),
        warranty: int.tryParse(_warrantyController.text.trim()) ?? 0,
        featured: _featured,
        trackStock: _trackStock,
        allowReturn: _allowReturn,
        stopWhenOut: _stopWhenOut,
        imagePath: imagePath,
        createdAt: widget.initialItem?.createdAt ?? now,
        updatedAt: now,
      );

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

  // ═══════════════════════════════════════════
  // ویلیڈیشن
  // ═══════════════════════════════════════════
  String? _validateNonNegativeNumber(
    String? value, {
    required bool isUrdu,
    required String fieldLabel,
    bool required = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? (isUrdu ? '$fieldLabel درج کریں' : 'Enter $fieldLabel')
          : null;
    }
    final number = double.tryParse(text);
    if (number == null || !number.isFinite || number < 0) {
      return isUrdu
          ? '$fieldLabel کی درست مثبت مقدار درج کریں'
          : 'Enter a valid non-negative $fieldLabel';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final stockService = Provider.of<StockService>(context);
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final isEdit = widget.initialItem != null;

    final categoryOptions = {
      ..._categoryLabels.keys,
      ...stockService.items
          .map((item) => item.categoryName.trim())
          .where((name) => name.isNotEmpty),
      if (_selectedCategory.isNotEmpty) _selectedCategory,
    }.toList();

    final unitOptions = {
      ..._unitLabels.keys,
      if (!_unitLabels.containsKey(_selectedUnit)) _selectedUnit,
    }.toList();

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
              // ═══ 1. تصویر ═══
              _buildSectionCard(
                title: isUrdu ? 'آئٹم کی تصویر' : 'Item Image',
                icon: PhosphorIcons.camera(),
                fontFamily: fontFamily,
                children: [
                  _buildImageRow(isUrdu, fontFamily, isLast: true),
                ],
              ),
              const SizedBox(height: 14),

              // ═══ 2. بنیادی معلومات ═══
              _buildSectionCard(
                title: isUrdu ? 'بنیادی معلومات' : 'Basic Information',
                icon: PhosphorIcons.package(),
                fontFamily: fontFamily,
                children: [
                  _buildFullField(
                    label: isUrdu ? 'آئٹم کا نام *' : 'Item Name *',
                    icon: PhosphorIcons.package(),
                    controller: _nameController,
                    fontFamily: fontFamily,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return isUrdu
                            ? 'آئٹم کا نام درج کریں'
                            : 'Enter item name';
                      }
                      return null;
                    },
                  ),
                  _buildRowField(
                    label: isUrdu ? 'اردو نام' : 'Urdu Name',
                    icon: PhosphorIcons.textT(),
                    controller: _nameUrduController,
                    fontFamily: fontFamily,
                    optional: true,
                    isUrdu: isUrdu,
                  ),
                  _buildRowField(
                    label: isUrdu ? 'بارکوڈ' : 'Barcode',
                    icon: PhosphorIcons.barcode(),
                    controller: _barcodeController,
                    fontFamily: fontFamily,
                    isLtr: true,
                    trailing: IconButton(
                      icon: Icon(PhosphorIcons.camera(), size: 20),
                      onPressed: () => _openBarcodeScanner(isUrdu),
                      color: AppTheme.themeColor,
                    ),
                  ),
                  _buildRowField(
                    label: isUrdu ? 'SKU' : 'SKU',
                    icon: PhosphorIcons.tag(),
                    controller: _skuController,
                    fontFamily: fontFamily,
                    isLtr: true,
                    optional: true,
                    isUrdu: isUrdu,
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ═══ 3. کیٹیگری اور اکائی ═══
              _buildSectionCard(
                title: isUrdu ? 'کیٹیگری اور اکائی' : 'Category & Unit',
                icon: PhosphorIcons.squaresFour(),
                fontFamily: fontFamily,
                children: [
                  _buildSliderSection(
                    label: isUrdu ? 'کیٹیگری' : 'Category',
                    icon: PhosphorIcons.squaresFour(),
                    fontFamily: fontFamily,
                    chips: categoryOptions.map((c) {
                      return _ChipData(
                        value: c,
                        label: isUrdu ? (_categoryLabels[c] ?? c) : c,
                        isSelected: c == _selectedCategory,
                        onTap: () {
                          setState(() => _selectedCategory = c);
                        },
                      );
                    }).toList(),
                  ),
                  _buildSliderSection(
                    label: isUrdu ? 'اکائی' : 'Unit',
                    icon: PhosphorIcons.ruler(),
                    fontFamily: fontFamily,
                    isLast: true,
                    chips: unitOptions.map((u) {
                      return _ChipData(
                        value: u,
                        label: isUrdu ? (_unitLabels[u] ?? u) : u,
                        isSelected: u == _selectedUnit,
                        onTap: () {
                          setState(() => _selectedUnit = u);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ═══ 4. قیمت ═══
              _buildSectionCard(
                title: isUrdu ? 'قیمت اور ریٹ' : 'Pricing & Rates',
                icon: PhosphorIcons.money(),
                fontFamily: fontFamily,
                children: [
                  _buildRowField(
                    label: isUrdu ? 'خرید قیمت' : 'Cost Price',
                    icon: PhosphorIcons.money(),
                    controller: _purchasePriceController,
                    fontFamily: fontFamily,
                    isNumber: true,
                    isLtr: true,
                    suffix: 'Rs.',
                    validator: (v) => _validateNonNegativeNumber(
                      v,
                      isUrdu: isUrdu,
                      fieldLabel: isUrdu ? 'خرید قیمت' : 'cost price',
                    ),
                  ),
                  _buildRowField(
                    label: isUrdu ? 'فروخت قیمت *' : 'Selling Price *',
                    icon: PhosphorIcons.tag(),
                    controller: _sellingPriceController,
                    fontFamily: fontFamily,
                    isNumber: true,
                    isLtr: true,
                    suffix: 'Rs.',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return isUrdu
                            ? 'فروخت قیمت درج کریں'
                            : 'Enter selling price';
                      }
                      return _validateNonNegativeNumber(
                        v,
                        isUrdu: isUrdu,
                        fieldLabel: isUrdu ? 'فروخت قیمت' : 'selling price',
                        required: true,
                      );
                    },
                  ),
                  _buildRowField(
                    label: isUrdu ? 'تھوک قیمت' : 'Wholesale Price',
                    icon: PhosphorIcons.buildings(),
                    controller: _wholesalePriceController,
                    fontFamily: fontFamily,
                    isNumber: true,
                    isLtr: true,
                    suffix: 'Rs.',
                    validator: (v) => _validateNonNegativeNumber(
                      v,
                      isUrdu: isUrdu,
                      fieldLabel: isUrdu ? 'تھوک قیمت' : 'wholesale price',
                    ),
                  ),
                  _buildRowField(
                    label: isUrdu ? 'MRP' : 'MRP',
                    icon: PhosphorIcons.clipboard(),
                    controller: _mrpController,
                    fontFamily: fontFamily,
                    isNumber: true,
                    isLtr: true,
                    suffix: 'Rs.',
                    optional: true,
                    isUrdu: isUrdu,
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ═══ 5. اسٹاک ═══
              _buildSectionCard(
                title: isUrdu ? 'اسٹاک اور الرٹ' : 'Stock & Alerts',
                icon: PhosphorIcons.stack(),
                fontFamily: fontFamily,
                children: [
                  _buildRowField(
                    label: isUrdu ? 'شروعاتی اسٹاک' : 'Opening Stock',
                    icon: PhosphorIcons.stack(),
                    controller: _initialQtyController,
                    fontFamily: fontFamily,
                    isNumber: true,
                    isLtr: true,
                    validator: (v) => _validateNonNegativeNumber(
                      v,
                      isUrdu: isUrdu,
                      fieldLabel: isUrdu ? 'ابتدائی اسٹاک' : 'opening stock',
                    ),
                  ),
                  _buildRowField(
                    label: isUrdu ? 'کم از کم الرٹ حد *' : 'Low Alert *',
                    icon: PhosphorIcons.bellRinging(),
                    controller: _minAlertController,
                    fontFamily: fontFamily,
                    isNumber: true,
                    isLtr: true,
                    validator: (v) => _validateNonNegativeNumber(
                      v,
                      isUrdu: isUrdu,
                      fieldLabel: isUrdu ? 'الرٹ حد' : 'alert limit',
                      required: true,
                    ),
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ═══ 6. اضافی تفصیلات ═══
              _buildSectionCard(
                title: isUrdu ? 'اضافی تفصیلات' : 'Additional Details',
                icon: PhosphorIcons.notePencil(),
                fontFamily: fontFamily,
                children: [
                  _buildFullField(
                    label: isUrdu ? 'تفصیل / نوٹ' : 'Description',
                    icon: PhosphorIcons.notePencil(),
                    controller: _descriptionController,
                    fontFamily: fontFamily,
                    maxLines: 3,
                  ),
                  _buildRowField(
                    label: isUrdu ? 'برانڈ' : 'Brand',
                    icon: PhosphorIcons.factory(),
                    controller: _brandController,
                    fontFamily: fontFamily,
                    optional: true,
                    isUrdu: isUrdu,
                  ),
                  _buildRowField(
                    label: isUrdu ? 'ماڈل' : 'Model',
                    icon: PhosphorIcons.wrench(),
                    controller: _modelController,
                    fontFamily: fontFamily,
                    isLtr: true,
                    optional: true,
                    isUrdu: isUrdu,
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ═══ 7. سپلائر اور وارنٹی ═══
              _buildSectionCard(
                title: isUrdu ? 'سپلائر اور وارنٹی' : 'Supplier & Warranty',
                icon: PhosphorIcons.storefront(),
                fontFamily: fontFamily,
                children: [
                  _buildRowField(
                    label: isUrdu ? 'سپلائر کا نام' : 'Supplier Name',
                    icon: PhosphorIcons.storefront(),
                    controller: _supplierNameController,
                    fontFamily: fontFamily,
                  ),
                  _buildRowField(
                    label: isUrdu ? 'بیچ / لاٹ نمبر' : 'Batch / Lot No.',
                    icon: PhosphorIcons.hash(),
                    controller: _batchNoController,
                    fontFamily: fontFamily,
                    isLtr: true,
                    optional: true,
                    isUrdu: isUrdu,
                  ),
                  _buildRowField(
                    label: isUrdu ? 'وارنٹی (مہینے)' : 'Warranty (months)',
                    icon: PhosphorIcons.shieldCheck(),
                    controller: _warrantyController,
                    fontFamily: fontFamily,
                    isNumber: true,
                    isLtr: true,
                    optional: true,
                    isUrdu: isUrdu,
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ═══ 8. خصوصیات ═══
              _buildSectionCard(
                title: isUrdu ? 'خصوصیات' : 'Settings',
                icon: PhosphorIcons.gear(),
                fontFamily: fontFamily,
                children: [
                  _buildToggleRow(
                    title: isUrdu ? 'نمایاں آئٹم' : 'Featured Item',
                    sub: isUrdu
                        ? 'دکان کے صفحے پر نمایاں کریں'
                        : 'Highlight on shop page',
                    value: _featured,
                    fontFamily: fontFamily,
                    onChanged: (v) => setState(() => _featured = v),
                  ),
                  _buildToggleRow(
                    title: isUrdu ? 'اسٹاک ٹریک کریں' : 'Track Stock',
                    sub: isUrdu
                        ? 'اس آئٹم کی مقدار ریکارڈ رکھیں'
                        : 'Keep quantity record',
                    value: _trackStock,
                    fontFamily: fontFamily,
                    onChanged: (v) => setState(() => _trackStock = v),
                  ),
                  _buildToggleRow(
                    title: isUrdu ? 'واپسی کی اجازت' : 'Allow Returns',
                    sub: isUrdu
                        ? 'گاہک آئٹم واپس کر سکتا ہے'
                        : 'Customer can return',
                    value: _allowReturn,
                    fontFamily: fontFamily,
                    onChanged: (v) => setState(() => _allowReturn = v),
                  ),
                  _buildToggleRow(
                    title: isUrdu ? 'ختم ہونے پر بند' : 'Stop When Out',
                    sub: isUrdu
                        ? 'اسٹاک ختم ہو تو فروخت بند'
                        : 'Stop selling when stock ends',
                    value: _stopWhenOut,
                    fontFamily: fontFamily,
                    onChanged: (v) => setState(() => _stopWhenOut = v),
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ═══ سیو بٹن ═══
              AppButton(
                text: isEdit
                    ? (isUrdu ? 'ترمیم محفوظ کریں' : 'Update Item')
                    : (isUrdu ? 'آئٹم شامل کریں' : 'Add Item'),
                color: AppTheme.themeColor,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.large,
                isFullWidth: true,
                isLoading: _isSaving,
                onPressed: () => _saveItem(isUrdu),
              ),

              // ═══ حذف کا بٹن (صرف ترمیم میں) ═══
              if (isEdit) ...[
                const SizedBox(height: 10),
                _buildDeleteButton(isUrdu, fontFamily),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // سیکشن کارڈ
  // ═══════════════════════════════════════════
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String fontFamily,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: AppTheme.themeColor),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppTheme.backgroundColor),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRowField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String fontFamily,
    bool isNumber = false,
    bool isLtr = false,
    bool optional = false,
    bool isUrdu = true,
    bool isLast = false,
    String? suffix,
    Widget? trailing,
    String? Function(String?)? validator,
  }) {
    return _CustomInputField(
      label: label,
      icon: icon,
      controller: controller,
      fontFamily: fontFamily,
      isNumber: isNumber,
      isLtr: isLtr,
      optional: optional,
      isUrdu: isUrdu,
      isLast: isLast,
      suffix: suffix,
      trailing: trailing,
      validator: validator,
    );
  }

  Widget _buildFullField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String fontFamily,
    int maxLines = 1,
    bool isLast = false,
    String? Function(String?)? validator,
  }) {
    return _CustomInputField(
      label: label,
      icon: icon,
      controller: controller,
      fontFamily: fontFamily,
      maxLines: maxLines,
      isLast: isLast,
      validator: validator,
    );
  }

  // ═══════════════════════════════════════════
  // سلائیڈر سیکشن (افقی چپس)
  // ═══════════════════════════════════════════
  Widget _buildSliderSection({
    required String label,
    required IconData icon,
    required String fontFamily,
    required List<_ChipData> chips,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppTheme.themeColor),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: chips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final chip = chips[index];
                    return _buildUnitChip(
                      label: chip.label,
                      isSelected: chip.isSelected,
                      fontFamily: fontFamily,
                      onTap: chip.onTap,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: AppTheme.backgroundColor),
      ],
    );
  }

  Widget _buildUnitChip({
    required String label,
    required bool isSelected,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.themeColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppTheme.themeColor : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: fontFamily,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.darkColor,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // تصویر والی قطار
  // ═══════════════════════════════════════════
  Widget _buildImageRow(bool isUrdu, String fontFamily, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(PhosphorIcons.camera(),
                    size: 16, color: AppTheme.themeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _imagePath != null
                          ? (isUrdu ? 'تصویر تبدیل کریں' : 'Change Image')
                          : (isUrdu ? 'تصویر اپلوڈ کریں' : 'Upload Image'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUrdu ? 'آئٹم کی واضح تصویر' : 'Clear picture of item',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey[500],
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  _pickImage(isUrdu);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _imagePath != null
                          ? AppTheme.themeColor
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _imagePath!.startsWith('http')
                              ? Image.network(_imagePath!, fit: BoxFit.cover)
                              : Image.file(File(_imagePath!), fit: BoxFit.cover),
                        )
                      : Icon(PhosphorIcons.camera(),
                          size: 22, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: AppTheme.backgroundColor),
      ],
    );
  }

  Future<void> _pickImage(bool isUrdu) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() => _imagePath = image.path);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════
  // ٹوگل والی قطار
  // ═══════════════════════════════════════════
  Widget _buildToggleRow({
    required String title,
    required String sub,
    required bool value,
    required String fontFamily,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey[500],
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppTheme.themeColor,
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Icon(Icons.check, size: 14, color: Colors.white);
                  }
                  return const Icon(Icons.close, size: 14, color: Colors.grey);
                }),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: AppTheme.backgroundColor),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // بارکوڈ اسکینر
  // ═══════════════════════════════════════════
  void _openBarcodeScanner(bool isUrdu) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isUrdu ? 'بارکوڈ اسکینر' : 'Barcode Scanner'),
        content: Text(
          isUrdu
              ? 'یہاں بارکوڈ اسکینر کھلے گا'
              : 'Barcode scanner will open here',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isUrdu ? 'ٹھیک ہے' : 'OK'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // حذف کا بٹن
  // ═══════════════════════════════════════════
  Widget _buildDeleteButton(bool isUrdu, String fontFamily) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(isUrdu ? 'آئٹم حذف کریں؟' : 'Delete item?'),
              content: Text(
                isUrdu
                    ? 'کیا آپ واقعی یہ آئٹم حذف کرنا چاہتے ہیں؟'
                    : 'Are you sure you want to delete this item?',
                style: TextStyle(fontFamily: fontFamily),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    isUrdu ? 'حذف کریں' : 'Delete',
                    style: TextStyle(color: AppTheme.expenseColor),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true && mounted) {
            final stockService =
                Provider.of<StockService>(context, listen: false);
            await stockService.deleteStockItem(widget.initialItem!.id);
            if (mounted) Navigator.pop(context);
          }
        },
        icon: Icon(PhosphorIcons.trash(),
            color: AppTheme.expenseColor, size: 18),
        label: Text(
          isUrdu ? 'آئٹم حذف کریں' : 'Delete Item',
          style: TextStyle(
            color: AppTheme.expenseColor,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: AppTheme.expenseColor.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// چپ ڈیٹا کلاس
// ═══════════════════════════════════════════
class _ChipData {
  final String value;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  _ChipData({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
}

// ═══════════════════════════════════════════
// کسٹم ان پٹ فیلڈ (پوری پٹی ان پٹ، فوکس پر گریڈینٹ، کنارے تک ڈیوائیڈر)
// ═══════════════════════════════════════════
class _CustomInputField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String fontFamily;
  final bool isNumber;
  final bool isLtr;
  final bool optional;
  final bool isUrdu;
  final int maxLines;
  final String? suffix;
  final Widget? trailing;
  final String? Function(String?)? validator;
  final bool isLast;

  const _CustomInputField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.fontFamily,
    this.isNumber = false,
    this.isLtr = false,
    this.optional = false,
    this.isUrdu = true,
    this.maxLines = 1,
    this.suffix,
    this.trailing,
    this.validator,
    this.isLast = false,
  });

  @override
  State<_CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<_CustomInputField> {
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullLabel = widget.optional
        ? '${widget.label} ${widget.isUrdu ? "(اختیاری)" : "(optional)"}'
        : widget.label;

    final effectiveFontFamily = widget.isNumber ? '' : widget.fontFamily;
    final effectiveIsLtr = widget.isNumber ? true : widget.isLtr;
    final effectiveTextAlign = widget.isNumber
        ? TextAlign.left
        : (widget.isLtr ? TextAlign.left : TextAlign.right);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: _hasFocus
                ? LinearGradient(
                    colors: [
                      AppTheme.themeColor.withValues(alpha: 0.3),
                      AppTheme.themeColor.withValues(alpha: 0.09),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: _hasFocus ? null : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon + Label on left
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: AppTheme.themeColor),
                  const SizedBox(width: 10),
                  Text(
                    fullLabel,
                    style: TextStyle(
                      fontFamily: widget.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: _hasFocus ? AppTheme.themeColor : AppTheme.darkColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Entire strip acts as input field
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: widget.isNumber
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : (widget.maxLines > 1
                          ? TextInputType.multiline
                          : TextInputType.text),
                  maxLines: widget.maxLines,
                  textDirection:
                      effectiveIsLtr ? TextDirection.ltr : TextDirection.rtl,
                  textAlign: effectiveTextAlign,
                  style: TextStyle(
                    fontFamily: effectiveFontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkColor,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: widget.isUrdu ? 'درج کریں...' : 'Enter...',
                    hintStyle: TextStyle(
                      fontFamily: effectiveFontFamily,
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                    suffixText: widget.suffix,
                    suffixStyle: TextStyle(
                      fontFamily: effectiveFontFamily,
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: widget.validator,
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
        if (!widget.isLast)
          const Divider(height: 1, thickness: 1, color: AppTheme.backgroundColor),
      ],
    );
  }
}
