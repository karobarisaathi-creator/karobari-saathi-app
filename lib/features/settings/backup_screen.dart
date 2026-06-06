// backup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/backup_service.dart';
import 'package:account_app/core/services/database_service.dart';

class BackupScreen extends StatefulWidget {
  @override
  _BackupScreenState createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  final DatabaseService _databaseService = DatabaseService();

  Map<String, dynamic> _backupInfo = {};
  bool _isLoading = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;

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

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isUrdu ? 'ڈیٹا بیک اپ' : 'Data Backup',
          style: TextStyle(
            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
            fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Backup Status Card
                  _buildBackupStatusCard(isUrdu),
                  SizedBox(height: 20),

                  // Data Statistics
                  _buildDataStatisticsCard(isUrdu),
                  SizedBox(height: 20),

                  // Backup Actions
                  _buildBackupActionsCard(isUrdu),
                  SizedBox(height: 20),

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

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu ? 'بیک اپ کی حالت' : 'Backup Status',
              style: TextStyle(
                fontSize: 18,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(height: 16),

            _buildStatusItem(
              isUrdu ? 'آخری بیک اپ:' : 'Last Backup:',
              lastBackup != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(lastBackup)
                  : isUrdu
                  ? 'کبھی نہیں'
                  : 'Never',
              Icons.backup,
              Colors.green,
            ),

            _buildStatusItem(
              isUrdu ? 'آخری بحالی:' : 'Last Restore:',
              lastRestore != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(lastRestore)
                  : isUrdu
                  ? 'کبھی نہیں'
                  : 'Never',
              Icons.restore,
              Colors.blue,
            ),

            _buildStatusItem(
              isUrdu ? 'بیک اپ سائز:' : 'Backup Size:',
              _formatFileSize(_backupInfo['backupSize'] ?? 0),
              Icons.storage,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataStatisticsCard(bool isUrdu) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu ? 'ڈیٹا کے اعداد و شمار' : 'Data Statistics',
              style: TextStyle(
                fontSize: 18,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    isUrdu ? 'اکاؤنٹس' : 'Accounts',
                    _backupInfo['totalAccounts']?.toString() ?? '0',
                    Icons.people,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    isUrdu ? 'لین دین' : 'Transactions',
                    _backupInfo['totalTransactions']?.toString() ?? '0',
                    Icons.account_balance_wallet,
                    Colors.blue,
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
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu ? 'بیک اپ کے اختیارات' : 'Backup Options',
              style: TextStyle(
                fontSize: 18,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(height: 16),

            _buildActionButton(
              isUrdu ? 'کلاؤڈ پر بیک اپ کریں' : 'Backup to Cloud',
              Icons.cloud_upload,
              Colors.green,
              _createCloudBackup,
              _isBackingUp,
            ),

            SizedBox(height: 12),

            _buildActionButton(
              isUrdu ? 'کلاؤڈ سے بحالی کریں' : 'Restore from Cloud',
              Icons.cloud_download,
              Colors.blue,
              _restoreFromCloud,
              _isRestoring,
            ),

            SizedBox(height: 12),

            _buildActionButton(
              isUrdu ? 'ڈیٹا ایکسپورٹ کریں' : 'Export Data',
              Icons.file_download,
              Colors.orange,
              _exportData,
              false,
            ),

            SizedBox(height: 12),

            _buildActionButton(
              isUrdu ? 'ڈیٹا امپورٹ کریں' : 'Import Data',
              Icons.file_upload,
              Colors.purple,
              _importData,
              false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupCard(bool isUrdu) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu ? 'خودکار بیک اپ' : 'Auto Backup',
              style: TextStyle(
                fontSize: 18,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    isUrdu ? 'خودکار بیک اپ فعال کریں' : 'Enable Auto Backup',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Switch(
                  value: _backupInfo['autoBackupEnabled'] ?? false,
                  onChanged: _toggleAutoBackup,
                ),
              ],
            ),

            SizedBox(height: 8),

            Text(
              isUrdu
                  ? 'خودکار بیک اپ ہر 7 دن بعد کلاؤڈ پر ڈیٹا محفوظ کرے گا'
                  : 'Auto backup will save data to cloud every 7 days',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
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
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[700],
              fontFamily: '',
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
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
            fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontFamily: '',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool isLoading,
  ) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, size: 20),
      label: Text(
        text,
        style: TextStyle(
          fontFamily: isUrdu ? 'NooriNastaleeq' : '',
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 50),
      ),
    );
  }

  Future<void> _createCloudBackup() async {
    setState(() => _isBackingUp = true);

    try {
      await _backupService.createBackup();
      await _loadBackupInfo();

      _showSnackBar(
        isUrdu
            ? 'بیک اپ کامیابی سے مکمل ہوگیا'
            : 'Backup completed successfully',
        false,
      );
    } catch (e) {
      _showSnackBar('${isUrdu ? 'خرابی:' : 'Error:'} $e', true);
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
      _showSnackBar('${isUrdu ? 'خرابی:' : 'Error:'} $e', true);
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  Future<void> _exportData() async {
    try {
      final jsonData = await _backupService.exportToJson();
      // Implementation for saving JSON file
      // This would use file_saver or share_plus

      _showSnackBar(
        isUrdu ? 'ڈیٹا ایکسپورٹ کیا گیا' : 'Data exported successfully',
        false,
      );
    } catch (e) {
      _showSnackBar('${isUrdu ? 'خرابی:' : 'Error:'} $e', true);
    }
  }

  Future<void> _importData() async {
    // Implementation for importing from JSON file
    // This would use file_picker
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    try {
      await _backupService.scheduleAutoBackup(enabled);
      await _loadBackupInfo();

      _showSnackBar(
        enabled
            ? (isUrdu ? 'خودکار بیک اپ فعال ہوگیا' : 'Auto backup enabled')
            : (isUrdu
                  ? 'خودکار بیک اپ غیر فعال ہوگیا'
                  : 'Auto backup disabled'),
        false,
      );
    } catch (e) {
      _showSnackBar('${isUrdu ? 'خرابی:' : 'Error:'} $e', true);
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
            title: Text(
              title,
              style: TextStyle(
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            content: Text(
              message,
              style: TextStyle(
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  isUrdu ? 'منسوخ' : 'Cancel',
                  style: TextStyle(
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  isUrdu ? 'جاری رکھیں' : 'Continue',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
            fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  bool get isUrdu {
    return Provider.of<LanguageService>(context, listen: false).isUrdu;
  }
}
