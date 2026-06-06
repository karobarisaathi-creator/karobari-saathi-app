// lib/features/inventory/widgets/vehicle_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class VehicleSellForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? initialData;

  const VehicleSellForm({
    super.key,
    required this.onSave,
    this.initialData,
  });

  @override
  State<VehicleSellForm> createState() => _VehicleSellFormState();
}

class _VehicleSellFormState extends State<VehicleSellForm> {
  // Controllers
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _engineController;
  late TextEditingController _mileageController;
  late TextEditingController _priceController;
  late TextEditingController _registrationController;
  
  // Selected options
  late String _transmission;
  late String _fuelType;
  late String _accidentHistory;
  late String _ownerCount;
  
  final List<String> _transmissionOptions = ['Automatic', 'Manual'];
  final List<String> _fuelOptions = ['Petrol', 'Diesel', 'CNG', 'Hybrid'];
  final List<String> _accidentOptions = ['No accident', 'Minor (touch-up)', 'Major (repainted)'];
  final List<String> _ownerOptions = ['1st Owner', '2nd Owner', '3rd Owner', '4th+ Owner'];

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.initialData?['model']);
    _yearController = TextEditingController(text: widget.initialData?['year']);
    _engineController = TextEditingController(text: widget.initialData?['engine']);
    _mileageController = TextEditingController(text: widget.initialData?['mileage']);
    _priceController = TextEditingController(text: widget.initialData?['price']);
    _registrationController = TextEditingController(text: widget.initialData?['registration']);
    
    _transmission = widget.initialData?['transmission'] ?? 'Automatic';
    _fuelType = widget.initialData?['fuelType'] ?? 'Petrol';
    _accidentHistory = widget.initialData?['accidentHistory'] ?? 'No accident';
    _ownerCount = widget.initialData?['ownerCount'] ?? '1st Owner';

    // Add listeners for auto-sync with parent
    _modelController.addListener(_notify);
    _yearController.addListener(_notify);
    _engineController.addListener(_notify);
    _mileageController.addListener(_notify);
    _priceController.addListener(_notify);
    _registrationController.addListener(_notify);
  }

  void _notify() {
    widget.onSave({
      'model': _modelController.text.trim(),
      'year': _yearController.text.trim(),
      'engine': _engineController.text.trim(),
      'mileage': _mileageController.text.trim(),
      'price': _priceController.text.trim(),
      'registration': _registrationController.text.trim(),
      'transmission': _transmission,
      'fuelType': _fuelType,
      'accidentHistory': _accidentHistory,
      'ownerCount': _ownerCount,
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _yearController.dispose();
    _engineController.dispose();
    _mileageController.dispose();
    _priceController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ========== CARD 1: بنیادی معلومات ==========
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.car(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _modelController,
                      label: isUrdu ? 'گاڑی کا ماڈل' : 'Vehicle Model',
                      hint: 'Corolla, Civic...',
                      icon: PhosphorIcons.tag(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _yearController,
                      label: isUrdu ? 'سال' : 'Year',
                      hint: '2022',
                      icon: PhosphorIcons.calendar(),
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
                      controller: _engineController,
                      label: isUrdu ? 'انجن (cc)' : 'Engine (cc)',
                      hint: '1800',
                      icon: PhosphorIcons.engine(),
                      isNumber: true,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _mileageController,
                      label: isUrdu ? 'مائلیج (km)' : 'Mileage (km)',
                      hint: '45000',
                      icon: PhosphorIcons.speedometer(),
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
                      controller: _priceController,
                      label: isUrdu ? 'قیمت' : 'Price',
                      hint: '3500000',
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
                      controller: _registrationController,
                      label: isUrdu ? 'رجسٹریشن' : 'Registration',
                      hint: 'Lahore',
                      icon: PhosphorIcons.mapPin(),
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

        // ========== CARD 2: اہم تفصیلات ==========
        _buildCard(
          title: isUrdu ? 'اہم تفصیلات' : 'Key Details',
          icon: PhosphorIcons.gear(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'ٹرانسمیشن' : 'Transmission',
                      value: _transmission,
                      items: _transmissionOptions,
                      icon: PhosphorIcons.gearSix(),
                      onChanged: (v) { setState(() => _transmission = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'فیول' : 'Fuel',
                      value: _fuelType,
                      items: _fuelOptions,
                      icon: PhosphorIcons.gasPump(),
                      onChanged: (v) { setState(() => _fuelType = v!); _notify(); },
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
                      label: isUrdu ? 'مالک' : 'Owner',
                      value: _ownerCount,
                      items: _ownerOptions,
                      icon: PhosphorIcons.user(),
                      onChanged: (v) { setState(() => _ownerCount = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'واقعات' : 'Accident',
                      value: _accidentHistory,
                      items: _accidentOptions,
                      icon: PhosphorIcons.shieldWarning(),
                      onChanged: (v) { setState(() => _accidentHistory = v!); _notify(); },
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

  Widget _buildDropdown({required String label, required String value, required List<String> items, required IconData icon, required Function(String?) onChanged, required bool isUrdu, required String fontFamily}) {
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
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}
