// lib/features/shopkeeper/widgets/currency_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/models/app_settings_model.dart';
import 'package:account_app/core/services/settings_service.dart';
import 'package:account_app/core/services/language_service.dart';

class CurrencySettingsDialog extends StatefulWidget {
  final bool isUrdu;
  final String fontFamily;

  const CurrencySettingsDialog({
    super.key,
    required this.isUrdu,
    required this.fontFamily,
  });

  static void show(BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => CurrencySettingsDialog(
        isUrdu: isUrdu,
        fontFamily: fontFamily,
      ),
    );
  }

  @override
  State<CurrencySettingsDialog> createState() => _CurrencySettingsDialogState();
}

class _CurrencySettingsDialogState extends State<CurrencySettingsDialog> {
  late AppSettings _tempSettings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settingsService =
    Provider.of<SettingsService>(context, listen: false);
    _tempSettings = settingsService.settings;
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final settingsService =
      Provider.of<SettingsService>(context, listen: false);
      await settingsService.updateSettings(_tempSettings);
      Formatters.updateSettings(_tempSettings);

      if (mounted) {
        AppToast.success(
          context,
          widget.isUrdu ? 'سیٹنگز محفوظ ہو گئیں' : 'Settings saved',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.isUrdu;
    final fontFamily = widget.fontFamily;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ Header ═══
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIcons.globeHemisphereWest(),
                          color: AppTheme.themeColor, size: 20),
                      const SizedBox(width: 8),
                      UrduAwareText(
                        isUrdu ? 'زبان اور کرنسی' : 'Language & Currency',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // ═══ 1. زبان ═══
              _buildLanguageSection(isUrdu, fontFamily),
              const SizedBox(height: 16),

              // ═══ 2. کرنسی ═══
              _buildCurrencySection(isUrdu, fontFamily),
              const SizedBox(height: 16),

              // ═══ 3. لائیو پریویو ═══
              _buildLivePreview(isUrdu, fontFamily),
              const SizedBox(height: 20),

              // ═══ Actions ═══
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: isUrdu ? 'منسوخ' : 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      size: AppButtonSize.small,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      text: isUrdu ? 'محفوظ کریں' : 'Save',
                      onPressed: _saveSettings,
                      isLoading: _isSaving,
                      size: AppButtonSize.small,
                      color: AppTheme.darkColor,
                      icon: PhosphorIcons.floppyDisk(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 1. LANGUAGE SECTION — فوری تبدیلی
  // ═══════════════════════════════════════════════════════════
  Widget _buildLanguageSection(bool isUrdu, String fontFamily) {
    final languageService = Provider.of<LanguageService>(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.translate(),
                  size: 14, color: AppTheme.themeColor),
              const SizedBox(width: 6),
              UrduAwareText(
                isUrdu ? 'زبان منتخب کریں' : 'Select Language',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildLanguageOption(
                  label: 'اردو',
                  flag: '🇵🇰',
                  isActive: languageService.isUrdu,
                  fontFamily: fontFamily,
                  onTap: () {
                    languageService.changeLanguage('ur');
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLanguageOption(
                  label: 'English',
                  flag: '🇬🇧',
                  isActive: !languageService.isUrdu,
                  fontFamily: fontFamily,
                  onTap: () {
                    languageService.changeLanguage('en');
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String label,
    required String flag,
    required bool isActive,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.themeColor.withValues(alpha: 0.12)
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppTheme.themeColor
                : AppTheme.backgroundColor,
            width: isActive ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            UrduAwareText(
              label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                color: isActive ? AppTheme.themeColor : AppTheme.darkColor,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded,
                  size: 16, color: AppTheme.themeColor),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. CURRENCY SECTION — صرف dropdown
  // ═══════════════════════════════════════════════════════════
  Widget _buildCurrencySection(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.currencyCircleDollar(),
                  size: 14, color: AppTheme.themeColor),
              const SizedBox(width: 6),
              UrduAwareText(
                isUrdu ? 'کرنسی منتخب کریں' : 'Select Currency',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showCurrencyPickerDialog(isUrdu, fontFamily),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: AppTheme.backgroundColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _tempSettings.currencySymbol,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.themeColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUrdu
                              ? (CurrencyOptions.list.firstWhere(
                                (c) =>
                            c['code'] ==
                                _tempSettings.currencyCode,
                            orElse: () => CurrencyOptions.list[0],
                          )['nameUrdu'] ??
                              _tempSettings.currencyCode)
                              : (CurrencyOptions.list.firstWhere(
                                (c) =>
                            c['code'] ==
                                _tempSettings.currencyCode,
                            orElse: () => CurrencyOptions.list[0],
                          )['name'] ??
                              _tempSettings.currencyCode),
                          style: TextStyle(
                            fontFamily: isUrdu ? fontFamily : null,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_tempSettings.currencyCode} · ${_tempSettings.currencySymbol}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 3. LIVE PREVIEW
  // ═══════════════════════════════════════════════════════════
  Widget _buildLivePreview(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.eye(),
                  size: 14, color: AppTheme.themeColor),
              const SizedBox(width: 6),
              UrduAwareText(
                isUrdu ? 'لائیو پریویو' : 'Live Preview',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPreviewRow(
            label: isUrdu ? 'چھوٹی رقم' : 'Small amount',
            value: Formatters.formatAmountWithCurrency(123),
            fontFamily: fontFamily,
          ),
          const SizedBox(height: 10),
          _buildPreviewRow(
            label: isUrdu ? 'درمیانی رقم' : 'Medium amount',
            value: Formatters.formatAmountWithCurrency(45678),
            fontFamily: fontFamily,
          ),
          const SizedBox(height: 10),
          _buildPreviewRow(
            label: isUrdu ? 'بڑی رقم' : 'Large amount',
            value: Formatters.formatAmountWithCurrency(1234567),
            fontFamily: fontFamily,
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow({
    required String label,
    required String value,
    required String fontFamily,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        UrduAwareText(
          value,
          style: TextStyle(
            fontFamily: null,
            fontSize: isHighlight ? 15 : 13,
            fontWeight: FontWeight.w900,
            color: isHighlight ? AppTheme.themeColor : AppTheme.darkColor,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Currency Picker (nested dialog)
  // ═══════════════════════════════════════════════════════════
  void _showCurrencyPickerDialog(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(PhosphorIcons.coins(),
                      color: AppTheme.themeColor, size: 20),
                  const SizedBox(width: 8),
                  UrduAwareText(
                    isUrdu ? 'کرنسی منتخب کریں' : 'Select Currency',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: CurrencyOptions.list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final currency = CurrencyOptions.list[index];
                  final isSelected =
                      currency['code'] == _tempSettings.currencyCode;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _tempSettings = _tempSettings.copyWith(
                          currencyCode: currency['code']!,
                          currencySymbol: currency['symbol']!,
                        );
                      });
                      Navigator.pop(dialogCtx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.themeColor.withValues(alpha: 0.08)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.themeColor
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.themeColor
                                  : AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                currency['symbol']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.darkColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isUrdu
                                      ? currency['nameUrdu']!
                                      : currency['name']!,
                                  style: TextStyle(
                                    fontFamily: isUrdu ? fontFamily : null,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkColor,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${currency['code']} · ${currency['symbol']}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.themeColor,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
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