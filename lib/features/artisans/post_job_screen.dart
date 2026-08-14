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
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';

class PostJobScreen extends StatefulWidget {
  final JobPost? jobToEdit;
  const PostJobScreen({super.key, this.jobToEdit});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  String? _selectedCategory;
  DateTime? _selectedDeadline;
  List<File> _images = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.jobToEdit != null) {
      final job = widget.jobToEdit!;
      _titleController.text = job.title;
      _descriptionController.text = job.description;
      _locationController.text = job.location;
      _budgetController.text = job.estimatedBudget?.toStringAsFixed(0) ?? '';
      _selectedCategory = job.category;
      _selectedDeadline = job.deadline;
      _deadlineController.text = DateFormat('dd/MM/yyyy').format(job.deadline);
      // Images handling if needed, currently JobPost uses List<String> for URLs
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _deadlineController.dispose();
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
              _buildTextField(
                controller: _titleController,
                label: isUrdu ? 'کام کا عنوان' : 'Job Title',
                hint: isUrdu ? 'مثال: پنکھا ٹھیک کریں' : 'e.g. Fix ceiling fan',
                icon: PhosphorIcons.briefcase(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _descriptionController,
                label: isUrdu ? 'کام کی تفصیل' : 'Description',
                hint: isUrdu ? 'تفصیل سے بتائیں کہ کیا کرنا ہے...' : 'Describe what needs to be done...',
                icon: PhosphorIcons.note(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                maxLines: 4,
              ),

              const SizedBox(height: 16),

              _buildCategorySelector(isUrdu, fontFamily),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _locationController,
                label: isUrdu ? 'مقام' : 'Location',
                icon: PhosphorIcons.mapPin(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                suffixIcon: IconButton(
                  icon: Icon(Icons.my_location, color: AppTheme.themeColor),
                  onPressed: _getCurrentLocation,
                ),
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _budgetController,
                label: isUrdu ? 'تخمینی بجٹ (اختیاری)' : 'Estimated Budget (Optional)',
                icon: PhosphorIcons.money(),
                isUrdu: isUrdu,
                fontFamily: fontFamily,
                isNumber: true,
              ),

              const SizedBox(height: 16),

              _buildDeadlinePicker(isUrdu, fontFamily),

              const SizedBox(height: 16),

              ImageSelectorField(
                label: isUrdu ? 'تصاویر (اختیاری)' : 'Images (Optional)',
                selectedFiles: _images,
                onFilesChanged: (newList) => setState(() => _images = newList),
                maxTotal: 3,
              ),

              const SizedBox(height: 32),

              AppButton(
                text: isUrdu 
                    ? (widget.jobToEdit != null ? 'تبدیلی محفوظ کریں' : 'کام پوسٹ کریں') 
                    : (widget.jobToEdit != null ? 'Save Changes' : 'Post Job'),
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
        if (label.contains('Category') || label.contains('قسم')) {
          if (_selectedCategory == null) return isUrdu ? 'منتخب کریں' : 'Required';
        }
        if (!label.contains('Optional') && !label.contains('اختیاری') && (value == null || value.isEmpty)) {
          return isUrdu ? 'یہ فیلڈ ضروری ہے' : 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildCategorySelector(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
    final selectedItem = _selectedCategory != null 
        ? professions.firstWhere((p) => p['id'] == _selectedCategory, orElse: () => professions.first)
        : null;

    return InkWell(
      onTap: () => _showCategoryPicker(isUrdu, fontFamily),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: isUrdu ? 'کام کی قسم' : 'Job Category',
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
          prefixIcon: Icon(
            selectedItem != null ? selectedItem['icon'] : PhosphorIcons.listBullets(), 
            color: AppTheme.themeColor, 
            size: 20
          ),
          suffixIcon: Icon(PhosphorIcons.caretDown(), color: Colors.grey, size: 16),
        ),
        isEmpty: _selectedCategory == null,
        child: Text(
          selectedItem != null 
              ? (isUrdu ? selectedItem['name'] : selectedItem['id'])
              : (isUrdu ? 'منتخب کریں...' : 'Select Category'), 
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            color: selectedItem != null ? AppTheme.darkColor : Colors.grey[400],
            fontWeight: FontWeight.bold,
          )
        ),
      ),
    );
  }

  void _showCategoryPicker(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
    
    // Group professions by category
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
      builder: (context) => DraggableScrollableSheet(
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
              Text(
                isUrdu ? 'کام کی قسم منتخب کریں' : 'Select Job Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily),
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
                            final isSelected = _selectedCategory == p['id'];
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedCategory = p['id']!);
                                Navigator.pop(context);
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
          label: isUrdu ? 'آخری تاریخ' : 'Deadline',
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
      final p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (p.isNotEmpty) setState(() => _locationController.text = "${p[0].locality}, ${p[0].subLocality}");
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _postJob() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final job = JobPost(
        id: widget.jobToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: user.uid,
        customerName: user.displayName ?? 'User',
        customerPhone: user.phoneNumber ?? '',
        customerPhotoUrl: user.photoURL,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        category: _selectedCategory!,
        estimatedBudget: double.tryParse(_budgetController.text),
        deadline: _selectedDeadline!,
        createdAt: widget.jobToEdit?.createdAt ?? DateTime.now(),
        bidCount: widget.jobToEdit?.bidCount ?? 0,
        status: widget.jobToEdit?.status ?? 'open',
      );
      await JobService().postJob(job);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(isUrdu 
                ? (widget.jobToEdit != null ? '✅ تبدیلی محفوظ کر لی گئی ہے!' : '✅ کام پوسٹ کر دیا گیا ہے!') 
                : (widget.jobToEdit != null ? '✅ Changes Saved!' : '✅ Job Posted!')), 
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
