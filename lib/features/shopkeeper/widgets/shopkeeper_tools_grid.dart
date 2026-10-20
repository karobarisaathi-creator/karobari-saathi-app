// lib/features/shopkeeper/widgets/shopkeeper_tools_grid.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/services/excel_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/features/settings/app_lock_screen.dart';
import 'package:account_app/features/order/nearby_shops_screen.dart';
import 'package:account_app/features/shopkeeper/shop_settings_screen.dart';
import 'package:account_app/features/settings/backup_screen.dart';
import 'package:account_app/features/shopkeeper/stock_history_screen.dart';

class ShopkeeperToolsGrid extends StatelessWidget {
  final bool isUrdu;
  final String fontFamily;
  static const String _appVersion = '1.0.0';

  const ShopkeeperToolsGrid({
    super.key,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.gridFour(), size: 14, color: AppTheme.themeColor),
              const SizedBox(width: 6),
              UrduAwareText(
                isUrdu ? 'کاروباری ٹولز اور مینو' : 'Business Tools & Menu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildItem(
                context,
                icon: PhosphorIcons.cloudArrowUp(),
                label: isUrdu ? 'سنک' : 'Sync',
                onTap: () => _syncData(context, isUrdu),
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.filePdf(),
                label: isUrdu ? 'رپورٹ' : 'Report',
                onTap: () => _showExportDialog(context, isUrdu, fontFamily),
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.database(),
                label: isUrdu ? 'بیک اپ' : 'Backup',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BackupScreen(),
                    ),
                  );
                },
              ),

              _buildItem(
                context,
                icon: PhosphorIcons.translate(),
                label: isUrdu ? 'زبان' : 'Language',
                onTap: () {
                  Provider.of<LanguageService>(context, listen: false)
                      .changeLanguage(isUrdu ? 'en' : 'ur');
                },
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.gearSix(),
                label: isUrdu ? 'سیٹنگز' : 'Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShopSettingsScreen(),
                    ),
                  );
                },
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.shareNetwork(),
                label: isUrdu ? 'شیئر' : 'Share',
                onTap: () => _shareApp(context, isUrdu),
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.info(),
                label: isUrdu ? 'معلومات' : 'About',
                onTap: () => _showAboutAppDialog(context, isUrdu, fontFamily),
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.shieldCheck(),
                label: isUrdu ? 'پرائیویسی' : 'Privacy',
                onTap: () => _showPrivacyPolicy(context, isUrdu, fontFamily),
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.signOut(),
                label: isUrdu ? 'لاگ آؤٹ' : 'Logout',
                onTap: () => _showLogoutDialog(context, isUrdu, fontFamily),
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.clockCounterClockwise(),
                label: isUrdu ? 'اسٹاک ہسٹری' : 'Stock Log',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StockHistoryScreen(),
                    ),
                  );
                },
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.storefront(),
                label: isUrdu ? 'قریبی دکاندار' : 'Nearby',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderSelectionScreen(),
                    ),
                  );
                },
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.lock(),
                label: isUrdu ? 'ایپ لاک' : 'App Lock',
                onTap: () async {
                  final securityService = Provider.of<SecurityService>(context, listen: false);
                  final isEnabled = await securityService.isAppLockEnabled();
                  if (isEnabled) {
                    await securityService.setAppLockEnabled(false);
                    AppToast.success(context, isUrdu ? 'ایپ لاک غیر فعال کر دیا گیا' : 'App Lock disabled');
                  } else {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppLockScreen(isSettingUp: true)),
                    );
                    if (result == true) {
                      AppToast.success(context, isUrdu ? 'ایپ لاک فعال کر دیا گیا' : 'App Lock enabled');
                    }
                  }
                },
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.key(),
                label: isUrdu ? 'پن کوڈ' : 'Change PIN',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AppLockScreen(isChangingPin: true)),
                  );
                  if (result == true) {
                    AppToast.success(context, isUrdu ? 'پن کوڈ کامیابی سے تبدیل ہو گیا' : 'PIN changed successfully');
                  }
                },
              ),
              _buildItem(
                context,
                icon: PhosphorIcons.userMinus(),
                label: isUrdu ? 'اکاؤنٹ بند' : 'Deactivate',
                onTap: () => _showDeactivateDialog(context, isUrdu, fontFamily),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(height: 4),
              UrduAwareText(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncData(BuildContext context, bool isUrdu) async {
    final syncService = Provider.of<AutoSyncService>(context, listen: false);
    AppToast.success(
        context, isUrdu ? 'ڈیٹا سنک ہو رہا ہے...' : 'Syncing data...');
    try {
      await syncService.syncAllDataToCloud();
      AppToast.success(context,
          isUrdu ? 'ڈیٹا سنک ہوگیا' : 'Data synced successfully');
    } catch (e) {
      AppToast.error(context, 'Error: $e');
    }
  }

  void _showExportDialog(BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: UrduAwareText(isUrdu ? 'رپورٹ ایکسپورٹ کریں' : 'Export Report',
            style: TextStyle(fontFamily: fontFamily)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              text: 'PDF Report',
              onPressed: () async {
                Navigator.pop(dialogContext);
                AppToast.success(
                    context,
                    isUrdu ? 'پی ڈی ایف بن رہی ہے...' : 'Generating PDF...');
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
                  AppToast.error(context, 'Error: $e');
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
                AppToast.success(
                    context,
                    isUrdu ? 'ایکسل فائل بن رہی ہے...' : 'Generating Excel...');
                final excelService =
                    Provider.of<ExcelService>(context, listen: false);
                final databaseService =
                    Provider.of<DatabaseService>(context, listen: false);
                try {
                  await excelService.generateAndShareAllAccountsCsv(
                      databaseService.accounts, isUrdu);
                } catch (e) {
                  AppToast.error(context, 'Error: $e');
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
                    UrduAwareText(isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily)),
                    UrduAwareText('Version $_appVersion',
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
          UrduAwareText(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: fontFamily)),
          UrduAwareText(sub,
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
        title: UrduAwareText(isUrdu ? 'پرائیویسی پالیسی' : 'Privacy Policy',
            style: TextStyle(fontFamily: fontFamily)),
        content: SingleChildScrollView(
          child: UrduAwareText(
            isUrdu
                ? 'ہم آپ کی رازداری کا احترام کرتے ہیں۔\n\n1. اکاؤنٹ: لاگ اِن کے لیے فون نمبر اور SMS OTP استعمال ہوتا ہے۔\n2. کاروباری ریکارڈ: آپ کے کھاتے، لین دین، پروفائل اور ایپ کا ڈیٹا آپ کے اکاؤنٹ کے ساتھ کلاؤڈ میں محفوظ ہوتا ہے تاکہ آپ اپنے ریکارڈ بحال کر سکیں۔\n3. مقامی حفاظت: ایپ PIN اور متعلقہ حساس معلومات کو ڈیوائس پر محفوظ طریقے سے رکھنے کی کوشش کرتی ہے۔\n4. شیئرنگ: آپ کا ڈیٹا فروخت نہیں کیا جاتا۔ رابطہ یا چیٹ کی معلومات صرف ایپ کے متعلقہ کاروباری فیچرز میں استعمال ہوتی ہے۔\n5. بیک اپ: کلاؤڈ سنک سہولت ہے، مگر اہم ریکارڈ کا اپنا بیک اپ بھی رکھیں۔'
                : 'We respect your privacy.\n\n1. Account: Phone number and SMS OTP are used to sign in.\n2. Business records: Your accounts, transactions, profile, and app data are stored in the cloud with your account so your records can be restored.\n3. Local security: App Lock, PIN, and related sensitive information are stored on the device using secure storage where available.\n4. Sharing: We do not sell your data. Contact and chat details are used only by the related business features.\n5. Backups: Cloud sync is provided for convenience, but keep your own backup of important records.',
            style:
                TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: UrduAwareText(isUrdu ? 'بند کریں' : 'Close'))
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
        title: UrduAwareText(isUrdu ? 'لاگ آؤٹ' : 'Logout',
            style: TextStyle(fontFamily: fontFamily)),
        content: UrduAwareText(isUrdu
            ? 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
            : 'Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: UrduAwareText(isUrdu ? 'نہیں' : 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<AuthService>(context, listen: false)
                  .signOut(context);
            },
            child: UrduAwareText(isUrdu ? 'ہاں' : 'Yes',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: UrduAwareText(isUrdu ? 'اکاؤنٹ ختم کریں' : 'Deactivate Account',
            style: TextStyle(fontFamily: fontFamily)),
        content: UrduAwareText(isUrdu
            ? 'کیا آپ واقعی اپنا اکاؤنٹ ختم کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔'
            : 'Are you sure you want to deactivate your account? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: UrduAwareText(isUrdu ? 'نہیں' : 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
                  await FirebaseFirestore.instance.collection('public_shops').doc(user.uid).delete();
                  await user.delete();
                  await Provider.of<AuthService>(context, listen: false).signOut(context);
                }
              } catch (e) {
                AppToast.error(context, 'Error: $e');
              }
            },
            child: UrduAwareText(isUrdu ? 'ہاں' : 'Yes',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
