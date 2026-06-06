// lib/features/inventory/widgets/transport_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

class TransportSellForm extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onChanged;

  const TransportSellForm({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<TransportSellForm> createState() => _TransportSellFormState();
}

class _TransportSellFormState extends State<TransportSellForm> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _capacityController;
  late TextEditingController _routesController;
  
  late String _transportType;
  late String _fuelType;
  late String _condition;
  late String _registration;
  
  final List<String> _transportTypes = [
    'Vehicle', 'Bus', 'Truck', 'Loader/Rickshaw', 'Delivery Bike',
    'Rent a Car', 'Transport Service', 'Courier Service', 'School Van',
    'Ambulance', 'Crane', 'Trailer', 'Tractor Trolley', 'Other'
  ];
  
  final List<String> _fuelOptions = ['Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid'];
  final List<String> _conditionOptions = ['New', 'Like New', 'Used - Good', 'Used - Fair', 'Needs Repair'];
  final List<String> _registrationOptions = [
    'Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Multan', 
    'Faisalabad', 'Gujranwala', 'Peshawar', 'Quetta', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _brandController = TextEditingController(text: widget.data['brand']);
    _priceController = TextEditingController(text: widget.data['price']);
    _capacityController = TextEditingController(text: widget.data['capacity']);
    _routesController = TextEditingController(text: widget.data['routes']);
    
    _transportType = widget.data['transportType'] ?? 'Vehicle';
    _fuelType = widget.data['fuelType'] ?? 'Diesel';
    _condition = widget.data['condition'] ?? 'New';
    _registration = widget.data['registration'] ?? 'Lahore';

    _nameController.addListener(_notify);
    _brandController.addListener(_notify);
    _priceController.addListener(_notify);
    _capacityController.addListener(_notify);
    _routesController.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'price': _priceController.text.trim(),
      'capacity': _capacityController.text.trim(),
      'routes': _routesController.text.trim(),
      'transportType': _transportType,
      'fuelType': _fuelType,
      'condition': _condition,
      'registration': _registration,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _routesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final transportTypesUr = [
      'گاڑی', 'بس', 'ٹرک', 'لوڈر/رکشہ', 'ڈلیوری بائیک',
      'رینٹ اے کار', 'ٹرانسپورٹ سروس', 'کورئیر سروس', 'سکول وین',
      'ایمبولینس', 'کرین', 'ٹریلر', 'ٹریکٹر ٹرالی', 'دیگر'
    ];
    final fuelUr = ['پیٹرول', 'ڈیزل', 'سی این جی', 'الیکٹرک', 'ہائبرڈ'];
    final regUr = ['لاہور', 'کراچی', 'اسلام آباد', 'راولپنڈی', 'ملتان', 'فیصل آباد', 'گوجرانوالہ', 'پشاور', 'کوئٹہ', 'دیگر'];

    return Column(
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.truck(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'نام / ماڈل' : 'Name / Model',
                      hint: 'Toyota HiAce...',
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
                      value: _transportType,
                      items: _transportTypes,
                      itemsUr: isUrdu ? transportTypesUr : null,
                      icon: PhosphorIcons.truck(),
                      onChanged: (v) { setState(() => _transportType = v!); _notify(); },
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
                      hint: 'Toyota, Suzuki...',
                      icon: PhosphorIcons.copyright(),
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
                      itemsUr: isUrdu ? fuelUr : null,
                      icon: PhosphorIcons.gasPump(),
                      onChanged: (v) { setState(() => _fuelType = v!); _notify(); },
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
          title: isUrdu ? 'گنجائش اور روٹس' : 'Capacity & Routes',
          icon: PhosphorIcons.users(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _capacityController,
                      label: isUrdu ? 'گنجائش' : 'Capacity',
                      hint: '10 tons, 50 seats...',
                      icon: PhosphorIcons.scales(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'رجسٹریشن' : 'Registration',
                      value: _registration,
                      items: _registrationOptions,
                      itemsUr: isUrdu ? regUr : null,
                      icon: PhosphorIcons.mapPin(),
                      onChanged: (v) { setState(() => _registration = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _routesController,
                label: isUrdu ? 'روٹس / سروس ایریا' : 'Routes / Area',
                hint: 'Lahore to Karachi...',
                icon: PhosphorIcons.mapPinArea(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: isUrdu ? 'قیمت اور حالت' : 'Price & Condition',
          icon: PhosphorIcons.currencyCircleDollar(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'حالت' : 'Condition',
                      value: _condition,
                      items: _conditionOptions,
                      icon: PhosphorIcons.shieldCheck(),
                      onChanged: (v) { setState(() => _condition = v!); _notify(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: isUrdu ? 'قیمت' : 'Price',
                      hint: '2500000',
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

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon, bool isNumber = false, int maxLines = 1, required bool isUrdu, required String fontFamily, String prefix = ''}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
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
