// lib/features/inventory/widgets/food_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class FoodSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const FoodSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<FoodSellForm> createState() => _FoodSellFormState();
}

class _FoodSellFormState extends State<FoodSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _weightController;
  late TextEditingController _expiryController;
  
  late String _foodType;
  late String _storageType;
  late String _dietaryType;
  late String _isHalal;
  
  final List<String> _foodTypes = [
    'Packaged Food', 'Fresh Fruits', 'Fresh Vegetables', 'Meat',
    'Beverages', 'Bakery Items', 'Dairy Products', 'Frozen Food',
    'Spices', 'Cooking Oil', 'Honey', 'Other'
  ];
  
  final List<String> _storageOptions = ['Room Temp', 'Refrigerated', 'Frozen', 'Cool Dark Place'];
  final List<String> _dietaryOptions = ['Regular', 'Organic', 'Gluten Free', 'Sugar Free', 'Low Fat', 'Vegan'];
  final List<String> _halalOptions = ['Yes', 'No', 'Unknown'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _brandController = TextEditingController(text: widget.data['brand']);
    _priceController = TextEditingController(text: widget.data['price']);
    _weightController = TextEditingController(text: widget.data['weight']);
    _expiryController = TextEditingController(text: widget.data['expiry']);
    
    _foodType = widget.data['foodType'] ?? 'Packaged Food';
    _storageType = widget.data['storageType'] ?? 'Room Temp';
    _dietaryType = widget.data['dietaryType'] ?? 'Regular';
    _isHalal = widget.data['isHalal'] ?? 'Yes';

    _nameController.addListener(_notify);
    _brandController.addListener(_notify);
    _priceController.addListener(_notify);
    _weightController.addListener(_notify);
    _expiryController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': _priceController.text.trim(),
      'weight': _weightController.text.trim(),
      'expiry': _expiryController.text.trim(),
      'foodType': _foodType,
      'storageType': _storageType,
      'dietaryType': _dietaryType,
      'isHalal': _isHalal,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final foodTypesUr = ['پیکڈ فوڈ', 'پھل', 'سبزیاں', 'گوشت', 'مشروبات', 'بیکری', 'ڈیری', 'منجمد', 'مصالحے', 'تیل', 'شہد', 'دیگر'];
    final storageUr = ['کمرے کا درجہ حرارت', 'فرج', 'منجمد', 'ٹھنڈی جگہ'];
    final halalUr = ['ہاں', 'نہیں', 'معلوم نہیں'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.cookingPot(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'آئٹم کا نام' : 'Item Name',
                      hint: 'Biscutes, Rice...',
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
                      value: _foodType,
                      items: _foodTypes,
                      itemsUr: isUrdu ? foodTypesUr : null,
                      icon: PhosphorIcons.forkKnife(),
                      onChanged: (v) { setState(() => _foodType = v!); _notify(); },
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
                      hint: 'National, Shan...',
                      icon: PhosphorIcons.copyright(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'حلال؟' : 'Halal?',
                      value: _isHalal,
                      items: _halalOptions,
                      itemsUr: isUrdu ? halalUr : null,
                      icon: PhosphorIcons.checkCircle(),
                      onChanged: (v) { setState(() => _isHalal = v!); _notify(); },
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
          title: isUrdu ? 'مقدار اور قیمت' : 'Quantity & Price',
          icon: PhosphorIcons.scales(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      label: isUrdu ? 'وزن / مقدار' : 'Weight / Qty',
                      hint: '1 kg, 500g...',
                      icon: PhosphorIcons.scales(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'ذخیرہ' : 'Storage',
                      value: _storageType,
                      items: _storageOptions,
                      itemsUr: isUrdu ? storageUr : null,
                      icon: PhosphorIcons.snowflake(),
                      onChanged: (v) { setState(() => _storageType = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _expiryController,
                      label: isUrdu ? 'ایکسپائری' : 'Expiry',
                      hint: '12/2025',
                      icon: PhosphorIcons.calendar(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ],
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
