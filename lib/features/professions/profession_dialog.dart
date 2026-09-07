import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/config/professions_config.dart';

class ProfessionDialog extends StatefulWidget {
  final bool isUrdu;
  final Profession? profession;
  final String? parentId; // Added parentId for seasons
  final Future<void> Function(String name, List<String> categories, String? description, double totalProduction, String productionUnit, String season, double targetProduction, Map<String, double>? budgetLimits, double benchmarkCostPerUnit, bool isMaster, String? parentId) onSave;

  const ProfessionDialog({
    required this.isUrdu,
    this.profession,
    this.parentId,
    required this.onSave,
  });

  @override
  _ProfessionDialogState createState() => _ProfessionDialogState();
}

class _ProfessionDialogState extends State<ProfessionDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedIcon = 'tools';
  bool _isSaving = false;

  Map<String, List<MasterProfession>> get _groupedProfessions {
    final Map<String, List<MasterProfession>> grouped = {};
    for (var p in ProfessionsConfig.allProfessions) {
      final cat = widget.isUrdu ? p.categoryUrdu : p.categoryName;
      if (!grouped.containsKey(cat)) grouped[cat] = [];
      grouped[cat]!.add(p);
    }
    return grouped;
  }

  @override
  void initState() {
    super.initState();
    if (widget.profession != null) {
      _nameController.text = widget.profession!.name;

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
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: widget.profession == null
            ? (widget.isUrdu ? 'نیا پیشہ' : 'New Profession')
            : (widget.isUrdu ? 'پیشہ ترمیم کریں' : 'Edit Profession'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isUrdu ? 'تفصیلات درج کریں' : 'Enter Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: fontFamily,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 16),

            // Form Fields at Top
            Column(
              children: [
                // Profession Name
                _buildTextField(
                  controller: _nameController,
                  label: widget.isUrdu ? 'پیشہ کا نام' : 'Profession Name',
                  fontFamily: fontFamily,
                  fontWeight: fontWeight,
                ),

                const SizedBox(height: 16),

                // Description
                _buildTextField(
                  controller: _descriptionController,
                  label: widget.isUrdu ? 'تفصیل (لازمی)' : 'Description (Required)',
                  hint: widget.isUrdu ? 'کم از کم 3 سے 4 لائنوں کی تفصیل لکھیں۔' : 'Enter 3-4 lines of description.',
                  fontFamily: fontFamily,
                  fontWeight: fontWeight,
                  maxLines: 4,
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              widget.isUrdu ? 'شعبہ یا آئیکن منتخب کریں' : 'Select Profession / Icon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: fontFamily,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 16),

            // Grouped Professions in Cards
            ..._groupedProfessions.entries.map((entry) {
              return _buildCategoryCard(
                category: entry.key,
                items: entry.value,
                isUrdu: widget.isUrdu,
                fontFamily: fontFamily,
              );
            }).toList(),

            const SizedBox(height: 24),

            // Save Button
            AppButton(
              text: widget.isUrdu ? 'محفوظ کریں' : 'Save Profession',
              onPressed: () async {
                if (_nameController.text.isNotEmpty && _descriptionController.text.isNotEmpty) {
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
                      '', // Season removed
                      widget.profession?.targetProduction ?? 0.0,
                      widget.profession?.budgetLimits,
                      widget.profession?.benchmarkCostPerUnit ?? 0.0,
                      widget.parentId == null && widget.profession == null ? true : (widget.profession?.isMaster ?? false),
                      widget.parentId ?? widget.profession?.parentId,
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
                        widget.isUrdu ? 'پیشہ کا نام اور تفصیل درج کریں' : 'Please enter profession name and description',
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

  Widget _buildCategoryCard({
    required String category,
    required List<MasterProfession> items,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.themeColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.75,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final p = items[idx];
              final isSelected = _selectedIcon == p.id;
              final pName = widget.isUrdu ? p.nameUrdu : p.name;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIcon = p.id;
                    if (_nameController.text.isEmpty) {
                      _nameController.text = pName;
                    }
                  });
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.themeColor : AppTheme.backgroundColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.themeColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        p.icon,
                        color: isSelected ? Colors.white : AppTheme.themeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        pName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontFamily: fontFamily,
                          color: isSelected ? AppTheme.themeColor : AppTheme.darkColor,
                          height: 1.1,
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.darkColor.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.darkColor.withOpacity(0.15)),
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
    super.dispose();
  }
}