import 'package:flutter/material.dart';
import 'package:account_app/core/config/professions_config.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class CategoriesManagementScreen extends StatefulWidget {
  final List<String> categories;
  final bool isUrdu;
  final ProfessionCategory categoryType;
  final Function(List<String>) onCategoriesUpdated;

  const CategoriesManagementScreen(
      {super.key,
      required this.categories,
      required this.isUrdu,
      required this.categoryType,
      required this.onCategoriesUpdated});

  @override
  _CategoriesManagementScreenState createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    // پرانے کوڈ کے سابقے (Prefixes) صاف کریں
    _categories = widget.categories
        .map((c) {
          if (c.startsWith('INC:')) return c.substring(4);
          if (c.startsWith('EXP:')) return c.substring(4);
          return c;
        })
        .toSet()
        .toList();

    // اگر لسٹ خالی ہو تو ڈیفالٹ زمرے دکھائیں
    if (_categories.isEmpty) {
      _categories = ProfessionsConfig.defaultCategories(
        widget.categoryType,
        isUrdu: widget.isUrdu,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = widget.isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = widget.isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: widget.isUrdu ? 'زمرے مینج کریں' : 'Manage Categories',
        actions: [
          IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _saveCategories)
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.themeColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isUrdu
                          ? 'یہ زمرے آپ کے پیشے کے لین دین میں استعمال ہوں گے۔'
                          : 'These categories will be used in your profession transactions.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.themeColor,
                          fontFamily: fontFamily,
                          fontWeight: fontWeight),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 5)
                    ],
                  ),
                  child: ListTile(
                    title: Text(cat,
                        style: TextStyle(
                            fontFamily: fontFamily,
                            fontWeight: fontWeight,
                            fontSize: 15)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      onPressed: () =>
                          setState(() => _categories.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppTheme.darkColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(widget.isUrdu ? 'نیا زمرہ' : 'Add Category',
            style: TextStyle(fontFamily: fontFamily, color: Colors.white)),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();
    final fontFamily = widget.isUrdu ? 'NooriNastaleeq' : '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.isUrdu ? 'نیا زمرہ' : 'New Category',
            style: TextStyle(fontFamily: fontFamily)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontFamily: fontFamily),
          decoration: InputDecoration(
            hintText: widget.isUrdu
                ? 'زمرہ کا نام لکھیں...'
                : 'Enter category name...',
            hintStyle: TextStyle(fontFamily: fontFamily, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isUrdu ? 'منسوخ' : 'Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _categories.add(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.darkColor),
            child: Text(widget.isUrdu ? 'شامل کریں' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _saveCategories() {
    widget.onCategoriesUpdated(_categories);
    Navigator.pop(context);
  }
}
