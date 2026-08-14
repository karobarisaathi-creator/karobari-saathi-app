import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_verification_screen.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/theme_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/core/services/backup_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/services/excel_service.dart';
import 'package:account_app/core/services/verification_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'app_lock_screen.dart';
import 'verification_request_screen.dart';
import 'package:account_app/features/artisans/artisan_profile_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/utils/image_utils.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';

import 'package:account_app/features/artisans/customer_orders_screen.dart';
import 'package:account_app/features/settings/login_screen.dart'; // For navigation

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricHardwareAvailable = false;
  String _appVersion = '1.0.0';
  String? _address;
  String? _slogan;
  String? _storeName;
  String? _storeImage;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  Future<void> _loadSettingsData() async {
    final securityService =
        Provider.of<SecurityService>(context, listen: false);
    final isEnabled = await securityService.isAppLockEnabled();
    final isBioEnabled = await securityService.isBiometricEnabled();
    final isHardwareAvailable = await securityService.isBiometricsAvailable();
    final packageInfo = await PackageInfo.fromPlatform();

    // Fetch user profile extra data from Firestore
    String? address;
    String? slogan;
    String? storeName;
    String? storeImage;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        address = doc.data()?['address'];
        slogan = doc.data()?['slogan'];
        storeName = doc.data()?['storeName'];
        storeImage = doc.data()?['storeImage'];
        _isAdmin = VerificationService.canAccessAdminPanel(
          userData: doc.data(),
          uid: user.uid,
          email: user.email,
          phone: user.phoneNumber,
        );
      }
    }

    if (mounted) {
      setState(() {
        _isAppLockEnabled = isEnabled;
        _isBiometricEnabled = isBioEnabled;
        _isBiometricHardwareAvailable = isHardwareAvailable;
        _appVersion = packageInfo.version;
        _address = address;
        _slogan = slogan;
        _storeName = storeName;
        _storeImage = storeImage;
      });
    }
  }

  Widget _buildShimmerLoading() {
    return const _ShimmerBox(width: 74, height: 74);
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final dbService = Provider.of<DatabaseService>(context);

    final myAccount = dbService.getAccounts().firstWhere(
          (a) => a.phone == (user?.phoneNumber ?? ''),
          orElse: () => Account(
            id: 'me',
            name: user?.displayName ?? (isUrdu ? 'صارف' : 'User'),
            phone: user?.phoneNumber ?? '',
            profileImage: photoUrl,
            category: isUrdu ? 'دکاندار' : 'Shopkeeper',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            initialBalance: 0,
            balanceType: 'credit',
            balance: 0,
            isActive: true,
          ),
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'ترتیبات' : 'Settings',
        showBackButton: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // User Profile Card
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtisanProfileScreen(),
                ),
              ).then((_) => _loadSettingsData());
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.12),
                    width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ProfileInfoWidget(
                      name: user?.displayName ??
                          (isUrdu ? 'صارف کا نام' : 'User Name'),
                      phone: user?.phoneNumber ??
                          (isUrdu
                              ? 'معلومات دستیاب نہیں'
                              : 'Info not available'),
                      profileImage: photoUrl,
                      isLarge: true,
                      isVerified: myAccount.isVerified,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // More Icon
                  Icon(PhosphorIcons.caretRight(), color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Admin Panel
          if (_isAdmin) _buildAdminTile(isUrdu, fontFamily),

          const SizedBox(height: 12),

          // Verification Status Button
          Consumer<VerificationService>(
            builder: (context, vService, _) {
              return _buildVerificationBadge(vService, isUrdu, fontFamily);
            },
          ),

          const SizedBox(height: 12),

          // General Settings Section
          _buildSectionHeader(isUrdu ? 'عمومی ترتیبات' : 'General Settings',
              fontFamily, isUrdu),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.12),
                  width: 1),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  icon: PhosphorIcons.translate(),
                  title: isUrdu ? 'زبان' : 'Language',
                  onTap: () => _showLanguageDialog(context, languageService),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  trailing: Text(
                    isUrdu ? 'اردو' : 'English',
                    style: TextStyle(
                      color: AppTheme.themeColor,
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                      fontFamily: fontFamily,
                      fontSize: 16, // سائز مزید بڑھا دیا گیا
                    ),
                  ),
                  context: context,
                ),
                /* _buildDivider(context),
                _buildSettingItem(
                  icon: PhosphorIcons.moon(),
                  title: isUrdu ? 'ڈارک موڈ' : 'Dark Mode',
                  onTap: () {},
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  trailing: Consumer<ThemeService>(
                    builder: (context, themeService, child) {
                      return Switch(
                        value: themeService.themeMode == ThemeMode.dark,
                        activeColor: AppTheme.themeColor,
                        onChanged: (value) {
                          themeService.changeTheme(value ? 'dark' : 'light');
                        },
                      );
                    },
                  ),
                  context: context,
                ), */
                _buildDivider(context),
                _buildSettingItem(
                  icon: PhosphorIcons.lock(),
                  title: isUrdu ? 'ایپ لاک' : 'App Lock',
                  onTap: () => _toggleAppLock(context, isUrdu),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  trailing: Switch(
                    value: _isAppLockEnabled,
                    activeColor: AppTheme.themeColor,
                    onChanged: (value) => _toggleAppLock(context, isUrdu),
                  ),
                  context: context,
                ),
                if (_isAppLockEnabled) ...[
                  _buildDivider(context),
                  _buildSettingItem(
                    icon: PhosphorIcons.key(),
                    title: isUrdu ? 'پن کوڈ تبدیل کریں' : 'Change PIN',
                    onTap: () => _changePin(context, isUrdu),
                    fontFamily: fontFamily,
                    isUrdu: isUrdu,
                    context: context,
                  ),
                  if (_isBiometricHardwareAvailable) ...[
                    _buildDivider(context),
                    _buildSettingItem(
                      icon: PhosphorIcons.fingerprint(),
                      title: isUrdu ? 'بائیو میٹرک' : 'Biometric',
                      onTap: () => _toggleBiometric(context, isUrdu),
                      fontFamily: fontFamily,
                      isUrdu: isUrdu,
                      trailing: Switch(
                        value: _isBiometricEnabled,
                        activeColor: AppTheme.themeColor,
                        onChanged: (value) => _toggleBiometric(context, isUrdu),
                      ),
                      context: context,
                    ),
                  ],
                ],
                _buildDivider(context),
                _buildSettingItem(
                  icon: PhosphorIcons.clockCounterClockwise(),
                  title: isUrdu ? 'میرے کام کی ہسٹری' : 'My Job History',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomerOrdersScreen(),
                      ),
                    );
                  },
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  context: context,
                ),
                _buildDivider(context),
                _buildSettingItem(
                  icon: PhosphorIcons.cloudArrowUp(),
                  title: isUrdu ? 'ڈیٹا سینک' : 'Data Sync',
                  onTap: () => _syncData(context, isUrdu),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  context: context,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data Management Section
          _buildSectionHeader(
              isUrdu ? 'ڈیٹا مینجمنٹ' : 'Data Management', fontFamily, isUrdu),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.12),
                  width: 1),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  icon: PhosphorIcons.filePdf(),
                  title: isUrdu ? 'پی ڈی ایف رپورٹ' : 'PDF Report',
                  onTap: () => _showExportDialog(context, isUrdu),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  context: context,
                ),
                _buildDivider(context),
                _buildSettingItem(
                  icon: PhosphorIcons.database(),
                  title: isUrdu ? 'بیک اپ اور بحالی' : 'Backup & Restore',
                  onTap: () => _showBackupDialog(context, isUrdu),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  context: context,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Application Section
          _buildSectionHeader(
              isUrdu ? 'ایپلی کیشن' : 'Application', fontFamily, isUrdu),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.12),
                  width: 1),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  icon: PhosphorIcons.info(),
                  title: isUrdu ? 'ایپ کے بارے میں' : 'About App',
                  onTap: () => _showAboutAppDialog(context, isUrdu, fontFamily),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  context: context,
                ),
                _buildDivider(context),
                _buildSettingItem(
                  icon: PhosphorIcons.shareNetwork(),
                  title: isUrdu ? 'ایپ شیئر کریں' : 'Share App',
                  onTap: () => _shareApp(context, isUrdu),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  context: context,
                ),
                _buildDivider(context),
                _buildSettingItem(
                  icon: PhosphorIcons.shieldCheck(),
                  title: isUrdu ? 'پرائیویسی اور شرائط' : 'Privacy & Terms',
                  onTap: () => _showPrivacyPolicy(context, isUrdu, fontFamily),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  context: context,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Help Card
          InkWell(
            onTap: () => _contactUs(context, isUrdu),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade400),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.headset(),
                      size: 32, color: Colors.green.shade700),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isUrdu
                          ? 'ہم آپ کی کیسے مدد کر سکتے ہیں؟'
                          : 'How can we help you?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isUrdu ? FontWeight.bold : FontWeight.normal,
                        color: Colors.green.shade900,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Logout Button
          TextButton.icon(
            onPressed: () => _showLogoutDialog(context, isUrdu),
            icon: Icon(PhosphorIcons.signOut(), color: Colors.red),
            label: Text(
              isUrdu ? 'لاگ آؤٹ' : 'Logout',
              style: TextStyle(
                  color: Colors.red,
                  fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                  fontFamily: fontFamily),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showDeactivateDialog(context, isUrdu),
            icon: Icon(PhosphorIcons.userMinus(),
                color: Colors.red.withOpacity(0.7)),
            label: Text(
              isUrdu ? 'اکاؤنٹ ختم کریں' : 'Deactivate Account',
              style: TextStyle(
                  color: Colors.red.withOpacity(0.7),
                  fontSize: 13,
                  fontFamily: fontFamily),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAdminTile(bool isUrdu, String fontFamily) {
    final vService = Provider.of<VerificationService>(context, listen: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
        stream: vService.getPendingRequests(),
        builder: (context, snapshot) {
          final int count = snapshot.data?.length ?? 0;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.darkColor,
                AppTheme.darkColor.withOpacity(0.8)
              ]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.darkColor.withOpacity(0.2), blurRadius: 8)
              ],
            ),
            child: ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.admin_panel_settings,
                      color: AppTheme.verifiedGold, size: 28),
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Text(
                    isUrdu ? 'ایڈمن کنٹرول پینل' : 'Admin Control Panel',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily),
                  ),
                ],
              ),
              subtitle: Text(
                isUrdu
                    ? 'تصدیق کی درخواستیں ہینڈل کریں'
                    : 'Manage verification requests',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: fontFamily),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 14),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminVerificationScreen()));
              },
            ),
          );
        });
  }

  Widget _buildSectionHeader(String title, String fontFamily, bool isUrdu) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
          color: Theme.of(context).textTheme.bodySmall?.color,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(
      VerificationService service, bool isUrdu, String fontFamily) {
    Color bgColor;
    String statusText;
    IconData icon;
    bool showButton = false;

    switch (service.currentStatus) {
      case VerificationStatus.approved:
        bgColor = Colors.green.shade50;
        statusText =
            isUrdu ? 'آپ کا اکاؤنٹ تصدیق شدہ ہے' : 'Your account is verified';
        icon = Icons.verified;
        break;
      case VerificationStatus.pending:
        bgColor = Colors.orange.shade50;
        statusText = isUrdu ? 'تصدیق زیرِ التوا ہے' : 'Verification is pending';
        icon = Icons.hourglass_empty;
        break;
      case VerificationStatus.rejected:
        bgColor = Colors.red.shade50;
        statusText = isUrdu
            ? 'درخواست مسترد کر دی گئی${service.adminNote != null ? ': ${service.adminNote}' : ''}'
            : 'Verification rejected${service.adminNote != null ? ': ${service.adminNote}' : ''}';
        icon = Icons.error_outline;
        showButton = true;
        break;
      default:
        bgColor = AppTheme.verifiedGold.withOpacity(0.05);
        statusText =
            isUrdu ? 'اکاؤنٹ تصدیق کروائیں' : 'Get your account verified';
        icon = Icons.verified_user_outlined;
        showButton = true;
    }

    return InkWell(
      onTap: showButton
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const VerificationRequestScreen()),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.verifiedGold.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: service.currentStatus == VerificationStatus.approved
                    ? Colors.green
                    : (service.currentStatus == VerificationStatus.pending
                        ? Colors.orange
                        : AppTheme.verifiedGold),
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                ),
              ),
            ),
            if (showButton)
              Icon(PhosphorIcons.caretRight(),
                  size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required String fontFamily,
    required bool isUrdu,
    required BuildContext context,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).iconTheme.color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).textTheme.titleMedium?.color,
          fontFamily: fontFamily,
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: trailing ??
          Icon(PhosphorIcons.caretRight(),
              color: Theme.of(context).textTheme.bodySmall?.color, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context).dividerColor.withOpacity(0.12),
        indent: 50);
  }

  void _showEditProfileDialog(BuildContext context, bool isUrdu, User? user) {
    final nameController = TextEditingController(text: user?.displayName);
    final addressController = TextEditingController(text: _address);
    final sloganController = TextEditingController(text: _slogan);
    final storeNameController = TextEditingController(text: _storeName);
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    bool isUpdating = false;
    File? localImage;
    File? localStoreImage;
    int activeTab = 0; // 0 for Personal, 1 for Shop

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentUser = FirebaseAuth.instance.currentUser;
          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Custom Tab Switcher
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => activeTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 0
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: activeTab == 0
                                    ? [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4)
                                      ]
                                    : null,
                              ),
                              child: Text(
                                isUrdu ? 'ذاتی معلومات' : 'Personal',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: activeTab == 0
                                      ? AppTheme.themeColor
                                      : Colors.grey,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => activeTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 1
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: activeTab == 1
                                    ? [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4)
                                      ]
                                    : null,
                              ),
                              child: Text(
                                isUrdu ? 'دکان کی معلومات' : 'Shop Info',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: activeTab == 1
                                      ? AppTheme.themeColor
                                      : Colors.grey,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (activeTab == 0) ...[
                    // Personal Info Fields
                    _buildProfileImagePicker(
                      localImage: localImage,
                      currentUrl: currentUser?.photoURL,
                      isUrdu: isUrdu,
                      onTap: () async {
                        final img = await _pickAndCropImage(isUrdu);
                        if (img != null) setModalState(() => localImage = img);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                        nameController,
                        isUrdu ? 'آپ کا نام' : 'Full Name',
                        PhosphorIcons.user()),
                  ] else ...[
                    // Shop Info Fields
                    _buildProfileImagePicker(
                      localImage: localStoreImage,
                      currentUrl: _storeImage,
                      isUrdu: isUrdu,
                      onTap: () async {
                        final img = await _pickAndCropImage(isUrdu);
                        if (img != null)
                          setModalState(() => localStoreImage = img);
                      },
                      icon: PhosphorIcons.storefront(),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                        storeNameController,
                        isUrdu ? 'دکان کا نام' : 'Shop Name',
                        PhosphorIcons.storefront()),
                    const SizedBox(height: 16),
                    _buildTextField(sloganController,
                        isUrdu ? 'سلوگن' : 'Shop Slogan', PhosphorIcons.tag()),
                    const SizedBox(height: 16),
                    _buildTextField(
                        addressController,
                        isUrdu ? 'دکان کا پتہ' : 'Shop Address',
                        PhosphorIcons.mapPin(),
                        maxLines: 2),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isUpdating
                          ? null
                          : () async {
                              setModalState(() => isUpdating = true);
                              try {
                                String? finalPhotoUrl;
                                String? finalStoreImageUrl;

                                if (localImage != null) {
                                  finalPhotoUrl = await _uploadToStorage(
                                      currentUser!.uid, localImage!, 'profile');
                                }
                                if (localStoreImage != null) {
                                  finalStoreImageUrl = await _uploadToStorage(
                                      currentUser!.uid,
                                      localStoreImage!,
                                      'store');
                                }

                                await Provider.of<AuthService>(context,
                                        listen: false)
                                    .updateProfile(
                                  displayName: nameController.text.trim(),
                                  photoUrl: finalPhotoUrl,
                                  address: addressController.text.trim(),
                                  slogan: sloganController.text.trim(),
                                  storeName: storeNameController.text.trim(),
                                  storeImage: finalStoreImageUrl,
                                );

                                await currentUser?.reload();
                                if (mounted) {
                                  _loadSettingsData();
                                  Navigator.pop(context);
                                  _showSnackBar(
                                      context,
                                      isUrdu
                                          ? 'پروفائل اپڈیٹ ہوگئی'
                                          : 'Profile updated successfully',
                                      isUrdu);
                                }
                              } catch (e) {
                                if (mounted)
                                  _showSnackBar(context, 'Error: $e', isUrdu,
                                      isError: true);
                              } finally {
                                if (mounted)
                                  setModalState(() => isUpdating = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(isUrdu ? 'محفوظ کریں' : 'Save Changes',
                              style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImagePicker(
      {File? localImage,
      String? currentUrl,
      required bool isUrdu,
      required VoidCallback onTap,
      IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.themeColor.withOpacity(0.2), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 100,
                height: 100,
                color: Colors.grey[100],
                child: localImage != null
                    ? Image.file(localImage, fit: BoxFit.cover)
                    : (currentUrl != null && currentUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: currentUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const _ShimmerBox(width: 100, height: 100),
                            errorWidget: (context, url, error) => Icon(
                                icon ?? PhosphorIcons.user(),
                                size: 40,
                                color: Colors.grey),
                          )
                        : Icon(icon ?? PhosphorIcons.user(),
                            size: 40, color: Colors.grey)),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.themeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(PhosphorIcons.camera(PhosphorIconsStyle.bold),
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<File?> _pickAndCropImage(bool isUrdu) async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isUrdu ? 'تصویر تراشیں' : 'Crop Image',
          toolbarColor: AppTheme.darkColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<String?> _uploadToStorage(String uid, File file, String type) async {
    try {
      // Compress image before upload
      final compressedFile = await ImageUtils.compressImage(file, quality: 60, maxWidth: 800);
      
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_uploads')
          .child('${uid}_$type.jpg');
      await ref.putFile(compressedFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage upload error: $e");
      return null;
    }
  }

  void _showLogoutDialog(BuildContext context, bool isUrdu) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isUrdu ? 'لاگ آؤٹ کریں؟' : 'Logout?',
          style: TextStyle(
              fontFamily: fontFamily,
              color: AppTheme.expenseColor,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        ),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
              : 'Are you sure you want to logout?',
          style: TextStyle(
              fontFamily: fontFamily,
              color: AppTheme.darkColor,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isUrdu ? 'منسوخ' : 'Cancel',
                style: TextStyle(
                    fontFamily: fontFamily,
                    color: AppTheme.textSecondary,
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await Provider.of<AuthService>(context, listen: false)
                    .signOut(context);
              } catch (e) {
                if (mounted)
                  _showSnackBar(
                      context, '${isUrdu ? 'خرابی:' : 'Error:'} $e', isUrdu,
                      isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expenseColor,
                foregroundColor: Colors.white),
            child: Text(isUrdu ? 'لاگ آؤٹ' : 'Logout',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(BuildContext parentContext, bool isUrdu) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isUrdu ? 'اکاؤنٹ غیر فعال کریں؟' : 'Deactivate Account?',
          style: TextStyle(
              fontFamily: fontFamily,
              color: AppTheme.expenseColor,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        ),
        content: Text(
          isUrdu
              ? 'اس سے آپ کا اکاؤنٹ اور ڈیٹا عارضی طور پر غیر فعال ہو جائے گا۔ آپ دوبارہ لاگ ان کر کے اسے بحال کر سکتے ہیں۔'
              : 'This will temporarily disable your account and data. You can reactivate it by logging in again.',
          style: TextStyle(
              fontFamily: fontFamily,
              color: AppTheme.darkColor,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isUrdu ? 'منسوخ' : 'Cancel',
                style: TextStyle(
                    fontFamily: fontFamily,
                    color: AppTheme.textSecondary,
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final authService =
                    Provider.of<AuthService>(parentContext, listen: false);
                await authService.deactivateAccount(parentContext);
              } catch (e) {
                if (mounted)
                  _showSnackBar(parentContext,
                      '${isUrdu ? 'خرابی:' : 'Error:'} $e', isUrdu,
                      isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expenseColor,
                foregroundColor: Colors.white),
            child: Text(isUrdu ? 'تصدیق' : 'Confirm',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(
      BuildContext context, LanguageService languageService) {
    final isUrdu = languageService.isUrdu;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isUrdu ? 'زبان منتخب کریں' : 'Select Language',
          style: TextStyle(
              fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              color: AppTheme.darkColor,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('اردو',
                  style: TextStyle(fontFamily: 'NooriNastaleeq', fontSize: 18)),
              value: 'ur',
              groupValue: languageService.currentLocale.languageCode,
              activeColor: AppTheme.themeColor,
              onChanged: (value) {
                languageService.changeLanguage(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English', style: TextStyle(fontSize: 18)),
              value: 'en',
              groupValue: languageService.currentLocale.languageCode,
              activeColor: AppTheme.themeColor,
              onChanged: (value) {
                languageService.changeLanguage(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAppLock(BuildContext context, bool isUrdu) async {
    final securityService =
        Provider.of<SecurityService>(context, listen: false);

    if (_isAppLockEnabled) {
      await securityService.setAppLockEnabled(false);
      setState(() => _isAppLockEnabled = false);
      if (mounted)
        _showSnackBar(
            context,
            isUrdu ? 'ایپ لاک غیر فعال کر دیا گیا' : 'App Lock disabled',
            isUrdu);
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppLockScreen(isSettingUp: true),
        ),
      );

      if (result == true) {
        final isEnabled = await securityService.isAppLockEnabled();
        setState(() => _isAppLockEnabled = isEnabled);

        if (isEnabled && mounted) {
          _showSnackBar(context,
              isUrdu ? 'ایپ لاک فعال کر دیا گیا' : 'App Lock enabled', isUrdu);
        }
      }
    }
  }

  Future<void> _changePin(BuildContext context, bool isUrdu) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppLockScreen(isChangingPin: true),
      ),
    );

    if (result == true && mounted) {
      _showSnackBar(
          context,
          isUrdu
              ? 'پن کوڈ کامیابی سے تبدیل ہو گیا'
              : 'PIN changed successfully',
          isUrdu);
    }
  }

  Future<void> _toggleBiometric(BuildContext context, bool isUrdu) async {
    final securityService =
        Provider.of<SecurityService>(context, listen: false);

    if (!_isBiometricEnabled) {
      final available = await securityService.isBiometricsAvailable();
      if (!available) {
        if (mounted) {
          _showSnackBar(
            context,
            isUrdu
                ? 'اس ڈیوائس پر بائیو میٹرک دستیاب نہیں'
                : 'Biometrics not available',
            isUrdu,
            isError: true,
          );
        }
        return;
      }
    }

    await securityService.setBiometricEnabled(!_isBiometricEnabled);
    setState(() {
      _isBiometricEnabled = !_isBiometricEnabled;
    });
  }

  void _syncData(BuildContext context, bool isUrdu) async {
    final syncService = Provider.of<AutoSyncService>(context, listen: false);
    try {
      await syncService.syncAllDataToCloud();
      if (mounted) {
        _showSnackBar(context,
            isUrdu ? 'ڈیٹا سینک ہوگیا' : 'Data synced successfully', isUrdu);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, '${isUrdu ? 'خرابی:' : 'Error:'} $e', isUrdu,
            isError: true);
      }
    }
  }

  void _showExportDialog(BuildContext context, bool isUrdu) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isUrdu ? 'ڈیٹا ایکسپورٹ کریں' : 'Export Data',
          style: TextStyle(
              fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              color: AppTheme.darkColor,
              fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildExportButton(
              title: 'PDF Report',
              icon: PhosphorIcons.filePdf(),
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
                await pdfService.generateAllAccountsReport(
                    databaseService.accounts,
                    databaseService.transactions,
                    isUrdu);
              },
            ),
            const SizedBox(height: 12),
            _buildExportButton(
              title: 'Excel / CSV',
              icon: PhosphorIcons.fileCsv(),
              onPressed: () async {
                Navigator.pop(dialogContext);
                _showSnackBar(
                    context,
                    isUrdu
                        ? 'ایکسل فائل بن رہی ہے...'
                        : 'Generating Excel/CSV...',
                    isUrdu);
                final excelService =
                    Provider.of<ExcelService>(context, listen: false);
                final databaseService =
                    Provider.of<DatabaseService>(context, listen: false);
                await excelService.generateAndShareAllAccountsCsv(
                    databaseService.accounts, isUrdu);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(
      {required String title,
      required IconData icon,
      required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, bool isUrdu) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? 'بیک اپ اور بحالی' : 'Backup & Restore',
            style: TextStyle(
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildExportButton(
              title: isUrdu ? 'بیک اپ بنائیں' : 'Create Backup',
              icon: PhosphorIcons.cloudArrowUp(),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Provider.of<BackupService>(context, listen: false)
                    .createBackup();
                if (mounted)
                  _showSnackBar(
                      context,
                      isUrdu
                          ? 'بیک اپ مکمل ہو گیا'
                          : 'Backup completed successfully',
                      isUrdu);
              },
            ),
            const SizedBox(height: 12),
            _buildExportButton(
              title: isUrdu ? 'بیک اپ بحال کریں' : 'Restore Backup',
              icon: PhosphorIcons.cloudArrowDown(),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Provider.of<BackupService>(context, listen: false)
                    .restoreBackup();
                if (mounted)
                  _showSnackBar(
                      context,
                      isUrdu
                          ? 'ڈیٹا کامیابی سے بحال ہو گیا'
                          : 'Data restored successfully',
                      isUrdu);
              },
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Logo/Icon
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppTheme.themeColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                            0.2), // ہلکا تھیم کلر بیک گراؤنڈ کے لیے
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: AppTheme
                              .darkColor, // سفید لوگو کے لیے گہرا بیک گراؤنڈ
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/icons/zalooq.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                                PhosphorIcons.wallet(PhosphorIconsStyle.fill),
                                color: Colors.white,
                                size: 48),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                    Text(
                      'Version $_appVersion',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info List
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildAboutItem(
                    icon: PhosphorIcons.shieldCheck(),
                    title: isUrdu ? 'محفوظ ڈیٹا' : 'Secure Data',
                    subtitle: isUrdu
                        ? 'آپ کا ڈیٹا مکمل طور پر محفوظ ہے'
                        : 'Your data is completely secure',
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                  const Divider(height: 24),
                  _buildAboutItem(
                    icon: PhosphorIcons.cloudArrowUp(),
                    title: isUrdu ? 'آٹو کلاؤڈ سنک' : 'Auto Cloud Sync',
                    subtitle: isUrdu
                        ? 'آن لائن بیک اپ کی سہولت'
                        : 'Online backup facility',
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                  const Divider(height: 24),
                  _buildAboutItem(
                    icon: PhosphorIcons.code(),
                    title: isUrdu ? 'تیار کردہ' : 'Developed By',
                    subtitle: 'Zalooq Tech Solutions',
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                  ),
                ],
              ),
            ),
            // Close Button
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.themeColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isUrdu ? 'بند کریں' : 'Close',
                      style: TextStyle(
                          fontFamily: fontFamily, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.themeColor, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: fontFamily,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPrivacyPolicy(BuildContext context, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isUrdu ? 'پرائیویسی پالیسی' : 'Privacy Policy', style: TextStyle(fontFamily: fontFamily)),
        content: SingleChildScrollView(
          child: Text(
            isUrdu 
              ? 'ہم آپ کی پرائیویسی کا احترام کرتے ہیں۔ آپ کا فون نمبر صرف تصدیق شدہ خریداروں کو دکھایا جائے گا اور آپ کا ڈیٹا محفوظ رہے گا۔\n\n1. ڈیٹا کا استعمال: صرف اشتہار کی سہولت کے لیے۔\n2. نمبر ماسکنگ: عوامی طور پر آپ کا مکمل نمبر نہیں دکھایا جائے گا۔\n3. رضامندی: اشتہار پوسٹ کر کے آپ نمبر شیئر کرنے کی اجازت دیتے ہیں۔'
              : 'We respect your privacy. Your phone number will only be shown to verified buyers and your data remains secure.\n\n1. Data Usage: Only for advertisement purposes.\n2. Number Masking: Your full number will not be shown publicly.\n3. Consent: By posting an ad, you agree to share your contact info.',
            style: TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: 14),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? 'بند کریں' : 'Close', style: TextStyle(fontFamily: fontFamily))),
        ],
      ),
    );
  }

  void _contactUs(BuildContext context, bool isUrdu) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'karobarisaathi@gmail.com',
      query: 'subject=Support Request&body=Hello Support Team,',
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showSnackBar(context,
              isUrdu ? 'ای میل ایپ نہیں ملی' : 'No email app found', isUrdu,
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error: $e', isUrdu, isError: true);
      }
    }
  }

  void _shareApp(BuildContext context, bool isUrdu) {
    Share.share(isUrdu
        ? 'کاروباری ساتھی ایپ استعمال کریں: https://play.google.com/store/apps/details?id=com.accountapp'
        : 'Use Karobari Saathi app: https://play.google.com/store/apps/details?id=com.accountapp');
  }

  void _rateApp(BuildContext context, bool isUrdu) async {
    const url = 'https://play.google.com/store/apps/details?id=com.accountapp';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showSnackBar(BuildContext context, String message, bool isUrdu,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: TextStyle(
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
        backgroundColor: isError ? AppTheme.expenseColor : AppTheme.darkColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerBox({required this.width, required this.height});

  @override
  _ShimmerBoxState createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}
