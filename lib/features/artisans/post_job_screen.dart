// lib/features/artisans/post_job_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/features/artisans/controllers/job_post_controller.dart';
import 'package:account_app/core/services/location_service.dart';

class PostJobScreen extends StatefulWidget {
  final JobPost? jobToEdit;
  const PostJobScreen({super.key, this.jobToEdit});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  late final JobPostController _controller;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = JobPostController(jobToEdit: widget.jobToEdit);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_controller.images.length >= 5) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        _controller.addImage(File(image.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _postJob() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    
    if (!_formKey.currentState!.validate()) return;

    // تفصیلات کی جانچ
    final detailError = _controller.validateDetails(isUrdu);
    if (detailError != null) {
      _showSnackBar(detailError, Colors.orange);
      return;
    }

    final success = await _controller.postJob();

    if (!mounted) return;

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isUrdu
                ? (widget.jobToEdit != null ? 'تبدیلی محفوظ کر لی گئی ہے!' : 'کام پوسٹ کر دیا گیا ہے!')
                : (widget.jobToEdit != null ? 'Changes Saved!' : 'Job Posted!'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showSnackBar(_controller.errorMessage ?? 'Error', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<JobPostController>(
        builder: (context, controller, _) {
          return _buildScreen(context, controller);
        },
      ),
    );
  }

  Widget _buildScreen(BuildContext context, JobPostController controller) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu
            ? (widget.jobToEdit != null ? 'کام میں ترمیم کریں' : 'نیا کام پوسٹ کریں')
            : (widget.jobToEdit != null ? 'Edit Job' : 'Post a Job'),
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // تفصیلی اسکوپ سیکشن
                    _buildDetailedScopeSection(controller, isUrdu, fontFamily),
                    
                    const SizedBox(height: 16),
                    
                    // تصاویر اور شعبہ کارڈ
                    _buildMediaAndCategoryCard(controller, isUrdu, fontFamily),
                    
                    const SizedBox(height: 32),
                    
                    // پوسٹ بٹن
                    AppButton(
                      text: isUrdu
                          ? (widget.jobToEdit != null ? 'تبدیلی محفوظ کریں' : 'کام پوسٹ کریں')
                          : (widget.jobToEdit != null ? 'Save Changes' : 'Post Job'),
                      color: AppTheme.darkColor,
                      size: AppButtonSize.large,
                      isFullWidth: true,
                      isLoading: controller.postStatus == JobPostStatus.loading,
                      onPressed: _postJob,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetailedScopeSection(
    JobPostController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // کام کا عنوان
          _buildTextField(
            controller: controller.titleController,
            label: isUrdu ? 'کام کا عنوان' : 'Job Title',
            hint: isUrdu ? 'مثال: آفس اسسٹنٹ کی ضرورت ہے' : 'e.g. Need Office Assistant',
            icon: PhosphorIcons.textT(),
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            maxLength: 40,
            borderless: true,
            fontSize: 18,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isUrdu ? 'عنوان لکھنا ضروری ہے' : 'Title is required';
              }
              if (value.trim().length < 5) {
                return isUrdu 
                    ? 'عنوان کم از کم 5 حروف کا ہونا چاہیے' 
                    : 'Title must be at least 5 characters';
              }
              if (value.trim().length > 40) {
                return isUrdu 
                    ? 'عنوان 40 حروف سے زیادہ نہیں ہونا چاہیے' 
                    : 'Title cannot exceed 40 characters';
              }
              return null;
            },
          ),
          
          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

          // تفصیلات سیکشن
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                ..._buildDetailFields(controller, isUrdu, fontFamily),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // ایڈ بٹن
                      InkWell(
                        onTap: controller.addDetailField,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.plusCircle(),
                              color: AppTheme.themeColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isUrdu ? 'مزید تفصیل' : 'Add more',
                              style: TextStyle(
                                color: AppTheme.themeColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // اسٹائل سلیکٹر
                      _buildBulletStyleSelector(controller, isUrdu, fontFamily),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

          // لوکیشن
          _buildLocationField(controller, isUrdu, fontFamily, borderless: true),
          
          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

          // بجٹ اور رقم کا سیکشن (مدت ختم کر دی گئی)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // رقم کا خانہ (بائیں طرف)
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: controller.budgetController,
                  label: isUrdu ? 'رقم / بجٹ (اختیاری)' : 'Budget (Optional)',
                  hint: '5000',
                  icon: PhosphorIcons.money(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  isNumber: true,
                  borderless: true,
                ),
              ),
              
              // درمیان کی لکیر
              Container(width: 1, height: 60, color: const Color(0xFFDDDDDD)),
              
              // یونٹ سلیکٹر (دائیں طرف - سلائیڈر کی شکل میں)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildUnitSelector(
                    value: controller.budgetUnit,
                    items: [
                      {'id': 'total', 'en': 'Total', 'ur': 'کل رقم'},
                      {'id': 'hourly', 'en': 'Per Hr', 'ur': 'فی گھنٹہ'},
                      {'id': 'daily', 'en': 'Per Day', 'ur': 'فی دیہاڑی'},
                      {'id': 'monthly', 'en': 'Per Mo', 'ur': 'فی مہینہ'},
                      {'id': 'contract', 'en': 'Contract', 'ur': 'ٹھیکہ'},
                      {'id': 'per_item', 'en': 'Per Item', 'ur': 'فی آئٹم'},
                      {'id': 'sqft', 'en': 'Per Sqft', 'ur': 'فی مربع فٹ'},
                      {'id': 'visit', 'en': 'Per Visit', 'ur': 'فی وزٹ'},
                      {'id': 'km', 'en': 'Per KM', 'ur': 'فی کلومیٹر'},
                      {'id': 'kg', 'en': 'Per KG', 'ur': 'فی کلو'},
                    ],
                    onChanged: (val) {
                      controller.budgetUnit = val!;
                      controller.notifyListeners();
                    },
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

          // ویب سائٹ لنک
          _buildTextField(
            controller: controller.websiteController,
            label: isUrdu ? 'ویب سائٹ (اختیاری)' : 'Website (Optional)',
            hint: 'www.example.com',
            icon: PhosphorIcons.globe(),
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            borderless: true,
            validator: (val) => null,
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

          // کمپنی کا نام
          _buildTextField(
            controller: controller.companyController,
            label: isUrdu ? 'کمپنی کا نام (اختیاری)' : 'Company Name (Optional)',
            hint: isUrdu ? 'مثلاً: اے بی سی کنسٹرکشن' : 'e.g. ABC Construction',
            icon: PhosphorIcons.buildings(),
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            borderless: true,
            maxLength: 20,
            validator: (value) {
              if (value != null && value.trim().length > 20) {
                return isUrdu 
                    ? 'کمپنی کا نام 20 حروف سے زیادہ نہیں ہونا چاہیے' 
                    : 'Company name cannot exceed 20 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaAndCategoryCard(
    JobPostController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // امیج پیکر
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildHorizontalImagePicker(controller, isUrdu, fontFamily),
          ),
          
          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),
          
          // شعبہ سیکشن
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  isUrdu ? 'کام کا شعبہ (اختیاری)' : 'Job Category (Optional)',
                  fontFamily,
                ),
                const SizedBox(height: 12),
                _buildCategorySelector(controller, isUrdu, fontFamily),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalImagePicker(
    JobPostController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isUrdu ? 'تصاویر (اختیاری - زیادہ سے زیادہ 5)' : 'Images (Optional - Max 5)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
            color: AppTheme.darkColor,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              final bool hasImage = index < controller.images.length;

              return GestureDetector(
                onTap: () => hasImage ? null : _pickImage(),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasImage
                          ? AppTheme.themeColor.withOpacity(0.3)
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    image: hasImage
                        ? (controller.images[index] is File
                            ? DecorationImage(
                                image: FileImage(controller.images[index]),
                                fit: BoxFit.cover,
                              )
                            : DecorationImage(
                                image: NetworkImage(controller.images[index]),
                                fit: BoxFit.cover,
                              ))
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (!hasImage)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIcons.cameraPlus(),
                                color: Colors.grey.shade400,
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isUrdu ? 'شامل کریں' : 'Add',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasImage)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => controller.removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Remove old _buildCategorySection since it's merged into _buildMediaAndCategoryCard

  Widget _buildCategorySelector(
    JobPostController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    final allProfessions = ArtisanService.getProfessions();
    
    // تمام پیشوں کو کیٹگری کے لحاظ سے گروپ کریں
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var p in allProfessions) {
      final cat = isUrdu ? p['categoryUrdu'] : p['category'];
      groups.putIfAbsent(cat, () => []).add(p);
    }

    final List<Map<String, dynamic>> itemsToDisplay = [];

    groups.forEach((categoryName, professions) {
      final List<String> allIds = professions.map((p) => p['id'] as String).toList();
      final List<String> selectedIds = allIds.where((id) => controller.selectedCategories.contains(id)).toList();

      if (selectedIds.isEmpty) return;

      // اگر تمام پیشے منتخب ہیں تو صرف کیٹگری دکھائیں (بشرطیکہ کیٹگری میں ایک سے زیادہ پیشے ہوں)
      if (selectedIds.length == allIds.length && allIds.length > 1) {
        IconData catIcon = PhosphorIcons.circlesThree(); // ڈیفالٹ کیٹگری آئیکن
        
        // کیٹگری کے نام کے مطابق بہتر آئیکن منتخب کریں
        if (categoryName.contains('تعمیرات') || categoryName.contains('Construction')) catIcon = PhosphorIcons.wall();
        else if (categoryName.contains('سافٹ ویئر') || categoryName.contains('IT')) catIcon = PhosphorIcons.code();
        else if (categoryName.contains('مرمت') || categoryName.contains('Repair')) catIcon = PhosphorIcons.wrench();
        else if (categoryName.contains('زراعت') || categoryName.contains('Agriculture')) catIcon = PhosphorIcons.plant();
        else if (categoryName.contains('ٹرانسپورٹ') || categoryName.contains('Transport')) catIcon = PhosphorIcons.car();
        else if (categoryName.contains('کھانا') || categoryName.contains('Food')) catIcon = PhosphorIcons.cookingPot();
        else if (categoryName.contains('تعلیم') || categoryName.contains('Education')) catIcon = PhosphorIcons.bookOpen();

        itemsToDisplay.add({
          'isCategory': true,
          'name': categoryName,
          'icon': catIcon,
          'ids': allIds,
        });
      } else {
        // ورنہ انفرادی پیشے دکھائیں
        for (var id in selectedIds) {
          final p = professions.firstWhere((element) => element['id'] == id);
          itemsToDisplay.add({
            'isCategory': false,
            'name': p['name'],
            'icon': p['icon'],
            'id': id,
          });
        }
      }
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ایڈ بٹن
          _buildItemSquare(
            onTap: () => _showCategoryPicker(controller, isUrdu, fontFamily),
            icon: PhosphorIcons.plus(),
            label: isUrdu ? 'شامل کریں' : 'Add New',
            isSelected: false,
            fontFamily: fontFamily,
            isUrdu: isUrdu,
          ),
          
          const SizedBox(width: 12),

          // منتخب شدہ آئٹمز (کیٹگری یا پیشے)
          ...itemsToDisplay.map((item) {
            final isCategory = item['isCategory'] as bool;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildItemSquare(
                onTap: () {
                  if (isCategory) {
                    controller.toggleWholeCategory(item['ids'] as List<String>);
                  } else {
                    controller.toggleCategory(item['id'] as String);
                  }
                },
                icon: item['icon'],
                label: item['name'],
                isSelected: true,
                fontFamily: fontFamily,
                isUrdu: isUrdu,
                showBadge: isCategory,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildItemSquare({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required bool isSelected,
    required String fontFamily,
    required bool isUrdu,
    bool showBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.themeColor
                        : AppTheme.backgroundColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.themeColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.themeColor,
                    size: 24,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        "ALL",
                        style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
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
          ],
        ),
      ),
    );
  }

  Widget _buildBulletStyleSelector(JobPostController controller, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniToggle(
            isSelected: controller.detailBulletStyle == 'dot',
            onTap: () => controller.setBulletStyle('dot'),
            icon: Icons.circle,
            size: 8,
          ),
          _buildMiniToggle(
            isSelected: controller.detailBulletStyle == 'number',
            onTap: () => controller.setBulletStyle('number'),
            text: "1.",
          ),
          _buildMiniToggle(
            isSelected: controller.detailBulletStyle == 'star',
            onTap: () => controller.setBulletStyle('star'),
            icon: Icons.star_rounded,
            size: 14,
          ),
          _buildMiniToggle(
            isSelected: controller.detailBulletStyle == 'tick',
            onTap: () => controller.setBulletStyle('tick'),
            icon: Icons.check_rounded,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniToggle({
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    String? text,
    double? size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
        ),
        child: icon != null
            ? Icon(icon, size: size ?? 14, color: isSelected ? AppTheme.themeColor : Colors.grey)
            : Text(
                text!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.themeColor : Colors.grey,
                ),
              ),
      ),
    );
  }

  Widget _buildUnitSelector({
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) {
            final isSelected = value == item['id'];
            return _buildMiniToggle(
              isSelected: isSelected,
              onTap: () => onChanged(item['id']),
              text: isUrdu ? item['ur']! : item['en']!,
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildDetailFields(
    JobPostController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    final List<Widget> fields = [];
    for (int i = 0; i < controller.detailControllers.length; i++) {
      final textController = controller.detailControllers[i];
      fields.add(
        Dismissible(
          key: ObjectKey(textController),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => controller.removeDetailFieldByController(textController),
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: isUrdu ? Alignment.centerLeft : Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(PhosphorIcons.trash(), color: Colors.red, size: 18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildBulletIcon(controller, i),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: textController,
                    maxLines: null,
                    minLines: 2,
                    style: TextStyle(fontFamily: fontFamily, fontSize: 17),
                    decoration: InputDecoration(
                      hintText: isUrdu ? 'تفصیل درج کریں...' : 'Enter detail...',
                      hintStyle: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (i < controller.detailControllers.length - 1) {
        fields.add(
          Divider(
            height: 1,
            color: Colors.grey.shade200,
            indent: 40,
            endIndent: 10,
          ),
        );
      }
    }
    return fields;
  }

  Widget _buildBulletIcon(JobPostController controller, int index) {
    String label = "•";
    double size = 24;
    
    if (controller.detailBulletStyle == 'star') {
      label = "★";
      size = 18;
    } else if (controller.detailBulletStyle == 'tick') {
      label = "✓";
      size = 20;
    } else if (controller.detailBulletStyle == 'number') {
      label = "${index + 1}.";
      size = 16;
    }

    return SizedBox(
      width: 24,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: AppTheme.themeColor,
          fontFamily: '',
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String fontFamily) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.darkColor,
        fontFamily: fontFamily,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isUrdu,
    required String fontFamily,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    bool isNumber = false,
    bool borderless = false,
    double? fontSize,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: TextStyle(
        color: AppTheme.darkColor,
        fontFamily: isNumber ? '' : fontFamily,
        fontSize: fontSize ?? (isNumber ? 18 : 16),
      ),
      cursorColor: AppTheme.themeColor,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: isUrdu ? 'NooriNastaleeq' : '',
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
        ),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: borderless ? 16 : 12, vertical: 12),
        fillColor: borderless ? Colors.transparent : const Color(0xFFF5F7F9),
        filled: !borderless,
        border: borderless ? InputBorder.none : OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: borderless ? InputBorder.none : OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: borderless ? InputBorder.none : OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1),
        ),
        prefixIcon: Icon(icon, color: AppTheme.themeColor, size: 20),
        suffixIcon: suffixIcon,
        counterText: borderless ? "" : null,
      ),
      validator: validator ??
          (value) {
            if (!label.contains('Optional') &&
                !label.contains('اختیاری') &&
                (value == null || value.isEmpty)) {
              return isUrdu ? 'یہ فیلڈ ضروری ہے' : 'Required';
            }
            return null;
          },
    );
  }

  void _showCategoryPicker(
    JobPostController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    final professions = ArtisanService.getProfessions();

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var p in professions) {
      final cat = isUrdu ? p['categoryUrdu'] : p['category'];
      if (!grouped.containsKey(cat)) grouped[cat] = [];
      grouped[cat]!.add(p);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider.value(
        value: controller,
        child: Consumer<JobPostController>(
          builder: (context, controller, _) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isUrdu ? 'شعبے منتخب کریں' : 'Select Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: fontFamily,
                            color: AppTheme.darkColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: grouped.keys.length,
                      itemBuilder: (context, index) {
                        final category = grouped.keys.elementAt(index);
                        final items = grouped[category]!;
                        final allSelected = items.every((e) => controller.selectedCategories.contains(e['id']));

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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  TextButton.icon(
                                    onPressed: () {
                                      final allIds = items.map((e) => e['id'] as String).toList();
                                      controller.toggleWholeCategory(allIds);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: Icon(
                                      allSelected ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
                                      size: 16,
                                      color: AppTheme.themeColor,
                                    ),
                                    label: Text(
                                      isUrdu ? 'سب منتخب کریں' : 'Select All',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.themeColor,
                                        fontFamily: fontFamily,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 0.75,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, idx) {
                                  final p = items[idx];
                                  final isSelected =
                                      controller.selectedCategories.contains(p['id']);
                                  return InkWell(
                                    onTap: () {
                                      controller.toggleCategory(p['id']!);
                                    },
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppTheme.themeColor
                                                : AppTheme.backgroundColor.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppTheme.themeColor
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            p['icon'],
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.themeColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Flexible(
                                          child: Text(
                                            isUrdu ? p['name']! : p['id']!,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              fontFamily: fontFamily,
                                              color: isSelected
                                                  ? AppTheme.themeColor
                                                  : AppTheme.darkColor,
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
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField(
    JobPostController controller,
    bool isUrdu,
    String fontFamily, {
    bool borderless = false,
  }) {
    return RawAutocomplete<Map<String, dynamic>>(
      key: const ValueKey('job_location_autocomplete'),
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (!mounted) return const Iterable<Map<String, dynamic>>.empty();
        if (textEditingValue.text.length < 3) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        try {
          return await controller.searchLocations(
            textEditingValue.text, 
            language: Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode
          );
        } catch (e) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
      },
      displayStringForOption: (option) => option['display_name'] ?? "",
      onSelected: (option) {
        controller.areaController.text = option['display_name'];
        controller.jobLatitude = option['lat'];
        controller.jobLongitude = option['lon'];
        controller.notifyListeners();
      },
      fieldViewBuilder: (context, textController, focusNode, onEditingComplete) {
        if (textController.text.isEmpty &&
            controller.areaController.text.isNotEmpty) {
          textController.text = controller.areaController.text;
        }

        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          style: TextStyle(
            color: AppTheme.darkColor,
            fontFamily: fontFamily,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            labelText: isUrdu ? 'کام کا علاقہ' : 'Work Area',
            hintText: isUrdu ? 'مثال: لاہور، گلبرگ' : 'e.g. Lahore, Gulberg',
            labelStyle: TextStyle(
              fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
            ),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: borderless ? 16 : 12,
              vertical: 12,
            ),
            fillColor: borderless ? Colors.transparent : const Color(0xFFF5F7F9),
            filled: !borderless,
            border: borderless ? InputBorder.none : OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: borderless ? InputBorder.none : OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: borderless ? InputBorder.none : OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(
                color: AppTheme.themeColor,
                width: 1,
              ),
            ),
            prefixIcon: Icon(
              PhosphorIcons.mapPin(),
              color: AppTheme.themeColor,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.my_location, color: AppTheme.themeColor),
              onPressed: () async {
                final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
                await controller.getCurrentLocation(language: lang);
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      textController.text = controller.areaController.text;
                    }
                  });
                }
              },
            ),
          ),
          onChanged: (val) {
            if (mounted) {
              controller.onLocationChanged(val);
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return isUrdu ? 'یہ فیلڈ ضروری ہے' : 'Required';
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (!mounted) return const SizedBox.shrink(); // حفاظتی چیک
        return Align(
          alignment: isUrdu ? Alignment.topLeft : Alignment.topRight,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width - 72,
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option['display_name'],
                      style: TextStyle(fontSize: 13, fontFamily: fontFamily),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
