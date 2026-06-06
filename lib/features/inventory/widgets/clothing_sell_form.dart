// lib/features/inventory/widgets/clothing_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

/// کپڑوں کے لیے فارم (مردانہ، زنانہ، بچوں کے کپڑے)
class ClothingSellForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? initialData;

  const ClothingSellForm({
    super.key,
    required this.onSave,
    this.initialData,
  });

  @override
  State<ClothingSellForm> createState() => _ClothingSellFormState();
}

class _ClothingSellFormState extends State<ClothingSellForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  
  // Selected options
  String _category = 'Men';
  String _size = 'Medium';
  String _fabric = 'Cotton';
  String _condition = 'New';
  
  final List<String> _categoryOptions = ['Men', 'Women', 'Kids', 'Unisex'];
  final List<String> _sizeOptions = ['XS', 'Small', 'Medium', 'Large', 'XL', 'XXL', 'Free Size'];
  final List<String> _fabricOptions = [
    'Cotton', 'Lawn', 'Chiffon', 'Linen', 'Silk', 
    'Wool', 'Denim', 'Polyester', 'Velvet', 'Other'
  ];
  final List<String> _conditionOptions = ['New with Tag', 'New without Tag', 'Like New', 'Used - Good', 'Used - Fair'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name']);
    _brandController = TextEditingController(text: widget.initialData?['brand']);
    _priceController = TextEditingController(text: widget.initialData?['price']);
    _descriptionController = TextEditingController(text: widget.initialData?['description']);
    _category = widget.initialData?['category'] ?? 'Men';
    _size = widget.initialData?['size'] ?? 'Medium';
    _fabric = widget.initialData?['fabric'] ?? 'Cotton';
    _condition = widget.initialData?['condition'] ?? 'New with Tag';

    // Add listeners for auto-sync with parent
    _nameController.addListener(_autoSave);
    _brandController.addListener(_autoSave);
    _priceController.addListener(_autoSave);
    _descriptionController.addListener(_autoSave);
  }

  void _autoSave() {
    widget.onSave({
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': _priceController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category,
      'size': _size,
      'fabric': _fabric,
      'condition': _condition,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
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
          icon: PhosphorIcons.tShirt(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'آئٹم کا نام *' : 'Item Name *',
                      hint: isUrdu ? 'کرتا شلوار، پرنٹڈ شرٹ' : 'Kurta Shalwar, Printed Shirt',
                      icon: PhosphorIcons.tag(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _brandController,
                      label: isUrdu ? 'برانڈ' : 'Brand',
                      hint: 'J., Alkaram, Gul Ahmed',
                      icon: PhosphorIcons.copyright(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _priceController,
                      label: isUrdu ? 'قیمت *' : 'Price *',
                      hint: '5000',
                      icon: PhosphorIcons.currencyCircleDollar(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      prefix: 'Rs ',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      label: isUrdu ? 'کیٹیگری' : 'Category',
                      value: _category,
                      items: _categoryOptions,
                      icon: PhosphorIcons.users(),
                      onChanged: (v) {
                        setState(() => _category = v!);
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

        const SizedBox(height: 16),

        // ========== CARD 2: تفصیلات ==========
        _buildCard(
          title: isUrdu ? 'تفصیلات' : 'Details',
          icon: PhosphorIcons.ruler(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'سائز' : 'Size',
                      value: _size,
                      items: _sizeOptions,
                      icon: PhosphorIcons.ruler(),
                      onChanged: (v) {
                        setState(() => _size = v!);
                        _autoSave();
                      },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'کپڑا' : 'Fabric',
                      value: _fabric,
                      items: _fabricOptions,
                      icon: PhosphorIcons.tShirt(),
                      onChanged: (v) {
                        setState(() => _fabric = v!);
                        _autoSave();
                      },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                label: isUrdu ? 'حالت' : 'Condition',
                value: _condition,
                items: _conditionOptions,
                icon: PhosphorIcons.shieldCheck(),
                onChanged: (v) {
                  setState(() => _condition = v!);
                  _autoSave();
                },
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ========== CARD 3: تفصیل ==========
        _buildCard(
          title: isUrdu ? 'مزید تفصیل' : 'Description',
          icon: PhosphorIcons.note(),
          child: _buildTextField(
            controller: _descriptionController,
            label: isUrdu ? 'تفصیل (اختیاری)' : 'Description (Optional)',
            hint: isUrdu ? 'رنگ، ڈیزائن، موقع وغیرہ' : 'Color, design, occasion, etc.',
            icon: PhosphorIcons.notePencil(),
            maxLines: 3,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            required: false,
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
    bool required = true,
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
