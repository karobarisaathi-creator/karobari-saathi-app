// lib/features/inventory/widgets/electronics_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

/// الیکٹرانکس آئٹمز (لیپ ٹاپ، ٹی وی، فرج، وغیرہ) کے لیے فارم
class ElectronicsSellForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? initialData;

  const ElectronicsSellForm({
    super.key,
    required this.onSave,
    this.initialData,
  });

  @override
  State<ElectronicsSellForm> createState() => _ElectronicsSellFormState();
}

class _ElectronicsSellFormState extends State<ElectronicsSellForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _modelController;
  late TextEditingController _brandController;
  late TextEditingController _specsController;
  late TextEditingController _priceController;
  late TextEditingController _warrantyController;
  
  // Selected options
  String _condition = 'New';
  String _warrantyType = 'Local Warranty';
  
  final List<String> _conditionOptions = ['New', 'Like New', 'Used', 'Needs Repair'];
  final List<String> _warrantyOptions = ['Local Warranty', 'International Warranty', 'No Warranty', 'Shop Warranty'];

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.initialData?['model']);
    _brandController = TextEditingController(text: widget.initialData?['brand']);
    _specsController = TextEditingController(text: widget.initialData?['specs']);
    _priceController = TextEditingController(text: widget.initialData?['price']);
    _warrantyController = TextEditingController(text: widget.initialData?['warrantyPeriod']);
    _condition = widget.initialData?['condition'] ?? 'New';
    _warrantyType = widget.initialData?['warrantyType'] ?? 'Local Warranty';

    // Add listeners for auto-sync with parent
    _modelController.addListener(_autoSave);
    _brandController.addListener(_autoSave);
    _specsController.addListener(_autoSave);
    _priceController.addListener(_autoSave);
    _warrantyController.addListener(_autoSave);
  }

  void _autoSave() {
    widget.onSave({
      'model': _modelController.text.trim(),
      'brand': _brandController.text.trim(),
      'specs': _specsController.text.trim(),
      'price': _priceController.text.trim(),
      'warrantyPeriod': _warrantyController.text.trim(),
      'condition': _condition,
      'warrantyType': _warrantyType,
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _brandController.dispose();
    _specsController.dispose();
    _priceController.dispose();
    _warrantyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.devices(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _modelController,
                      label: isUrdu ? 'ماڈل *' : 'Model *',
                      hint: 'iPhone 14, TV, Dell Laptop',
                      icon: PhosphorIcons.tag(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _brandController,
                      label: isUrdu ? 'برانڈ *' : 'Brand *',
                      hint: 'Apple, Samsung, Dell',
                      icon: PhosphorIcons.copyright(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _specsController,
                label: isUrdu ? 'اہم خصوصیات *' : 'Key Specs *',
                hint: '8GB RAM, 256GB SSD, Core i7',
                icon: PhosphorIcons.cpu(),
                maxLines: 2,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: isUrdu ? 'قیمت *' : 'Price *',
                      hint: '150000',
                      icon: PhosphorIcons.currencyCircleDollar(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      prefix: 'Rs ',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _warrantyController,
                      label: isUrdu ? 'وارنٹی مدت' : 'Warranty Period',
                      hint: '1 year',
                      icon: PhosphorIcons.certificate(),
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

        // ========== CARD 2: حالت اور وارنٹی ==========
        _buildCard(
          title: isUrdu ? 'حالت اور وارنٹی' : 'Condition & Warranty',
          icon: PhosphorIcons.shieldCheck(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'حالت *' : 'Condition *',
                      value: _condition,
                      items: _conditionOptions,
                      icon: PhosphorIcons.cube(),
                      onChanged: (v) {
                        setState(() => _condition = v!);
                        _autoSave();
                      },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'وارنٹی قسم' : 'Warranty Type',
                      value: _warrantyType,
                      items: _warrantyOptions,
                      icon: PhosphorIcons.certificate(),
                      onChanged: (v) {
                        setState(() => _warrantyType = v!);
                        _autoSave();
                      },
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

  // ========== Helper Widgets ==========

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.themeColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    required bool isUrdu,
    required String fontFamily,
    String prefix = '',
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(fontSize: 15, fontFamily: isNumber ? '' : fontFamily),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
        labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.themeColor),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.themeColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(fontFamily: fontFamily, fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
