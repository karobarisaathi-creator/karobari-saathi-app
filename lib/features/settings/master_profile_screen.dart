import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/config/app_roles.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'package:account_app/features/profile/controllers/profile_controller.dart';
import 'package:account_app/features/shopkeeper/shopkeeper_dashboard_screen.dart';

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
      await MainNavigationScreen.refreshRole();
      if (!mounted) return;
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 20),

                        // ═══ ROLE SELECTION ═══
                        Text(
                          isUrdu ? 'پروفائل کی قسم منتخب کریں' : 'Select Profile Mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRoleCard(
                                role: AppRole.simple,
                                controller: controller,
                                isUrdu: isUrdu,
                                fontFamily: fontFamily,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRoleCard(
                                role: AppRole.shopkeeper,
                                controller: controller,
                                isUrdu: isUrdu,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ═══ FIELDS ═══
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
                              if (controller.selectedRole == AppRole.shopkeeper) ...[
                                const Divider(height: 1),
                                _buildField(
                                  controller: controller.shopNameController,
                                  label: isUrdu
                                      ? 'دکان / اسٹور کا نام'
                                      : 'Shop / Store Name',
                                  icon: PhosphorIcons.storefront(),
                                  fontFamily: fontFamily,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? (isUrdu
                                              ? 'دکان کا نام درج کریں'
                                              : 'Enter shop name')
                                          : null,
                                ),
                              ],
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

                        if (controller.selectedRole == AppRole.shopkeeper) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ShopkeeperDashboardScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D6ED6).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1D6ED6).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D6ED6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.storefront_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isUrdu
                                              ? 'شاپ کیپر ڈیش بورڈ کھولیں'
                                              : 'Open Shopkeeper Dashboard',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF123248),
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                        Text(
                                          isUrdu
                                              ? 'فوری آرڈرز، بکی اور پروڈکٹس کا خلاصہ'
                                              : 'Quick orders, sales & products overview',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.grey[700],
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF1D6ED6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

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

  Widget _buildRoleCard({
    required AppRole role,
    required ProfileController controller,
    required bool isUrdu,
    required String fontFamily,
  }) {
    final isSelected = controller.selectedRole == role;
    return GestureDetector(
      onTap: () => controller.setRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.themeColor.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.themeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              role.icon,
              size: 28,
              color: isSelected ? AppTheme.themeColor : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              role.label(isUrdu),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppTheme.themeColor : AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              role.subtitle(isUrdu),
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? AppTheme.themeColor : Colors.grey[600],
                fontFamily: fontFamily,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
