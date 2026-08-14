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

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

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

  String _selectedCategory = 'electrician';
  DateTime? _selectedDeadline;
  List<File> _images = [];
  bool _isLoading = false;

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
        title: isUrdu ? 'نیا کام پوسٹ کریں' : 'Post a Job',
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

              _buildImagePicker(isUrdu, fontFamily),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _postJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isUrdu ? 'کام پوسٹ کریں' : 'Post Job',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(fontFamily: isUrdu ? fontFamily : ''),
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
    final professions = ArtisanService.getProfessions();
    final current = professions.firstWhere((p) => p['id'] == _selectedCategory, orElse: () => professions.first);

    return InkWell(
      onTap: () => _showCategoryPicker(isUrdu, fontFamily),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(current['icon'], color: AppTheme.themeColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(isUrdu ? current['name'] : current['id'], style: TextStyle(fontFamily: fontFamily)),
            ),
            Icon(PhosphorIcons.caretDown(), color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.8),
          itemCount: professions.length,
          itemBuilder: (context, index) {
            final p = professions[index];
            return InkWell(
              onTap: () {
                setState(() => _selectedCategory = p['id']!);
                Navigator.pop(context);
              },
              child: Column(
                children: [
                  Icon(p['icon'], size: 32, color: AppTheme.themeColor),
                  const SizedBox(height: 8),
                  Text(isUrdu ? p['name']! : p['id']!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontFamily: fontFamily)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeadlinePicker(bool isUrdu, String fontFamily) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
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
        child: TextFormField(
          controller: _deadlineController,
          decoration: InputDecoration(
            labelText: isUrdu ? 'آخری تاریخ' : 'Deadline',
            prefixIcon: Icon(PhosphorIcons.calendar()),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (val) => _selectedDeadline == null ? (isUrdu ? 'تاریخ منتخب کریں' : 'Select date') : null,
        ),
      ),
    );
  }

  Widget _buildImagePicker(bool isUrdu, String fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isUrdu ? 'تصاویر (اختیاری)' : 'Images (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
        const SizedBox(height: 8),
        Row(
          children: [
            ..._images.map((file) => Container(
              width: 70, height: 70, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(file), fit: BoxFit.cover)),
            )),
            if (_images.length < 3)
              InkWell(
                onTap: () async {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (img != null) setState(() => _images.add(File(img.path)));
                },
                child: Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_a_photo, color: Colors.grey)),
              ),
          ],
        ),
      ],
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final job = JobPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: user.uid,
        customerName: user.displayName ?? 'User',
        customerPhone: user.phoneNumber ?? '',
        customerPhotoUrl: user.photoURL,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        category: _selectedCategory,
        estimatedBudget: double.tryParse(_budgetController.text),
        deadline: _selectedDeadline!,
        createdAt: DateTime.now(),
      );
      await JobService().postJob(job);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Job Posted!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
