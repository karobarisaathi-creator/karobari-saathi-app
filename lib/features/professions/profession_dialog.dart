import 'package:flutter/material.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/config/professions_config.dart';

class ProfessionDialog extends StatefulWidget {
  final bool isUrdu;
  final Profession? profession;
  final String? parentId; // Added parentId for seasons
  final Future<void> Function(
    String name,
    List<String> categories,
    String? description,
    double totalProduction,
    String productionUnit,
    String season,
    double targetProduction,
    Map<String, double>? budgetLimits,
    double benchmarkCostPerUnit,
    ProfessionCategory categoryType,
    bool isMaster,
    String? parentId,
  ) onSave;

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
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedIcon = 'services';
  bool _isSaving = false;

  ProfessionGroup get _selectedGroup => ProfessionsConfig.professionGroups
      .firstWhere((group) => group.id == _selectedIcon);

  @override
  void initState() {
    super.initState();
    if (widget.profession != null) {
      final categoryType =
          ProfessionsConfig.categoryTypeFor(widget.profession!);
      _selectedIcon = ProfessionsConfig.professionGroups
          .firstWhere(
            (group) => group.categoryType == categoryType,
            orElse: () => ProfessionsConfig.professionGroups.last,
          )
          .id;

      String desc = widget.profession!.description ?? '';
      if (desc.startsWith('ICON:')) {
        try {
          final parts = desc.split('|');
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              widget.isUrdu ? 'تفصیلات درج کریں' : 'Enter Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: fontFamily,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 16),

            // Profession description
            Column(
              children: [
                _buildTextField(
                  controller: _descriptionController,
                  label: widget.isUrdu
                      ? 'تفصیل (لازمی)'
                      : 'Description (Required)',
                  hint: widget.isUrdu
                      ? 'کم از کم 3 سے 4 لائنوں کی تفصیل لکھیں۔'
                      : 'Enter 3-4 lines of description.',
                  fontFamily: fontFamily,
                  fontWeight: fontWeight,
                  maxLines: 4,
                ),
              ],
            ),

            const SizedBox(height: 24),

            UrduAwareText(
              widget.isUrdu
                  ? 'پیشہ کا شعبہ منتخب کریں'
                  : 'Select a Profession Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: fontFamily,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 16),

            _buildCategoryGrid(widget.isUrdu, fontFamily),

            const SizedBox(height: 24),

            // Save Button
            AppButton(
              text: widget.isUrdu ? 'محفوظ کریں' : 'Save Profession',
              onPressed: () async {
                if (_descriptionController.text.trim().isNotEmpty) {
                  setState(() {
                    _isSaving = true;
                  });

                  try {
                    String finalDescription =
                        "ICON:$_selectedIcon|${_descriptionController.text}";

                    await widget.onSave(
                      widget.profession?.name ??
                          (widget.isUrdu
                              ? _selectedGroup.nameUrdu
                              : _selectedGroup.name),
                      [],
                      finalDescription,
                      widget.profession?.totalProduction ?? 0.0,
                      widget.profession?.productionUnit ?? '',
                      '', // Season removed
                      widget.profession?.targetProduction ?? 0.0,
                      widget.profession?.budgetLimits,
                      widget.profession?.benchmarkCostPerUnit ?? 0.0,
                      _selectedGroup.categoryType,
                      widget.parentId == null && widget.profession == null
                          ? true
                          : (widget.profession?.isMaster ?? false),
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
                  AppToast.warning(
                    context,
                    widget.isUrdu
                        ? 'پیشہ کی تفصیل درج کریں'
                        : 'Please enter a profession description',
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

  Widget _buildCategoryGrid(bool isUrdu, String fontFamily) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: ProfessionsConfig.professionGroups.length,
      itemBuilder: (context, index) {
        final group = ProfessionsConfig.professionGroups[index];
        final isSelected = group.id == _selectedIcon;
        return InkWell(
          onTap: () => setState(() => _selectedIcon = group.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.themeColor.withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppTheme.themeColor
                    : AppTheme.darkColor.withOpacity(0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  group.icon,
                  color: AppTheme.themeColor,
                  size: 23,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: UrduAwareText(
                    isUrdu ? group.nameUrdu : group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    _descriptionController.dispose();
    super.dispose();
  }
}
