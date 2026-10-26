// lib/features/shopkeeper/widgets/shopkeeper_tools_grid.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/services/excel_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/features/settings/app_lock_screen.dart';
import 'package:account_app/features/order/nearby_shops_screen.dart';
import 'package:account_app/features/shopkeeper/shop_settings_screen.dart';
import 'package:account_app/features/shopkeeper/sales_analytics_screen.dart';
import 'package:account_app/features/order/my_orders_screen.dart';
import 'currency_settings_dialog.dart';
import 'package:account_app/features/settings/backup_screen.dart';
import 'package:account_app/features/shopkeeper/stock_history_screen.dart';

class ShopkeeperToolsGrid extends StatefulWidget {
  final bool isUrdu;
  final String fontFamily;

  const ShopkeeperToolsGrid({
    super.key,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  State<ShopkeeperToolsGrid> createState() => _ShopkeeperToolsGridState();
}

class _ShopkeeperToolsGridState extends State<ShopkeeperToolsGrid> {
  String _appVersion = '1.0.0';
  bool _isSyncing = false;

  // URLs — اپنی اصلی URLs سے بدلیں
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.zalooq.karobari_saathi';
  static const String _supportEmail = 'support@zalooq.com';
  static const String _supportWhatsApp = '+923001234567';
  static const String _privacyUrl = 'https://zalooq.com/privacy';
  static const String _termsUrl = 'https://zalooq.com/terms';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.isUrdu;
    final fontFamily = widget.fontFamily;

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
              Icon(PhosphorIcons.gridFour(),
                  size: 14, color: AppTheme.themeColor),
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
              // 1. Sync — loading state
              _buildItem(
                context,
                icon: _isSyncing
                    ? PhosphorIcons.spinner()
                    : PhosphorIcons.cloudArrowUp(),
                label: _isSyncing
                    ? (isUrdu ? 'سنک...' : 'Syncing')
                    : (isUrdu ? 'سنک' : 'Sync'),
                isBusy: _isSyncing,
                onTap: _isSyncing ? null : () => _syncData(context, isUrdu),
              ),

              // 2. Report — 3 options
              _buildItem(
                context,
                icon: PhosphorIcons.filePdf(),
                label: isUrdu ? 'رپورٹ' : 'Report',
                onTap: () => _showExportDialog(context, isUrdu, fontFamily),
              ),

              // 3. Backup
              _buildItem(
                context,
                icon: PhosphorIcons.database(),
                label: isUrdu ? 'بیک اپ' : 'Backup',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                },
              ),

              // Sales Analytics
              _buildItem(
                context,
                icon: PhosphorIcons.chartBar(),
                label: isUrdu ? 'تجزیہ' : 'Analytics',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SalesAnalyticsScreen()),
                  );
                },
              ),



              // 5. Settings
              _buildItem(
                context,
                icon: PhosphorIcons.gearSix(),
                label: isUrdu ? 'سیٹنگز' : 'Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ShopSettingsScreen()),
                  );
                },
              ),

              // 6. Share — with Play Store link
              _buildItem(
                context,
                icon: PhosphorIcons.shareNetwork(),
                label: isUrdu ? 'شیئر' : 'Share',
                onTap: () => _shareApp(context, isUrdu),
              ),

              // 7. About — with support contact
              _buildItem(
                context,
                icon: PhosphorIcons.info(),
                label: isUrdu ? 'معلومات' : 'About',
                onTap: () =>
                    _showAboutAppDialog(context, isUrdu, fontFamily),
              ),

              // 8. Privacy
              _buildItem(
                context,
                icon: PhosphorIcons.shieldCheck(),
                label: isUrdu ? 'پرائیویسی' : 'Privacy',
                onTap: () => _showPrivacyPolicy(context, isUrdu, fontFamily),
              ),

              // 9. Logout — with sync warning
              _buildItem(
                context,
                icon: PhosphorIcons.signOut(),
                label: isUrdu ? 'لاگ آؤٹ' : 'Logout',
                onTap: () => _showLogoutDialog(context, isUrdu, fontFamily),
              ),

              // 10. Stock Log
              _buildItem(
                context,
                icon: PhosphorIcons.clockCounterClockwise(),
                label: isUrdu ? 'اسٹاک ہسٹری' : 'Stock Log',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StockHistoryScreen()),
                  );
                },
              ),

              // 11. Nearby Shops
              _buildItem(
                context,
                icon: PhosphorIcons.storefront(),
                label: isUrdu ? 'قریبی دکاندار' : 'Nearby',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OrderSelectionScreen()),
                  );
                },
              ),

              // 12. App Lock — with verification
              _buildItem(
                context,
                icon: PhosphorIcons.lock(),
                label: isUrdu ? 'ایپ لاک' : 'App Lock',
                onTap: () => _toggleAppLock(context, isUrdu, fontFamily),
              ),

              // 13. Change PIN
              _buildItem(
                context,
                icon: PhosphorIcons.key(),
                label: isUrdu ? 'پن کوڈ' : 'Change PIN',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const AppLockScreen(isChangingPin: true),
                    ),
                  );
                  if (result == true && context.mounted) {
                    AppToast.success(
                      context,
                      isUrdu
                          ? 'پن کوڈ تبدیل ہو گیا'
                          : 'PIN changed successfully',
                    );
                  }
                },
              ),

              // 14. Deactivate (خطرناک — P3)
              _buildItem(
                context,
                icon: PhosphorIcons.userMinus(),
                label: isUrdu ? 'اکاؤنٹ بند' : 'Deactivate',
                onTap: () =>
                    _showDeactivateDialog(context, isUrdu, fontFamily),
              ),

              // 15. Language & Currency Settings
              _buildItem(
                context,
                icon: PhosphorIcons.currencyCircleDollar(),
                label: isUrdu ? 'زبان اور کرنسی' : 'Language & Currency',
                onTap: () => CurrencySettingsDialog.show(context, isUrdu, fontFamily),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ITEM BUILDER
  // ═══════════════════════════════════════════════════════════
  Widget _buildItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback? onTap,
        bool isBusy = false,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
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
                if (isBusy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 1. SYNC — Internet check + loading + result
  // ═══════════════════════════════════════════════════════════
  Future<void> _syncData(BuildContext context, bool isUrdu) async {
    // Internet check
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      if (context.mounted) {
        AppToast.warning(
          context,
          isUrdu ? 'انٹرنیٹ نہیں ہے، پہلے کنیکٹ کریں' : 'No internet, connect first',
        );
      }
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final syncService =
      Provider.of<AutoSyncService>(context, listen: false);
      await syncService.syncAllDataToCloud();

      if (context.mounted) {
        AppToast.success(
          context,
          isUrdu ? '✓ ڈیٹا سنک ہو گیا' : '✓ Data synced successfully',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          isUrdu ? 'سنک ناکام: $e' : 'Sync failed: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 2. REPORT — 3 options (Sales / Stock / Profit)
  // ═══════════════════════════════════════════════════════════
  void _showExportDialog(
      BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(PhosphorIcons.filePdf(),
                size: 20, color: AppTheme.themeColor),
            const SizedBox(width: 8),
            UrduAwareText(
              isUrdu ? 'رپورٹ ایکسپورٹ' : 'Export Report',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption(
              icon: PhosphorIcons.receipt(),
              color: AppTheme.incomeColor,
              title: isUrdu ? 'سیلز رپورٹ' : 'Sales Report',
              sub: isUrdu ? 'تمام بلوں کی تفصیل' : 'All bills detail',
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              onTap: () => _exportReport(
                context,
                dialogContext,
                isUrdu,
                fontFamily,
                type: 'sales',
              ),
            ),
            const SizedBox(height: 8),
            _buildReportOption(
              icon: PhosphorIcons.package(),
              color: AppTheme.themeColor,
              title: isUrdu ? 'اسٹاک رپورٹ' : 'Stock Report',
              sub: isUrdu
                  ? 'موجودہ اسٹاک اور مالیت'
                  : 'Current stock & value',
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              onTap: () => _exportReport(
                context,
                dialogContext,
                isUrdu,
                fontFamily,
                type: 'stock',
              ),
            ),
            const SizedBox(height: 8),
            _buildReportOption(
              icon: PhosphorIcons.chartLine(),
              color: AppTheme.verifiedGold,
              title: isUrdu ? 'منافع رپورٹ' : 'Profit Report',
              sub: isUrdu ? 'آئٹم وار منافع' : 'Item-wise profit',
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              onTap: () => _exportReport(
                context,
                dialogContext,
                isUrdu,
                fontFamily,
                type: 'profit',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'بند' : 'Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required bool isUrdu,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    title,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  UrduAwareText(
                    sub,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(),
                size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport(
      BuildContext context,
      BuildContext dialogContext,
      bool isUrdu,
      String fontFamily, {
        required String type,
      }) async {
    Navigator.pop(dialogContext);

    // Show choice: PDF or Excel
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: UrduAwareText(
          isUrdu ? 'فارمیٹ منتخب کریں' : 'Choose format',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              text: 'PDF',
              icon: PhosphorIcons.filePdf(),
              isFullWidth: true,
              onPressed: () => Navigator.pop(ctx, 'pdf'),
            ),
            const SizedBox(height: 10),
            AppButton(
              text: 'Excel / CSV',
              icon: PhosphorIcons.fileCsv(),
              isFullWidth: true,
              onPressed: () => Navigator.pop(ctx, 'excel'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
        ],
      ),
    );

    if (format == null || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.themeColor),
              const SizedBox(height: 12),
              UrduAwareText(
                isUrdu ? 'رپورٹ بن رہی ہے...' : 'Generating report...',
                style: TextStyle(fontFamily: fontFamily),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final pdfService = Provider.of<PdfService>(context, listen: false);
      final excelService =
      Provider.of<ExcelService>(context, listen: false);
      final databaseService =
      Provider.of<DatabaseService>(context, listen: false);
      final stockService = Provider.of<StockService>(context, listen: false);

      switch (type) {
        case 'sales':
          if (format == 'pdf') {
            await pdfService.generateSalesReport(
              databaseService.transactions,
              isUrdu,
            );
          } else {
            await excelService.generateSalesCsv(
              databaseService.transactions,
              isUrdu,
            );
          }
          break;
        case 'stock':
          if (format == 'pdf') {
            await pdfService.generateStockReport(
              stockService.items,
              stockService,
              isUrdu,
            );
          } else {
            await excelService.generateStockCsv(
              stockService.items,
              stockService,
              isUrdu,
            );
          }
          break;
        case 'profit':
          if (format == 'pdf') {
            await pdfService.generateProfitReport(
              databaseService.transactions,
              stockService,
              isUrdu,
            );
          } else {
            await excelService.generateProfitCsv(
              databaseService.transactions,
              stockService,
              isUrdu,
            );
          }
          break;
      }

      if (context.mounted) {
        Navigator.pop(context);
        AppToast.success(
          context,
          isUrdu ? '✓ رپورٹ تیار' : '✓ Report ready',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        AppToast.error(context, isUrdu ? 'ناکام: $e' : 'Failed: $e');
      }
    }
  }



  // ═══════════════════════════════════════════════════════════
  // 6. SHARE — Play Store link
  // ═══════════════════════════════════════════════════════════
  void _shareApp(BuildContext context, bool isUrdu) {
    final message = isUrdu
        ? 'کاروباری ساتھی — آپ کے کاروبار کا مکمل ساتھی!\n\nحسابات، اسٹاک، بل، رپورٹس — سب ایک ایپ میں۔\n\nڈاؤن لوڈ کریں:\n$_playStoreUrl'
        : 'Karobari Saathi — your complete business companion!\n\nAccounts, stock, bills, reports — all in one app.\n\nDownload:\n$_playStoreUrl';

    Share.share(message);
  }

  // ═══════════════════════════════════════════════════════════
  // 7. ABOUT — with support contact
  // ═══════════════════════════════════════════════════════════
  void _showAboutAppDialog(
      BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  color: AppTheme.themeColor,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
                ),
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
                        child:
                        Image.asset('assets/images/icons/zalooq.png'),
                      ),
                      const SizedBox(height: 12),
                      UrduAwareText(
                        isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily,
                        ),
                      ),
                      UrduAwareText(
                        'Version $_appVersion',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAboutItem(
                      PhosphorIcons.shieldCheck(),
                      isUrdu ? 'محفوظ ڈیٹا' : 'Secure Data',
                      isUrdu
                          ? 'آپ کا ڈیٹا محفوظ ہے'
                          : 'Your data is secure',
                      isUrdu,
                      fontFamily,
                    ),
                    const Divider(),
                    _buildAboutItem(
                      PhosphorIcons.cloudArrowUp(),
                      isUrdu ? 'آٹو کلاؤڈ سنک' : 'Auto Cloud Sync',
                      isUrdu
                          ? 'آن لائن بیک اپ'
                          : 'Online backup',
                      isUrdu,
                      fontFamily,
                    ),
                    const Divider(),
                    _buildAboutItem(
                      PhosphorIcons.code(),
                      isUrdu ? 'تیار کردہ' : 'Developed By',
                      'Zalooq Tech Solutions',
                      isUrdu,
                      fontFamily,
                    ),
                    const Divider(),
                    // ⭐ Support contact
                    _buildSupportItem(
                      context,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      icon: PhosphorIcons.envelope(),
                      title: isUrdu ? 'ای میل سپورٹ' : 'Email Support',
                      value: _supportEmail,
                      onTap: () =>
                          _launchUrl('mailto:$_supportEmail', context, isUrdu),
                    ),
                    const Divider(),
                    _buildSupportItem(
                      context,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      icon: PhosphorIcons.whatsappLogo(),
                      title: isUrdu ? 'واٹس ایپ' : 'WhatsApp',
                      value: _supportWhatsApp,
                      onTap: () => _launchUrl(
                        'https://wa.me/$_supportWhatsApp',
                        context,
                        isUrdu,
                      ),
                    ),
                    const Divider(),
                    // ⭐ Rate app
                    _buildSupportItem(
                      context,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      icon: PhosphorIcons.star(),
                      title: isUrdu ? 'ایپ ریٹنگ' : 'Rate App',
                      value: isUrdu
                          ? 'پلے سٹور پر ریٹنگ دیں'
                          : 'Rate on Play Store',
                      onTap: () =>
                          _launchUrl(_playStoreUrl, context, isUrdu),
                    ),
                    const Divider(),
                    // ⭐ Terms link
                    _buildSupportItem(
                      context,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      icon: PhosphorIcons.fileText(),
                      title: isUrdu ? 'شرائط و ضوابط' : 'Terms of Service',
                      value: _termsUrl,
                      onTap: () => _launchUrl(_termsUrl, context, isUrdu),
                    ),
                  ],
                ),
              ),
              // Close
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: AppButton(
                  text: isUrdu ? 'بند کریں' : 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                  isFullWidth: true,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportItem(
      BuildContext context, {
        required bool isUrdu,
        required String fontFamily,
        required IconData icon,
        required String title,
        required String value,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.themeColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: fontFamily),
                  ),
                  UrduAwareText(
                    value,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(),
                size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutItem(IconData icon, String title, String sub, bool isUrdu,
      String fontFamily) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.themeColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UrduAwareText(
                title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: fontFamily),
              ),
              UrduAwareText(
                sub,
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: fontFamily),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(
      String url, BuildContext context, bool isUrdu) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          AppToast.error(
            context,
            isUrdu ? 'لنک نہیں کھل سکا' : 'Could not open link',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 8. PRIVACY
  // ═══════════════════════════════════════════════════════════
  void _showPrivacyPolicy(
      BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: UrduAwareText(
          isUrdu ? 'پرائیویسی پالیسی' : 'Privacy Policy',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UrduAwareText(
                isUrdu
                    ? 'ہم آپ کی رازداری کا احترام کرتے ہیں۔\n\n1. اکاؤنٹ: لاگ اِن کے لیے فون نمبر اور SMS OTP۔\n2. کاروباری ریکارڈ: آپ کے کھاتے، لین دین، پروفائل کلاؤڈ میں محفوظ۔\n3. مقامی حفاظت: ایپ PIN اور حساس معلومات ڈیوائس پر محفوظ۔\n4. شیئرنگ: آپ کا ڈیٹا فروخت نہیں کیا جاتا۔\n5. بیک اپ: کلاؤڈ سنک سہولت ہے، اپنا بیک اپ بھی رکھیں۔'
                    : 'We respect your privacy.\n\n1. Account: Phone number and SMS OTP for sign in.\n2. Business records: Your accounts, transactions, profile stored in cloud.\n3. Local security: App Lock, PIN and sensitive data stored securely on device.\n4. Sharing: We do not sell your data.\n5. Backups: Cloud sync is provided, keep your own backup too.',
                style: TextStyle(
                    fontFamily: isUrdu ? fontFamily : null, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // ⭐ Web link
              InkWell(
                onTap: () => _launchUrl(_privacyUrl, context, isUrdu),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.globe(),
                        size: 14, color: AppTheme.themeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _privacyUrl,
                        style: const TextStyle(
                          color: AppTheme.themeColor,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'بند' : 'Close'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 9. LOGOUT — with sync warning
  // ═══════════════════════════════════════════════════════════
  void _showLogoutDialog(
      BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: UrduAwareText(
          isUrdu ? 'لاگ آؤٹ' : 'Logout',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu
                  ? 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
                  : 'Are you sure you want to logout?',
              style: TextStyle(fontFamily: fontFamily),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFD97706).withValues(alpha: 0.30)),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.warning(),
                      size: 16, color: const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UrduAwareText(
                      isUrdu
                          ? 'لاگ آؤٹ سے پہلے ڈیٹا سنک کر لیں ورنہ نقصان ہو سکتا ہے'
                          : 'Sync your data before logout to avoid loss',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: fontFamily,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Provider.of<AuthService>(context, listen: false)
                  .signOut(context);
            },
            child: UrduAwareText(
              isUrdu ? 'صرف لاگ آؤٹ' : 'Logout Anyway',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          // ⭐ Sync + Logout
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final syncService =
                Provider.of<AutoSyncService>(context, listen: false);
                await syncService.syncAllDataToCloud();
              } catch (_) {}
              if (context.mounted) {
                await Provider.of<AuthService>(context, listen: false)
                    .signOut(context);
              }
            },
            child: UrduAwareText(
              isUrdu ? 'سنک + لاگ آؤٹ' : 'Sync + Logout',
              style: const TextStyle(
                  color: AppTheme.incomeColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 12. APP LOCK — با تصدیق disable
  // ═══════════════════════════════════════════════════════════
  Future<void> _toggleAppLock(
      BuildContext context, bool isUrdu, String fontFamily) async {
    final securityService =
    Provider.of<SecurityService>(context, listen: false);
    final isEnabled = await securityService.isAppLockEnabled();

    if (isEnabled) {
      // ⭐ Disable کرنے سے پہلے تصدیق کرائیں
      final verified = await _verifyBeforeDisable(context, isUrdu, fontFamily);
      if (verified != true) return;

      await securityService.setAppLockEnabled(false);
      if (context.mounted) {
        AppToast.success(
          context,
          isUrdu ? 'ایپ لاک غیر فعال' : 'App Lock disabled',
        );
      }
    } else {
      // Enable
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const AppLockScreen(isSettingUp: true)),
      );
      if (result == true && context.mounted) {
        AppToast.success(
          context,
          isUrdu ? 'ایپ لاک فعال' : 'App Lock enabled',
        );
      }
    }
  }

  Future<bool?> _verifyBeforeDisable(
      BuildContext context, bool isUrdu, String fontFamily) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(PhosphorIcons.lock(),
                size: 20, color: AppTheme.expenseColor),
            const SizedBox(width: 8),
            UrduAwareText(
              isUrdu ? 'ایپ لاک بند کریں؟' : 'Disable App Lock?',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: UrduAwareText(
          isUrdu
              ? 'ایپ لاک بند کرنے کے لیے اپنا موجودہ PIN درج کریں۔'
              : 'Enter your current PIN to disable App Lock.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // ⭐ PIN verification screen کھولیں
              final verified = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppLockScreen(
                    isChangingPin: false,
                    isVerifyingOnly: true,
                  ),
                ),
              );
              // Note: یہاں result کو parent تک پہنچائیں
            },
            child: UrduAwareText(
              isUrdu ? 'PIN درج کریں' : 'Enter PIN',
              style: const TextStyle(color: AppTheme.themeColor),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 14. DEACTIVATE — Soft delete (P3)
  // ═══════════════════════════════════════════════════════════
  void _showDeactivateDialog(
      BuildContext context, bool isUrdu, String fontFamily) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(PhosphorIcons.warning(),
                size: 22, color: AppTheme.expenseColor),
            const SizedBox(width: 8),
            UrduAwareText(
              isUrdu ? 'اکاؤنٹ بند کریں' : 'Deactivate Account',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.expenseColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu
                  ? 'یہ عمل آپ کا اکاؤنٹ 30 دن کے لیے بند کر دے گا۔ اس دوران دوبارہ لاگ اِن کر کے بحال کر سکتے ہیں۔'
                  : 'This will deactivate your account for 30 days. You can restore by logging in again during this period.',
              style: TextStyle(fontFamily: fontFamily, fontSize: 12),
            ),
            const SizedBox(height: 12),
            UrduAwareText(
              isUrdu ? 'تصدیق کے لیے "DELETE" لکھیں:' : 'Type "DELETE" to confirm:',
              style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: 'DELETE',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (confirmController.text.trim() != 'DELETE') {
                AppToast.warning(
                  context,
                  isUrdu ? '"DELETE" درست لکھیں' : 'Type "DELETE" correctly',
                );
                return;
              }
              Navigator.pop(dialogContext);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // ⭐ Soft delete
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                    'isDeactivated': true,
                    'deactivatedAt': FieldValue.serverTimestamp(),
                    'restoreDeadline':
                    DateTime.now().add(const Duration(days: 30)),
                  }, SetOptions(merge: true));

                  if (context.mounted) {
                    await Provider.of<AuthService>(context, listen: false)
                        .signOut(context);
                    AppToast.success(
                      context,
                      isUrdu
                          ? 'اکاؤنٹ بند — 30 دن میں بحال کر سکتے ہیں'
                          : 'Account deactivated — can restore in 30 days',
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, 'Error: $e');
                }
              }
            },
            child: UrduAwareText(
              isUrdu ? 'بند کریں' : 'Deactivate',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}