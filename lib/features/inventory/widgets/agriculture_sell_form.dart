// lib/features/inventory/widgets/agriculture_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class AgricultureSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const AgricultureSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<AgricultureSellForm> createState() => _AgricultureSellFormState();
}

class _AgricultureSellFormState extends State<AgricultureSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  
  late String _productType;
  late String _season;
  late String _quality;
  
  final List<String> _productTypes = [
    'Seeds', 'Fertilizer', 'Pesticide', 'Herbicide',
    'Tractor', 'Harvester', 'Plough', 'Water Pump',
    'Fruits', 'Vegetables', 'Grains', 'Other'
  ];
  
  final List<String> _seasonOptions = ['Spring', 'Summer', 'Autumn', 'Winter', 'Rabi', 'Kharif', 'All Season'];
  final List<String> _qualityOptions = ['Premium', 'Grade A', 'Grade B', 'Standard', 'Economic'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _brandController = TextEditingController(text: widget.data['brand']);
    _priceController = TextEditingController(text: widget.data['price']);
    _quantityController = TextEditingController(text: widget.data['quantity']);
    
    _productType = widget.data['productType'] ?? 'Seeds';
    _season = widget.data['season'] ?? 'Spring';
    _quality = widget.data['quality'] ?? 'Premium';

    _nameController.addListener(_notify);
    _brandController.addListener(_notify);
    _priceController.addListener(_notify);
    _quantityController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': _priceController.text.trim(),
      'quantity': _quantityController.text.trim(),
      'productType': _productType,
      'season': _season,
      'quality': _quality,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final productTypesUr = ['بیج', 'کھاد', 'کیڑے مار دوا', 'جڑی بوٹی مار دوا', 'ٹریکٹر', 'کٹائی مشین', 'ہل', 'واٹر پمپ', 'پھل', 'سبزیاں', 'اناج', 'دیگر'];
    final seasonUr = ['بہار', 'گرمی', 'خزاں', 'سردی', 'ربیع', 'خریف', 'تمام موسم'];
    final qualityUr = ['پریمیم', 'گریڈ اے', 'گریڈ بی', 'معیاری', 'اقتصادی'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.leaf(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'آئٹم کا نام' : 'Item Name',
                      hint: 'Wheat Seeds...',
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
                      label: isUrdu ? 'برانڈ / کمپنی' : 'Brand / Co',
                      hint: 'Engro, Fauji...',
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
          title: isUrdu ? 'مقدار اور موسم' : 'Quantity & Season',
          icon: PhosphorIcons.calendar(),
          child: Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _quantityController,
                  label: isUrdu ? 'مقدار' : 'Quantity',
                  hint: '50 kg...',
                  icon: PhosphorIcons.scales(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: isUrdu ? 'موسم' : 'Season',
                  value: _season,
                  items: _seasonOptions,
                  itemsUr: isUrdu ? seasonUr : null,
                  icon: PhosphorIcons.sun(),
                  onChanged: (v) { setState(() => _season = v!); _notify(); },
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                ),
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
            hint: '5000',
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
