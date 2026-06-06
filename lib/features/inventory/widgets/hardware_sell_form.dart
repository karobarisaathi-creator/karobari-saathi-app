// lib/features/inventory/widgets/hardware_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class HardwareSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const HardwareSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<HardwareSellForm> createState() => _HardwareSellFormState();
}

class _HardwareSellFormState extends State<HardwareSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _sizeController;
  
  late String _productType;
  late String _material;
  late String _condition;
  late String _warranty;
  
  final List<String> _productTypes = [
    'Tools', 'Drill Machine', 'Saw', 'Hammer', 'Screwdriver',
    'Wrench', 'Pliers', 'Measuring Tape', 'Level Tool',
    'Pipe', 'Valve', 'Faucet', 'Wire', 'Switch',
    'Socket', 'Bulb', 'Fan', 'Motor', 'Other'
  ];
  
  final List<String> _materialOptions = [
    'Steel', 'Iron', 'Stainless Steel', 'Brass', 'Copper', 
    'Aluminum', 'Plastic', 'Rubber', 'Glass', 'Other'
  ];
  
  final List<String> _conditionOptions = ['New', 'Like New', 'Used - Good', 'Used - Fair', 'Needs Repair'];
  final List<String> _warrantyOptions = ['No Warranty', '1 Month', '3 Months', '6 Months', '1 Year', '2 Years'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _brandController = TextEditingController(text: widget.data['brand']);
    _priceController = TextEditingController(text: widget.data['price']);
    _quantityController = TextEditingController(text: widget.data['quantity']);
    _sizeController = TextEditingController(text: widget.data['size']);
    
    _productType = widget.data['productType'] ?? 'Tools';
    _material = widget.data['material'] ?? 'Steel';
    _condition = widget.data['condition'] ?? 'New';
    _warranty = widget.data['warranty'] ?? 'No Warranty';

    _nameController.addListener(_notify);
    _brandController.addListener(_notify);
    _priceController.addListener(_notify);
    _quantityController.addListener(_notify);
    _sizeController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': _priceController.text.trim(),
      'quantity': _quantityController.text.trim(),
      'size': _sizeController.text.trim(),
      'productType': _productType,
      'material': _material,
      'condition': _condition,
      'warranty': _warranty,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final productTypesUr = [
      'اوزار', 'ڈرل مشین', 'آری', 'ہتھوڑا', 'پچکس',
      'رینچ', 'چمٹا', 'ٹیپ', 'لیول ٹول',
      'پائپ', 'والو', 'نل', 'تار', 'سوئچ',
      'سوکٹ', 'بلب', 'پنکھا', 'موٹر', 'دیگر'
    ];
    final materialUr = ['اسٹیل', 'آئرن', 'سٹین لیس اسٹیل', 'براس', 'کاپر', 'ایلومینیم', 'پلاسٹک', 'ربڑ', 'شیشہ', 'دیگر'];
    final conditionUr = ['نئی', 'نئی جیسی', 'استعمال شدہ - اچھی', 'استعمال شدہ - معمولی', 'مرمت درکار'];
    final warrantyUr = ['کوئی وارنٹی نہیں', '1 مہینہ', '3 ماہ', '6 ماہ', '1 سال', '2 سال'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.wrench(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'آئٹم کا نام' : 'Item Name',
                      hint: 'Drill Machine...',
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
                      value: _productType,
                      items: _productTypes,
                      itemsUr: isUrdu ? productTypesUr : null,
                      icon: PhosphorIcons.cube(),
                      onChanged: (v) { setState(() => _productType = v!); _notify(); },
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
                      hint: 'Bosch, Local...',
                      icon: PhosphorIcons.copyright(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'مواد (Material)' : 'Material',
                      value: _material,
                      items: _materialOptions,
                      itemsUr: isUrdu ? materialUr : null,
                      icon: PhosphorIcons.shapes(),
                      onChanged: (v) { setState(() => _material = v!); _notify(); },
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
          title: isUrdu ? 'تفصیلات اور مقدار' : 'Details & Quantity',
          icon: PhosphorIcons.ruler(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _sizeController,
                      label: isUrdu ? 'سائز / ماپ' : 'Size / Measure',
                      hint: '1 inch, 6mm...',
                      icon: PhosphorIcons.ruler(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _quantityController,
                      label: isUrdu ? 'مقدار' : 'Quantity',
                      hint: '10 pcs...',
                      icon: PhosphorIcons.package(),
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
                      itemsUr: isUrdu ? warrantyUr : null,
                      icon: PhosphorIcons.certificate(),
                      onChanged: (v) { setState(() => _warranty = v!); _notify(); },
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
            hint: '500',
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
        labelStyle: TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: 13, color: Colors.grey[600]),
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
