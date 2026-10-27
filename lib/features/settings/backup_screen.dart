// backup_screen.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/backup_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:hive/hive.dart';

import 'package:account_app/core/models/stock_item_model.dart';
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
  final BackupService _backupService = BackupService();
  final DatabaseService _databaseService = DatabaseService();

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
      _backupInfo = await _backupService.getBackupInfo();

      final accounts = _databaseService.getAccounts();
      final transactions = _databaseService.getAllTransactions();

      final stockBox = Hive.isBoxOpen('stock_items') ? Hive.box<StockItem>('stock_items') : await Hive.openBox<StockItem>('stock_items');
      final categoriesBox = Hive.isBoxOpen('categories') ? Hive.box<Category>('categories') : await Hive.openBox<Category>('categories');
      final professionsBox = Hive.isBoxOpen('professions') ? Hive.box<Profession>('professions') : await Hive.openBox<Profession>('professions');

      _backupInfo['totalAccounts'] = accounts.length;
      _backupInfo['totalTransactions'] = transactions.length;
      _backupInfo['totalStockItems'] = stockBox.length;
      _backupInfo['totalCategories'] = categoriesBox.length + professionsBox.length;
    } catch (_) {
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
    final isUrdu = languageService.isUrdu;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'ڈیٹا بیک اپ' : 'Data Backup',
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
              child: Column(
                children: [
                  // Backup Status Card
                  _buildBackupStatusCard(isUrdu),
                  const SizedBox(height: 6),

                  // Data Statistics
                  _buildDataStatisticsCard(isUrdu),
                  const SizedBox(height: 6),

                  // Backup Actions
                  _buildBackupActionsCard(isUrdu),
                  const SizedBox(height: 6),

                  // Auto Backup Settings
                  _buildAutoBackupCard(isUrdu),
                ],
              ),
            ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      child: Column(
        children: [
          // Shimmer 1: Status Card
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonShimmer(width: 130, height: 20, borderRadius: 8),
                      SkeletonShimmer(width: 90, height: 16, borderRadius: 6),
                    ],
                  ),
                  SizedBox(height: 16),
                  SkeletonShimmer(width: double.infinity, height: 40, borderRadius: 12),
                  SizedBox(height: 10),
                  SkeletonShimmer(width: double.infinity, height: 40, borderRadius: 12),
                  SizedBox(height: 10),
                  SkeletonShimmer(width: double.infinity, height: 40, borderRadius: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Shimmer 2: Data Stats Card
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonShimmer(width: 140, height: 18, borderRadius: 8),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: SkeletonShimmer(width: double.infinity, height: 60, borderRadius: 14)),
                      SizedBox(width: 10),
                      Expanded(child: SkeletonShimmer(width: double.infinity, height: 60, borderRadius: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Shimmer 3: Actions Card
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SkeletonShimmer(width: double.infinity, height: 48, borderRadius: 14),
                  SizedBox(height: 10),
                  SkeletonShimmer(width: double.infinity, height: 48, borderRadius: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupStatusCard(bool isUrdu) {
    final lastBackup = _backupInfo['lastBackup'];
    final lastRestore = _backupInfo['lastRestore'];
    final email = _backupInfo['email']?.toString() ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                UrduAwareText(
                  isUrdu ? 'بیک اپ کی حالت' : 'Backup Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                  ),
                ),
                TextButton.icon(
                  onPressed: _navigateToProfile,
                  icon: Icon(PhosphorIcons.pencilSimple(), size: 16, color: AppTheme.themeColor),
                  label: UrduAwareText(
                    isUrdu ? 'ای میل تبدیل کریں' : 'Change Email',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.themeColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildStatusItem(
              isUrdu ? 'بیک اپ ای میل:' : 'Backup Email:',
              email.isNotEmpty
                  ? email
                  : isUrdu
                  ? 'درج نہیں ہے (پروفائل میں جوڑیں)'
                  : 'Not set (Link in Profile)',
              PhosphorIcons.envelopeSimple(),
              AppTheme.verifiedGold,
              isUrdu,
            ),

            _buildStatusItem(
              isUrdu ? 'آخری بیک اپ:' : 'Last Backup:',
              lastBackup != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(lastBackup)
                  : isUrdu
                  ? 'کبھی نہیں'
                  : 'Never',
              PhosphorIcons.cloudArrowUp(),
              AppTheme.verifiedGold,
              isUrdu,
            ),

            _buildStatusItem(
              isUrdu ? 'آخری بحالی:' : 'Last Restore:',
              lastRestore != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(lastRestore)
                  : isUrdu
                  ? 'کبھی نہیں'
                  : 'Never',
              PhosphorIcons.cloudArrowDown(),
              AppTheme.verifiedGold,
              isUrdu,
            ),

            _buildStatusItem(
              isUrdu ? 'بیک اپ سائز:' : 'Backup Size:',
              _formatFileSize(_backupInfo['backupSize'] ?? 0),
              PhosphorIcons.hardDrive(),
              AppTheme.verifiedGold,
              isUrdu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataStatisticsCard(bool isUrdu) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu ? 'ڈیٹا کے اعداد و شمار' : 'Data Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    isUrdu ? 'اکاؤنٹس / پارٹیاں' : 'Accounts',
                    _backupInfo['totalAccounts']?.toString() ?? '0',
                    PhosphorIcons.users(),
                    AppTheme.verifiedGold,
                    isUrdu,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    isUrdu ? 'لین دین / بل' : 'Transactions',
                    _backupInfo['totalTransactions']?.toString() ?? '0',
                    PhosphorIcons.receipt(),
                    AppTheme.verifiedGold,
                    isUrdu,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEF1F5)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    isUrdu ? 'اسٹاک اشیاء' : 'Stock Items',
                    _backupInfo['totalStockItems']?.toString() ?? '0',
                    PhosphorIcons.package(),
                    AppTheme.verifiedGold,
                    isUrdu,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    isUrdu ? 'زمرے و پروجیکٹس' : 'Categories',
                    _backupInfo['totalCategories']?.toString() ?? '0',
                    PhosphorIcons.folders(),
                    AppTheme.verifiedGold,
                    isUrdu,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupActionsCard(bool isUrdu) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu ? 'بیک اپ کے اختیارات' : 'Backup Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
            const SizedBox(height: 16),

            AppButton(
              text: isUrdu ? 'کلاؤڈ پر بیک اپ کریں' : 'Backup to Cloud',
              icon: PhosphorIcons.cloudArrowUp(),
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

            const SizedBox(height: 12),

            AppButton(
              text: isUrdu ? 'کلاؤڈ سے بحالی کریں' : 'Restore from Cloud',
              icon: PhosphorIcons.cloudArrowDown(),
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

  Widget _buildAutoBackupCard(bool isUrdu) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu ? 'خودکار بیک اپ' : 'Auto Backup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: UrduAwareText(
                    isUrdu ? 'خودکار بیک اپ فعال کریں' : 'Enable Auto Backup',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor,
                      fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                    ),
                  ),
                ),
                Switch.adaptive(
                  activeThumbColor: AppTheme.themeColor,
                  value: _backupInfo['autoBackupEnabled'] ?? false,
                  onChanged: _toggleAutoBackup,
                  thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Icon(PhosphorIcons.check(), size: 14, color: Colors.white);
                    }
                    return Icon(PhosphorIcons.x(), size: 14, color: Colors.grey);
                  }),
                ),
              ],
            ),

            const SizedBox(height: 8),

            UrduAwareText(
              isUrdu
                  ? 'خودکار بیک اپ ہر 7 دن بعد کلاؤڈ پر ڈیٹا محفوظ کرے گا'
                  : 'Auto backup will save data to cloud every 7 days',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isUrdu,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: UrduAwareText(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
          ),
          UrduAwareText(
            value,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isUrdu,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
          ),
        ),
        const SizedBox(height: 4),
        UrduAwareText(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkColor,
          ),
        ),
      ],
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
          ? (err.toLowerCase().contains('email') || err.toLowerCase().contains('profile') || err.toLowerCase().contains('ای میل')
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
      _showSnackBar(isUrdu ? 'ڈیٹا بحال کرنے میں خرابی: $err' : 'Restore error: $err', true);
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
          ? (err.toLowerCase().contains('email') || err.toLowerCase().contains('profile') || err.toLowerCase().contains('ای میل')
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: UrduAwareText(
                  isUrdu ? 'جاری رکھیں' : 'Continue',
                  style: TextStyle(
                    color: AppTheme.expenseColor,
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
