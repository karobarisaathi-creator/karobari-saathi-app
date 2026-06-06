// lib/features/inventory/widgets/real_estate_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class RealEstateSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const RealEstateSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<RealEstateSellForm> createState() => _RealEstateSellFormState();
}

class _RealEstateSellFormState extends State<RealEstateSellForm> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;
  late TextEditingController _areaController;
  
  late String _propertyType;
  late String _bedrooms;
  late String _bathrooms;
  late String _purpose;
  late String _areaUnit;
  
  final List<String> _propertyTypes = [
    'House', 'Flat/Apartment', 'Plot', 'Commercial Shop', 
    'Office', 'Warehouse', 'Farm House', 'Land'
  ];
  
  final List<String> _bedroomOptions = ['0', '1', '2', '3', '4', '5', '6', '7', '8+'];
  final List<String> _bathroomOptions = ['1', '2', '3', '4', '5', '6'];
  final List<String> _purposeOptions = ['Sale', 'Rent', 'Lease'];
  final List<String> _areaUnitOptions = ['Marla', 'Kanal', 'Sq ft', 'Sq yd', 'Sq m'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.data['title']);
    _locationController = TextEditingController(text: widget.data['location']);
    _priceController = TextEditingController(text: widget.data['price']);
    _areaController = TextEditingController(text: widget.data['area']);
    
    _propertyType = widget.data['propertyType'] ?? 'House';
    _bedrooms = widget.data['bedrooms'] ?? '3';
    _bathrooms = widget.data['bathrooms'] ?? '2';
    _purpose = widget.data['purpose'] ?? 'Sale';
    _areaUnit = widget.data['areaUnit'] ?? 'Marla';

    _titleController.addListener(_notify);
    _locationController.addListener(_notify);
    _priceController.addListener(_notify);
    _areaController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'title': _titleController.text.trim(),
      'location': _locationController.text.trim(),
      'price': _priceController.text.trim(),
      'area': _areaController.text.trim(),
      'propertyType': _propertyType,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'purpose': _purpose,
      'areaUnit': _areaUnit,
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final propertyTypesUr = ['مکان', 'فلیٹ', 'پلاٹ', 'دکان', 'آفس', 'گودام', 'فارم ہاؤس', 'زمین'];
    final purposeOptionsUr = ['فروخت', 'کرایہ', 'لیز'];
    final areaUnitUr = ['مرلہ', 'کنال', 'فٹ', 'گز', 'میٹر'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.house(),
          child: Column(
            children: [
              _buildTextField(
                controller: _titleController,
                label: isUrdu ? 'عنوان (اشتہار کا نام)' : 'Title (Ad Name)',
                hint: '5 Marla House...',
                icon: PhosphorIcons.tag(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _locationController,
                      label: isUrdu ? 'علاقہ / سوسائٹی' : 'Area / Society',
                      hint: 'DHA, Bahria...',
                      icon: PhosphorIcons.mapPin(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      label: isUrdu ? 'مقصد' : 'Purpose',
                      value: _purpose,
                      items: _purposeOptions,
                      itemsUr: isUrdu ? purposeOptionsUr : null,
                      icon: PhosphorIcons.target(),
                      onChanged: (v) { setState(() => _purpose = v!); _notify(); },
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
          title: isUrdu ? 'جائیداد کی تفصیلات' : 'Property Details',
          icon: PhosphorIcons.buildings(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'قسم' : 'Type',
                      value: _propertyType,
                      items: _propertyTypes,
                      itemsUr: isUrdu ? propertyTypesUr : null,
                      icon: PhosphorIcons.houseLine(),
                      onChanged: (v) { setState(() => _propertyType = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _areaController,
                            label: isUrdu ? 'رقبہ' : 'Area',
                            hint: '5',
                            icon: PhosphorIcons.ruler(),
                            isNumber: true,
                            isUrdu: isUrdu,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 65,
                          child: _buildDropdown(
                            label: '',
                            value: _areaUnit,
                            items: _areaUnitOptions,
                            itemsUr: isUrdu ? areaUnitUr : null,
                            icon: null,
                            onChanged: (v) { setState(() => _areaUnit = v!); _notify(); },
                            isUrdu: isUrdu,
                            fontFamily: fontFamily,
                            showIcon: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'بیڈ رومز' : 'Bedrooms',
                      value: _bedrooms,
                      items: _bedroomOptions,
                      icon: PhosphorIcons.bed(),
                      onChanged: (v) { setState(() => _bedrooms = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'باتھ رومز' : 'Bathrooms',
                      value: _bathrooms,
                      items: _bathroomOptions,
                      icon: PhosphorIcons.drop(),
                      onChanged: (v) { setState(() => _bathrooms = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _priceController,
                label: isUrdu ? 'قیمت' : 'Price',
                hint: '15000000',
                icon: PhosphorIcons.currencyCircleDollar(),
                isNumber: true,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                prefix: 'Rs ',
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

  Widget _buildDropdown({required String label, required String value, required List<String> items, List<String>? itemsUr, IconData? icon, required Function(String?) onChanged, required bool isUrdu, required String fontFamily, bool showIcon = true}) {
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
