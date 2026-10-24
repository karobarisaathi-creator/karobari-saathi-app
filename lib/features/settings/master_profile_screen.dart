import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/features/dashboard/app_shell_screen.dart';
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
    final stockService = Provider.of<StockService>(context, listen: false);
    final success = await _controller.saveProfile();
    if (!mounted) return;

    if (success) {
      String? catalogError;
      if (_controller.isShopkeeper) {
        try {
          await stockService.syncPublicCatalog();
        } catch (error) {
          catalogError = error.toString();
        }
      }
      if (!mounted) return;
      if (catalogError != null) {
        AppToast.error(
          context,
          isUrdu
              ? 'پروفائل محفوظ ہوگیا، مگر دکان کے آئٹمز شائع نہیں ہوسکے: $catalogError'
              : 'Profile saved, but shop items could not be published: $catalogError',
        );
        return;
      }
      AppToast.success(
        context,
        isUrdu
            ? 'پروفائل کامیابی سے محفوظ ہو گیا'
            : 'Profile saved successfully',
      );
      await AppShellScreen.refreshRole();
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
    _controller.nameController.isUrdu = isUrdu;
    _controller.phoneController.isUrdu = isUrdu;
    _controller.emailController.isUrdu = isUrdu;
    _controller.addressController.isUrdu = isUrdu;
    _controller.shopNameController.isUrdu = isUrdu;

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ProfileController>(
        builder: (context, controller, _) => Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: CustomAppBar(
            title: controller.isEditing
                ? (isUrdu ? 'پروفائل کی ترتیبات' : 'Profile Settings')
                : (isUrdu ? 'نیا پروفائل' : 'New Profile'),
          ),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
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
                        const SizedBox(height: 16),

                        // Shop Banner Image
                        ImageSelectorField(
                          label: isUrdu
                              ? 'دکان کا بینر (تصویر)'
                              : 'Shop Banner Image',
                          isFullWidth: true,
                          aspectRatio: 16 / 6,
                          selectedFiles: controller.bannerImage == null
                              ? []
                              : [controller.bannerImage!],
                          remoteUrls: controller.remoteBannerImage == null
                              ? []
                              : [controller.remoteBannerImage!],
                          maxTotal: 1,
                          onFilesChanged: (files) {
                            controller.bannerImage =
                                files.isEmpty ? null : files.first;
                            controller.notifyListeners();
                          },
                          onRemoteRemoved: (_) {
                            controller.remoteBannerImage = null;
                            controller.notifyListeners();
                          },
                        ),
                        const SizedBox(height: 16),

                        // Detailed Shop Note
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  AppTheme.themeColor.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  PhosphorIcons.storefront(),
                                  size: 20,
                                  color: AppTheme.themeColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: UrduAwareText(
                                  isUrdu
                                      ? '🏪 دکان رجسٹر کرنے کی تفصیل:\nاگر آپ "دکان کا نام" اور "دکان کا پتہ" دونوں درج کریں گے، تو آپ کی دکان "قریبی دکاندار" کی فہرست میں شامل ہو جائے گی اور علاقے کے تمام گاہک آپ کا اسٹاک، سامان اور کیٹلاگ لائیو دیکھ سکیں گے۔'
                                      : '🏪 Shop Registration Details:\nBy entering both Shop Name and Address, your shop will be listed under "Nearby Shops". Local customers will be able to browse your live stock, items, and catalog.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkColor,
                                    fontFamily: fontFamily,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

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
                              ),
                              const Divider(height: 1),
                              _buildField(
                                controller: controller.shopNameController,
                                label: isUrdu
                                    ? 'دکان کا نام (اختیاری)'
                                    : 'Shop Name (Optional)',
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

                        if (controller.isShopkeeper) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ShopkeeperDashboardScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.themeColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.themeColor
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.themeColor,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        UrduAwareText(
                                          isUrdu
                                              ? 'شاپ کیپر ڈیش بورڈ کھولیں'
                                              : 'Open Shopkeeper Dashboard',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.darkColor,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                        UrduAwareText(
                                          isUrdu
                                              ? 'سٹاک اور پروڈکٹس کا حساب کتاب'
                                              : 'Manage stock & products',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: AppTheme.textSecondary,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppTheme.themeColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),
                        AppButton(
                          text: controller.isEditing
                              ? (isUrdu ? 'محفوظ کریں' : 'Save Profile')
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
