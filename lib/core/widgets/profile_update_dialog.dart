import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';

class ProfileUpdateDialog extends StatefulWidget {
  final Account party;
  final Map<String, String> remoteProfile;
  final VoidCallback? onUpdated;

  const ProfileUpdateDialog({
    super.key,
    required this.party,
    required this.remoteProfile,
    this.onUpdated,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Account party,
    required Map<String, String> remoteProfile,
    VoidCallback? onUpdated,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ProfileUpdateDialog(
        party: party,
        remoteProfile: remoteProfile,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<ProfileUpdateDialog> createState() => _ProfileUpdateDialogState();
}

class _ProfileUpdateDialogState extends State<ProfileUpdateDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    final remoteName = widget.remoteProfile['name']?.trim() ?? '';
    final localName = widget.party.name.trim();
    final bool isNameDifferent = remoteName.isNotEmpty && remoteName != localName;

    final remotePhoto = widget.remoteProfile['photoUrl']?.trim() ?? '';
    final localPhoto = (widget.party.profileImage ?? '').trim();
    final bool isPhotoDifferent = remotePhoto.isNotEmpty && remotePhoto != localPhoto;

    final remoteProf = widget.remoteProfile['profession']?.trim() ?? '';
    final localProf = (widget.party.category).trim();
    final bool isProfDifferent = remoteProf.isNotEmpty && remoteProf != localProf;

    final remoteAddress = widget.remoteProfile['address']?.trim() ?? '';
    final localAddress = (widget.party.address ?? '').trim();
    final bool isAddressDifferent = remoteAddress.isNotEmpty && remoteAddress != localAddress;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              PhosphorIcons.userSwitch(),
              color: AppTheme.themeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: UrduAwareText(
              isUrdu ? 'پروفائل اپڈیٹ دستیاب ہے' : 'Profile Update Available',
              style: TextStyle(
                fontSize: isUrdu ? 18 : 16,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
                color: AppTheme.darkColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu
                  ? 'آن لائن نئی معلومات دستیاب ہیں۔ کیا آپ معلومات کو اپڈیٹ کرنا چاہتے ہیں؟'
                  : 'New information is available online. Would you like to update party profile?',
              style: TextStyle(
                fontSize: 13,
                fontFamily: fontFamily,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Comparison Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Profile Photo Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          UrduAwareText(
                            isUrdu ? 'موجودہ' : 'Current',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: fontFamily,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ProfileInfoWidget(
                            name: localName,
                            phone: widget.party.phone,
                            profileImage: widget.party.profileImage,
                            showText: false,
                            customSize: 44,
                            borderRadius: 8,
                          ),
                        ],
                      ),
                      Icon(PhosphorIcons.arrowRight(), color: AppTheme.themeColor, size: 20),
                      Column(
                        children: [
                          UrduAwareText(
                            isUrdu ? 'جدید' : 'Updated',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: fontFamily,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ProfileInfoWidget(
                            name: remoteName.isNotEmpty ? remoteName : localName,
                            phone: widget.party.phone,
                            profileImage: remotePhoto.isNotEmpty ? remotePhoto : widget.party.profileImage,
                            showText: false,
                            customSize: 44,
                            borderRadius: 8,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 0.5),

                  // Name Field Comparison
                  _buildComparisonRow(
                    label: isUrdu ? 'نام' : 'Name',
                    icon: PhosphorIcons.user(),
                    currentVal: localName.isNotEmpty ? localName : (isUrdu ? 'نامعلوم' : 'Unknown'),
                    newVal: remoteName,
                    isChanged: isNameDifferent,
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    isHighlight: isNameDifferent,
                  ),

                  // Category / Profession Comparison
                  if (remoteProf.isNotEmpty)
                    _buildComparisonRow(
                      label: isUrdu ? 'زمرہ / کاروبار' : 'Category / Profession',
                      icon: PhosphorIcons.briefcase(),
                      currentVal: localProf.isNotEmpty ? localProf : (isUrdu ? 'عام' : 'General'),
                      newVal: remoteProf,
                      isChanged: isProfDifferent,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      isHighlight: isProfDifferent,
                    ),

                  // Address Comparison (Highlighted!)
                  _buildComparisonRow(
                    label: isUrdu ? 'پتہ (Address)' : 'Address',
                    icon: PhosphorIcons.mapPin(),
                    currentVal: localAddress.isNotEmpty ? localAddress : (isUrdu ? 'درج نہیں ہے' : 'Not set'),
                    newVal: remoteAddress,
                    isChanged: isAddressDifferent,
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    isHighlight: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: UrduAwareText(
            isUrdu ? 'منسوخ' : 'Cancel',
            style: TextStyle(
              fontFamily: fontFamily,
              color: AppTheme.textSecondary,
              fontWeight: fontWeight,
            ),
          ),
        ),
        AppButton(
          text: isUrdu ? 'پروفائل اپڈیٹ کریں' : 'Update Profile',
          icon: PhosphorIcons.checkCircle(),
          isLoading: _isLoading,
          color: Colors.green,
          onPressed: () => _applyUpdate(
            context,
            isNameDifferent: isNameDifferent,
            remoteName: remoteName,
            isPhotoDifferent: isPhotoDifferent,
            remotePhoto: remotePhoto,
            isProfDifferent: isProfDifferent,
            remoteProf: remoteProf,
            isAddressDifferent: isAddressDifferent,
            remoteAddress: remoteAddress,
            isUrdu: isUrdu,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required IconData icon,
    required String currentVal,
    required String newVal,
    required bool isChanged,
    required bool isUrdu,
    required String fontFamily,
    bool isHighlight = false,
  }) {
    final effectiveNew = newVal.isNotEmpty ? newVal : currentVal;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: isHighlight ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: isHighlight
          ? BoxDecoration(
              color: isChanged ? Colors.green.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isChanged ? Colors.green.withValues(alpha: 0.3) : Colors.grey.shade300,
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isChanged ? Colors.green : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UrduAwareText(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: fontFamily,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isChanged) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: UrduAwareText(
                          isUrdu ? 'نیا اپڈیٹ' : 'New Update',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (isChanged) ...[
                  if (currentVal.isNotEmpty)
                    UrduAwareText(
                      currentVal,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: fontFamily,
                        color: Colors.red.shade400,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  const SizedBox(height: 2),
                  UrduAwareText(
                    effectiveNew,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: fontFamily,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  UrduAwareText(
                    currentVal.isNotEmpty ? currentVal : (newVal.isNotEmpty ? newVal : (isUrdu ? 'درج نہیں ہے' : 'Not specified')),
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyUpdate(
    BuildContext context, {
    required bool isNameDifferent,
    required String remoteName,
    required bool isPhotoDifferent,
    required String remotePhoto,
    required bool isProfDifferent,
    required String remoteProf,
    required bool isAddressDifferent,
    required String remoteAddress,
    required bool isUrdu,
  }) async {
    setState(() => _isLoading = true);

    try {
      final updatedParty = widget.party.copyWith(
        name: isNameDifferent ? remoteName : widget.party.name,
        profileImage: isPhotoDifferent ? remotePhoto : widget.party.profileImage,
        category: isProfDifferent ? remoteProf : widget.party.category,
        address: isAddressDifferent ? remoteAddress : widget.party.address,
        updatedAt: DateTime.now(),
      );

      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.updateAccount(updatedParty);

      if (mounted) {
        AppToast.success(
          context,
          isUrdu ? 'پارٹی معلومات کامیابی سے اپڈیٹ ہو گئیں' : 'Party profile updated successfully',
        );
        Navigator.pop(context, true);
        if (widget.onUpdated != null) widget.onUpdated!();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'اپڈیٹ کرنے میں ناکامی: $e' : 'Failed to update profile: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
