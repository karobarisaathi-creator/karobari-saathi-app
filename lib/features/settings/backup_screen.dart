// backup_screen.dart
import 'package:flutter/material.dart';
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
import 'package:account_app/features/settings/master_profile_screen.dart';

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
    setState(() => _isLoading = true);

    try {
      _backupInfo = await _backupService.getBackupInfo();

      // Get additional stats from database
      final accounts = await _databaseService.getAccounts();
      final transactions = await _databaseService.getAllTransactions();

      _backupInfo['totalAccounts'] = accounts.length;
      _backupInfo['totalTransactions'] = transactions.length;
    } catch (e) {
      print('Error loading backup info: $e');
    } finally {
      setState(() => _isLoading = false);
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
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
                  icon: const Icon(Icons.edit, size: 16, color: AppTheme.themeColor),
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
              Icons.email,
              AppTheme.purpleColor,
              isUrdu,
            ),

            _buildStatusItem(
              isUrdu ? 'آخری بیک اپ:' : 'Last Backup:',
              lastBackup != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(lastBackup)
                  : isUrdu
                  ? 'کبھی نہیں'
                  : 'Never',
              Icons.backup,
              AppTheme.incomeColor,
              isUrdu,
            ),

            _buildStatusItem(
              isUrdu ? 'آخری بحالی:' : 'Last Restore:',
              lastRestore != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(lastRestore)
                  : isUrdu
                  ? 'کبھی نہیں'
                  : 'Never',
              Icons.restore,
              AppTheme.themeColor,
              isUrdu,
            ),

            _buildStatusItem(
              isUrdu ? 'بیک اپ سائز:' : 'Backup Size:',
              _formatFileSize(_backupInfo['backupSize'] ?? 0),
              Icons.storage,
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
                    isUrdu ? 'اکاؤنٹس' : 'Accounts',
                    _backupInfo['totalAccounts']?.toString() ?? '0',
                    Icons.people,
                    AppTheme.incomeColor,
                    isUrdu,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    isUrdu ? 'لین دین' : 'Transactions',
                    _backupInfo['totalTransactions']?.toString() ?? '0',
                    Icons.account_balance_wallet,
                    AppTheme.themeColor,
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
              icon: Icons.cloud_upload,
              color: AppTheme.incomeColor,
              size: AppButtonSize.large,
              isLoading: _isBackingUp,
              isFullWidth: true,
              onPressed: _createCloudBackup,
            ),

            const SizedBox(height: 12),

            AppButton(
              text: isUrdu ? 'کلاؤڈ سے بحالی کریں' : 'Restore from Cloud',
              icon: Icons.cloud_download,
              color: AppTheme.themeColor,
              size: AppButtonSize.large,
              isLoading: _isRestoring,
              isFullWidth: true,
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
                      return const Icon(Icons.check, size: 14, color: Colors.white);
                    }
                    return const Icon(Icons.close, size: 14, color: Colors.grey);
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
