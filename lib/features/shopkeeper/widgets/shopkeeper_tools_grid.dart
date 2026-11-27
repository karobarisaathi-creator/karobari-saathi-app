// lib/features/shopkeeper/widgets/shopkeeper_tools_grid.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/services/excel_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/features/settings/app_lock_settings_screen.dart';
import 'package:account_app/features/shopkeeper/sales_analytics_screen.dart';
import 'currency_settings_dialog.dart';
import 'package:account_app/features/settings/backup_screen.dart';

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
      'https://play.google.com/store/apps/details?id=com.zalooq.account_app';
  static const String _supportEmail = 'karobarisaathi@gmail.com';

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
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (!width.isFinite || width <= 24) {
                return const SizedBox.shrink();
              }
              final itemWidth = (width - 24) / 4;
              final itemHeight = itemWidth / 1.1;
              final doubleWidth = (itemWidth * 2) + 8;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // 1. Sync — loading state
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: _isSyncing
                          ? PhosphorIcons.spinner()
                          : PhosphorIcons.cloudArrowUp(),
                      label: _isSyncing
                          ? (isUrdu ? 'سنک...' : 'Syncing')
                          : (isUrdu ? 'سنک' : 'Sync'),
                      isBusy: _isSyncing,
                      onTap:
                          _isSyncing ? null : () => _syncData(context, isUrdu),
                    ),
                  ),

                  // 2. Report — 3 options
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.filePdf(),
                      label: isUrdu ? 'رپورٹ' : 'Report',
                      onTap: () =>
                          _showExportDialog(context, isUrdu, fontFamily),
                    ),
                  ),

                  // 3. Backup
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.database(),
                      label: isUrdu ? 'بیک اپ' : 'Backup',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BackupScreen()),
                        );
                      },
                    ),
                  ),

                  // 4. Sales Analytics
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
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
                  ),

                  // 5. Share — with Play Store link
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.shareNetwork(),
                      label: isUrdu ? 'شیئر' : 'Share',
                      onTap: () => _shareApp(context, isUrdu),
                    ),
                  ),

                  // 6. About — with support contact
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.info(),
                      label: isUrdu ? 'معلومات' : 'About',
                      onTap: () =>
                          _showAboutAppDialog(context, isUrdu, fontFamily),
                    ),
                  ),

                  // 7. Privacy
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.shieldCheck(),
                      label: isUrdu ? 'پرائیویسی' : 'Privacy',
                      onTap: () =>
                          _showPrivacyPolicy(context, isUrdu, fontFamily),
                    ),
                  ),

                  // 8. Logout — with sync warning
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.signOut(),
                      label: isUrdu ? 'لاگ آؤٹ' : 'Logout',
                      onTap: () =>
                          _showLogoutDialog(context, isUrdu, fontFamily),
                    ),
                  ),

                  // 9. Security settings
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.lock(),
                      label: isUrdu ? 'سیکیورٹی' : 'Security',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AppLockSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  // 10. Request account deletion
                  SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildItem(
                      context,
                      icon: PhosphorIcons.userMinus(),
                      label: isUrdu ? 'اکاؤنٹ حذف' : 'Delete account',
                      onTap: () =>
                          _showDeactivateDialog(context, isUrdu, fontFamily),
                    ),
                  ),

                  // 11. Language & Currency Settings (Double Width - 2 columns span)
                  SizedBox(
                    width: doubleWidth,
                    height: itemHeight,
                    child: _buildDoubleWidthItem(
                      context,
                      icon: PhosphorIcons.currencyCircleDollar(),
                      label: isUrdu ? 'زبان اور کرنسی' : 'Language & Currency',
                      onTap: () => CurrencySettingsDialog.show(
                          context, isUrdu, fontFamily),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DOUBLE WIDTH ITEM BUILDER
  // ═══════════════════════════════════════════════════════════
  Widget _buildDoubleWidthItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: UrduAwareText(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    if (!mounted || !context.mounted) return;
    if (connectivity.contains(ConnectivityResult.none)) {
      AppToast.warning(
        context,
        isUrdu
            ? 'انٹرنیٹ نہیں ہے، پہلے کنیکٹ کریں'
            : 'No internet, connect first',
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final syncService = Provider.of<AutoSyncService>(context, listen: false);
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
  void _showExportDialog(BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(PhosphorIcons.filePdf(), size: 20, color: AppTheme.themeColor),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              sub: isUrdu ? 'موجودہ اسٹاک اور مالیت' : 'Current stock & value',
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
            const SizedBox(height: 8),
            _buildReportOption(
              icon: PhosphorIcons.calendar(),
              color: AppTheme.purpleColor,
              title: isUrdu ? 'سالانہ رپورٹ (سال)' : 'Yearly Report (Year)',
              sub: isUrdu ? 'رواں سال کا مکمل ریکارڈ' : 'Current year record',
              isUrdu: isUrdu,
              fontFamily: fontFamily,
              onTap: () => _exportReport(
                context,
                dialogContext,
                isUrdu,
                fontFamily,
                type: 'yearly',
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: isUrdu ? 'بند کریں' : 'Close',
              color: AppTheme.themeColor,
              isFullWidth: true,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
        actions: const [],
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            AppButton(
              text: isUrdu ? 'منسوخ کریں' : 'Cancel',
              color: AppTheme.themeColor,
              isFullWidth: true,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        actions: const [],
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
      final excelService = Provider.of<ExcelService>(context, listen: false);
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
        case 'yearly':
          final currentYear = DateTime.now().year;
          final yearlyTransactions = databaseService.transactions
              .where((t) => t.date.year == currentYear)
              .toList();
          if (format == 'pdf') {
            await pdfService.generateSalesReport(
              yearlyTransactions,
              isUrdu,
            );
          } else {
            await excelService.generateSalesCsv(
              yearlyTransactions,
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        child: Image.asset('assets/images/icons/zalooq.png'),
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
                      isUrdu ? 'آپ کا ڈیٹا محفوظ ہے' : 'Your data is secure',
                      isUrdu,
                      fontFamily,
                    ),
                    const Divider(),
                    _buildAboutItem(
                      PhosphorIcons.cloudArrowUp(),
                      isUrdu ? 'آٹو کلاؤڈ سنک' : 'Auto Cloud Sync',
                      isUrdu ? 'آن لائن بیک اپ' : 'Online backup',
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
                      onTap: () => _launchUrl(_playStoreUrl, context, isUrdu),
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

  Widget _buildAboutItem(
      IconData icon, String title, String sub, bool isUrdu, String fontFamily) {
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
                    color: Colors.grey, fontSize: 12, fontFamily: fontFamily),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url, BuildContext context, bool isUrdu) async {
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
    final policyText = isUrdu
        ? [
            'کاروباری ساتھی (Account App) دکانداروں اور کاروباری افراد کے کھاتوں، لین دین، اسٹاک اور مزدوروں کی اجرت کے ریکارڈ سنبھالنے کے لیے ہے۔ یہ پالیسی بتاتی ہے کہ ایپ کون سا ڈیٹا استعمال کرتی ہے۔',
            'مؤثر تاریخ: 27 نومبر 2026',
            '1. جمع ہونے والا ڈیٹا\nاکاؤنٹ کے لیے فون نمبر اور SMS تصدیقی کوڈ استعمال ہوتے ہیں۔ آپ کا نام، ای میل، دکان کا نام، پیشہ، تصویر اور ہاتھ سے درج کردہ کاروباری پتہ بھی محفوظ ہو سکتے ہیں۔ ای میل اختیاری ہے، لیکن کلاؤڈ بیک اپ بنانے کے لیے پروفائل میں ای میل درج ہونا ضروری ہے۔\nآپ کے درج کردہ کاروباری ریکارڈ میں گاہکوں/سپلائرز کے نام، فون نمبر اور پتے، لین دین کی رقوم، تاریخیں، نوٹس، اسٹاک، معاہدے، مزدوروں کی حاضری/اجرت اور اپ لوڈ کی گئی تصاویر شامل ہو سکتی ہیں۔ رابطے صرف اس وقت پڑھے جاتے ہیں جب آپ کسی رابطے کو خود منتخب کرتے ہیں۔',
            '2. ڈیٹا کا استعمال\nیہ معلومات فون نمبر کے ذریعے اکاؤنٹ کی تصدیق، کاروباری ریکارڈ سنبھالنے، ایپ کے سنک فنکشن کے چلنے پر متعلقہ ڈیٹا کلاؤڈ سے ملانے، آپ کی درخواست پر بیک اپ/ریسٹور، پروفائل اور دکان کی معلومات دکھانے، اور متعلقہ مزدور کو اجرت کے اندراج کی اطلاع دینے کے لیے استعمال ہوتی ہیں۔',
            '3. مقامی اور کلاؤڈ اسٹوریج\nایپ کاروباری ریکارڈ فون پر مقامی ڈیٹا بیس میں رکھتی ہے۔ اکاؤنٹس، لین دین اور کچھ دیگر ریکارڈ سنک کے ذریعے Firebase پر بھی جا سکتے ہیں؛ بیک اپ آپ کی درخواست پر Firebase میں محفوظ ہوتا ہے۔ ایپ کی بعض ترتیبات SharedPreferences اور ایپ لاک کی حساس معلومات ڈیوائس کے محفوظ اسٹوریج میں رکھی جاتی ہیں۔',
            '4. رسائی اور شیئرنگ\nآپ کے نجی کھاتے اور لین دین عموماً آپ کے اکاؤنٹ تک محدود ہیں۔ اگر مزدور کا فون نمبر ایپ اکاؤنٹ سے مل جائے تو اجرت کا مخصوص اندراج اس مزدور کے اکاؤنٹ میں بھی نقل ہو سکتا ہے۔ اس میں رقم، تاریخ، اندراج کی تفصیل، آپ کا نام اور فون نمبر شامل ہو سکتے ہیں۔ سائن اِن صارفین آپ کا تصدیق شدہ فون نمبر، نام، تصویر، پیشہ، کاروباری پتہ اور دکان کا نام دیکھ سکتے ہیں۔ دکان کی معلومات، آئٹمز اور ریویوز بھی سائن اِن صارفین کو نظر آ سکتے ہیں۔ Firebase/Google اکاؤنٹ اور کلاؤڈ ہوسٹنگ فراہم کرتے ہیں۔',
            '5. بیک اپ اور ریسٹور\nکلاؤڈ بیک اپ بنانے کے لیے پروفائل میں ای میل درکار ہے۔ بیک اپ میں آپ کے کاروباری ریکارڈ کی نقل شامل ہو سکتی ہے اور اسے آپ کے اکاؤنٹ سے جوڑا جاتا ہے؛ بیک اپ آن کرنے سے پہلے یقینی بنائیں کہ آپ کو یہ سہولت درکار ہے۔',
            '6. ڈیٹا رکھنے اور اکاؤنٹ حذف کرنے کی مدت\nایپ کی سیٹنگز سے اکاؤنٹ حذف کرنے کی درخواست دی جا سکتی ہے۔ درخواست پر اکاؤنٹ فوراً غیر فعال ہوتا ہے اور 30 دن کے اندر دوبارہ لاگ اِن کر کے بحال کیا جا سکتا ہے۔ اس مدت میں دکان کی کچھ معلومات سائن اِن صارفین کو نظر آ سکتی ہیں۔ 30 دن بعد کلاؤڈ اکاؤنٹ، متعلقہ ریکارڈ، بیک اپ اور اپ لوڈ کردہ فائلیں حذف کرنے کے لیے سرور پر شیڈول ہوتی ہیں۔ [تصدیق درکار: سرور فنکشنز کی deployment اور 30 دن بعد حذف ہونے کے عمل کی عملی جانچ] پہلے ورژن میں بنائی گئی کوئی marketplace لسٹنگ، اگر موجود ہو، اکاؤنٹ حذف ہونے تک نجی طور پر باقی رہ سکتی ہے۔ دوسرے صارفین کے اپنے ریکارڈ میں محفوظ کی گئی آزاد نقلیں بھی باقی رہ سکتی ہیں۔',
            '7. اجازتیں اور مقام\nکیمرہ تصاویر لینے یا اسکین کرنے، Contacts منتخب رابطہ چننے، Internet کلاؤڈ سروسز کے لیے، اور biometric اجازت ایپ لاک کے لیے استعمال ہوتی ہے۔ ایپ GPS، لوکیشن اجازت، نقشہ، آن لائن ایڈریس تلاش یا آڈیو ریکارڈنگ استعمال نہیں کرتی؛ کاروباری پتہ صرف آپ کے ہاتھ سے درج کرنے پر محفوظ ہوتا ہے۔ پہلے ورژن کے محفوظ کردہ کوآرڈینیٹس، اگر موجود ہوں، پروفائل محفوظ کرنے یا اکاؤنٹ حذف ہونے تک کلاؤڈ میں رہ سکتے ہیں۔',
            '8. بچوں کا ڈیٹا\nیہ ایپ کاروباری استعمال کے لیے ہے، بچوں کے لیے نہیں بنائی گئی، اور ایپ میں عمر کی جانچ موجود نہیں۔ [تصدیق درکار: کم از کم عمر اور بچوں کے ڈیٹا سے متعلق قانونی پالیسی]',
            '9. سیکیورٹی\nایپ Firebase سروسز اور Firestore rules استعمال کرتی ہے۔ پروفائل اور دکان کی اوپر بیان کردہ معلومات دوسرے سائن اِن صارفین کو دکھائی جاتی ہیں۔ ایپ لاک اور biometric ڈیوائس پر رسائی کنٹرول کے لیے ہیں؛ یہ تمام کاروباری ریکارڈز کی الگ انکرپشن کی ضمانت نہیں۔ [تصدیق درکار: Firebase کنسول کی سیکیورٹی اور سرور/بیک اپ کی ترتیبات]',
            '10. پالیسی میں تبدیلی اور رابطہ\nپالیسی میں تبدیلی ہو تو ایپ یا متعلقہ صفحے پر نظرثانی شدہ تاریخ کے ساتھ اپ ڈیٹ کیا جائے گا۔ سوال یا ڈیٹا سے متعلق درخواست کے لیے اس ای میل پر رابطہ کریں:',
            'قانونی نوٹ: یہ پالیسی قانونی مشورہ نہیں ہے۔ اشاعت سے پہلے کسی مستند وکیل سے اس کا جائزہ کروائیں۔',
          ].join('\n\n')
        : [
            'Karobari Saathi (Account App) helps shopkeepers and business owners manage accounts, transactions, inventory and worker wage records. This policy explains what information the app uses.',
            'Effective date: November 27, 2026',
            '1. Information we collect\nYour phone number and SMS verification code are used for account authentication. Your name, email, shop name, profession, photo and manually entered business address may also be stored. Email is optional for the account, but is required in your profile to create a cloud backup.\nBusiness records you enter may include customer/supplier names, phone numbers and addresses, transaction amounts, dates and notes, inventory, contracts, worker attendance/payroll, and uploaded images. Contacts are accessed only when you choose a contact.',
            '2. How we use information\nWe use this information to authenticate your account by phone, manage business records, sync relevant data to the cloud when the app sync function runs, create or restore a backup at your request, display profile and shop information, and notify the relevant worker about a wage entry.',
            '3. Local and cloud storage\nThe app stores business records in a local database on your device. Accounts, transactions and some other records may also be synced to Firebase; a backup is stored in Firebase when you request one. Some app settings are stored in SharedPreferences; sensitive app-lock information is kept in the device secure storage.',
            '4. Access and sharing\nYour private accounts and transactions are generally limited to your account. If a worker’s phone number matches an app account, a specific wage entry may also be copied to that worker’s account. It may include the amount, date, entry description, your name and phone number. Signed-in users can see your verified phone number, name, photo, profession, business address and shop name. Shop information, items and reviews may also be visible to signed-in users. Firebase/Google provide account and cloud-hosting services.',
            '5. Backup and restore\nAn email address in your profile is required to create a cloud backup. A backup may contain copies of your business records and is associated with your account. Enable this feature only if you want cloud backups.',
            '6. Retention and account deletion\nYou can request account deletion in Settings. The account is disabled immediately and can be restored by signing in within 30 days. Some shop information may remain visible to signed-in users during this period. After 30 days, the server is configured to schedule deletion of the cloud account, associated records, backups and uploaded files. [Verification required: confirm the server functions are deployed and the 30-day deletion process has been tested.] Any marketplace listings created in an earlier version, if present, may remain private until account deletion. Independent copies that other users keep in their own records may also remain.',
            '7. Permissions and location\nCamera is used to take photos or scan; Contacts to choose a contact; Internet for cloud services; and biometric permission for the app lock. The app does not use GPS, location permission, maps, online address lookup or audio recording; a business address is stored only when you enter it manually. Coordinates saved by an earlier version, if any, may remain in cloud storage until you save your profile or account deletion completes.',
            '8. Children’s information\nThis app is intended for business use and is not designed for children. The app does not verify users’ ages. [Verification required: set the minimum age and confirm the legal policy for children’s data.]',
            '9. Security\nThe app uses Firebase services and Firestore rules. The profile and shop information described above is visible to other signed-in users. App lock and biometrics control access on your device; they do not mean that all business records are separately encrypted. [Verification required: confirm Firebase Console security and server/backup settings.]',
            '10. Changes and contact\nWe may update this policy and show the revised date in the app or on the related page. For questions or data requests, contact:',
            'Legal note: This policy is not legal advice. Have it reviewed by a qualified lawyer before publication.',
          ].join('\n\n');
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
                policyText,
                style: TextStyle(
                    fontFamily: isUrdu ? fontFamily : null, fontSize: 13),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _launchUrl(
                  'mailto:$_supportEmail',
                  context,
                  isUrdu,
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.envelope(),
                      size: 16,
                      color: AppTheme.themeColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _supportEmail,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppTheme.themeColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            text: isUrdu ? 'بند' : 'Close',
            variant: AppButtonVariant.outlined,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 9. LOGOUT — with sync warning
  // ═══════════════════════════════════════════════════════════
  void _showLogoutDialog(BuildContext context, bool isUrdu, String fontFamily) {
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
                          ? 'بغیر سنک لاگ آؤٹ کرنے سے اس فون کا غیر سنک شدہ ڈیٹا حذف ہو سکتا ہے'
                          : 'Logging out without syncing may remove unsynced data from this device.',
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
              try {
                await Provider.of<AuthService>(context, listen: false)
                    .signOut(context);
              } catch (error) {
                if (context.mounted) {
                  AppToast.error(context, 'Could not complete logout: $error');
                }
              }
            },
            child: UrduAwareText(
              isUrdu ? 'بغیر سنک لاگ آؤٹ' : 'Logout without syncing',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          // ⭐ Sync + Logout
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await Provider.of<AuthService>(context, listen: false)
                    .signOut(context, syncBeforeLogout: true);
              } catch (error) {
                if (context.mounted) {
                  AppToast.error(
                    context,
                    isUrdu
                        ? 'سنک ناکام ہوا، آپ لاگ آؤٹ نہیں ہوئے: $error'
                        : 'Sync failed; you are still signed in: $error',
                  );
                }
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
  // 14. ACCOUNT DELETION
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
              isUrdu
                  ? 'اکاؤنٹ حذف کرنے کی درخواست'
                  : 'Request account deletion',
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
                  ? 'اکاؤنٹ فوراً غیر فعال ہو گا۔ 30 دن کے اندر لاگ اِن کر کے بحال کریں؛ اس کے بعد اکاؤنٹ، کلاؤڈ ریکارڈ، بیک اپ اور اپ لوڈ کی گئی فائلیں مستقل حذف کرنے کے لیے شیڈول ہوں گی۔'
                  : 'Your account will be disabled immediately. Sign in within 30 days to restore it; afterward, the account, cloud records, backups and uploaded files will be scheduled for permanent deletion.',
              style: TextStyle(fontFamily: fontFamily, fontSize: 12),
            ),
            const SizedBox(height: 12),
            UrduAwareText(
              isUrdu
                  ? 'تصدیق کے لیے "DELETE" لکھیں:'
                  : 'Type "DELETE" to confirm:',
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  await Provider.of<AuthService>(context, listen: false)
                      .requestAccountDeletion(context, isUrdu: isUrdu);
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, 'Error: $e');
                }
              }
            },
            child: UrduAwareText(
              isUrdu ? 'اکاؤنٹ حذف کریں' : 'Delete account',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
