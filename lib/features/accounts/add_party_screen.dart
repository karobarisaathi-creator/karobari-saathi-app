import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide Account;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:async';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/utils/helpers.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/category_chip.dart';
import 'package:account_app/core/widgets/app_filter_chip.dart';
import 'package:account_app/l10n/app_localizations.dart';

class AddPartyScreen extends StatefulWidget {
  final Account? partyToEdit;

  const AddPartyScreen({Key? key, this.partyToEdit}) : super(key: key);

  @override
  _AddPartyScreenState createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends State<AddPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  late String _selectedCategory;
  File? _profileImage;
  String? _remoteImageUrl; // For profiles found via global lookup
  bool _isLoading = false;
  bool _isSearchingProfile = false;
  Map<String, String>? _foundProfile;

  final ImagePicker _picker = ImagePicker();
  final List<AppCategory> _partyCategories = CategoryChip.partyCategories;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updatePreview);
    _phoneController.addListener(_onPhoneChanged);
    
    if (widget.partyToEdit != null) {
      _nameController.text = widget.partyToEdit!.name;
      _phoneController.text = widget.partyToEdit!.phone;
      
      _selectedCategory = widget.partyToEdit!.category;

      if (widget.partyToEdit!.profileImage != null) {
        if (widget.partyToEdit!.profileImage!.startsWith('http')) {
          _remoteImageUrl = widget.partyToEdit!.profileImage;
        } else {
          _profileImage = File(widget.partyToEdit!.profileImage!);
        }
      }
    } else {
      _selectedCategory = 'general';
    }
  }

  void _updatePreview() {
    setState(() {});
  }

  void _onPhoneChanged() {
    _updatePreview();
    
    // Global profile lookup logic
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length >= 10) {
      if (_searchTimer?.isActive ?? false) _searchTimer!.cancel();
      _searchTimer = Timer(const Duration(milliseconds: 800), () {
        _lookupProfile(phone);
      });
    } else {
      if (_foundProfile != null) {
        setState(() => _foundProfile = null);
      }
    }
  }

  Future<void> _lookupProfile(String phone) async {
    if (widget.partyToEdit != null) return; // Don't lookup in edit mode

    setState(() => _isSearchingProfile = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final profile = await dbService.findPublicProfileByPhone(phone);
    
    if (mounted) {
      setState(() {
        _foundProfile = profile;
        _isSearchingProfile = false;
      });
    }
  }

  void _useFoundProfile() {
    if (_foundProfile == null) return;
    setState(() {
      _nameController.text = _foundProfile!['name'] ?? _nameController.text;
      _remoteImageUrl = _foundProfile!['photoUrl'];
      _profileImage = null; // Clear local image if using remote
      _foundProfile = null; // Hide the lookup card
    });
  }

  Future<void> _pickImage() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    
    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isUrdu ? 'تصویر تراشیں' : 'Crop Image',
            toolbarColor: AppTheme.darkColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: isUrdu ? 'تصویر تراشیں' : 'Crop Image',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _profileImage = File(croppedFile.path);
          _remoteImageUrl = null; // Clear remote image if user picks local
        });
      }
    }
  }

  void _removeImage() {
    setState(() {
      _profileImage = null;
      _remoteImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        title: widget.partyToEdit != null ? l10n.editParty : l10n.addParty,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.darkColor.withOpacity(0.12), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _remoteImageUrl != null 
                                    ? CachedNetworkImage(
                                        imageUrl: _remoteImageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        errorWidget: (context, url, error) => Icon(PhosphorIcons.user(), color: AppTheme.darkColor.withOpacity(0.3)),
                                      )
                                    : (_profileImage != null
                                        ? Image.file(_profileImage!, fit: BoxFit.cover)
                                        : Icon(PhosphorIcons.camera(), size: 45, color: AppTheme.darkColor.withOpacity(0.5))),
                              ),
                            ),
                          ),
                          if (_profileImage != null || _remoteImageUrl != null)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: _removeImage,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.expenseColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isUrdu ? 'تصویر شامل کریں' : 'Add Photo',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                        fontWeight: fontWeight,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Modern Live Preview / Found Profile Card
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _foundProfile != null 
                                  ? Colors.green.withOpacity(0.5) 
                                  : AppTheme.themeColor.withOpacity(0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                ProfileInfoWidget(
                                  name: (_foundProfile != null && _nameController.text.isEmpty)
                                      ? (_foundProfile!['name'] ?? l10n.partyName)
                                      : (_nameController.text.isEmpty ? l10n.partyName : _nameController.text),
                                  phone: _phoneController.text.isEmpty ? '03000000000' : _phoneController.text,
                                  profileImage: _remoteImageUrl ?? (_foundProfile != null && _profileImage == null ? _foundProfile!['photoUrl'] : null) ?? _profileImage?.path,
                                  category: _foundProfile != null 
                                      ? (_foundProfile!['profession']?.isNotEmpty == true 
                                          ? _foundProfile!['profession'] 
                                          : (isUrdu ? 'پرسنل کھاتہ' : 'Personal Account'))
                                      : (isUrdu ? 'نیا کھاتہ' : 'New Account'),
                                  address: _foundProfile != null 
                                      ? (isUrdu ? 'پہلے سے موجود اکاؤنٹ' : 'Existing Account') 
                                      : null,
                                  isLarge: true,
                                  isVerticalCategory: true,
                                  customSize: 90, // تصویر کا سائز بڑھا دیا گیا
                                  isVerified: (_foundProfile != null && _foundProfile!['isVerified'] == 'true') || (widget.partyToEdit?.isVerified ?? false),
                                ),
                                if (_foundProfile != null) ...[
                                  const Divider(height: 24, thickness: 0.5),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: _useFoundProfile,
                                      icon: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 20),
                                      label: Text(
                                        isUrdu ? 'یہ معلومات استعمال کریں' : 'Use this information',
                                        style: TextStyle(
                                          fontFamily: fontFamily,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_foundProfile != null)
                          Positioned.directional(
                            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                            top: 0,
                            end: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.only(
                                  topRight: isUrdu ? Radius.zero : const Radius.circular(16),
                                  bottomLeft: isUrdu ? Radius.zero : const Radius.circular(16),
                                  topLeft: isUrdu ? const Radius.circular(16) : Radius.zero,
                                  bottomRight: isUrdu ? const Radius.circular(16) : Radius.zero,
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
                                ],
                              ),
                              child: Text(
                                isUrdu ? 'اکاؤنٹ ملا' : 'Account Found',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
              
                    // Phone Field (Moved Up for better lookup experience)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneController,
                            label: l10n.phone,
                            icon: PhosphorIcons.phone(),
                            isPhone: true,
                            fontFamily: '',
                            fontWeight: FontWeight.bold,
                            suffix: _isSearchingProfile ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.themeColor)) : null,
                            validator: (value) {
                              if (value == null || value.isEmpty) return l10n.invalidPhone;
                              if (!RegExp(r'^[\d\+\-\s]+$').hasMatch(value)) return l10n.invalidPhone;
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _showPhoneSelectionDialog(isUrdu, fontFamily, fontWeight),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.darkColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              elevation: 0,
                            ),
                            child: Icon(PhosphorIcons.addressBook()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: l10n.name,
                      icon: PhosphorIcons.user(),
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                      validator: (value) => value == null || value.isEmpty ? l10n.invalidName : null,
                    ),
                    const SizedBox(height: 40),
              
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveParty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.floppyDisk(), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.save,
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label, bool isUrdu, String fontFamily) {
    return Align(
      alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.bold,
          color: AppTheme.darkColor.withOpacity(0.7),
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isPhone = false,
    int maxLines = 1,
    String? Function(String?)? validator,
    required String fontFamily,
    required FontWeight fontWeight,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(
        color: AppTheme.darkColor,
        fontFamily: isPhone ? '' : fontFamily,
        fontWeight: isPhone ? FontWeight.bold : fontWeight,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontSize: 14, fontWeight: fontWeight),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5),
        ),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.darkColor.withOpacity(0.6), size: 20) : null,
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.all(12), child: suffix) : null,
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Future<void> _showPhoneSelectionDialog(bool isUrdu, String fontFamily, FontWeight fontWeight) async {
    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      contacts = contacts.where((c) => c.phones.isNotEmpty).toList();

      showDialog(
        context: context,
        builder: (context) => _ContactSelectionDialog(
          contacts: contacts,
          isUrdu: isUrdu,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          onSelect: (name, phone) {
            setState(() {
              _nameController.text = name;
              _phoneController.text = phone.replaceAll(' ', '');
            });
            Navigator.pop(context);
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrdu ? 'رابطوں تک رسائی کی اجازت نہیں دی گئی' : 'Permission to access contacts denied', 
            style: TextStyle(fontFamily: fontFamily, color: Colors.white, fontWeight: fontWeight)
          ),
          backgroundColor: AppTheme.expenseColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
      );
    }
  }

  Future<void> _saveParty() async {
    final l10n = AppLocalizations.of(context);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);

      // Check for duplicate phone number
      final existingAccounts = databaseService.getAccounts();
      final cleanNewPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      
      bool isDuplicate = existingAccounts.any((a) {
        String p1 = a.phone.replaceAll(RegExp(r'\D'), '');
        String p2 = cleanNewPhone;
        // Normalize 92 to 0
        if (p1.startsWith('92')) p1 = '0${p1.substring(2)}';
        if (p2.startsWith('92')) p2 = '0${p2.substring(2)}';
        
        return p1 == p2 && (widget.partyToEdit == null || a.id != widget.partyToEdit!.id);
      });

      if (isDuplicate) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUrdu ? 'اس فون نمبر پر پہلے ہی ایک اکاؤنٹ موجود ہے۔' : 'An account with this phone number already exists.',
              style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '', fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal, color: Colors.white)
            ),
            backgroundColor: AppTheme.expenseColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          )
        );
        return;
      }

      final syncService = Provider.of<AutoSyncService>(context, listen: false);

      // Check connectivity
      bool isConnected = false;
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          isConnected = true;
        }
      } on SocketException catch (_) {
        isConnected = false;
      }

      String? finalImagePath = _remoteImageUrl ?? _profileImage?.path;

      if (widget.partyToEdit != null) {
        // Edit Mode
        final updatedParty = widget.partyToEdit!.copyWith(
          name: _nameController.text,
          phone: _phoneController.text,
          address: null,
          category: _selectedCategory,
          profileImage: finalImagePath,
          updatedAt: DateTime.now(),
        );

        await databaseService.updateAccount(updatedParty);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.updatedSuccessfully,
                style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '', fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal, color: Colors.white)
              ),
              backgroundColor: AppTheme.darkColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            )
        );
      } else {
        // Add Mode
        final party = Account(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          phone: _phoneController.text,
          address: null,
          category: _selectedCategory,
          initialBalance: 0.0,
          balanceType: 'credit',
          balance: 0.0,
          profileImage: finalImagePath,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        await databaseService.addAccount(party);
        
        if (isConnected) {
           try {
             await syncService.syncNewAccount(party);
           } catch (e) {
             print("Sync error: $e");
           }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConnected ? l10n.addedSuccessfully : (isUrdu ? 'پارٹی محفوظ ہوگئی (آف لائن)' : 'Party saved locally (Offline)'), 
              style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '', fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal, color: Colors.white)
            ),
            backgroundColor: AppTheme.darkColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e', style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '', fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class _ContactSelectionDialog extends StatefulWidget {
  final List<Contact> contacts;
  final bool isUrdu;
  final String fontFamily;
  final FontWeight fontWeight;
  final Function(String, String) onSelect;

  const _ContactSelectionDialog({
    Key? key,
    required this.contacts,
    required this.isUrdu,
    required this.fontFamily,
    required this.fontWeight,
    required this.onSelect,
  }) : super(key: key);

  @override
  __ContactSelectionDialogState createState() => __ContactSelectionDialogState();
}

