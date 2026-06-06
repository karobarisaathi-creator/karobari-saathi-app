// lib/features/inventory/widgets/furniture_sell_form.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';

/// فرنیچر فروخت کرنے کے لیے فارم
class FurnitureSellForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? initialData;

  const FurnitureSellForm({
    super.key,
    required this.onSave,
    this.initialData,
  });

  @override
  State<FurnitureSellForm> createState() => _FurnitureSellFormState();
}

class _FurnitureSellFormState extends State<FurnitureSellForm> {
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _dimensionsController;
  late TextEditingController _descriptionController;
  
  // Selected options
  String _furnitureType = 'Sofa';
  String _material = 'Wood';
  String _condition = 'Brand New';
  String _assembly = 'Assembled (Ready to use)';
  
  final List<String> _furnitureTypes = [
    'Sofa', 'Bed', 'Dining Table', 'Chair', 'Wardrobe', 
    'Cabinet', 'Bookshelf', 'Desk', 'Dressing Table', 
    'Nightstand', 'Shoe Rack', 'Other'
  ];
  
  final List<String> _materialOptions = [
    'Wood', 'Engineered Wood', 'Metal', 'Plastic', 
    'Bamboo', 'Glass', 'Leather', 'Fabric', 'Marble', 'Other'
  ];
  
  final List<String> _conditionOptions = [
    'Brand New', 'Like New', 'Good Condition', 
    'Used - Minor Scratches', 'Used - Needs Repair'
  ];
  
  final List<String> _assemblyOptions = [
    'Assembled (Ready to use)',
    'Disassembled (DIY)',
    'Assembly Required',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name']);
    _priceController = TextEditingController(text: widget.initialData?['price']);
    _dimensionsController = TextEditingController(text: widget.initialData?['dimensions']);
    _descriptionController = TextEditingController(text: widget.initialData?['description']);
    _furnitureType = widget.initialData?['furnitureType'] ?? 'Sofa';
    _material = widget.initialData?['material'] ?? 'Wood';
    _condition = widget.initialData?['condition'] ?? 'Brand New';
    _assembly = widget.initialData?['assembly'] ?? 'Assembled (Ready to use)';

    _nameController.addListener(_autoSave);
    _priceController.addListener(_autoSave);
    _dimensionsController.addListener(_autoSave);
    _descriptionController.addListener(_autoSave);
  }

  void _autoSave() {
    widget.onSave({
      'name': _nameController.text.trim(),
      'price': _priceController.text.trim(),
      'dimensions': _dimensionsController.text.trim(),
      'description': _descriptionController.text.trim(),
      'furnitureType': _furnitureType,
      'material': _material,
      'condition': _condition,
      'assembly': _assembly,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _dimensionsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final furnitureTypesUr = [
      'سوفی', 'بستر', 'کھانے کی میز', 'کرسی', 'الماری', 
      'کیبنٹ', 'بک شیلف', 'ڈیسک', 'ڈریسنگ ٹیبل', 
      'نائٹ اسٹینڈ', 'جوتوں کی ریک', 'دیگر'
    ];
    
    final materialOptionsUr = [
      'لکڑی', 'انجینئرڈ لکڑی', 'دھات', 'پلاسٹک', 
      'بانس', 'شیشہ', 'چمڑا', 'کپڑا', 'ماربل', 'دیگر'
    ];
    
    final conditionOptionsUr = [
      'بالکل نئی', 'نئی جیسی', 'اچھی حالت', 
      'استعمال شدہ - معمولی خراش', 'استعمال شدہ - مرمت درکار'
    ];
    
    final assemblyOptionsUr = [
      'تیار (استعمال کے لیے)',
      'الگ کیا ہوا (خود جوڑنا)',
      'جوڑنے کی ضرورت ہے',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          title: isUrdu ? 'بنیادی معلومات' : 'Basic Info',
          icon: PhosphorIcons.couch(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      label: isUrdu ? 'آئٹم کا نام *' : 'Item Name *',
                      hint: isUrdu ? 'سوفی سیٹ، ڈبل بیڈ' : 'Sofa Set, Double Bed',
                      icon: PhosphorIcons.tag(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(
                      label: isUrdu ? 'قسم *' : 'Type *',
                      value: _furnitureType,
                      items: _furnitureTypes,
                      itemsUr: isUrdu ? furnitureTypesUr : null,
                      icon: PhosphorIcons.couch(),
                      onChanged: (v) { setState(() => _furnitureType = v!); _autoSave(); },
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
                    child: _buildTextField(
                      controller: _priceController,
                      label: isUrdu ? 'قیمت *' : 'Price *',
                      hint: '50000',
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
                      controller: _dimensionsController,
                      label: isUrdu ? 'سائز (لمبائی x چوڑائی)' : 'Dimensions (L x W)',
                      hint: '84 x 36 inch',
                      icon: PhosphorIcons.ruler(),
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
          icon: PhosphorIcons.gear(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: isUrdu ? 'مواد' : 'Material',
                      value: _material,
                      items: _materialOptions,
                      itemsUr: isUrdu ? materialOptionsUr : null,
                      icon: PhosphorIcons.cube(),
                      onChanged: (v) { setState(() => _material = v!); _autoSave(); },
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
                      itemsUr: isUrdu ? conditionOptionsUr : null,
                      icon: PhosphorIcons.shieldCheck(),
                      onChanged: (v) { setState(() => _condition = v!); _autoSave(); },
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                label: isUrdu ? 'اسمبلی' : 'Assembly',
                value: _assembly,
                items: _assemblyOptions,
                itemsUr: isUrdu ? assemblyOptionsUr : null,
                icon: PhosphorIcons.wrench(),
                onChanged: (v) { setState(() => _assembly = v!); _autoSave(); },
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
            hint: isUrdu ? 'رنگ، ڈیزائن، نقصانات، وغیرہ' : 'Color, design, defects, etc.',
            icon: PhosphorIcons.notePencil(),
            maxLines: 3,
            isUrdu: isUrdu,
            fontFamily: fontFamily,
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 20, color: AppTheme.themeColor), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: fontFamily))]),
          const SizedBox(height: 16),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.themeColor)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, List<String>? itemsUr, required IconData icon, required Function(String?) onChanged, required bool isUrdu, required String fontFamily}) {
    final displayItems = (isUrdu && itemsUr != null) ? itemsUr : items;
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
          items: displayItems.asMap().entries.map((entry) {
            final index = entry.key;
            final displayItem = entry.value;
            final originalValue = items[index];
            return DropdownMenuItem(value: originalValue, child: Text(displayItem, style: TextStyle(fontFamily: fontFamily, fontSize: 14)));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
