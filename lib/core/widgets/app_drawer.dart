import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/backup_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/services/excel_service.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/features/settings/master_profile_screen.dart';
import 'package:account_app/features/settings/app_lock_screen.dart';
import 'package:account_app/features/stock/stock_list_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _appVersion = '1.0.0';
  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadDrawerData();
  }

  Future<void> _loadDrawerData() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final securityService =
        Provider.of<SecurityService>(context, listen: false);
    final isLockEnabled = await securityService.isAppLockEnabled();
    final isBioEnabled = await securityService.isBiometricEnabled();
    final isBioAvailable = await securityService.isBiometricsAvailable();

    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
        _isAppLockEnabled = isLockEnabled;
        _isBiometricEnabled = isBioEnabled;
        _isBiometricAvailable = isBioAvailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: AppTheme.scaffoldBackground,
      child: Column(
        children: [
          // Drawer Header
          _buildHeader(context, user, isUrdu, fontFamily),

          // Drawer Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader(isUrdu ? 'کاروباری ٹولز' : 'Business Tools',
                    fontFamily, isUrdu),
                _buildDrawerItem(
                  icon: PhosphorIcons.package(),
                  title: isUrdu ? 'اسٹاک اور انوینٹری' : 'Stock & Inventory',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StockListScreen(),
                      ),
                    );
                  },
                  fontFamily: fontFamily,
                ),
                _buildDivider(),
                _buildSectionHeader(
                    isUrdu ? 'ڈیٹا اور رپورٹ' : 'Data & Reports',
                    fontFamily,
                    isUrdu),
                _buildDrawerItem(
                  icon: PhosphorIcons.cloudArrowUp(),
                  title: isUrdu ? 'ڈیٹا سنک کریں' : 'Sync Data',
                  onTap: () => _syncData(context, isUrdu),
                  fontFamily: fontFamily,
                ),
                _buildDrawerItem(
                  icon: PhosphorIcons.filePdf(),
                  title: isUrdu ? 'پی ڈی ایف رپورٹ' : 'PDF Report',
                  onTap: () => _showExportDialog(context, isUrdu),
                  fontFamily: fontFamily,
                ),
                _buildDrawerItem(
                  icon: PhosphorIcons.database(),
                  title: isUrdu ? 'بیک اپ اور بحالی' : 'Backup & Restore',
                  onTap: () => _showBackupDialog(context, isUrdu),
                  fontFamily: fontFamily,
                ),
                _buildDivider(),
                _buildSectionHeader(
                    isUrdu ? 'سیکیورٹی اور زبان' : 'Security & Language',
                    fontFamily,
                    isUrdu),
                _buildDrawerItem(
                  icon: PhosphorIcons.translate(),
                  title: isUrdu ? 'زبان تبدیل کریں' : 'Change Language',
                  onTap: () =>
                      languageService.changeLanguage(isUrdu ? 'en' : 'ur'),
                  fontFamily: fontFamily,
                  trailing: Text(
                    isUrdu ? 'اردو' : 'English',
                    style: TextStyle(
                      color: AppTheme.themeColor,
                      fontWeight: FontWeight.w900,
                      fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                      fontSize: isUrdu ? 19 : 15,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  icon: PhosphorIcons.lock(),
                  title: isUrdu ? 'ایپ لاک' : 'App Lock',
                  onTap: () => _toggleAppLock(context, isUrdu),
                  fontFamily: fontFamily,
                  trailing: Switch(
                    value: _isAppLockEnabled,
                    activeColor: AppTheme.themeColor,
                    onChanged: (value) => _toggleAppLock(context, isUrdu),
                  ),
                ),
                if (_isAppLockEnabled) ...[
                  _buildDrawerItem(
                    icon: PhosphorIcons.key(),
                    title: isUrdu ? 'پن کوڈ تبدیل کریں' : 'Change PIN',
                    onTap: () => _changePin(context, isUrdu),
                    fontFamily: fontFamily,
                  ),
                  if (_isBiometricAvailable)
                    _buildDrawerItem(
                      icon: PhosphorIcons.fingerprint(),
                      title: isUrdu ? 'بائیو میٹرک' : 'Biometric',
                      onTap: () => _toggleBiometric(context, isUrdu),
                      fontFamily: fontFamily,
                      trailing: Switch(
                        value: _isBiometricEnabled,
                        activeColor: AppTheme.themeColor,
                        onChanged: (value) => _toggleBiometric(context, isUrdu),
                      ),
                    ),
                ],
                _buildDivider(),
                _buildSectionHeader(isUrdu ? 'ایپ کے بارے میں' : 'About App',
                    fontFamily, isUrdu),
                _buildDrawerItem(
                  icon: PhosphorIcons.info(),
                  title: isUrdu ? 'ایپ کے بارے میں' : 'About App',
                  onTap: () => _showAboutAppDialog(context, isUrdu, fontFamily),
                  fontFamily: fontFamily,
                ),
                _buildDrawerItem(
                  icon: PhosphorIcons.shareNetwork(),
                  title: isUrdu ? 'ایپ شیئر کریں' : 'Share App',
                  onTap: () => _shareApp(context, isUrdu),
                  fontFamily: fontFamily,
                ),
                _buildDrawerItem(
                  icon: PhosphorIcons.shieldCheck(),
                  title: isUrdu ? 'پرائیویسی اور شرائط' : 'Privacy & Terms',
                  onTap: () => _showPrivacyPolicy(context, isUrdu, fontFamily),
                  fontFamily: fontFamily,
                ),
                _buildDivider(),
                const SizedBox(height: 12),
                _buildAccountCompactActions(context, isUrdu, fontFamily),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // Version Info
          Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            color: Colors.grey[100],
            child: Text(
              'Karobari Saathi v$_appVersion',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, User? user, bool isUrdu, String fontFamily) {
    return GestureDetector(
      onTap: () {
        if (user == null) return;
        Navigator.pop(context); // ڈراور بند کریں
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MasterProfileScreen(),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 20,
            left: 16,
            right: 16),
        decoration: BoxDecoration(
          color: AppTheme.darkColor,
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20)),
        ),
        child: ProfileInfoWidget(
          name: user?.displayName ?? (isUrdu ? 'صارف' : 'User'),
          phone: user?.phoneNumber ?? '',
          profileImage: user?.photoURL,
          isLarge: true,
          textColor: Colors.white,
          subtitleColor: Colors.white70,
          isVerified: false,
          customSize: 60,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String fontFamily, bool isUrdu) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.themeColor,
          fontFamily: fontFamily,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required String fontFamily,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black87, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor ?? Colors.black87,
        ),
      ),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildDivider() {
    return const Divider(
        height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE));
  }

  Widget _buildLanguageSelector(BuildContext context, bool isUrdu,
      String fontFamily, LanguageService languageService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildLanguageOption(
              label: 'English',
              isSelected: !isUrdu,
              onTap: () => languageService.changeLanguage('en'),
              fontFamily: '',
              fontSize: 15,
            ),
            _buildLanguageOption(
              label: 'اردو',
              isSelected: isUrdu,
              onTap: () => languageService.changeLanguage('ur'),
              fontFamily: 'NooriNastaleeq',
              fontSize: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required String fontFamily,
    required double fontSize,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? AppTheme.themeColor : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCompactActions(
      BuildContext context, bool isUrdu, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // لاگ آؤٹ بٹن
          Expanded(
            child: InkWell(
              onTap: () => _showLogoutDialog(context, isUrdu, fontFamily),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.blue.withOpacity(0.6), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.signOut(),
                        color: Colors.blue.shade900, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isUrdu ? 'لاگ آؤٹ' : 'Logout',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w900,
                        fontFamily: fontFamily,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // اکاؤنٹ ختم کریں بٹن
          Expanded(
            child: InkWell(
              onTap: () => _showDeactivateDialog(context, isUrdu, fontFamily),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.6), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.userMinus(),
                        color: Colors.red.shade900, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isUrdu ? 'اکاؤنٹ ڈیلیٹ' : 'Delete Account',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w900,
                        fontFamily: fontFamily,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Logic Helper Methods ---

  Future<void> _toggleAppLock(BuildContext context, bool isUrdu) async {
    final securityService =
        Provider.of<SecurityService>(context, listen: false);

    if (_isAppLockEnabled) {
      await securityService.setAppLockEnabled(false);
      setState(() => _isAppLockEnabled = false);
      _showSnackBar(context,
          isUrdu ? 'ایپ لاک غیر فعال کر دیا گیا' : 'App Lock disabled', isUrdu);
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const AppLockScreen(isSettingUp: true)),
      );

      if (result == true) {
        final isEnabled = await securityService.isAppLockEnabled();
        setState(() => _isAppLockEnabled = isEnabled);
        if (isEnabled) {
          _showSnackBar(context,
              isUrdu ? 'ایپ لاک فعال کر دیا گیا' : 'App Lock enabled', isUrdu);
        }
      }
    }
  }

  Future<void> _toggleBiometric(BuildContext context, bool isUrdu) async {
    final securityService =
        Provider.of<SecurityService>(context, listen: false);

    if (!_isBiometricEnabled) {
      final available = await securityService.isBiometricsAvailable();
      if (!available) {
        _showSnackBar(
            context,
            isUrdu ? 'بائیو میٹرک دستیاب نہیں' : 'Biometrics not available',
            isUrdu,
            isError: true);
        return;
      }
    }

    await securityService.setBiometricEnabled(!_isBiometricEnabled);
    setState(() {
      _isBiometricEnabled = !_isBiometricEnabled;
    });
    _showSnackBar(
        context, isUrdu ? 'ترتیب اپڈیٹ ہوگئی' : 'Setting updated', isUrdu);
  }

  Future<void> _changePin(BuildContext context, bool isUrdu) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const AppLockScreen(isChangingPin: true)),
    );
    if (result == true) {
      _showSnackBar(
          context,
          isUrdu
              ? 'پن کوڈ کامیابی سے تبدیل ہو گیا'
              : 'PIN changed successfully',
          isUrdu);
    }
  }

  void _syncData(BuildContext context, bool isUrdu) async {
    final syncService = Provider.of<AutoSyncService>(context, listen: false);
    _showSnackBar(
        context, isUrdu ? 'ڈیٹا سنک ہو رہا ہے...' : 'Syncing data...', isUrdu);
    try {
      await syncService.syncAllDataToCloud();
      _showSnackBar(context,
          isUrdu ? 'ڈیٹا سنک ہوگیا' : 'Data synced successfully', isUrdu);
    } catch (e) {
      _showSnackBar(context, 'Error: $e', isUrdu, isError: true);
    }
  }

  void _showExportDialog(BuildContext context, bool isUrdu) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? 'رپورٹ ایکسپورٹ کریں' : 'Export Report',
            style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              text: 'PDF Report',
              onPressed: () async {
                Navigator.pop(dialogContext);
                _showSnackBar(
                    context,
                    isUrdu ? 'پی ڈی ایف بن رہی ہے...' : 'Generating PDF...',
                    isUrdu);
                final pdfService =
                    Provider.of<PdfService>(context, listen: false);
                final databaseService =
                    Provider.of<DatabaseService>(context, listen: false);
                try {
                  await pdfService.generateAllAccountsReport(
                      databaseService.accounts,
                      databaseService.transactions,
                      isUrdu);
                } catch (e) {
                  _showSnackBar(context, 'Error: $e', isUrdu, isError: true);
                }
              },
              icon: PhosphorIcons.filePdf(),
              isFullWidth: true,
            ),
            const SizedBox(height: 12),
            AppButton(
              text: 'Excel / CSV',
              onPressed: () async {
                Navigator.pop(dialogContext);
                _showSnackBar(
                    context,
                    isUrdu ? 'ایکسل فائل بن رہی ہے...' : 'Generating Excel...',
                    isUrdu);
                final excelService =
                    Provider.of<ExcelService>(context, listen: false);
                final databaseService =
                    Provider.of<DatabaseService>(context, listen: false);
                try {
                  await excelService.generateAndShareAllAccountsCsv(
                      databaseService.accounts, isUrdu);
                } catch (e) {
                  _showSnackBar(context, 'Error: $e', isUrdu, isError: true);
                }
              },
              icon: PhosphorIcons.fileCsv(),
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, bool isUrdu) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? 'بیک اپ اور بحالی' : 'Backup & Restore',
            style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              text: isUrdu ? 'بیک اپ بنائیں' : 'Create Backup',
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await Provider.of<BackupService>(context, listen: false)
                      .createBackup();
                  _showSnackBar(
                      context,
                      isUrdu ? 'بیک اپ مکمل ہو گیا' : 'Backup completed',
                      isUrdu);
                } catch (e) {
                  _showSnackBar(context, 'Error: $e', isUrdu, isError: true);
                }
              },
              icon: PhosphorIcons.cloudArrowUp(),
              isFullWidth: true,
            ),
            const SizedBox(height: 12),
            AppButton(
              text: isUrdu ? 'بیک اپ بحال کریں' : 'Restore Backup',
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await Provider.of<BackupService>(context, listen: false)
                      .restoreBackup();
                  _showSnackBar(context,
                      isUrdu ? 'ڈیٹا بحال ہو گیا' : 'Data restored', isUrdu);
                } catch (e) {
                  _showSnackBar(context, 'Error: $e', isUrdu, isError: true);
                }
              },
              icon: PhosphorIcons.cloudArrowDown(),
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutAppDialog(
      BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                  color: AppTheme.themeColor,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(12))),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      height: 70,
                      width: 70,
                      decoration: const BoxDecoration(
                        color: AppTheme.darkColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('assets/images/icons/zalooq.png'),
                    ),
                    const SizedBox(height: 12),
                    Text(isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily)),
                    Text('Version $_appVersion',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildAboutItem(
                      PhosphorIcons.shieldCheck(),
                      isUrdu ? 'محفوظ ڈیٹا' : 'Secure Data',
                      isUrdu
                          ? 'آپ کا ڈیٹا مکمل طور پر محفوظ ہے'
                          : 'Your data is completely secure',
                      isUrdu,
                      fontFamily),
                  const Divider(),
                  _buildAboutItem(
                      PhosphorIcons.cloudArrowUp(),
                      isUrdu ? 'آٹو کلاؤڈ سنک' : 'Auto Cloud Sync',
                      isUrdu
                          ? 'آن لائن بیک اپ کی سہولت'
                          : 'Online backup facility',
                      isUrdu,
                      fontFamily),
                  const Divider(),
                  _buildAboutItem(
                      PhosphorIcons.code(),
                      isUrdu ? 'تیار کردہ' : 'Developed By',
                      'Zalooq Tech Solutions',
                      isUrdu,
                      fontFamily),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: AppButton(
                  text: isUrdu ? 'بند کریں' : 'Close',
                  onPressed: () => Navigator.pop(context),
                  isFullWidth: true),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutItem(
      IconData icon, String title, String sub, bool isUrdu, String fontFamily) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.themeColor, size: 24),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: fontFamily)),
          Text(sub,
              style: TextStyle(
                  color: Colors.grey, fontSize: 12, fontFamily: fontFamily)),
        ]),
      ],
    );
  }

  void _showPrivacyPolicy(
      BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? 'پرائیویسی پالیسی' : 'Privacy Policy',
            style: TextStyle(fontFamily: fontFamily)),
        content: SingleChildScrollView(
          child: Text(
            isUrdu
                ? 'ہم آپ کی رازداری کا احترام کرتے ہیں۔\n\n1. اکاؤنٹ: لاگ اِن کے لیے فون نمبر اور SMS OTP استعمال ہوتا ہے۔\n2. کاروباری ریکارڈ: آپ کے کھاتے، لین دین، پروفائل اور ایپ کا ڈیٹا آپ کے اکاؤنٹ کے ساتھ کلاؤڈ میں محفوظ ہوتا ہے تاکہ آپ اپنے ریکارڈ بحال کر سکیں۔\n3. مقامی حفاظت: ایپ PIN اور متعلقہ حساس معلومات کو ڈیوائس پر محفوظ طریقے سے رکھنے کی کوشش کرتی ہے۔\n4. شیئرنگ: آپ کا ڈیٹا فروخت نہیں کیا جاتا۔ رابطہ یا چیٹ کی معلومات صرف ایپ کے متعلقہ کاروباری فیچرز میں استعمال ہوتی ہیں۔\n5. بیک اپ: کلاؤڈ سنک سہولت ہے، مگر اہم ریکارڈ کا اپنا بیک اپ بھی رکھیں۔'
                : 'We respect your privacy.\n\n1. Account: Phone number and SMS OTP are used to sign in.\n2. Business records: Your accounts, transactions, profile, and app data are stored in the cloud with your account so your records can be restored.\n3. Local security: App Lock, PIN, and related sensitive information are stored on the device using secure storage where available.\n4. Sharing: We do not sell your data. Contact and chat details are used only by the related business features.\n5. Backups: Cloud sync is provided for convenience, but keep your own backup of important records.',
            style:
                TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'بند کریں' : 'Close'))
        ],
      ),
    );
  }

  void _shareApp(BuildContext context, bool isUrdu) {
    Share.share(isUrdu
        ? 'کاروباری ساتھی ایپ ڈاؤن لوڈ کریں!'
        : 'Download Karobari Saathi app now!');
  }

  void _showLogoutDialog(BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'لاگ آؤٹ' : 'Logout',
            style: TextStyle(fontFamily: fontFamily)),
        content: Text(isUrdu
            ? 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
            : 'Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'نہیں' : 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<AuthService>(context, listen: false)
                  .signOut(context);
            },
            child: Text(isUrdu ? 'ہاں' : 'Yes',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(
      BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'اکاؤنٹ ختم کریں' : 'Deactivate',
            style: TextStyle(fontFamily: fontFamily, color: Colors.red)),
        content: Text(isUrdu
            ? 'کیا آپ واقعی اپنا اکاؤنٹ عارضی طور پر ختم کرنا چاہتے ہیں؟'
            : 'Are you sure you want to deactivate your account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'نہیں' : 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<AuthService>(context, listen: false)
                  .deactivateAccount(context);
            },
            child: Text(isUrdu ? 'ہاں' : 'Yes',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String msg, bool isUrdu,
      {bool isError = false}) {
    if (isError) {
      AppToast.error(context, msg);
    } else {
      AppToast.success(context, msg);
    }
  }
}
