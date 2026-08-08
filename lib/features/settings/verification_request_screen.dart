import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/verification_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';

class VerificationRequestScreen extends StatefulWidget {
  final bool isArtisanMode; // To customize labels if opened from Artisan profile
  const VerificationRequestScreen({super.key, this.isArtisanMode = false});

  @override
  State<VerificationRequestScreen> createState() =>
      _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessTypeController = TextEditingController();

  File? _cnicFront;
  File? _cnicBack;
  File? _shopImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.isArtisanMode) {
      _businessNameController.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(isUrdu ? 'کیمرہ' : 'Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(isUrdu ? 'گیلری' : 'Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile =
          await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: type == 'shop' 
              ? const CropAspectRatio(ratioX: 16, ratioY: 9)
              : const CropAspectRatio(ratioX: 3, ratioY: 2),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: isUrdu ? 'تصویر تراشیں' : 'Crop Image',
              toolbarColor: AppTheme.darkColor,
              toolbarWidgetColor: Colors.white,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            if (type == 'front') _cnicFront = File(croppedFile.path);
            if (type == 'back') _cnicBack = File(croppedFile.path);
            if (type == 'shop') _shopImage = File(croppedFile.path);
          });
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    if (_cnicFront == null || _cnicBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUrdu
                ? 'براہ کرم شناختی کارڈ کی دونوں تصویریں اپ لوڈ کریں'
                : 'Please upload both sides of CNIC')),
      );
      return;
    }

    try {
      final service = Provider.of<VerificationService>(context, listen: false);
      
      await service.submitRequest(
        cnicFront: _cnicFront!,
        cnicBack: _cnicBack!,
        shopImage: _shopImage,
        businessName: _businessNameController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        isArtisan: widget.isArtisanMode,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isUrdu ? 'آپ کی درخواست جمع کر دی گئی ہے' : 'Your request has been submitted')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRequest() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    try {
      final service = Provider.of<VerificationService>(context, listen: false);
      await service.cancelRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isUrdu
                  ? 'درخواست منسوخ کر دی گئی'
                  : 'Request cancelled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final service = Provider.of<VerificationService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: isUrdu ? 'پروفائل کی تصدیق' : 'Profile Verification'),
      body: service.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isUrdu, fontFamily),
                    const SizedBox(height: 24),

                    if (service.currentStatus == VerificationStatus.pending)
                      _buildStatusBanner(
                        isUrdu
                            ? 'آپ کی درخواست زیر التوا ہے۔ ہم 24 سے 48 گھنٹوں میں جائزہ لیں گے۔'
                            : 'Your request is pending. We will review it within 24-48 hours.',
                        Colors.orange.shade50,
                        Colors.orange.shade800,
                        fontFamily,
                      ),

                    if (service.currentStatus == VerificationStatus.approved)
                      _buildStatusBanner(
                        isUrdu
                            ? 'آپ کا اکاؤنٹ تصدیق شدہ ہے۔ مبارک ہو!'
                            : 'Your account is verified. Congratulations!',
                        Colors.green.shade50,
                        Colors.green.shade800,
                        fontFamily,
                      ),

                    if (service.currentStatus == VerificationStatus.rejected &&
                        service.adminNote != null)
                      _buildRejectionNote(
                          service.adminNote!, isUrdu, fontFamily),

                    _buildSectionTitle(
                        isUrdu ? 'بنیادی معلومات' : 'Basic Information',
                        isUrdu,
                        fontFamily),
                    const SizedBox(height: 15),

                    // Business Info
                    _buildTextField(
                      controller: _businessNameController,
                      label: isUrdu ? 'کاروبار یا اپنا مکمل نام' : 'Business or Full Name',
                      icon: PhosphorIcons.user(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _businessTypeController,
                      label: isUrdu ? 'کاروبار یا ہنر کی قسم' : 'Business or Skill Type',
                      hint: isUrdu
                          ? 'مثلاً: کریانہ، الیکٹریشن، درزی'
                          : 'e.g. Grocery, Electrician, Tailor',
                      icon: PhosphorIcons.tag(),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),

                    const SizedBox(height: 30),
                    _buildSectionTitle(
                        isUrdu ? 'دستاویزات کی تصاویر' : 'Document Images',
                        isUrdu,
                        fontFamily),
                    const SizedBox(height: 15),

                    // CNIC Front
                    _buildImagePicker(
                      image: _cnicFront,
                      label: isUrdu ? 'شناختی کارڈ (سامنے کی تصویر)' : 'CNIC Front Side',
                      onTap: () => _pickImage('front'),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                    const SizedBox(height: 16),

                    // CNIC Back
                    _buildImagePicker(
                      image: _cnicBack,
                      label: isUrdu ? 'شناختی کارڈ (پیچھے کی تصویر)' : 'CNIC Back Side',
                      onTap: () => _pickImage('back'),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),
                    const SizedBox(height: 16),

                    // Shop Image (Optional for some, but good to have)
                    _buildImagePicker(
                      image: _shopImage,
                      label: isUrdu
                          ? 'دکان یا کام کی جگہ (اختیاری)'
                          : 'Shop or Workplace (Optional)',
                      onTap: () => _pickImage('shop'),
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed:
                            service.currentStatus == VerificationStatus.approved
                                ? null
                                : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          service.currentStatus == VerificationStatus.approved
                              ? (isUrdu
                                  ? 'پہلے ہی تصدیق شدہ'
                                  : 'Already Verified')
                              : (isUrdu
                                  ? 'درخواست جمع کروائیں'
                                  : 'Submit Request'),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (service.currentStatus == VerificationStatus.pending ||
                        service.currentStatus == VerificationStatus.rejected)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _cancelRequest,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade400),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isUrdu ? 'درخواست منسوخ کریں' : 'Cancel Request',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: fontFamily,
                                color: Colors.red.shade700),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.verifiedGold.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.verifiedGold.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
              color: AppTheme.verifiedGold, size: 45),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrdu ? 'ویریفائیڈ ٹک حاصل کریں' : 'Get Verified Badge',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor),
                ),
                Text(
                  isUrdu
                      ? 'تصدیق شدہ اکاؤنٹ سے گاہکوں کا آپ پر اعتماد بڑھتا ہے۔'
                      : 'Verified profiles build more trust with customers.',
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: fontFamily,
                      color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionNote(String note, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                isUrdu ? 'درخواست مسترد ہونے کی وجہ' : 'Reason for rejection',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                    fontFamily: fontFamily),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade800,
                fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isUrdu, String fontFamily) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
          color: AppTheme.darkColor),
    );
  }

  Widget _buildStatusBanner(
      String text, Color background, Color color, String fontFamily) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(64)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 14,
            color: color,
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    required bool isUrdu,
    required String fontFamily,
    bool enabled = true,
  }) {
    return TextFormField(
      enabled: enabled,
      controller: controller,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontFamily: fontFamily, color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: AppTheme.themeColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) => (value == null || value.isEmpty)
          ? (isUrdu ? 'ضروری ہے' : 'Required')
          : null,
    );
  }

  Widget _buildImagePicker({
    required File? image,
    required String label,
    required VoidCallback onTap,
    required bool isUrdu,
    required String fontFamily,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(image,
                    fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.cameraPlus(), size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(label,
                      style: TextStyle(
                          color: Colors.grey[600], fontFamily: fontFamily, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
