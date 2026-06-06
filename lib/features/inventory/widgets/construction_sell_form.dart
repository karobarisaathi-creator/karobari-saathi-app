// lib/features/inventory/widgets/construction_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class ConstructionSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const ConstructionSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<ConstructionSellForm> createState() => _ConstructionSellFormState();
}

class _ConstructionSellFormState extends State<ConstructionSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _gradeController;
  
  late String _productType;
  late String _unit;
  late String _quality;
  
  final List<String> _productTypes = [
    'Cement', 'Bricks', 'Crush/Stone', 'Sand', 'Steel/Sarya',
    'Paint', 'Tiles', 'Marble', 'Wood', 'Gypsum',
    'Plaster', 'Blocks', 'Insulation', 'Roofing', 'Other'
  ];
  
  final List<String> _unitOptions = [
    'Bag', 'Kg', 'Ton', 'Piece', 'Square Foot', 'Cubic Foot', 
    'Liter', 'Gallon', 'Roll', 'Box', 'Truck', 'Other'
  ];
  
  final List<String> _qualityOptions = ['Premium', 'Grade A', 'Grade B', 'Standard', 'Economic'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _brandController = TextEditingController(text: widget.data['brand']);
    _priceController = TextEditingController(text: widget.data['price']);
    _quantityController = TextEditingController(text: widget.data['quantity']);
    _gradeController = TextEditingController(text: widget.data['grade']);
    
    _productType = widget.data['productType'] ?? 'Cement';
    _unit = widget.data['unit'] ?? 'Bag';
    _quality = widget.data['quality'] ?? 'Premium';

    _nameController.addListener(_notify);
    _brandController.addListener(_notify);
    _priceController.addListener(_notify);
    _quantityController.addListener(_notify);
    _gradeController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': _priceController.text.trim(),
      'quantity': _quantityController.text.trim(),
      'grade': _gradeController.text.trim(),
      'productType': _productType,
      'unit': _unit,
      'quality': _quality,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final productTypesUr = [
      'سیمنٹ', 'اینٹیں', 'بجری/پتھر', 'ریت', 'اسٹیل/سرایا',
      'پینٹ', 'ٹائلیں', 'ماربل', 'لکڑی', 'جپسم',
      'پلاسٹر', 'بلاکس', 'انسولیشن', 'چھت سازی', 'دیگر'
    ];
    final unitOptionsUr = ['بوری', 'کلو', 'ٹن', 'عدد', 'مربع فٹ', 'کیوبک فٹ', 'لیٹر', 'رول', 'ٹرک', 'دیگر'];
    final qualityUr = ['پریمیم', 'گریڈ اے', 'گریڈ بی', 'معیاری', 'اقتصادی'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.factory(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'آئٹم کا نام' : 'Item Name',
                      hint: 'Bestway Cement...',
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
                      hint: 'Lucky, Engro...',
                      icon: PhosphorIcons.copyright(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'معیار' : 'Quality',
                      value: _quality,
                      items: _qualityOptions,
                      itemsUr: isUrdu ? qualityUr : null,
                      icon: PhosphorIcons.star(),
                      onChanged: (v) { setState(() => _quality = v!); _notify(); },
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
          title: isUrdu ? 'مقدار اور درجہ' : 'Quantity & Grade',
          icon: PhosphorIcons.package(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _quantityController,
                      label: isUrdu ? 'مقدار' : 'Quantity',
                      hint: '100',
                      icon: PhosphorIcons.scales(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      label: isUrdu ? 'یونٹ' : 'Unit',
                      value: _unit,
                      items: _unitOptions,
                      itemsUr: isUrdu ? unitOptionsUr : null,
                      icon: PhosphorIcons.ruler(),
                      onChanged: (v) { setState(() => _unit = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _gradeController,
                label: isUrdu ? 'گریڈ / تفصیلات' : 'Grade / Specs',
                hint: '42.5 Grade...',
                icon: PhosphorIcons.info(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
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
            hint: '1200',
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
        labelStyle: TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: 13, color: Colors.grey[600]),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.themeColor),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
