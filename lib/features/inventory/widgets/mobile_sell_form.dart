// lib/features/inventory/widgets/mobile_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class MobileSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const MobileSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<MobileSellForm> createState() => _MobileSellFormState();
}

class _MobileSellFormState extends State<MobileSellForm> {
  late TextEditingController _modelController;
  late TextEditingController _ramController;
  late TextEditingController _storageController;
  late TextEditingController _processorController;
  late TextEditingController _batteryHealthController;
  late TextEditingController _priceController;
  
  late String _ptaStatus;
  late String _screenCondition;
  late String _bodyCondition;
  late String _accessories;
  
  final List<String> _ptaOptions = ['PTA Approved', 'Non-PTA', 'CPID (Patch)'];
  final List<String> _screenOptions = ['No scratch', 'Minor scratches', 'Cracked'];
  final List<String> _bodyOptions = ['No scratch', 'Minor scratches', 'Dents'];
  final List<String> _accessoriesOptions = [
    'Charger + Cable included',
    'Only phone (no accessories)',
    'Full box (charger, cable, earphones)',
  ];

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.data['model']);
    _ramController = TextEditingController(text: widget.data['ram']);
    _storageController = TextEditingController(text: widget.data['storage']);
    _processorController = TextEditingController(text: widget.data['processor']);
    _batteryHealthController = TextEditingController(text: widget.data['batteryHealth']);
    _priceController = TextEditingController(text: widget.data['price']);
    
    _ptaStatus = widget.data['ptaStatus'] ?? 'PTA Approved';
    _screenCondition = widget.data['screenCondition'] ?? 'No scratch';
    _bodyCondition = widget.data['bodyCondition'] ?? 'No scratch';
    _accessories = widget.data['accessories'] ?? 'Charger + Cable included';

    _modelController.addListener(_notify);
    _ramController.addListener(_notify);
    _storageController.addListener(_notify);
    _processorController.addListener(_notify);
    _batteryHealthController.addListener(_notify);
    _priceController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'model': _modelController.text,
      'ram': _ramController.text,
      'storage': _storageController.text,
      'processor': _processorController.text,
      'batteryHealth': _batteryHealthController.text,
      'price': _priceController.text,
      'ptaStatus': _ptaStatus,
      'screenCondition': _screenCondition,
      'bodyCondition': _bodyCondition,
      'accessories': _accessories,
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _ramController.dispose();
    _storageController.dispose();
    _processorController.dispose();
    _batteryHealthController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.deviceMobile(),
          child: Column(
            children: [
              _buildTextField(
                controller: _modelController,
                label: isUrdu ? 'ماڈل کا نام' : 'Model Name',
                hint: 'iPhone 13 Pro',
                icon: PhosphorIcons.tag(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _ramController,
                      label: isUrdu ? 'ریم' : 'RAM',
                      hint: '8GB',
                      icon: PhosphorIcons.memory(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _storageController,
                      label: isUrdu ? 'سٹوریج' : 'Storage',
                      hint: '256GB',
                      icon: PhosphorIcons.database(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _processorController,
                label: isUrdu ? 'پروسیسر' : 'Processor',
                hint: 'A15 Bionic',
                icon: PhosphorIcons.cpu(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _batteryHealthController,
                      label: isUrdu ? 'بیٹری %' : 'Battery %',
                      hint: '90',
                      icon: PhosphorIcons.batteryHigh(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: isUrdu ? 'قیمت' : 'Price',
                      hint: '120000',
                      icon: PhosphorIcons.currencyCircleDollar(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      prefix: 'Rs ',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: isUrdu ? 'اہم تفصیلات' : 'Key Details',
          icon: PhosphorIcons.gear(),
          child: Column(
            children: [
              _buildDropdown(
                label: isUrdu ? 'پی ٹی اے اسٹیٹس' : 'PTA Status',
                value: _ptaStatus,
                items: _ptaOptions,
                icon: PhosphorIcons.shieldCheck(),
                onChanged: (v) { setState(() => _ptaStatus = v!); _notify(); },
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: isUrdu ? 'سکرین کی حالت' : 'Screen Condition',
                value: _screenCondition,
                items: _screenOptions,
                icon: PhosphorIcons.deviceMobile(),
                onChanged: (v) { setState(() => _screenCondition = v!); _notify(); },
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: isUrdu ? 'باڈی کی حالت' : 'Body Condition',
                value: _bodyCondition,
                items: _bodyOptions,
                icon: PhosphorIcons.hardDrive(),
                onChanged: (v) { setState(() => _bodyCondition = v!); _notify(); },
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: isUrdu ? 'لوازمات' : 'Accessories',
                value: _accessories,
                items: _accessoriesOptions,
                icon: PhosphorIcons.package(),
                onChanged: (v) { setState(() => _accessories = v!); _notify(); },
                isUrdu: isUrdu,
                fontFamily: fontFamily,
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

  Widget _buildDropdown({required String label, required String value, required List<String> items, required IconData icon, required Function(String?) onChanged, required bool isUrdu, required String fontFamily}) {
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
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}