class __ContactSelectionDialogState extends State<_ContactSelectionDialog> {
  late List<Contact> _filteredContacts;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
    _searchController.addListener(_filterContacts);
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = widget.contacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      title: Text(
        widget.isUrdu ? 'رابطوں سے منتخب کریں' : 'Select Contact',
        style: TextStyle(
          fontFamily: widget.fontFamily,
          color: AppTheme.darkColor,
          fontWeight: widget.fontWeight,
        ),
      ),
      content: Container(
        width: double.maxFinite,
        height: 450,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.darkColor, fontFamily: ''),
                decoration: InputDecoration(
                  hintText: widget.isUrdu ? 'تلاش کریں...' : 'Search...',
                  hintStyle: TextStyle(fontFamily: widget.fontFamily, color: Colors.grey, fontWeight: widget.fontWeight),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), color: AppTheme.themeColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredContacts.isEmpty
                  ? Center(
                      child: Text(
                        widget.isUrdu ? 'کوئی رابطہ نہیں ملا' : 'No contacts found',
                        style: TextStyle(fontFamily: widget.fontFamily, color: AppTheme.textSecondary, fontWeight: widget.fontWeight),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        Contact contact = _filteredContacts[index];
                        String phone = contact.phones.first.number;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.themeColor.withOpacity(0.1),
                              child: Text(
                                contact.displayName.isNotEmpty ? contact.displayName[0] : '?',
                                style: const TextStyle(color: AppTheme.themeColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              contact.displayName,
                              style: TextStyle(
                                fontFamily: widget.fontFamily,
                                color: AppTheme.darkColor,
                                fontWeight: widget.isUrdu ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              phone,
                              style: const TextStyle(fontFamily: '', fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            onTap: () => widget.onSelect(contact.displayName, phone),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.isUrdu ? 'منسوخ' : 'Cancel',
            style: TextStyle(fontFamily: widget.fontFamily, color: AppTheme.expenseColor, fontWeight: widget.fontWeight),
          ),
        ),
      ],
    );
  }
}
