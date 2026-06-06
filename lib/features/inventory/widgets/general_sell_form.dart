// lib/features/inventory/widgets/general_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

/// عام اشیاء کے لیے فارم
class GeneralSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const GeneralSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<GeneralSellForm> createState() => _GeneralSellFormState();
}

class _GeneralSellFormState extends State<GeneralSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  
  late String _condition;
  
  final List<String> _conditionOptions = ['New', 'Like New', 'Good', 'Used', 'Needs Repair'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _priceController = TextEditingController(text: widget.data['price']);
    _quantityController = TextEditingController(text: widget.data['quantity']);
    _condition = widget.data['condition'] ?? 'New';

    _nameController.addListener(_notify);
    _priceController.addListener(_notify);
    _quantityController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'price': _priceController.text.trim(),
      'quantity': _quantityController.text.trim(),
      'condition': _condition,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final conditionUr = ['نئی', 'نئی جیسی', 'اچھی', 'استعمال شدہ', 'مرمت درکار'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.cube(),
          child: Column(
            children: [
              _buildTextField(
                controller: _nameController,
                label: isUrdu ? 'آئٹم کا نام' : 'Item Name',
                hint: isUrdu ? 'کتاب، کھلونا وغیرہ...' : 'Book, toy, etc...',
                icon: PhosphorIcons.tag(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _quantityController,
                      label: isUrdu ? 'مقدار' : 'Quantity',
                      hint: '1',
                      icon: PhosphorIcons.package(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _priceController,
                label: isUrdu ? 'قیمت' : 'Price',
                hint: '500',
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
