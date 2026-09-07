// lib/features/settings/master_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/utils/image_utils.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'package:account_app/features/profile/controllers/profile_controller.dart';
import 'package:account_app/core/utils/artisan_validators.dart';

class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  late final ProfileController _controller;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = ProfileController();
    _controller.loadExistingProfile();
    // getCurrentLocation is already called inside loadExistingProfile or can be called here
    _controller.getCurrentLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage({bool isProfile = true}) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null && mounted) {
        final cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle:
                  isProfile ? 'Crop Profile Image' : 'Crop Work Image',
              toolbarColor: AppTheme.darkColor,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
          ],
        );

        if (cropped != null) {
          final compressed = await ImageUtils.compressImage(File(cropped.path));
          if (mounted) {
            setState(() {
              if (isProfile) {
                _controller.profileImage = compressed;
              } else {
                _controller.workImages.add(compressed);
              }
            });
            _controller.notifyListeners();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final success = await _controller.saveProfile();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isUrdu ? 'پروفائل محفوظ ہوگیا' : 'Profile saved successfully'),
          backgroundColor: AppTheme.incomeColor,
        ),
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage ??
              (isUrdu
                  ? 'پروفائل محفوظ کرنے میں غلطی'
                  : 'Error saving profile')),
          backgroundColor: AppTheme.expenseColor,
        ),
      );
    }
  }

  void _showDeleteConfirmation(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUrdu ? 'پروفائل ختم کریں؟' : 'Delete Profile?',
          style: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی اپنا کاریگر پروفائل ختم کرنا چاہتے ہیں؟'
              : 'Are you sure you want to delete your artisan profile?',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isUrdu ? 'کینسل' : 'Cancel',
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
          AppButton(
            text: isUrdu ? 'ہاں، ڈیلیٹ کریں' : 'Yes, Delete',
            onPressed: () async {
              Navigator.pop(context);
              final success = await _controller.deleteProfile();
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isUrdu
                          ? 'پروفائل ختم کر دی گئی'
                          : 'Profile deleted successfully',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(context);
              }
            },
            color: Colors.red,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ProfileController>(
        builder: (context, controller, _) {
          return _buildScreen(context, controller);
        },
      ),
    );
  }

  Widget _buildScreen(BuildContext context, ProfileController controller) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: controller.isEditing
            ? (isUrdu ? 'پروفائل میں ترمیم' : 'Edit Profile')
            : (isUrdu ? 'نیا پروفائل' : 'New Profile'),
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
                    // Profile Image Section
                    _buildProfileImageSection(controller),

                    const SizedBox(height: 24),

                    // Personal Info Section
                    _buildPersonalInfoSection(controller, isUrdu, fontFamily),

                    const SizedBox(height: 20),

                    // Expert Info Section
                    _buildExpertInfoSection(
                      controller,
                      isUrdu,
                      fontFamily,
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    AppButton(
                      text: controller.isEditing
                          ? (isUrdu ? 'اپ ڈیٹ کریں' : 'Update Profile')
                          : (isUrdu ? 'پروفائل بنائیں' : 'Create Profile'),
                      color: AppTheme.darkColor,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.large,
                      isFullWidth: true,
                      isLoading:
                          controller.saveStatus == ProfileSaveStatus.loading,
                      onPressed: _saveProfile,
                    ),

                    if (controller.isEditing) ...[
                      const SizedBox(height: 16),
                      AppButton(
                        text: isUrdu
                            ? 'کاریگر پروفائل ختم کریں'
                            : 'Delete Artisan Profile',
                        icon: Icons.delete_forever,
                        color: Colors.red,
                        variant: AppButtonVariant.ghost,
                        isFullWidth: true,
                        onPressed: () =>
                            _showDeleteConfirmation(isUrdu, fontFamily),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImageSection(ProfileController controller) {
    return ImageSelectorField(
      isProfile: true,
      selectedFiles:
          controller.profileImage != null ? [controller.profileImage!] : [],
      remoteUrls: controller.remoteProfileImage != null &&
              controller.remoteProfileImage!.isNotEmpty
          ? [controller.remoteProfileImage!]
          : (controller.profileImage == null
              ? [_getAvatarForName(controller.nameController.text)]
              : []),
      onFilesChanged: (files) {
        controller.profileImage = files.isNotEmpty ? files.first : null;
        controller.notifyListeners();
      },
      onRemoteRemoved: (_) {
        controller.remoteProfileImage = null;
        controller.notifyListeners();
      },
    );
  }

  Widget _buildPersonalInfoSection(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
          _buildTextField(
            controller: controller.nameController,
            label: isUrdu ? 'مکمل نام' : 'Full Name',
            icon: PhosphorIcons.user(),
            fontFamily: fontFamily,
            isUrdu: isUrdu,
            borderless: true,
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),
          _buildTextField(
            controller: controller.phoneController,
            label: isUrdu ? 'فون نمبر' : 'Phone Number',
            icon: PhosphorIcons.phone(),
            fontFamily: '',
            isUrdu: isUrdu,
            isPhone: true,
            readOnly: true,
            borderless: true,
            hint: isUrdu ? 'لاگ ان نمبر' : 'Login phone',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),
          _buildTextField(
            controller: controller.emailController,
            label: isUrdu ? 'ای میل (اختیاری)' : 'Email Address (Opt)',
            icon: PhosphorIcons.envelope(),
            fontFamily: fontFamily,
            isUrdu: isUrdu,
            borderless: true,
            hint: 'example@mail.com',
            validator: (val) {
              if (val != null && val.isNotEmpty) {
                if (!val.contains('@') || !val.contains('.')) {
                  return isUrdu
                      ? 'درست ای میل درج کریں'
                      : 'Enter a valid email';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpertInfoSection(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
          _buildInvitationHeader(controller, isUrdu, fontFamily),
          if (controller.showExpertFields)
            Column(
              children: [
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // 1. تعارف (سب سے اوپر)
                _buildDynamicSection(
                  controllers: controller.descriptionControllers,
                  label: isUrdu
                      ? 'اپنے کام کی تفصیل (تعارف - لازمی)'
                      : 'Work Description (Intro - Required)',
                  hint: isUrdu
                      ? 'کم از کم 10 لائنیں لکھیں...'
                      : 'Min 10 lines required...',
                  icon: PhosphorIcons.note(),
                  style: controller.descriptionBulletStyle,
                  onStyleChanged: controller.setDescriptionStyle,
                  onAdd: controller.addDescriptionField,
                  onRemove: controller.removeDescriptionField,
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                ),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // 2. تعلیمی قابلیت
                _buildDynamicSection(
                  controllers: controller.qualificationControllers,
                  label: isUrdu
                      ? 'تعلیمی قابلیت (اختیاری)'
                      : 'Qualification (Optional)',
                  hint: isUrdu
                      ? 'مثلاً: میٹرک، ڈپلومہ...'
                      : 'e.g. Matric, Diploma...',
                  icon: PhosphorIcons.graduationCap(),
                  style: controller.qualificationBulletStyle,
                  onStyleChanged: controller.setQualificationStyle,
                  onAdd: controller.addQualificationField,
                  onRemove: controller.removeQualificationField,
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                ),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // 3. ایڈریس (لوکیشن)
                _buildLocationField(controller, isUrdu, fontFamily,
                    borderless: true),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // 4. ریٹ سیکشن
                _buildRateSection(controller, isUrdu, fontFamily),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // تجربہ (ریٹ کے بعد منطقی جگہ)
                _buildTextField(
                  controller: controller.experienceController,
                  label: isUrdu ? 'تجربہ (سال - اختیاری)' : 'Exp (Years - Opt)',
                  icon: PhosphorIcons.calendar(),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  isNumber: true,
                  borderless: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final years = int.tryParse(value);
                    if (years == null ||
                        !ArtisanValidators.isValidExperience(years)) {
                      return ArtisanValidators.getErrorMessage(
                        'experience',
                        isUrdu: isUrdu,
                      );
                    }
                    return null;
                  },
                ),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // 5. پروفیشن (پیشہ)
                _buildProfessionSelector(controller, isUrdu, fontFamily),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // 6. مہارتیں (Skills)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSkillsSection(controller, isUrdu, fontFamily),
                ),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDDDDD)),

                // 7. ویب سائٹ (آخر میں)
                _buildTextField(
                  controller: controller.websiteController,
                  label:
                      isUrdu ? 'ویب سائٹ (اختیاری)' : 'Website Address (Opt)',
                  icon: PhosphorIcons.globe(),
                  fontFamily: '',
                  isUrdu: isUrdu,
                  borderless: true,
                  hint: 'www.example.com',
                  validator: (val) => null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _getAvatarForName(String name) {
    if (name.isEmpty) return 'assets/avatars/avatar.svg';
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % 8;
    if (index == 0) return 'assets/avatars/avatar.svg';
    return 'assets/avatars/avatar ($index).svg';
  }

  Widget _buildSectionHeader(
    String title,
    String fontFamily,
    bool isUrdu, {
    double topPadding = 20,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.themeColor,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String fontFamily,
    required bool isUrdu,
    String? hint,
    bool isNumber = false,
    bool isPhone = false,
    int? maxLines = 1,
    Widget? suffixIcon,
    bool readOnly = false,
    bool borderless = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: isNumber
          ? TextInputType.number
          : (isPhone ? TextInputType.phone : TextInputType.text),
      style: TextStyle(
        fontFamily: isNumber ? '' : fontFamily,
        fontSize: 16,
        color: readOnly ? Colors.grey : AppTheme.darkColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: isUrdu ? fontFamily : '',
          color: Colors.grey[600],
          fontSize: 13,
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
        ),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: readOnly ? Colors.grey : AppTheme.themeColor,
        ),
        suffixIcon: suffixIcon,
        filled: !borderless,
        fillColor: borderless ? Colors.transparent : Colors.white,
        border: borderless
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
        enabledBorder: borderless
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
        focusedBorder: borderless
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.themeColor,
                  width: 1.5,
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.themeColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildInvitationHeader(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return InkWell(
      onTap: () {
        controller.showExpertFields = !controller.showExpertFields;
        controller.notifyListeners();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    controller.showExpertFields
                        ? PhosphorIcons.briefcase(PhosphorIconsStyle.fill)
                        : PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                    color: AppTheme.themeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUrdu
                        ? 'کیا آپ ایک ماہر کاریگر ہیں؟'
                        : 'Are you an Expert Artisan?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.themeColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                Switch(
                  value: controller.showExpertFields,
                  onChanged: (val) {
                    controller.showExpertFields = val;
                    controller.notifyListeners();
                  },
                  activeColor: AppTheme.themeColor,
                ),
              ],
            ),
            if (!controller.showExpertFields) ...[
              const SizedBox(height: 10),
              Text(
                isUrdu
                    ? 'اگر آپ بجلی، پلمبنگ، پینٹ یا کسی بھی ہنر کے ماہر ہیں، تو اسے آن کریں تاکہ گاہک آپ کو ڈھونڈ سکیں اور آپ کو کام مل سکے۔'
                    : 'If you are an expert in electricity, plumbing, painting or any skill, turn this on so customers can find you and you get work.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkColor.withOpacity(0.7),
                  fontFamily: fontFamily,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionSelector(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    final professions = ArtisanService.getProfessions();
    final currentProfession = professions.firstWhere(
      (p) => p['id'] == controller.selectedProfession,
      orElse: () => professions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Icon(PhosphorIcons.briefcase(),
                  size: 20, color: AppTheme.themeColor),
              const SizedBox(width: 12),
              Text(
                isUrdu ? 'آپ کا پیشہ (لازمی)' : 'Your Profession (Required)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildItemSquare(
                onTap: () =>
                    _showAllProfessionsPicker(controller, isUrdu, fontFamily),
                icon: currentProfession['icon'],
                label: isUrdu
                    ? currentProfession['name']
                    : currentProfession['id'],
                isSelected: true,
                fontFamily: fontFamily,
                isUrdu: isUrdu,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isUrdu
                      ? 'پیشہ تبدیل کرنے کے لیے کارڈ پر کلک کریں۔'
                      : 'Tap the card to change your profession.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemSquare({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required bool isSelected,
    required String fontFamily,
    required bool isUrdu,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 70,
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
                  color: isSelected ? AppTheme.themeColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.themeColor,
                size: 24,
              ),
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

  Widget _buildRateSection(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ریٹ کی رقم
        Expanded(
          flex: 2,
          child: _buildTextField(
            controller: controller.rateController,
            label: isUrdu ? 'اجرت / ریٹ' : 'Rate / Price',
            icon: PhosphorIcons.currencyCircleDollar(),
            fontFamily: fontFamily,
            isUrdu: isUrdu,
            isNumber: true,
            hint: '1000',
            borderless: true,
            validator: (val) => null,
          ),
        ),

        // درمیان کی لکیر
        Container(
          width: 1,
          height: 50,
          color: const Color(0xFFDDDDDD),
          margin: const EdgeInsets.symmetric(horizontal: 4),
        ),

        // ریٹ کے یونٹ کا سلائیڈر (اسی لائن میں)
        Expanded(
          flex: 3,
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: _buildRateUnitSlider(controller, isUrdu, fontFamily),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicSection({
    required List<TextEditingController> controllers,
    required String label,
    required String hint,
    required IconData icon,
    required String style,
    required Function(String) onStyleChanged,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required String fontFamily,
    required bool isUrdu,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.themeColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
        ...List.generate(controllers.length, (index) {
          return Dismissible(
            key: ObjectKey(controllers[index]),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onRemove(index),
            background: Container(
              color: Colors.red.shade50,
              alignment: isUrdu ? Alignment.centerLeft : Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildBulletIcon(style, index),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controllers[index],
                      maxLines: null,
                      style: TextStyle(fontFamily: fontFamily, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle:
                            TextStyle(fontSize: 14, color: Colors.grey[400]),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              InkWell(
                onTap: onAdd,
                child: Row(
                  children: [
                    Icon(PhosphorIcons.plusCircle(),
                        color: AppTheme.themeColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      isUrdu ? 'مزید شامل کریں' : 'Add more',
                      style: TextStyle(
                        color: AppTheme.themeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildMiniStyleSelector(style, onStyleChanged),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletIcon(String style, int index) {
    String label = "•";
    double size = 20;
    if (style == 'star')
      label = "★";
    else if (style == 'tick')
      label = "✓";
    else if (style == 'number') {
      label = "${index + 1}.";
      size = 14;
    }

    return SizedBox(
      width: 20,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: AppTheme.themeColor,
        ),
      ),
    );
  }

  Widget _buildMiniStyleSelector(
      String currentStyle, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniToggle('dot', currentStyle == 'dot', Icons.circle,
              () => onChanged('dot')),
          _buildMiniToggle('number', currentStyle == 'number', null,
              () => onChanged('number'),
              text: "1."),
          _buildMiniToggle('star', currentStyle == 'star', Icons.star_rounded,
              () => onChanged('star')),
          _buildMiniToggle('tick', currentStyle == 'tick', Icons.check_rounded,
              () => onChanged('tick')),
        ],
      ),
    );
  }

  Widget _buildMiniToggle(
      String id, bool isSelected, IconData? icon, VoidCallback onTap,
      {String? text}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [const BoxShadow(color: Colors.black12, blurRadius: 2)]
              : null,
        ),
        child: icon != null
            ? Icon(icon,
                size: 14, color: isSelected ? AppTheme.themeColor : Colors.grey)
            : Text(text!,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.themeColor : Colors.grey)),
      ),
    );
  }

  Widget _buildRateUnitSlider(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    final units = [
      {'id': 'fixed', 'en': 'Total', 'ur': 'کل رقم'},
      {'id': 'hour', 'en': 'Per Hr', 'ur': 'فی گھنٹہ'},
      {'id': 'day', 'en': 'Per Day', 'ur': 'فی دیہاڑی'},
      {'id': 'month', 'en': 'Per Mo', 'ur': 'فی مہینہ'},
      {'id': 'contract', 'en': 'Contract', 'ur': 'ٹھیکہ'},
      {'id': 'item', 'en': 'Per Item', 'ur': 'فی آئٹم'},
      {'id': 'sqft', 'en': 'Per Sqft', 'ur': 'فی مربع فٹ'},
      {'id': 'visit', 'en': 'Per Visit', 'ur': 'فی وزٹ'},
      {'id': 'km', 'en': 'Per KM', 'ur': 'فی کلومیٹر'},
      {'id': 'kg', 'en': 'Per KG', 'ur': 'فی کلو'},
    ];

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: units.map((unit) {
            final isSelected = controller.rateUnit == unit['id'];
            return _buildMiniToggle(
              unit['id']!,
              isSelected,
              null,
              () {
                controller.rateUnit = unit['id']!;
                controller.notifyListeners();
              },
              text: isUrdu ? unit['ur']! : unit['en']!,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSkillsSection(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isUrdu ? 'تکنیکی مہارتیں (Skills)' : 'Technical Skills',
          fontFamily,
          isUrdu,
          topPadding: 0,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: controller.skillInputController,
                label: isUrdu ? 'مہارت لکھیں' : 'Add a skill',
                icon: PhosphorIcons.hammer(),
                fontFamily: fontFamily,
                isUrdu: isUrdu,
                validator: (_) => null,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () => controller.addSkill(),
              icon: Icon(PhosphorIcons.plus()),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.themeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        if (controller.customSkills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.customSkills.map((skill) {
              return Chip(
                label: Text(
                  skill,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 12,
                    color: AppTheme.themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppTheme.themeColor.withOpacity(0.1),
                side: BorderSide(color: AppTheme.themeColor.withOpacity(0.3)),
                deleteIcon: Icon(
                  PhosphorIcons.xCircle(),
                  size: 16,
                  color: Colors.red,
                ),
                onDeleted: () => controller.removeSkill(skill),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationField(
    ProfileController controller,
    bool isUrdu,
    String fontFamily, {
    bool borderless = false,
  }) {
    return RawAutocomplete<Map<String, dynamic>>(
      key: const ValueKey('location_autocomplete'),
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (!mounted) return const Iterable<Map<String, dynamic>>.empty();
        if (textEditingValue.text.length < 3) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        try {
          return await controller.searchLocations(textEditingValue.text);
        } catch (e) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
      },
      displayStringForOption: (option) => option['display_name'] ?? "",
      onSelected: (option) {
        controller.locationController.text = option['display_name'];
        controller.jobLatitude = option['lat'];
        controller.jobLongitude = option['lon'];
        controller.notifyListeners();
      },
      fieldViewBuilder:
          (context, textController, focusNode, onEditingComplete) {
        if (textController.text.isEmpty &&
            controller.locationController.text.isNotEmpty) {
          textController.text = controller.locationController.text;
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
            labelText: isUrdu ? 'شہر / علاقہ (اختیاری)' : 'City / Area (Opt)',
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
            fillColor:
                borderless ? Colors.transparent : const Color(0xFFF5F7F9),
            filled: !borderless,
            border: borderless
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
            enabledBorder: borderless
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
            focusedBorder: borderless
                ? InputBorder.none
                : OutlineInputBorder(
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
                await controller.getCurrentLocation();
                textController.text = controller.locationController.text;
              },
            ),
          ),
          onChanged: controller.onLocationChanged,
          validator: (value) => null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (!mounted) return const SizedBox.shrink();
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

  void _showAllProfessionsPicker(
    ProfileController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    final professions = ArtisanService.getProfessions();

    final Map<String, List<Map<String, dynamic>>> groupedProfessions = {};
    for (var p in professions) {
      final cat = isUrdu ? p['categoryUrdu'] : p['category'];
      if (!groupedProfessions.containsKey(cat)) {
        groupedProfessions[cat] = [];
      }
      groupedProfessions[cat]!.add(p);
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
                      isUrdu ? 'پیشہ منتخب کریں' : 'Select Profession',
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
                  itemCount: groupedProfessions.keys.length,
                  itemBuilder: (context, index) {
                    final category = groupedProfessions.keys.elementAt(index);
                    final categoryItems = groupedProfessions[category]!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.darkColor.withOpacity(0.05)),
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
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.themeColor,
                              fontFamily: fontFamily,
                            ),
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
                            itemCount: categoryItems.length,
                            itemBuilder: (context, idx) {
                              final p = categoryItems[idx];
                              final isSelected =
                                  controller.selectedProfession == p['id'];
                              return InkWell(
                                onTap: () {
                                  controller.selectedProfession = p['id']!;
                                  controller.notifyListeners();
                                  Navigator.pop(context);
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.themeColor
                                            : AppTheme.backgroundColor
                                                .withOpacity(0.5),
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
    );
  }
}
