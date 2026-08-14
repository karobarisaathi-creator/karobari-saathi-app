import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';

class ProfessionDialog extends StatefulWidget {
  final bool isUrdu;
  final Profession? profession;
  final Future<void> Function(String name, List<String> categories, String? description, double totalProduction, String productionUnit, String season, double targetProduction, Map<String, double>? budgetLimits, double benchmarkCostPerUnit) onSave;

  const ProfessionDialog({
    required this.isUrdu,
    this.profession,
    required this.onSave,
  });

  @override
  _ProfessionDialogState createState() => _ProfessionDialogState();
}

class _ProfessionDialogState extends State<ProfessionDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _seasonController = TextEditingController();

  String _selectedIcon = 'business_center';
  bool _isSaving = false;

  final List<Map<String, dynamic>> _availableIcons = [
    {'key': 'agriculture', 'icon': PhosphorIcons.tractor(), 'label': 'Agri', 'labelUr': 'زراعت'},
    {'key': 'livestock', 'icon': PhosphorIcons.cow(), 'label': 'Livestock', 'labelUr': 'مال مویشی'},
    {'key': 'transport', 'icon': PhosphorIcons.truck(), 'label': 'Transport', 'labelUr': 'گاڑی/ٹرک'},
    {'key': 'shop', 'icon': PhosphorIcons.storefront(), 'label': 'Shop', 'labelUr': 'دکان'},
    {'key': 'factory', 'icon': PhosphorIcons.factory(), 'label': 'Factory', 'labelUr': 'فیکٹری'},
    {'key': 'hammer', 'icon': PhosphorIcons.hammer(), 'label': 'Hammer', 'labelUr': 'تعمیرات'},
    {'key': 'land', 'icon': PhosphorIcons.mapPin(), 'label': 'Land', 'labelUr': 'زمین/پلاٹ'},
    {'key': 'tools', 'icon': PhosphorIcons.wrench(), 'label': 'Services', 'labelUr': 'خدمات'},
    {'key': 'food', 'icon': PhosphorIcons.cookingPot(), 'label': 'Food', 'labelUr': 'کھانا'},
    {'key': 'tech', 'icon': PhosphorIcons.cpu(), 'label': 'Tech', 'labelUr': 'ٹیکنالوجی'},
    {'key': 'finance', 'icon': PhosphorIcons.bank(), 'label': 'Bank', 'labelUr': 'بینک'},
    {'key': 'cart', 'icon': PhosphorIcons.shoppingCart(), 'label': 'Cart', 'labelUr': 'خریداری'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.profession != null) {
      _nameController.text = widget.profession!.name;
      _seasonController.text = widget.profession!.season;

      String desc = widget.profession!.description ?? '';
      if (desc.startsWith('ICON:')) {
        try {
          final parts = desc.split('|');
          _selectedIcon = parts[0].substring(5);
          if (parts.length > 1) {
            _descriptionController.text = parts.sublist(1).join('|');
          } else {
            _descriptionController.text = '';
          }
        } catch (e) {
          _descriptionController.text = desc;
        }
      } else {
        _descriptionController.text = desc;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = widget.isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = widget.isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        title: widget.profession == null
            ? (widget.isUrdu ? 'نیا پیشہ' : 'New Profession')
            : (widget.isUrdu ? 'پیشہ ترمیم کریں' : 'Edit Profession'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Icon Selection
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.darkColor.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isUrdu ? 'آئیکن منتخب کریں' : 'Select Icon',
                    style: TextStyle(
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _availableIcons.length,
                    itemBuilder: (context, index) {
                      final iconData = _availableIcons[index];
                      final isSelected = _selectedIcon == iconData['key'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIcon = iconData['key'];
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.themeColor : AppTheme.lightColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppTheme.themeColor : AppTheme.darkColor.withOpacity(0.1),
                                  width: 1.5,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: AppTheme.themeColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ] : null,
                              ),
                              child: Icon(
                                iconData['icon'],
                                color: isSelected ? Colors.white : AppTheme.themeColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.isUrdu ? iconData['labelUr'] : iconData['label'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: fontFamily,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Form Fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.darkColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  // Profession Name
                  _buildTextField(
                    controller: _nameController,
                    label: widget.isUrdu ? 'پیشہ کا نام' : 'Profession Name',
                    icon: PhosphorIcons.briefcase(),
                    fontFamily: fontFamily,
                    fontWeight: fontWeight,
                  ),

                  const SizedBox(height: 16),

                  // Season / Year
                  _buildTextField(
                    controller: _seasonController,
                    label: widget.isUrdu ? 'سیزن / سال (اختیاری)' : 'Season / Year (Optional)',
                    hint: widget.isUrdu ? 'مثلاً: گندم 2024' : 'e.g., Wheat 2024',
                    icon: PhosphorIcons.calendar(),
                    fontFamily: fontFamily,
                    fontWeight: fontWeight,
                  ),
                  
                  const SizedBox(height: 8),
                  Align(
                    alignment: widget.isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      widget.isUrdu
                          ? 'نوٹ: اگر آپ سیزن کا موازنہ کرنا چاہتے ہیں تو سیزن لکھنا ضروری ہے۔'
                          : 'Note: Season is required if you want to use season comparison.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: fontFamily,
                        fontWeight: fontWeight,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    label: widget.isUrdu ? 'تفصیل (اختیاری)' : 'Description (Optional)',
                    icon: PhosphorIcons.note(),
                    fontFamily: fontFamily,
                    fontWeight: fontWeight,
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            AppButton(
              text: widget.isUrdu ? 'محفوظ کریں' : 'Save Profession',
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  setState(() {
                    _isSaving = true;
                  });
                  
                  try {
                    String finalDescription = "ICON:$_selectedIcon|${_descriptionController.text}";

                    await widget.onSave(
                      _nameController.text,
                      [],
                      finalDescription,
                      widget.profession?.totalProduction ?? 0.0,
                      widget.profession?.productionUnit ?? '',
                      _seasonController.text,
                      widget.profession?.targetProduction ?? 0.0,
                      widget.profession?.budgetLimits,
                      widget.profession?.benchmarkCostPerUnit ?? 0.0,
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.isUrdu ? 'پیشہ کا نام درج کریں' : 'Please enter profession name',
                        style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight),
                      ),
                      backgroundColor: AppTheme.expenseColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              isLoading: _isSaving,
              isFullWidth: true,
              size: AppButtonSize.large,
              color: AppTheme.darkColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String fontFamily,
    required FontWeight fontWeight,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: AppTheme.darkColor,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          color: AppTheme.textSecondary,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          color: AppTheme.textSecondary.withOpacity(0.5),
        ),
        filled: true,
        fillColor: AppTheme.lightColor.withOpacity(0.5),
        prefixIcon: Icon(icon, color: AppTheme.themeColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.darkColor.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.darkColor.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5),
        ),
        alignLabelWithHint: true,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _seasonController.dispose();
    super.dispose();
  }
}