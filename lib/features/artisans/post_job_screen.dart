import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/firebase_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:flutter/services.dart';

class PostJobScreen extends StatefulWidget {
  final JobPost? jobToEdit;
  const PostJobScreen({super.key, this.jobToEdit});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // کنٹرولرز
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _timeInController = TextEditingController();
  final TextEditingController _timeOutController = TextEditingController();
  
  // تفصیل کے لیے کنٹرولرز
  final List<TextEditingController> _detailControllers = [];
  final List<TextEditingController> _exclusionControllers = [];
  
  List<String> _selectedCategories = [];
  DateTime? _selectedDeadline;
  List<dynamic> _images = []; // Can contain File (new) or String (existing URL)
  bool _isLoading = false;
  
  double? _jobLatitude;
  double? _jobLongitude;

  @override
  void initState() {
    super.initState();
    
    // شروع میں 1 تفصیل اور 1 استثناء والا خانہ
    _addDetailField();
    _addExclusionField();
    
    if (widget.jobToEdit != null) {
      _loadJobData();
    }
  }

  void _addDetailField() {
    setState(() {
      _detailControllers.add(TextEditingController());
    });
  }

  void _removeDetailField(int index) {
    if (_detailControllers.length <= 1) return;
    setState(() {
      _detailControllers.removeAt(index);
    });
  }

  void _loadJobData() {
    final job = widget.jobToEdit!;
    _titleController.text = job.title;
    _selectedCategories = List.from(job.categories);
    _categoryController.text = _selectedCategories.join(', ');
    _areaController.text = job.location;
    if (job.deadline != null) {
      _deadlineController.text = DateFormat('dd/MM/yyyy').format(job.deadline!);
      _selectedDeadline = job.deadline;
    }
    _budgetController.text = job.estimatedBudget?.toStringAsFixed(0) ?? '';
    _daysController.text = job.estimatedDays?.toString() ?? '';
    _timeInController.text = job.timeIn ?? '';
    _timeOutController.text = job.timeOut ?? '';
    
    // تفصیلات لوڈ کریں
    final detailsText = job.detailedScope ?? job.description;
    final details = detailsText.split('\n');
    _detailControllers.clear();
    for (var d in details) {
      final text = d.replaceAll(RegExp(r'^•\s*'), '').trim();
      if (text.isNotEmpty) {
        _detailControllers.add(TextEditingController(text: text));
      }
    }
    if (_detailControllers.isEmpty) _addDetailField();

    // تصاویر لوڈ کریں
    _images = List.from(job.images);
    
    if (job.exclusions != null) {
      final exclusions = job.exclusions!.split('\n');
      _exclusionControllers.clear(); // Clear initial empty fields
      for (int i = 0; i < exclusions.length; i++) {
        final text = exclusions[i].replaceAll(RegExp(r'^•\s*'), '').trim();
        if (text.isNotEmpty) {
          final c = TextEditingController(text: text);
          _exclusionControllers.add(c);
        }
      }
      if (_exclusionControllers.isEmpty) _addExclusionField();
    }
    
    _jobLatitude = job.latitude;
    _jobLongitude = job.longitude;
  }

  void _addExclusionField() {
    setState(() {
      _exclusionControllers.add(TextEditingController());
    });
  }

