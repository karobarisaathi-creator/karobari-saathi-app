import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class CategoriesManagementScreen extends StatefulWidget {
  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final bool isUrdu;
  final Function(List<String>, List<String>) onCategoriesUpdated;

  const CategoriesManagementScreen({super.key, required this.incomeCategories, required this.expenseCategories, required this.isUrdu, required this.onCategoriesUpdated});

  @override
  _CategoriesManagementScreenState createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> {
  late List<String> _incomeCategories;
  late List<String> _expenseCategories;

  @override
  void initState() {
    super.initState();
    _incomeCategories = List.from(widget.incomeCategories);
    _expenseCategories = List.from(widget.expenseCategories);
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = widget.isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = widget.isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: widget.isUrdu ? 'زمرے مینج کریں' : 'Manage Categories',
        actions: [IconButton(icon: Icon(PhosphorIcons.checkCircle()), onPressed: _saveCategories)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _buildCategoryCard(isIncome: true, isUrdu: widget.isUrdu, fontFamily: fontFamily),
            const SizedBox(height: 16),
            _buildCategoryCard(isIncome: false, isUrdu: widget.isUrdu, fontFamily: fontFamily),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({required bool isIncome, required bool isUrdu, required String fontFamily}) {
    final categories = isIncome ? _incomeCategories : _expenseCategories;
    final title = isIncome 
        ? (isUrdu ? 'آمدنی کے زمرے' : 'Income Categories') 
        : (isUrdu ? 'خرچ کے زمرے' : 'Expense Categories');
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 17, fontWeight: fontWeight, color: AppTheme.darkColor, fontFamily: fontFamily)),
                IconButton(icon: Icon(PhosphorIcons.plusCircle(), color: AppTheme.themeColor), onPressed: () => _showAddCategoryDialog(isIncome, isUrdu)),
              ],
            ),
            const Divider(height: 24, thickness: 0.5),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (context, index) => Divider(color: AppTheme.darkColor.withValues(alpha: 0.05), height: 1),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    cat, 
                    style: TextStyle(
                      color: AppTheme.darkColor, 
                      fontFamily: fontFamily, 
                      fontWeight: fontWeight, 
                      fontSize: 15
                    )
                  ),
                  trailing: IconButton(
                    icon: Icon(PhosphorIcons.trash(), color: AppTheme.expenseColor, size: 18),
                    onPressed: () {
                      setState(() {
                        if (isIncome) {
                          _incomeCategories.remove(cat);
                        } else {
                          _expenseCategories.remove(cat);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(bool isIncome, bool isUrdu) {
    final TextEditingController controller = TextEditingController();
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isUrdu ? 'نیا زمرہ شامل کریں' : 'Add New Category', style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight, color: AppTheme.darkColor)),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: fontWeight),
          decoration: InputDecoration(
            labelText: isUrdu ? 'زمرہ کا نام' : 'Category Name',
            labelStyle: TextStyle(color: AppTheme.textSecondary, fontFamily: fontFamily, fontWeight: fontWeight),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.darkColor.withValues(alpha: 0.1))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.themeColor)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? 'منسوخ' : 'Cancel', style: TextStyle(color: AppTheme.textSecondary, fontFamily: fontFamily, fontWeight: fontWeight))),
          ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    if (isIncome) {
                      _incomeCategories.add(controller.text);
                    } else {
                      _expenseCategories.add(controller.text);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkColor, foregroundColor: Colors.white),
              child: Text(isUrdu ? 'شامل کریں' : 'Add', style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight))),
        ],
      ),
    );
  }

  void _saveCategories() {
    widget.onCategoriesUpdated(_incomeCategories, _expenseCategories);
    Navigator.pop(context);
  }
}
