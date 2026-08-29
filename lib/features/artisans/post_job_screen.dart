import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
import 'package:account_app/core/services/location_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/widgets/app_button.dart';

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
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  // تفصیل کے لیے کنٹرولرز
  final List<TextEditingController> _detailControllers = [];

  List<String> _selectedCategories = [];
  List<dynamic> _images = []; // Can contain File (new) or String (existing URL)
  bool _isLoading = false;

  double? _jobLatitude;
  double? _jobLongitude;

  @override
  void initState() {
    super.initState();

    // شروع میں 1 تفصیل والا خانہ
    _addDetailField();

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
    _budgetController.text = job.estimatedBudget?.toStringAsFixed(0) ?? '';
    _daysController.text = job.estimatedDays?.toString() ?? '';

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

    _jobLatitude = job.latitude;
    _jobLongitude = job.longitude;
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var c in _detailControllers) c.dispose();
    _categoryController.dispose();
    _areaController.dispose();
    _daysController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      appBar: CustomAppBar(
        title: isUrdu
            ? (widget.jobToEdit != null
                ? 'کام میں ترمیم کریں'
                : 'نیا کام پوسٹ کریں')
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
                    // سیکشن 2: نمبر شمار تفصیل (اسٹام پیپر)
                    _buildDetailedScopeSection(isUrdu, fontFamily),

                    const SizedBox(height: 20),

                    // 🆕 ہاریزنٹل امیج پیکر (5 بکس بٹن) - Moved here to "main screen"
                    _buildHorizontalImagePicker(isUrdu, fontFamily),

                    const SizedBox(height: 20),

                    // سیکشن 3: شعبہ (Category)
                    _buildCategorySection(isUrdu, fontFamily),

                    const SizedBox(height: 32),

                    // پوسٹ بٹن
                    AppButton(
                      text: isUrdu
                          ? (widget.jobToEdit != null
                              ? 'تبدیلی محفوظ کریں'
                              : ' کام پوسٹ کریں')
                          : (widget.jobToEdit != null
                              ? 'Save Changes'
                              : ' Post Job'),
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
              fontFamily),
          const SizedBox(height: 12),
          _buildCategorySelector(isUrdu, fontFamily),
        ],
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
              color: AppTheme.darkColor),
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
                        color: hasImage
                            ? AppTheme.themeColor.withOpacity(0.3)
                            : Colors.grey.shade300,
                        width: 1.5),
                    image: hasImage
                        ? (_images[index] is File
                            ? DecorationImage(
                                image: FileImage(_images[index]),
                                fit: BoxFit.cover)
                            : DecorationImage(
                                image: NetworkImage(_images[index]),
                                fit: BoxFit.cover))
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (!hasImage)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.cameraPlus(),
                                  color: Colors.grey.shade400, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                isUrdu ? 'شامل کریں' : 'Add',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontFamily: fontFamily),
                              ),
                            ],
                          ),
                        ),
                      if (hasImage)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _images.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
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
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
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
          // 1. کام کا عنوان (سب سے اوپر)
          _buildTextField(
            controller: _titleController,
            label: isUrdu ? 'کام کا عنوان' : 'Job Title',
            hint: isUrdu
                ? 'مثال: آفس اسسٹنٹ کی ضرورت ہے'
                : 'e.g. Need Office Assistant',
            icon: PhosphorIcons.textT(),
            isUrdu: isUrdu,
            fontFamily: fontFamily,
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                ..._buildDetailFields(isUrdu, fontFamily),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Align(
                    alignment:
                        isUrdu ? Alignment.centerLeft : Alignment.centerRight,
                    child: IconButton(
                      onPressed: _addDetailField,
                      icon: Icon(PhosphorIcons.plusCircle(),
                          color: AppTheme.themeColor, size: 28),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(thickness: 1, color: Colors.grey),
          ),

          // 3. کام کا علاقہ (آٹو کمپلیٹ کے ساتھ)
          _buildLocationField(isUrdu, fontFamily),
          const SizedBox(height: 16),

          // 4. بجٹ اور مدت (آمنے سامنے)
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _budgetController,
                  label: isUrdu ? 'بجٹ (اختیاری)' : 'Budget (Optional)',
                  hint: '5000',
                  icon: PhosphorIcons.money(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _daysController,
                  label: isUrdu ? 'مدت (دن)' : 'Days',
                  hint: '3',
                  icon: PhosphorIcons.calendarDots(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  isNumber: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailFields(bool isUrdu, String fontFamily) {
    final List<Widget> fields = [];
    for (int i = 0; i < _detailControllers.length; i++) {
      final controller = _detailControllers[i];
      fields.add(
        Dismissible(
          key: ObjectKey(controller),
          direction: DismissDirection.endToStart,
          onDismissed: (_) =>
              _removeDetailField(_detailControllers.indexOf(controller)),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextFormField(
              controller: controller,
              maxLines: null,
              style: TextStyle(fontFamily: fontFamily, fontSize: 14),
              decoration: InputDecoration(
                hintText: isUrdu ? 'تفصیل درج کریں...' : 'Enter detail...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8, top: 10),
                  child: Text("•",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.themeColor,
                          fontFamily: '')),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      );
      if (i < _detailControllers.length - 1) {
        fields.add(Divider(
            height: 1,
            color: Colors.grey.shade200,
            indent: 40,
            endIndent: 10));
      }
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
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
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
            fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: const Color(0xFFF5F7F9),
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
        prefixIcon: Icon(icon, color: AppTheme.themeColor, size: 20),
        suffixIcon: suffixIcon,
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
                  Icon(PhosphorIcons.plusCircle(),
                      size: 18, color: AppTheme.themeColor),
                  const SizedBox(width: 6),
                  Text(
                    isUrdu ? 'شعبہ شامل کریں' : 'Add Category',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.themeColor,
                        fontFamily: fontFamily),
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
                orElse: () => {'name': catId, 'id': catId});
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.darkColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
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
                        fontFamily: fontFamily),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategories.remove(catId)),
                    child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.white24, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.white)),
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
      builder: (context) => StatefulBuilder(
        // Use StatefulBuilder to update selection in real-time
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
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
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 4),
                            child: Text(
                              category,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.themeColor,
                                  fontFamily: fontFamily),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, idx) {
                              final p = items[idx];
                              final isSelected =
                                  _selectedCategories.contains(p['id']);
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
                                    color: isSelected
                                        ? AppTheme.themeColor.withOpacity(0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: isSelected
                                            ? AppTheme.themeColor
                                            : Colors.grey[200]!,
                                        width: 1.5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(p['icon'],
                                          color: isSelected
                                              ? AppTheme.themeColor
                                              : Colors.grey[700],
                                          size: 28),
                                      const SizedBox(height: 8),
                                      Text(
                                        isUrdu ? p['name']! : p['id']!,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          fontFamily: fontFamily,
                                          color: isSelected
                                              ? AppTheme.themeColor
                                              : Colors.black87,
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


  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _jobLatitude = pos.latitude;
        _jobLongitude = pos.longitude;
      });
      final p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (p.isNotEmpty)
        setState(() =>
            _areaController.text = "${p[0].locality}, ${p[0].subLocality}");
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _postJob() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (!_formKey.currentState!.validate()) return;

    // چیک کریں کہ تفصیل لکھی ہوئی ہے
    final validDetails = _detailControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();

    if (validDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrdu
              ? 'براہ کرم کم از کم ایک تفصیل درج کریں'
              : 'Please enter at least one detail'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final details = validDetails.length > 1
        ? validDetails.map((d) => '• $d').join('\n')
        : validDetails.first;

    // چیک کریں کہ کم از کم ایک شعبہ منتخب ہے
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrdu
              ? 'براہ کرم کم از کم ایک شعبہ منتخب کریں'
              : 'Please select at least one category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 🆕 خودکار لوکیشن سرچ (اگر ہاتھ سے نام لکھا گیا ہو)
      if ((_jobLatitude == null || _jobLongitude == null) &&
          _areaController.text.isNotEmpty) {
        try {
          final locations =
              await locationFromAddress(_areaController.text.trim());
          if (locations.isNotEmpty) {
            _jobLatitude = locations.first.latitude;
            _jobLongitude = locations.first.longitude;
          }
        } catch (e) {
          debugPrint("Geocoding failed: $e");
        }
      }

      final user = FirebaseAuth.instance.currentUser!;
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);

      // تصاویر اپ لوڈ کریں
      List<String> uploadedImageUrls = [];
      for (var item in _images) {
        if (item is File) {
          // نیا امیج ہے، اپ لوڈ کریں
          String fileName =
              "job_${DateTime.now().millisecondsSinceEpoch}_${_images.indexOf(item)}.jpg";
          String url = await firebaseService.uploadFile(item.path, fileName);
          uploadedImageUrls.add(url);
        } else if (item is String) {
          // پہلے سے اپ لوڈ شدہ URL ہے
          uploadedImageUrls.add(item);
        }
      }

      // final details is already defined at the top of this method

      final job = JobPost(
        id: widget.jobToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: user.uid,
        customerName: user.displayName ?? 'User',
        customerPhone: user.phoneNumber ?? '',
        customerPhotoUrl: user.photoURL,
        title: _titleController.text.trim(),
        description: details,
        location: _areaController.text.trim(),
        categories: _selectedCategories,
        estimatedBudget: double.tryParse(_budgetController.text),
        images: uploadedImageUrls,
        createdAt: widget.jobToEdit?.createdAt ?? DateTime.now(),
        status: widget.jobToEdit?.status ?? 'open',
        detailedScope: details,
        scopeOfWork: details,
        exclusions: null,
        estimatedDays: int.tryParse(_daysController.text),
        latitude: _jobLatitude,
        longitude: _jobLongitude,
      );

      await JobService().postJob(job);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
            content: Text(isUrdu
                ? (widget.jobToEdit != null
                    ? 'تبدیلی محفوظ کر لی گئی ہے!'
                    : 'کام پوسٹ کر دیا گیا ہے!')
                : (widget.jobToEdit != null
                    ? 'Changes Saved!'
                    : 'Job Posted!')),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLocationField(bool isUrdu, String fontFamily) {
    return RawAutocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.length < 3) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        return await LocationService.searchLocations(textEditingValue.text);
      },
      displayStringForOption: (option) => option['display_name'],
      onSelected: (option) {
        setState(() {
          _areaController.text = option['display_name'];
          _jobLatitude = option['lat'];
          _jobLongitude = option['lon'];
        });
      },
      fieldViewBuilder:
          (context, controller, focusNode, onEditingComplete) {
        // ہم اپنا کنٹرولر استعمال کریں گے تاکہ بیرونی تبدیلیوں کا اثر پڑے
        if (controller.text != _areaController.text && _areaController.text.isNotEmpty && controller.text.isEmpty) {
           controller.text = _areaController.text;
        }
        
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontSize: 16),
          decoration: InputDecoration(
            labelText: isUrdu ? 'کام کا علاقہ' : 'Work Area',
            hintText: isUrdu ? 'مثال: لاہور، گلبرگ' : 'e.g. Lahore, Gulberg',
            labelStyle: TextStyle(
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            fillColor: const Color(0xFFF5F7F9),
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey.shade400)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey.shade400)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
            prefixIcon: Icon(PhosphorIcons.mapPin(), color: AppTheme.themeColor, size: 20),
            suffixIcon: IconButton(
              icon: Icon(Icons.my_location, color: AppTheme.themeColor),
              onPressed: () async {
                await _getCurrentLocation();
                controller.text = _areaController.text;
              },
            ),
          ),
          onChanged: (val) {
             _areaController.text = val;
             if (_jobLatitude != null || _jobLongitude != null) {
                setState(() {
                  _jobLatitude = null;
                  _jobLongitude = null;
                });
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
