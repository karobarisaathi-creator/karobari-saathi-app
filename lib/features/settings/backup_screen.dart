// backup_screen.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/backup_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:hive/hive.dart';

import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/features/settings/master_profile_screen.dart';
import 'package:account_app/core/widgets/skeleton_shimmer.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final DatabaseService _databaseService = DatabaseService();

  BackupService get _backupService =>
      Provider.of<BackupService>(context, listen: false);

  Map<String, dynamic> _backupInfo = {};
  bool _isLoading = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  bool get isUrdu {
    return Provider.of<LanguageService>(context, listen: false).isUrdu;
  }

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final stockService = Provider.of<StockService>(context, listen: false);
      _backupInfo = await _backupService.getBackupInfo(
        stockItemCount: stockService.items.length,
        stockMovementCount: stockService.movements.length,
      );

      final accounts = _databaseService.getAccounts();
      final transactions = _databaseService.getAllTransactions();

      final categoriesBox = Hive.isBoxOpen('categories')
          ? Hive.box<Category>('categories')
          : await Hive.openBox<Category>('categories');
      final professionsBox = Hive.isBoxOpen('professions')
          ? Hive.box<Profession>('professions')
          : await Hive.openBox<Profession>('professions');

      _backupInfo['totalAccounts'] = accounts.length;
      _backupInfo['totalTransactions'] = transactions.length;
      _backupInfo['totalCategories'] =
          categoriesBox.length + professionsBox.length;
    } catch (e) {
      debugPrint('BackupScreen._loadBackupInfo failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MasterProfileScreen(),
      ),
    );
    await _loadBackupInfo();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final stockService = Provider.of<StockService>(context);
    final isUrdu = languageService.isUrdu;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ScreenAppBar(
        title: isUrdu ? 'کلاؤڈ بیک اپ اور ڈیٹا' : 'Cloud Backup & Sync',
        isUrdu: isUrdu,
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : RefreshIndicator(
              onRefresh: _loadBackupInfo,
              color: AppTheme.themeColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modern Hero Status Card
                    _buildModernBackupStatusCard(isUrdu),
                    const SizedBox(height: 8),

                    // Backup Actions Card
                    _buildModernBackupActionsCard(isUrdu),
                    const SizedBox(height: 8),

                    // Data Statistics Card
                    _buildModernDataStatisticsCard(isUrdu, stockService),
                    const SizedBox(height: 8),

                    // Auto Backup Settings Card
                    _buildModernAutoBackupCard(isUrdu),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SkeletonShimmer(width: double.infinity, height: 220, borderRadius: 20),
          const SizedBox(height: 8),
          SkeletonShimmer(width: double.infinity, height: 180, borderRadius: 20),
          const SizedBox(height: 8),
          SkeletonShimmer(width: double.infinity, height: 260, borderRadius: 20),
          const SizedBox(height: 8),
          SkeletonShimmer(width: double.infinity, height: 120, borderRadius: 20),
        ],
      ),
    );
  }

  Widget _buildModernBackupStatusCard(bool isUrdu) {
    final lastBackup = _backupInfo['lastBackup'];
    final lastRestore = _backupInfo['lastRestore'];
    final email = _backupInfo['email']?.toString() ?? '';
    final hasEmail = email.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.themeColor, AppTheme.incomeColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.themeColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        hasEmail ? PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill) : PhosphorIcons.cloudWarning(PhosphorIconsStyle.fill),
                        color: hasEmail ? Colors.greenAccent : Colors.amberAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          isUrdu ? 'کلاؤڈ سکیورٹی' : 'Cloud Status',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                          ),
                        ),
                        const SizedBox(height: 2),
                        UrduAwareText(
                          hasEmail
                              ? (isUrdu ? 'محفوظ اور فعال' : 'Protected & Active')
                              : (isUrdu ? 'ای میل درکار ہے' : 'Email Required'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _navigateToProfile,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), color: Colors.white, size: 16),
                  tooltip: isUrdu ? 'پروفائل میں ای میل تبدیل کریں' : 'Change Email in Profile',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.envelopeSimple(), color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UrduAwareText(
                      hasEmail ? email : (isUrdu ? 'ای میل درج نہیں ہے (پروفائل میں جوڑیں)' : 'Not set (Link in Profile)'),
                      style: TextStyle(
                        fontSize: 12,
                        color: hasEmail ? Colors.white : Colors.amberAccent,
                        fontWeight: FontWeight.w600,
                        fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderDetailItem(
                  isUrdu ? 'آخری بیک اپ' : 'Last Backup',
                  lastBackup != null
                      ? DateFormat('dd/MM/yy hh:mm a').format(lastBackup)
                      : (isUrdu ? 'کبھی نہیں' : 'Never'),
                  PhosphorIcons.cloudArrowUp(),
                  isUrdu,
                ),
                Container(width: 1, height: 30, color: Colors.white24),
                _buildHeaderDetailItem(
                  isUrdu ? 'آخری بحالی' : 'Last Restore',
                  lastRestore != null
                      ? DateFormat('dd/MM/yy hh:mm a').format(lastRestore)
                      : (isUrdu ? 'کبھی نہیں' : 'Never'),
                  PhosphorIcons.cloudArrowDown(),
                  isUrdu,
                ),
                Container(width: 1, height: 30, color: Colors.white24),
                _buildHeaderDetailItem(
                  isUrdu ? 'سائز' : 'Size',
                  _formatFileSize(_backupInfo['backupSize'] ?? 0),
                  PhosphorIcons.hardDrive(),
                  isUrdu,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderDetailItem(String label, String value, IconData icon, bool isUrdu) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 13),
              const SizedBox(width: 4),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                  fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          UrduAwareText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernBackupActionsCard(bool isUrdu) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(PhosphorIcons.cloudArrowUp(PhosphorIconsStyle.bold), color: AppTheme.themeColor, size: 18),
                ),
                const SizedBox(width: 10),
                UrduAwareText(
                  isUrdu ? 'بیک اپ اور بحالی کے اختیارات' : 'Cloud Synchronization',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            UrduAwareText(
              isUrdu
                  ? 'تمام کاروباری ڈیٹا، کسٹمر اکاؤنٹس، لین دین، مارکیٹ تصاویر اور کنٹریکٹ دستاویزات محفوظ کلاؤڈ پر محفوظ یا بحال کریں۔'
                  : 'Safely backup or restore your business ledger, customer accounts, transactions, and media files.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: isUrdu ? 'کلاؤڈ پر بیک اپ کریں' : 'Backup to Cloud',
              icon: PhosphorIcons.cloudArrowUp(PhosphorIconsStyle.bold),
              color: AppTheme.incomeColor,
              size: AppButtonSize.large,
              isLoading: _isBackingUp,
              isFullWidth: true,
              loadingTexts: isUrdu
                  ? [
                      'ڈیٹا تیار ہو رہا ہے...',
                      'کلاؤڈ پر اپ لوڈ ہو رہا ہے...',
                      'بیک اپ مکمل ہو رہا ہے...',
                    ]
                  : [
                      'Preparing data...',
                      'Uploading to cloud...',
                      'Finalizing backup...',
                    ],
              onPressed: _createCloudBackup,
            ),
            const SizedBox(height: 10),
            AppButton(
              text: isUrdu ? 'کلاؤڈ سے بحالی کریں' : 'Restore from Cloud',
              icon: PhosphorIcons.cloudArrowDown(PhosphorIconsStyle.bold),
              color: AppTheme.themeColor,
              size: AppButtonSize.large,
              isLoading: _isRestoring,
              isFullWidth: true,
              loadingTexts: isUrdu
                  ? [
                      'کلاؤڈ سے رابطہ کیا جا رہا ہے...',
                      'ڈیٹا ڈاؤن لوڈ ہو رہا ہے...',
                      'مقامی ڈیٹا بحال ہو رہا ہے...',
                    ]
                  : [
                      'Connecting to cloud...',
                      'Downloading data...',
                      'Restoring local database...',
                    ],
              onPressed: _restoreFromCloud,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDataStatisticsCard(bool isUrdu, StockService stockService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.verifiedGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(PhosphorIcons.chartBar(PhosphorIconsStyle.bold), color: AppTheme.verifiedGold, size: 18),
                ),
                const SizedBox(width: 10),
                UrduAwareText(
                  isUrdu ? 'ڈیٹا کے اعداد و شمار' : 'Data Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: [
                _buildStatTile(
                  isUrdu ? 'اکاؤنٹس / پارٹیاں' : 'Accounts',
                  _backupInfo['totalAccounts']?.toString() ?? '0',
                  PhosphorIcons.users(PhosphorIconsStyle.fill),
                  AppTheme.themeColor,
                  isUrdu,
                ),
                _buildStatTile(
                  isUrdu ? 'لین دین / بل' : 'Transactions',
                  _backupInfo['totalTransactions']?.toString() ?? '0',
                  PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                  AppTheme.incomeColor,
                  isUrdu,
                ),
                _buildStatTile(
                  isUrdu ? 'اسٹاک اشیاء' : 'Stock Items',
                  stockService.isLoading ? '…' : stockService.items.length.toString(),
                  PhosphorIcons.package(PhosphorIconsStyle.fill),
                  AppTheme.verifiedGold,
                  isUrdu,
                ),
                _buildStatTile(
                  isUrdu ? 'زمرے و پروجیکٹس' : 'Categories',
                  _backupInfo['totalCategories']?.toString() ?? '0',
                  PhosphorIcons.folders(PhosphorIconsStyle.fill),
                  AppTheme.purpleColor,
                  isUrdu,
                ),
                _buildStatTile(
                  isUrdu ? 'کنٹریکٹس' : 'Contracts',
                  _backupInfo['totalContracts']?.toString() ?? '0',
                  PhosphorIcons.fileText(PhosphorIconsStyle.fill),
                  AppTheme.slateColor,
                  isUrdu,
                ),
                _buildStatTile(
                  isUrdu ? 'مارکیٹ اشتہارات' : 'Market Listings',
                  _backupInfo['totalMarketplaceListings']?.toString() ?? '0',
                  PhosphorIcons.storefront(PhosphorIconsStyle.fill),
                  AppTheme.expenseColor,
                  isUrdu,
                ),
                _buildStatTile(
                  isUrdu ? 'حاضری و اجرت' : 'Attendance & Payroll',
                  _backupInfo['totalWorkerPayrollRecords']?.toString() ?? '0',
                  PhosphorIcons.userList(PhosphorIconsStyle.fill),
                  AppTheme.greenColor,
                  isUrdu,
                ),
                _buildStatTile(
                  isUrdu ? 'مزدور / کاریگر' : 'Workers',
                  _backupInfo['totalWorkers']?.toString() ?? '0',
                  PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
                  AppTheme.themeColor,
                  isUrdu,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color, bool isUrdu) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              UrduAwareText(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          UrduAwareText(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontFamily: isUrdu ? 'NooriNastaleeq' : '',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModernAutoBackupCard(bool isUrdu) {
    final autoBackupEnabled = _backupInfo['autoBackupEnabled'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.purpleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.bold), color: AppTheme.purpleColor, size: 18),
                ),
                const SizedBox(width: 10),
                UrduAwareText(
                  isUrdu ? 'خودکار بیک اپ' : 'Auto Backup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        isUrdu ? 'خودکار بیک اپ فعال کریں' : 'Enable Auto Backup',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor,
                          fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                        ),
                      ),
                      const SizedBox(height: 2),
                      UrduAwareText(
                        isUrdu
                            ? 'ایپ کھلنے پر، ہر 7 دن بعد خودکار کلاؤڈ بیک اپ ہوگا'
                            : 'Automatically syncs to cloud every 7 days on app launch',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  activeTrackColor: AppTheme.themeColor,
                  value: autoBackupEnabled,
                  onChanged: _toggleAutoBackup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCloudBackup() async {
    setState(() => _isBackingUp = true);

    try {
      await _backupService.createBackup(isUrdu: isUrdu);
      await _loadBackupInfo();

      final email = _backupInfo['email']?.toString() ?? '';
      _showSnackBar(
        isUrdu
            ? 'بیک اپ کامیابی سے مکمل ہو گیا اور ای میل ($email) سے جڑ گیا'
            : 'Backup completed successfully and linked to $email',
        false,
      );
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      final message = isUrdu
          ? (err.toLowerCase().contains('email') ||
                  err.toLowerCase().contains('profile') ||
                  err.toLowerCase().contains('ای میل')
              ? 'براہ کرم پہلے پروفائل میں ای میل درج کریں تاکہ بیک اپ جڑ سکے'
              : 'بیک اپ بنانے میں خرابی: $err')
          : err;
      _showSnackBar(message, true);
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final shouldRestore = await _showConfirmationDialog(
      isUrdu ? 'ڈیٹا بحالی' : 'Data Restore',
      isUrdu
          ? 'کیا آپ واقعی کلاؤڈ سے ڈیٹا بحال کرنا چاہتے ہیں؟ موجودہ ڈیٹا حذف ہو جائے گا۔'
          : 'Are you sure you want to restore data from cloud? Current data will be deleted.',
    );

    if (!shouldRestore) return;

    setState(() => _isRestoring = true);

    try {
      await _backupService.restoreBackup();
      await _loadBackupInfo();

      _showSnackBar(
        isUrdu ? 'ڈیٹا کامیابی سے بحال ہوگیا' : 'Data restored successfully',
        false,
      );
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      _showSnackBar(
          isUrdu ? 'ڈیٹا بحال کرنے میں خرابی: $err' : 'Restore error: $err',
          true);
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    try {
      await _backupService.scheduleAutoBackup(enabled, isUrdu: isUrdu);
      await _loadBackupInfo();

      final email = _backupInfo['email']?.toString() ?? '';
      if (enabled) {
        _showSnackBar(
          isUrdu
              ? 'خودکار بیک اپ فعال ہو گیا اور ای میل ($email) سے جڑ گیا'
              : 'Auto backup enabled and linked to $email',
          false,
        );
      } else {
        _showSnackBar(
          isUrdu ? 'خودکار بیک اپ غیر فعال ہوگیا' : 'Auto backup disabled',
          false,
        );
      }
    } catch (e) {
      await _loadBackupInfo();
      final err = e.toString().replaceAll('Exception: ', '');
      final message = isUrdu
          ? (err.toLowerCase().contains('email') ||
                  err.toLowerCase().contains('profile') ||
                  err.toLowerCase().contains('ای میل')
              ? 'خودکار بیک اپ فعال کرنے کے لیے پہلے پروفائل میں ای میل درج کریں'
              : 'خودکار بیک اپ میں خرابی: $err')
          : err;
      _showSnackBar(message, true);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: UrduAwareText(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
            content: UrduAwareText(
              message,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: UrduAwareText(
                  isUrdu ? 'منسوخ' : 'Cancel',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.expenseColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: UrduAwareText(
                  isUrdu ? 'جاری رکھیں' : 'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message, bool isError) {
    if (isError) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }
}
