import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/features/dashboard/app_shell_screen.dart';
import 'package:account_app/features/profile/controllers/profile_controller.dart';

class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  late final ProfileController _controller;
  final _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocusNode = FocusNode();
  bool _isSavingProfile = false;
  String? _saveLoadingText;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController()..loadExistingProfile();
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        final text = _controller.emailController.text;
        _controller.emailController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;
    if (!_formKey.currentState!.validate()) return;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    setState(() {
      _isSavingProfile = true;
      _saveLoadingText =
          isUrdu ? 'پروفائل محفوظ ہو رہا ہے...' : 'Saving profile...';
    });

    try {
      final success = await _controller.saveProfile();
      if (!mounted) return;

      if (!success) {
        AppToast.error(
          context,
          _controller.errorMessage ??
              (isUrdu ? 'پروفائل محفوظ نہیں ہو سکا' : 'Unable to save profile'),
        );
        return;
      }

      if (!mounted) return;
      AppToast.success(
        context,
        isUrdu
            ? 'پروفائل کامیابی سے محفوظ ہو گیا'
            : 'Profile saved successfully',
      );
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AppShellScreen(key: AppShellScreen.navigationKey),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        isUrdu
            ? 'پروفائل محفوظ کرنے میں مسئلہ پیش آیا: $error'
            : 'Could not complete profile save: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
          _saveLoadingText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    _controller.nameController.isUrdu = isUrdu;
    _controller.phoneController.isUrdu = isUrdu;
    _controller.emailController.isUrdu = isUrdu;
    _controller.addressController.isUrdu = isUrdu;
    _controller.shopNameController.isUrdu = isUrdu;
    _controller.professionController.isUrdu = isUrdu;
    _controller.aboutController.isUrdu = isUrdu;

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ProfileController>(
        builder: (context, controller, _) => Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: ScreenAppBar(
            title: isUrdu ? 'پروفائل' : 'Profile',
            isUrdu: isUrdu,
          ),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Avatar
                        Center(
                          child: ImageSelectorField(
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
                        ),
                        const SizedBox(height: 8),

                        // Fields Container
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFD1D5DB), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.darkColor.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildField(
                                controller: controller.nameController,
                                label: isUrdu ? 'مکمل نام *' : 'Full Name *',
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
                                controller: controller.professionController,
                                label: isUrdu ? 'شعبہ / پیشہ' : 'Profession',
                                icon: PhosphorIcons.briefcase(),
                                fontFamily: fontFamily,
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
                                focusNode: _emailFocusNode,
                                onTap: () {
                                  final text = controller.emailController.text;
                                  controller.emailController.selection =
                                      TextSelection(
                                    baseOffset: 0,
                                    extentOffset: text.length,
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              _buildField(
                                controller: controller.shopNameController,
                                label: isUrdu
                                    ? 'کمپنی / شاپ کا نام (اختیاری)'
                                    : 'Company / Shop Name (Optional)',
                                icon: PhosphorIcons.storefront(),
                                fontFamily: fontFamily,
                              ),
                              const Divider(height: 1),
                              _buildField(
                                controller: controller.addressController,
                                label: isUrdu
                                    ? 'دکان کا پتہ (اختیاری)'
                                    : 'Shop Address (Optional)',
                                icon: PhosphorIcons.mapPin(),
                                fontFamily: fontFamily,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                        AppButton(
                          text: controller.isEditing
                              ? (isUrdu ? 'محفوظ کریں' : 'Save Profile')
                              : (isUrdu ? 'پروفائل بنائیں' : 'Create Profile'),
                          color: AppTheme.darkColor,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.large,
                          isFullWidth: true,
                          isLoading: _isSavingProfile,
                          loadingText: _saveLoadingText,
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
    FocusNode? focusNode,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      focusNode: focusNode,
      onTap: onTap,
      validator: validator,
      maxLines: maxLines,
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
