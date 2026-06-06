// lib/features/inventory/widgets/assets_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class AssetsSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const AssetsSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<AssetsSellForm> createState() => _AssetsSellFormState();
}

class _AssetsSellFormState extends State<AssetsSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _modelController;
  late TextEditingController _serialController;
  
  late String _assetType;
  late String _condition;
  late String _warranty;
  late String _depreciation;
  
  final List<String> _assetTypes = [
    'Machinery', 'Equipment', 'Office Furniture', 'Computer/IT',
    'Generator', 'Vehicle (Company)', 'Tools', 'Medical Equipment',
    'Restaurant Equipment', 'Photography Gear', 'Printing Press',
    'HVAC System', 'Security System', 'Other'
  ];
  
  final List<String> _conditionOptions = ['New', 'Like New', 'Good', 'Used - Working', 'Used - Needs Repair'];
  final List<String> _warrantyOptions = ['No Warranty', '1 Month', '3 Months', '6 Months', '1 Year', '2 Years', '3+ Years'];
  final List<String> _depreciationOptions = ['Less than 1 year', '1-2 years', '2-3 years', '3-5 years', '5+ years'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _brandController = TextEditingController(text: widget.data['brand']);
    _priceController = TextEditingController(text: widget.data['price']);
    _modelController = TextEditingController(text: widget.data['model']);
    _serialController = TextEditingController(text: widget.data['serial']);
    
    _assetType = widget.data['assetType'] ?? 'Machinery';
    _condition = widget.data['condition'] ?? 'New';
    _warranty = widget.data['warranty'] ?? 'No Warranty';
    _depreciation = widget.data['depreciation'] ?? 'Less than 1 year';

    _nameController.addListener(_notify);
    _brandController.addListener(_notify);
    _priceController.addListener(_notify);
    _modelController.addListener(_notify);
    _serialController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': _priceController.text.trim(),
      'model': _modelController.text.trim(),
      'serial': _serialController.text.trim(),
      'assetType': _assetType,
      'condition': _condition,
      'warranty': _warranty,
      'depreciation': _depreciation,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final assetTypesUr = ['مشینری', 'آلات', 'آفس فرنیچر', 'کمپیوٹر/آئی ٹی', 'جنریٹر', 'گاڑی (کمپنی)', 'اوزار', 'میڈیکل', 'ریسٹورنٹ', 'فوٹوگرافی', 'پریس', 'HVAC', 'سیکیورٹی', 'دیگر'];
    final conditionUr = ['نئی', 'نئی جیسی', 'اچھی', 'استعمال شدہ', 'مرمت درکار'];
    final depreciationUr = ['1 سال سے کم', '1-2 سال', '2-3 سال', '3-5 سال', '5+ سال'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.buildings(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'اثاثہ کا نام' : 'Asset Name',
                      hint: 'Lathe Machine...',
                      icon: PhosphorIcons.tag(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      label: isUrdu ? 'قسم' : 'Type',
                      value: _assetType,
                      items: _assetTypes,
                      itemsUr: isUrdu ? assetTypesUr : null,
                      icon: PhosphorIcons.cube(),
                      onChanged: (v) { setState(() => _assetType = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _brandController,
                      label: isUrdu ? 'برانڈ' : 'Brand',
                      hint: 'Siemens...',
                      icon: PhosphorIcons.copyright(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _modelController,
                      label: isUrdu ? 'ماڈل' : 'Model',
                      hint: 'XYZ-2000...',
                      icon: PhosphorIcons.cpu(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: isUrdu ? 'تکنیکی معلومات' : 'Technical Info',
          icon: PhosphorIcons.gear(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'حالت' : 'Condition',
                      value: _condition,
                      items: _conditionOptions,
                      itemsUr: isUrdu ? conditionUr : null,
                      icon: PhosphorIcons.shieldCheck(),
                      onChanged: (v) { setState(() => _condition = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'وارنٹی' : 'Warranty',
                      value: _warranty,
                      items: _warrantyOptions,
                      icon: PhosphorIcons.certificate(),
                      onChanged: (v) { setState(() => _warranty = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'استعمال مدت' : 'Usage Duration',
                      value: _depreciation,
                      items: _depreciationOptions,
                      itemsUr: isUrdu ? depreciationUr : null,
                      icon: PhosphorIcons.clock(),
                      onChanged: (v) { setState(() => _depreciation = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _serialController,
                      label: isUrdu ? 'سیریل نمبر' : 'Serial No',
                      hint: 'SN-123...',
                      icon: PhosphorIcons.barcode(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: isUrdu ? 'قیمت' : 'Pricing',
          icon: PhosphorIcons.currencyCircleDollar(),
          child: _buildTextField(
            controller: _priceController,
            label: isUrdu ? 'قیمت' : 'Price',
            hint: '500000',
            icon: PhosphorIcons.currencyCircleDollar(),
            isNumber: true,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            prefix: 'Rs ',
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18, color: AppTheme.themeColor), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: fontFamily))]),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon, bool isNumber = false, required bool isUrdu, required String fontFamily, String prefix = ''}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: isUrdu ? 15 : 12, color: Colors.grey[600]),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkColor),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.themeColor),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5)),
      ),
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, List<String>? itemsUr, required IconData icon, required Function(String?) onChanged, required bool isUrdu, required String fontFamily}) {
    final displayItems = (isUrdu && itemsUr != null) ? itemsUr : items;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 14, color: AppTheme.darkColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: isUrdu ? 15 : 12, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5)),
      ),
      items: displayItems.asMap().entries.map((entry) {
        final index = entry.key;
        return DropdownMenuItem(value: items[index], child: Text(entry.value));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
