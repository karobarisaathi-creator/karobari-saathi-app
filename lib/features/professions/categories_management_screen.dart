import 'package:flutter/material.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/config/professions_config.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';

class CategoriesManagementScreen extends StatefulWidget {
  final List<String> categories;
  final bool isUrdu;
  final ProfessionCategory categoryType;
  final Future<void> Function(List<String>) onCategoriesUpdated;
  final String? title;
  final String? description;
  final bool useDefaultCategories;

  const CategoriesManagementScreen({
    super.key,
    required this.categories,
    required this.isUrdu,
    required this.categoryType,
    required this.onCategoriesUpdated,
    this.title,
    this.description,
    this.useDefaultCategories = true,
  });

  @override
  _CategoriesManagementScreenState createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  late List<String> _categories;
  bool _isSaving = false;

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
    if (_categories.isEmpty && widget.useDefaultCategories) {
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
      appBar: ScreenAppBar(
        title: widget.title ?? (widget.isUrdu ? 'زمرے' : 'Categories'),
        isUrdu: widget.isUrdu,
        actions: [
          IconButton(
            tooltip: widget.isUrdu ? 'محفوظ کریں' : 'Save categories',
            onPressed: _isSaving ? null : _saveCategories,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
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
                    child: UrduAwareText(
                      widget.description ??
                          (widget.isUrdu
                              ? 'یہ زمرے آپ کے پیشے کے لین دین میں استعمال ہوں گے۔'
                              : 'These categories will be used in your profession transactions.'),
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 5)
                    ],
                  ),
                  child: ListTile(
                    title: UrduAwareText(cat,
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
        heroTag: 'categoryAdd',
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppTheme.darkColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: UrduAwareText(widget.isUrdu ? 'نیا زمرہ' : 'Add Category',
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
        title: UrduAwareText(widget.isUrdu ? 'نیا زمرہ' : 'New Category',
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
              child: UrduAwareText(widget.isUrdu ? 'منسوخ' : 'Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              if (_categories.any((category) =>
                  category.trim().toLowerCase() == name.toLowerCase())) {
                AppToast.error(
                  context,
                  widget.isUrdu
                      ? 'یہ زمرہ پہلے سے موجود ہے'
                      : 'This category already exists',
                );
                return;
              }
              setState(() => _categories.add(name));
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.darkColor),
            child: UrduAwareText(widget.isUrdu ? 'شامل کریں' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCategories() async {
    setState(() => _isSaving = true);
    try {
      await widget.onCategoriesUpdated(_categories);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.error(
        context,
        widget.isUrdu ? 'زمرے محفوظ نہیں ہو سکے' : 'Could not save categories',
        subtitle: error.toString(),
      );
    }
  }
}
