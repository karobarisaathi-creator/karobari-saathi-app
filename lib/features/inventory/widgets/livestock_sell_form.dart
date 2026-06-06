// lib/features/inventory/widgets/livestock_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class LivestockSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const LivestockSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<LivestockSellForm> createState() => _LivestockSellFormState();
}

class _LivestockSellFormState extends State<LivestockSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _priceController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _milkController;
  
  late String _animalType;
  late String _purpose;
  late String _vaccinated;
  late String _gender;
  
  final List<String> _animalTypes = ['Cow', 'Buffalo', 'Goat', 'Sheep', 'Camel', 'Horse', 'Chicken', 'Other'];
  final List<String> _purposeOptions = ['Dairy (Milk)', 'Meat (Qurbani)', 'Breeding', 'Work', 'Pet'];
  final List<String> _vaccineOptions = ['Yes (Certified)', 'Yes (Uncertified)', 'No'];
  final List<String> _genderOptions = ['Female', 'Male', 'Castrated'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _breedController = TextEditingController(text: widget.data['breed']);
    _priceController = TextEditingController(text: widget.data['price']);
    _ageController = TextEditingController(text: widget.data['age']);
    _weightController = TextEditingController(text: widget.data['weight']);
    _milkController = TextEditingController(text: widget.data['milk']);
    
    _animalType = widget.data['animalType'] ?? 'Cow';
    _purpose = widget.data['purpose'] ?? 'Dairy (Milk)';
    _vaccinated = widget.data['vaccinated'] ?? 'Yes (Certified)';
    _gender = widget.data['gender'] ?? 'Female';

    _nameController.addListener(_notify);
    _breedController.addListener(_notify);
    _priceController.addListener(_notify);
    _ageController.addListener(_notify);
    _weightController.addListener(_notify);
    _milkController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'breed': _breedController.text.trim(),
      'price': _priceController.text.trim(),
      'age': _ageController.text.trim(),
      'weight': _weightController.text.trim(),
      'milk': _milkController.text.trim(),
      'animalType': _animalType,
      'purpose': _purpose,
      'vaccinated': _vaccinated,
      'gender': _gender,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _priceController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _milkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final animalTypesUr = ['گائے', 'بھینس', 'بکرا', 'بھیڑ', 'اونٹ', 'گھوڑا', 'مرغی', 'دیگر'];
    final purposeUr = ['دودھ (ڈیری)', 'گوشت (قربانی)', 'نسل افزائی', 'کام', 'پالتو'];
    final genderUr = ['مادہ', 'نر', 'خواجہ سرا'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.cow(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'جانور کا نام' : 'Animal Name',
                      hint: 'Gulabo, Shera...',
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
                      value: _animalType,
                      items: _animalTypes,
                      itemsUr: isUrdu ? animalTypesUr : null,
                      icon: PhosphorIcons.pawPrint(),
                      onChanged: (v) { setState(() => _animalType = v!); _notify(); },
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
                      controller: _breedController,
                      label: isUrdu ? 'نسل' : 'Breed',
                      hint: 'Sahiwal, Cholistani...',
                      icon: PhosphorIcons.treeStructure(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'جنس' : 'Gender',
                      value: _gender,
                      items: _genderOptions,
                      itemsUr: isUrdu ? genderUr : null,
                      icon: PhosphorIcons.genderIntersex(),
                      onChanged: (v) { setState(() => _gender = v!); _notify(); },
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
          title: isUrdu ? 'جسمانی معلومات و صحت' : 'Physical & Health',
          icon: PhosphorIcons.heartbeat(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _ageController,
                      label: isUrdu ? 'عمر' : 'Age',
                      hint: '2 Years...',
                      icon: PhosphorIcons.calendar(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      label: isUrdu ? 'وزن (کلو)' : 'Weight (kg)',
                      hint: '450',
                      icon: PhosphorIcons.scales(),
                      isNumber: true,
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
                      controller: _milkController,
                      label: isUrdu ? 'دودھ (لیٹر)' : 'Milk (Ltr)',
                      hint: '12',
                      icon: PhosphorIcons.drop(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'مقصد' : 'Purpose',
                      value: _purpose,
                      items: _purposeOptions,
                      itemsUr: isUrdu ? purposeUr : null,
                      icon: PhosphorIcons.target(),
                      onChanged: (v) { setState(() => _purpose = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: isUrdu ? 'ویکسینیشن' : 'Vaccination',
                value: _vaccinated,
                items: _vaccineOptions,
                icon: PhosphorIcons.shieldCheck(),
                onChanged: (v) { setState(() => _vaccinated = v!); _notify(); },
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
            hint: '250000',
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
