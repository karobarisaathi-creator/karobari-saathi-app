import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'package:account_app/features/profile/controllers/profile_controller.dart';

class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  late final ProfileController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = ProfileController()..loadExistingProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final success = await _controller.saveProfile();
    if (!mounted) return;

    if (success) {
      AppToast.success(
          context, isUrdu ? 'پروفائل محفوظ ہوگیا' : 'Profile saved');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } else {
      AppToast.error(
        context,
        _controller.errorMessage ??
            (isUrdu ? 'پروفائل محفوظ نہیں ہو سکا' : 'Unable to save profile'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ProfileController>(
        builder: (context, controller, _) => Scaffold(
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
                      children: [
                        ImageSelectorField(
                          isProfile: true,
                          selectedFiles: controller.profileImage == null
                              ? []
                              : [controller.profileImage!],
                          remoteUrls: controller.remoteProfileImage == null
                              ? []
                              : [controller.remoteProfileImage!],
                          maxTotal: 1,
                          onFilesChanged: (files) {
                            controller.profileImage =
                                files.isEmpty ? null : files.first;
                            controller.notifyListeners();
                          },
                          onRemoteRemoved: (_) {
                            controller.remoteProfileImage = null;
                            controller.notifyListeners();
                          },
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildField(
                                controller: controller.nameController,
                                label: isUrdu ? 'مکمل نام' : 'Full Name',
                                icon: PhosphorIcons.user(),
                                fontFamily: fontFamily,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? (isUrdu
                                            ? 'نام درج کریں'
                                            : 'Enter your name')
                                        : null,
                              ),
                              const Divider(height: 1),
                              _buildField(
                                controller: controller.phoneController,
                                label: isUrdu ? 'فون نمبر' : 'Phone Number',
                                icon: PhosphorIcons.phone(),
                                readOnly: true,
                              ),
                              const Divider(height: 1),
                              _buildField(
                                controller: controller.emailController,
                                label: isUrdu
                                    ? 'ای میل (اختیاری)'
                                    : 'Email Address (Optional)',
                                icon: PhosphorIcons.envelope(),
                                fontFamily: fontFamily,
                                validator: (value) {
                                  if (value != null &&
                                      value.isNotEmpty &&
                                      (!value.contains('@') ||
                                          !value.contains('.'))) {
                                    return isUrdu
                                        ? 'درست ای میل درج کریں'
                                        : 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const Divider(height: 1),
                              _buildField(
                                controller: controller.addressController,
                                label: isUrdu
                                    ? 'دکان / کاروبار کا پتہ (اختیاری)'
                                    : 'Shop / business address (optional)',
                                icon: PhosphorIcons.mapPin(),
                                fontFamily: fontFamily,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        AppButton(
                          text: controller.isEditing
                              ? (isUrdu ? 'اپ ڈیٹ کریں' : 'Update Profile')
                              : (isUrdu ? 'پروفائل بنائیں' : 'Create Profile'),
                          color: AppTheme.darkColor,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.large,
                          isFullWidth: true,
                          isLoading: controller.saveStatus ==
                              ProfileSaveStatus.loading,
                          onPressed: _saveProfile,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String fontFamily = '',
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator,
      style: TextStyle(color: readOnly ? Colors.grey : AppTheme.darkColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: fontFamily),
        prefixIcon: Icon(icon, color: AppTheme.themeColor),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
