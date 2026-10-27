import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/settings/app_lock_screen.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final isEnabled = await context.read<SecurityService>().isAppLockEnabled();
    if (!mounted) return;
    setState(() {
      _isEnabled = isEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleAppLock(bool enabled, bool isUrdu) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      if (enabled) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const AppLockScreen(isSettingUp: true),
          ),
        );
        if (!mounted) return;
        if (result == true) {
          setState(() => _isEnabled = true);
          AppToast.success(
            context,
            isUrdu ? 'ایپ لاک فعال ہو گیا' : 'App Lock enabled',
          );
        }
      } else {
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const AppLockScreen(isVerifyingOnly: true),
          ),
        );
        if (!mounted) return;
        if (verified == true) {
          await context.read<SecurityService>().setAppLockEnabled(false);
          if (!mounted) return;
          setState(() => _isEnabled = false);
          AppToast.success(
            context,
            isUrdu ? 'ایپ لاک بند ہو گیا' : 'App Lock disabled',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'سیکیورٹی سیٹنگ تبدیل نہیں ہو سکی: $error'
              : 'Could not update security settings: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _changePin(bool isUrdu) async {
    if (!_isEnabled || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(isChangingPin: true),
        ),
      );
      if (mounted && result == true) {
        AppToast.success(
          context,
          isUrdu ? 'پن کوڈ تبدیل ہو گیا' : 'PIN changed successfully',
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'پن کوڈ تبدیل نہیں ہو سکا: $error'
              : 'Could not change PIN: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.watch<LanguageService>().isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FC),
        foregroundColor: const Color(0xFF14263D),
        elevation: 0,
        title: UrduAwareText(
          isUrdu ? 'سیکیورٹی' : 'Security',
          style: TextStyle(fontWeight: FontWeight.w700, fontFamily: fontFamily),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF142B49), Color(0xFF1D6ED6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.themeColor.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _isEnabled
                              ? PhosphorIcons.shieldCheck()
                              : PhosphorIcons.shield(),
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      const SizedBox(height: 22),
                      UrduAwareText(
                        isUrdu
                            ? 'اپنے اکاؤنٹ کو محفوظ بنائیں'
                            : 'Protect your account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: fontFamily,
                        ),
                      ),
                      const SizedBox(height: 8),
                      UrduAwareText(
                        isUrdu
                            ? 'PIN کے ذریعے اپنی ایپ تک رسائی محفوظ رکھیں۔'
                            : 'Secure access to your app with a private PIN.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.5,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _SettingsCard(
                  icon: PhosphorIcons.lockKey(),
                  title: isUrdu ? 'ایپ لاک' : 'App Lock',
                  subtitle: _isEnabled
                      ? (isUrdu
                          ? 'PIN سے لاک فعال ہے'
                          : 'Protected with your PIN')
                      : (isUrdu
                          ? 'PIN سے ایپ محفوظ کریں'
                          : 'Require a PIN to open the app'),
                  fontFamily: fontFamily,
                  trailing: _isBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Switch.adaptive(
                          value: _isEnabled,
                          activeThumbColor: AppTheme.themeColor,
                          onChanged: (value) => _toggleAppLock(value, isUrdu),
                        ),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  icon: PhosphorIcons.key(),
                  title: isUrdu ? 'پن کوڈ تبدیل کریں' : 'Change PIN',
                  subtitle: isUrdu
                      ? 'اپنا موجودہ پن تصدیق کے بعد تبدیل کریں'
                      : 'Verify your current PIN before changing it',
                  fontFamily: fontFamily,
                  trailing: Icon(
                    isUrdu
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: _isEnabled ? AppTheme.themeColor : Colors.black26,
                  ),
                  onTap:
                      _isEnabled && !_isBusy ? () => _changePin(isUrdu) : null,
                ),
                if (!_isEnabled) ...[
                  const SizedBox(height: 12),
                  UrduAwareText(
                    isUrdu
                        ? 'پن کوڈ تبدیل کرنے کے لیے پہلے ایپ لاک فعال کریں۔'
                        : 'Turn on App Lock before changing your PIN.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontFamily: fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? fontFamily;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fontFamily,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: AppTheme.themeColor, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UrduAwareText(
                      title,
                      style: TextStyle(
                        color: const Color(0xFF14263D),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    UrduAwareText(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.35,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