  void _removeExclusionField(int index) {
    if (_exclusionControllers.length <= 1) return;
    setState(() {
      _exclusionControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var c in _detailControllers) c.dispose();
    for (var c in _exclusionControllers) c.dispose();
    _categoryController.dispose();
    _areaController.dispose();
    _deadlineController.dispose();
    _daysController.dispose();
    _budgetController.dispose();
    _timeInController.dispose();
    _timeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      appBar: CustomAppBar(
        title: isUrdu 
            ? (widget.jobToEdit != null ? 'کام میں ترمیم کریں' : 'نیا کام پوسٹ کریں') 
            : (widget.jobToEdit != null ? 'Edit Job' : 'Post a Job'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // سیکشن 1: بنیادی معلومات
              _buildBasicInfoSection(isUrdu, fontFamily),

              const SizedBox(height: 20),

              // سیکشن 2: نمبر شمار تفصیل (اسٹام پیپر)
              _buildDetailedScopeSection(isUrdu, fontFamily),

              const SizedBox(height: 20),

              // سیکشن 3: شعبہ (Category) - Moved here
              _buildCategorySection(isUrdu, fontFamily),

              const SizedBox(height: 32),

              // پوسٹ بٹن
              AppButton(
                text: isUrdu 
                    ? (widget.jobToEdit != null ? 'تبدیلی محفوظ کریں' : ' کام پوسٹ کریں')
                    : (widget.jobToEdit != null ? 'Save Changes' : ' Post Job'),
                color: AppTheme.darkColor,
                size: AppButtonSize.large,
                isFullWidth: true,
                onPressed: _postJob,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          _buildSectionHeader(
            isUrdu ? 'کام کا شعبہ / پروفشن' : 'Job Category / Profession',
            fontFamily
          ),
          const SizedBox(height: 12),
          _buildCategorySelector(isUrdu, fontFamily),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          _buildSectionHeader(
            isUrdu ? 'بنیادی معلومات' : 'Basic Information',
            fontFamily
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _areaController,
            label: isUrdu ? 'کام کا علاقہ' : 'Work Area',
            hint: isUrdu ? 'مثال: لاہور، گلبرگ' : 'e.g. Lahore, Gulberg',
            icon: PhosphorIcons.mapPin(),
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            suffixIcon: IconButton(
              icon: Icon(Icons.my_location, color: AppTheme.themeColor),
              onPressed: _getCurrentLocation,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDeadlinePicker(isUrdu, fontFamily),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTimePicker(
                  controller: _timeInController,
                  label: isUrdu ? 'ٹائم ان (اختیاری)' : 'Time In (Optional)',
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePicker(
                  controller: _timeOutController,
                  label: isUrdu ? 'ٹائم آؤٹ (اختیاری)' : 'Time Out (Optional)',
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _budgetController,
            label: isUrdu
                ? 'تخمینی بجٹ / تنخواہ (اختیاری)'
                : 'Budget / Salary (Optional)',
            hint: isUrdu ? 'مثال: 50000' : 'e.g. 50000',
            icon: PhosphorIcons.money(),
            isUrdu: isUrdu,
            fontFamily: fontFamily,
            isNumber: true,
          ),
          const SizedBox(height: 20),

          // 🆕 ہاریزنٹل امیج پیکر (5 بکس بٹن)
          _buildHorizontalImagePicker(isUrdu, fontFamily),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required TextEditingController controller,
    required String label,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          if (mounted) controller.text = time.format(context);
        }
      },
      child: IgnorePointer(
        child: _buildTextField(
          controller: controller,
          label: label,
          icon: PhosphorIcons.clockAfternoon(),
          isUrdu: isUrdu,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildHorizontalImagePicker(bool isUrdu, String fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isUrdu ? 'تصاویر (زیادہ سے زیادہ 5)' : 'Images (Max 5)',
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            fontFamily: fontFamily, 
            color: AppTheme.darkColor
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5, // فکسڈ 5 بکس
            itemBuilder: (context, index) {
              final bool hasImage = index < _images.length;
              
              return GestureDetector(
                onTap: () => hasImage ? null : _pickImage(),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasImage ? AppTheme.themeColor.withOpacity(0.3) : Colors.grey.shade300,
                      width: 1.5
                    ),
                    image: hasImage 
                        ? (_images[index] is File 
                            ? DecorationImage(image: FileImage(_images[index]), fit: BoxFit.cover)
                            : DecorationImage(image: NetworkImage(_images[index]), fit: BoxFit.cover))
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (!hasImage)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.cameraPlus(), color: Colors.grey.shade400, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                isUrdu ? 'شامل کریں' : 'Add',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: fontFamily),
                              ),
                            ],
                          ),
                        ),
                      if (hasImage)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
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

  Future<void> _pickImage() async {
    if (_images.length >= 5) return;
    
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() {
          _images.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Widget _buildDetailedScopeSection(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          _buildTextField(
            controller: _titleController,
            label: isUrdu ? 'کام کا عنوان' : 'Job Title',
            hint: isUrdu ? 'مثال: آفس اسسٹنٹ کی ضرورت ہے' : 'e.g. Need Office Assistant',
            icon: PhosphorIcons.textT(),
            isUrdu: isUrdu,
            fontFamily: fontFamily,
          ),
          const SizedBox(height: 20),
          
          ..._buildDetailFields(isUrdu, fontFamily),
          
          Center(
            child: TextButton.icon(
              onPressed: _addDetailField,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.themeColor.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: Icon(PhosphorIcons.plusCircle(), color: AppTheme.themeColor, size: 20),
              label: Text(
                isUrdu ? 'نئی تفصیل شامل کریں' : 'Add New Detail',
                style: TextStyle(
                  color: AppTheme.themeColor, 
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(thickness: 1, color: Colors.grey),
          ),
          
          Text(
            isUrdu ? 'اس کام میں کیا شامل نہیں ہے؟ ' : 'What is NOT included? ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isUrdu ? 'مثلاً: میٹیریل گاہک لائے گا، یا ٹرانسپورٹ شامل نہیں ہے۔' : 'e.g. Material provided by customer, or transport not included.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: fontFamily),
          ),
          const SizedBox(height: 12),
          ..._buildExclusionFields(isUrdu, fontFamily),
          
          Center(
            child: TextButton.icon(
              onPressed: _addExclusionField,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.themeColor.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: Icon(PhosphorIcons.plusCircle(), color: AppTheme.themeColor, size: 20),
              label: Text(
                isUrdu ? 'نیا استثناء شامل کریں' : 'Add New Exclusion',
                style: TextStyle(
                  color: AppTheme.themeColor, 
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailFields(bool isUrdu, String fontFamily) {
    final List<Widget> fields = [];
    for (int i = 0; i < _detailControllers.length; i++) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TextFormField(
                controller: _detailControllers[i],
                maxLines: 2,
                style: TextStyle(fontFamily: fontFamily, fontSize: 14),
                decoration: InputDecoration(
                  labelText: i == 0 ? (isUrdu ? 'کام کی تفصیل' : 'Work Detail') : null,
                  hintText: isUrdu ? 'تفصیل درج کریں...' : 'Enter detail...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  labelStyle: TextStyle(
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '', 
                    color: Colors.grey.shade600, 
                    fontSize: 13, 
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F7F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              if (_detailControllers.length > 1)
                Positioned(
                  top: -10,
                  right: isUrdu ? null : -5,
                  left: isUrdu ? -5 : null,
                  child: GestureDetector(
                    onTap: () => _removeDetailField(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return fields;
  }

  List<Widget> _buildExclusionFields(bool isUrdu, String fontFamily) {
    final List<Widget> fields = [];
    for (int i = 0; i < _exclusionControllers.length; i++) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TextFormField(
                controller: _exclusionControllers[i],
                maxLines: 2,
                style: TextStyle(fontFamily: fontFamily, fontSize: 14),
                decoration: InputDecoration(
                  hintText: isUrdu ? 'استثناء درج کریں...' : 'Enter exclusion...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F7F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              if (_exclusionControllers.length > 1)
                Positioned(
                  top: -10,
                  right: isUrdu ? null : -5,
                  left: isUrdu ? -5 : null,
                  child: GestureDetector(
                    onTap: () => _removeExclusionField(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return fields;
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
    bool isNumber = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        color: AppTheme.darkColor, 
        fontFamily: isNumber ? '' : fontFamily, 
        fontSize: isNumber ? 18 : 16,
      ),
      cursorColor: AppTheme.themeColor,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: isUrdu ? 'NooriNastaleeq' : '', 
          color: Colors.grey.shade600, 
          fontSize: 13, 
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: const Color(0xFFF5F7F9),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
        prefixIcon: Icon(icon, color: AppTheme.themeColor, size: 20),
        suffixIcon: suffixIcon,
      ),
      validator: (value) {
        if (!label.contains('Optional') && !label.contains('اختیاری') && (value == null || value.isEmpty)) {
          return isUrdu ? 'یہ فیلڈ ضروری ہے' : 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildCategorySelector(bool isUrdu, String fontFamily) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ایڈ بٹن ڈیزائن
          InkWell(
            onTap: () => _showCategoryPicker(isUrdu, fontFamily),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.themeColor, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.plusCircle(), size: 18, color: AppTheme.themeColor),
                  const SizedBox(width: 6),
                  Text(
                    isUrdu ? 'شعبہ شامل کریں' : 'Add Category',
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.bold, 
                      color: AppTheme.themeColor,
                      fontFamily: fontFamily
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // منتخب شدہ ٹیگز
          ..._selectedCategories.map((catId) {
            final prof = ArtisanService.getProfessions().firstWhere(
              (p) => p['id'] == catId, 
              orElse: () => {'name': catId, 'id': catId}
            );
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.darkColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isUrdu ? prof['name'] : prof['id'],
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategories.remove(catId)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 12, color: Colors.white)
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showCategoryPicker(bool isUrdu, String fontFamily) {
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
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update selection in real-time
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isUrdu ? 'شعبے منتخب کریں' : 'Select Categories',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily),
                      ),
                      AppButton(
                        text: isUrdu ? 'ہو گیا' : 'Done',
                        size: AppButtonSize.small,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, index) {
                      final category = grouped.keys.elementAt(index);
                      final items = grouped[category]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Text(
                              category,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.themeColor, fontFamily: fontFamily),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, idx) {
                              final p = items[idx];
                              final isSelected = _selectedCategories.contains(p['id']);
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedCategories.remove(p['id']);
                                    } else {
                                      _selectedCategories.add(p['id']!);
                                    }
                                  });
                                  setModalState(() {}); // Refresh modal UI
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.themeColor.withOpacity(0.1) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? AppTheme.themeColor : Colors.grey[200]!, width: 1.5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(p['icon'], color: isSelected ? AppTheme.themeColor : Colors.grey[700], size: 28),
                                      const SizedBox(height: 8),
                                      Text(
                                        isUrdu ? p['name']! : p['id']!,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontFamily: fontFamily,
                                          color: isSelected ? AppTheme.themeColor : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlinePicker(bool isUrdu, String fontFamily) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() {
            _selectedDeadline = date;
            _deadlineController.text = DateFormat('dd/MM/yyyy').format(date);
          });
        }
      },
      child: IgnorePointer(
        child: _buildTextField(
          controller: _deadlineController,
          label: isUrdu ? 'آخری تاریخ (اختیاری)' : 'Deadline (Optional)',
          icon: PhosphorIcons.calendar(),
          isUrdu: isUrdu,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _jobLatitude = pos.latitude;
        _jobLongitude = pos.longitude;
      });
      final p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (p.isNotEmpty) setState(() => _areaController.text = "${p[0].locality}, ${p[0].subLocality}");
    } catch (e) { debugPrint(e.toString()); }
  }



  Future<void> _postJob() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (!_formKey.currentState!.validate()) return;
    
    // چیک کریں کہ تفصیل لکھی ہوئی ہے
    final details = _detailControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => '• ${c.text.trim()}')
        .join('\n');

    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrdu ? 'براہ کرم کم از کم ایک تفصیل درج کریں' : 'Please enter at least one detail'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // چیک کریں کہ کم از کم ایک شعبہ منتخب ہے
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrdu ? 'براہ کرم کم از کم ایک شعبہ منتخب کریں' : 'Please select at least one category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);

      // تصاویر اپ لوڈ کریں
      List<String> uploadedImageUrls = [];
      for (var item in _images) {
        if (item is File) {
          // نیا امیج ہے، اپ لوڈ کریں
          String fileName = "job_${DateTime.now().millisecondsSinceEpoch}_${_images.indexOf(item)}.jpg";
          String url = await firebaseService.uploadFile(item.path, fileName);
          uploadedImageUrls.add(url);
        } else if (item is String) {
          // پہلے سے اپ لوڈ شدہ URL ہے
          uploadedImageUrls.add(item);
        }
      }
      
      // final details is already defined at the top of this method
      
      final exclusions = _exclusionControllers
          .where((c) => c.text.trim().isNotEmpty)
          .map((c) => '• ${c.text.trim()}')
          .join('\n');
      
      final job = JobPost(
        id: widget.jobToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: user.uid,
        customerName: user.displayName ?? 'User',
        customerPhone: user.phoneNumber ?? '',
        customerPhotoUrl: user.photoURL,
        title: _titleController.text.trim(),
        description: details,
        location: _areaController.text.trim(),
        categories: _selectedCategories,
        estimatedBudget: double.tryParse(_budgetController.text),
        deadline: _selectedDeadline,
        images: uploadedImageUrls,
        createdAt: widget.jobToEdit?.createdAt ?? DateTime.now(),
        bidCount: widget.jobToEdit?.bidCount ?? 0,
        status: widget.jobToEdit?.status ?? 'open',
        detailedScope: details,
        scopeOfWork: details,
        exclusions: exclusions.isNotEmpty ? exclusions : null,
        estimatedDays: int.tryParse(_daysController.text),
        latitude: _jobLatitude,
        longitude: _jobLongitude,
        timeIn: _timeInController.text.trim(),
        timeOut: _timeOutController.text.trim(),
      );
      
      await JobService().postJob(job);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(isUrdu 
                ? (widget.jobToEdit != null ? 'تبدیلی محفوظ کر لی گئی ہے!' : 'کام پوسٹ کر دیا گیا ہے!') 
                : (widget.jobToEdit != null ? 'Changes Saved!' : 'Job Posted!')), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
