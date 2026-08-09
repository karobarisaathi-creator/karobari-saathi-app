// lib/features/artisans/screens/artisan_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/utils/image_utils.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/auth_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';

import 'package:account_app/core/services/verification_service.dart';
import 'package:account_app/features/settings/verification_request_screen.dart';

class ArtisanProfileScreen extends StatefulWidget {
  const ArtisanProfileScreen({super.key});

  @override
  State<ArtisanProfileScreen> createState() => _ArtisanProfileScreenState();
}

class _ArtisanProfileScreenState extends State<ArtisanProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  String _selectedProfession = 'electrician';
  String _availability = 'available';
  String _verificationStatus = 'none';
  bool _showPhone = true;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isVerified = false;
  bool _showExpertFields = false; // To toggle expert section

  String? _remoteProfileImage;
  List<String> _remoteWorkImages = [];

  File? _profileImage;
  File? _workImage1;
  File? _workImage2;
  File? _workImage3;
  List<File> _workImages = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    _getCurrentLocation();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _isLoading = true);

    // Set phone from Auth (Login identity is critical)
    _phoneController.text = user.phoneNumber ?? '';

    final service = ArtisanService();
    
    try {
      // 1. Try fetching existing Artisan Profile
      final profile = await service.getProfile(user.uid);

      if (profile != null && profile.name.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isEditing = true;
            _nameController.text = profile.name;
            _remoteProfileImage = profile.profileImage;
            _remoteWorkImages = profile.workImages;
            if (profile.phone.isNotEmpty) _phoneController.text = profile.phone;
            _locationController.text = profile.location;
            _descriptionController.text = profile.description;
            _experienceController.text = profile.experience.toString();
            _selectedProfession = profile.profession;
            _availability = profile.availability;
            _showPhone = profile.showPhone;
            _verificationStatus = profile.verificationStatus;
            _isVerified = profile.isVerified;
            _showExpertFields = true;
          });
        }
      } else {
        // 2. If no artisan profile or name is empty, try FirebaseAuth
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          if (mounted) {
            setState(() {
              _nameController.text = user.displayName!;
            });
          }
        }
        
        // 3. Try fetching from Firestore users collection
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final name = data?['displayName'] ?? data?['name'] ?? '';
          if (name.toString().isNotEmpty && _nameController.text.isEmpty) {
            if (mounted) {
              setState(() {
                _nameController.text = name.toString();
              });
            }
          }
        }

        // 4. Try Hive accounts box as a last resort
        if (_nameController.text.isEmpty) {
          final accountsBox = Hive.box<Account>('accounts');
          // Find an account that belongs to this user (usually by phone)
          try {
            final myAccount = accountsBox.values.firstWhere(
              (a) => a.phone == user.phoneNumber,
            );
            if (mounted) {
              setState(() {
                _nameController.text = myAccount.name;
              });
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        setState(() {
          _locationController.text = "${p.locality}, ${p.subLocality}";
        });
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _pickImage({bool isProfile = true}) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        if (!mounted) return;
        final cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: isProfile ? 'Crop Profile Image' : 'Crop Work Image',
              toolbarColor: AppTheme.darkColor,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
          ],
        );
        if (cropped != null) {
          final compressed = await ImageUtils.compressImage(File(cropped.path));
          if (mounted) {
            setState(() {
              if (isProfile) {
                _profileImage = compressed;
              } else {
                _workImages.add(compressed);
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _removeWorkImage(int index, {bool isRemote = false}) {
    setState(() {
      if (isRemote) {
        _remoteWorkImages.removeAt(index);
      } else {
        _workImages.removeAt(index);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    try {
      final service = ArtisanService();
      
      // 1. Update Personal Info in Firebase Auth
      await user.updateDisplayName(_nameController.text.trim());

      // 2. Upload Images
      String? profileImageUrl = _remoteProfileImage;
      if (_profileImage != null) {
        profileImageUrl = await service.uploadImage(user.uid, _profileImage!, 'profile');
      }

      List<String> finalWorkImages = List.from(_remoteWorkImages);
      for (var file in _workImages) {
        final url = await service.uploadImage(user.uid, file, 'work');
        if (url != null) finalWorkImages.add(url);
      }

      // 3. موجودہ پروفائل چیک کریں
      final existingProfile = await service.getProfile(user.uid);

      final profile = ArtisanProfile(
        id: user.uid,
        name: _nameController.text.trim(),
        profession: _selectedProfession,
        professionUrdu: _getProfessionUrdu(_selectedProfession),
        location: _locationController.text.trim(),
        experience: int.tryParse(_experienceController.text) ?? 0,
        rate: null, // Removed rate field
        availability: _availability,
        phone: _phoneController.text.trim(),
        showPhone: true, // Always show phone by default
        description: _descriptionController.text.trim(),
        profileImage: profileImageUrl,
        workImages: finalWorkImages,
        rating: existingProfile?.rating ?? 0.0,
        totalReviews: existingProfile?.totalReviews ?? 0,
        isVerified: existingProfile?.isVerified ?? false,
        isActive: true,
        createdAt: existingProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.saveProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? 'پروفائل محفوظ ہوگیا' : 'Profile saved successfully'),
            backgroundColor: AppTheme.incomeColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.expenseColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeleteConfirmation(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUrdu ? 'پروفائل ختم کریں؟' : 'Delete Profile?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          isUrdu 
            ? 'کیا آپ واقعی اپنا کاریگر پروفائل ختم کرنا چاہتے ہیں؟ اس سے آپ کی تمام پیشہ ورانہ معلومات مٹ جائیں گی۔' 
            : 'Are you sure you want to delete your artisan profile? All your professional details will be removed.',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'کینسل' : 'Cancel', style: TextStyle(fontFamily: fontFamily)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await ArtisanService().deleteProfile(user.uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isUrdu ? 'پروفائل ختم کر دی گئی' : 'Profile deleted successfully'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    Navigator.pop(context);
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              isUrdu ? 'ہاں، ڈیلیٹ کریں' : 'Yes, Delete',
              style: TextStyle(fontFamily: fontFamily, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getProfessionUrdu(String profession) {
    final professions = ArtisanService.getProfessions();
    final found = professions.firstWhere(
      (p) => p['id'] == profession,
      orElse: () => {'name': profession},
    );
    return found['name'] ?? profession;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final verificationService = Provider.of<VerificationService>(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: _isEditing
            ? (isUrdu ? 'پروفائل میں ترمیم' : 'Edit Profile')
            : (isUrdu ? 'نیا پروفائل' : 'New Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditing) ...[
                      _buildVerificationBanner(isUrdu, fontFamily, verificationService),
                      const SizedBox(height: 16),
                    ],
                    // پروفائل تصویر
                    Center(
                      child: GestureDetector(
                        onTap: () => _pickImage(isProfile: true),
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.themeColor.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: _profileImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _profileImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : (_remoteProfileImage != null && _remoteProfileImage!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: _remoteProfileImage!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                            errorWidget: (context, url, error) => Icon(PhosphorIcons.camera(), size: 40, color: Colors.grey[400]),
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              PhosphorIcons.camera(),
                                              size: 40,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              isUrdu ? 'تصویر شامل کریں' : 'Add Photo',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[400],
                                                fontFamily: fontFamily,
                                              ),
                                            ),
                                          ],
                                        )),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.themeColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  PhosphorIcons.pencilSimple(),
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 1: PERSONAL INFO ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.themeColor.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(isUrdu ? 'ذاتی معلومات (کھاتہ اکاؤنٹ)' : 'Personal Account Info', fontFamily, isUrdu, topPadding: 0),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _nameController,
                            label: isUrdu ? 'مکمل نام' : 'Full Name',
                            icon: PhosphorIcons.user(),
                            fontFamily: fontFamily,
                            isUrdu: isUrdu,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _phoneController,
                            label: isUrdu ? 'فون نمبر' : 'Phone Number',
                            icon: PhosphorIcons.phone(),
                            fontFamily: '',
                            isUrdu: isUrdu,
                            isPhone: true,
                            readOnly: true,
                            hint: isUrdu ? 'لاگ ان نمبر' : 'Login phone',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- SECTION 2: EXPERT INFO ---
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.themeColor.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInvitationHeader(isUrdu, fontFamily),
                          
                          if (_showExpertFields)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: [
                                  const Divider(height: 32),
                                  _buildProfessionSelector(isUrdu, fontFamily),
                                  const SizedBox(height: 16),

                                  // لوکیشن
                                  _buildTextField(
                                    controller: _locationController,
                                    label: isUrdu ? 'شہر / علاقہ' : 'City / Area',
                                    icon: PhosphorIcons.mapPin(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.my_location, color: AppTheme.themeColor),
                                      onPressed: _getCurrentLocation,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // تجربہ
                                  _buildTextField(
                                    controller: _experienceController,
                                    label: isUrdu ? 'تجربہ (سال)' : 'Exp (Years)',
                                    icon: PhosphorIcons.calendar(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                    isNumber: true,
                                  ),

                                  const SizedBox(height: 16),

                                  // تفصیل
                                  _buildTextField(
                                    controller: _descriptionController,
                                    label: isUrdu ? 'اپنے کام کی تفصیل' : 'Work Description',
                                    icon: PhosphorIcons.note(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                    maxLines: 4,
                                  ),

                                  const SizedBox(height: 16),

                                  // کام کی تصاویر
                                  Align(
                                    alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Text(
                                      isUrdu ? 'کام کی تصاویر (اختیاری)' : 'Work Images (Optional)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkColor,
                                        fontFamily: fontFamily,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildWorkImagesGrid(isUrdu, fontFamily),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // محفوظ کریں بٹن
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isEditing
                              ? (isUrdu ? 'اپ ڈیٹ کریں' : 'Update Profile')
                              : (isUrdu ? 'پروفائل بنائیں' : 'Create Profile'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ),
                    ),

                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _showDeleteConfirmation(isUrdu, fontFamily),
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: Text(
                            isUrdu ? 'کاریگر پروفائل ختم کریں' : 'Delete Artisan Profile',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInvitationHeader(bool isUrdu, String fontFamily) {
    return InkWell(
      onTap: () => setState(() => _showExpertFields = !_showExpertFields),
      borderRadius: BorderRadius.circular(16),
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
                    color: AppTheme.themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.fill), color: AppTheme.themeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUrdu ? 'اپنے ہنر کو پہچان دلائیں!' : 'Get Recognized for Your Skills!',
                    style: TextStyle(
                      fontSize: 18, // Larger font
                      fontWeight: FontWeight.bold,
                      color: AppTheme.themeColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                Icon(
                  _showExpertFields ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
                  color: AppTheme.themeColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isUrdu 
                ? 'ماہرین کی فہرست میں شامل ہونے اور زیادہ کام حاصل کرنے کے لیے اپنی پیشہ ورانہ تفصیلات یہاں درج کریں۔ اس سے آپ کا پروفائل پبلش ہو جائے گا اور گاہک آپ تک آسانی سے پہنچ سکیں گے۔' 
                : 'Enter your professional details here to join our expert directory and get more work. This will publish your profile for potential customers.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor.withOpacity(0.9),
                fontFamily: fontFamily,
                height: 1.4,
              ),
            ),
            if (!_showExpertFields)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Text(
                      isUrdu ? 'تفصیلات درج کرنے کے لیے یہاں کلک کریں' : 'Click here to enter details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.themeColor,
                        fontFamily: fontFamily,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(PhosphorIcons.arrowRight(), size: 14, color: AppTheme.themeColor),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String fontFamily, bool isUrdu, {double topPadding = 20}) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.themeColor,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildVerificationBanner(bool isUrdu, String fontFamily, VerificationService service) {
    final status = service.artisanStatus;
    
    Color bgColor;
    Color iconColor;
    String text;
    IconData icon;
    bool showButton = false;

    if (status == VerificationStatus.approved || _isVerified) {
      bgColor = Colors.green[50]!;
      iconColor = Colors.green;
      text = isUrdu ? 'آپ کا پروفائل ویریفائیڈ ہے!' : 'Your profile is verified!';
      icon = PhosphorIcons.sealCheck(PhosphorIconsStyle.fill);
    } else if (status == VerificationStatus.pending || _verificationStatus == 'pending') {
      bgColor = Colors.amber[50]!;
      iconColor = Colors.amber[800]!;
      text = isUrdu ? 'تصدیق کا عمل جاری ہے...' : 'Verification is in progress...';
      icon = PhosphorIcons.clock();
      showButton = true;
    } else if (status == VerificationStatus.rejected || _verificationStatus == 'rejected') {
      bgColor = Colors.red[50]!;
      iconColor = Colors.red;
      text = isUrdu ? 'تصدیق مسترد کر دی گئی ہے' : 'Verification was rejected';
      icon = PhosphorIcons.warningCircle();
      showButton = true;
    } else {
      bgColor = AppTheme.themeColor.withOpacity(0.05);
      iconColor = AppTheme.themeColor;
      text = isUrdu ? 'اپنا اکاؤنٹ ویریفائی کروائیں' : 'Verify your account';
      icon = PhosphorIcons.shieldCheck();
      showButton = true;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
            ),
          ),
          if (showButton)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VerificationRequestScreen(
                      isArtisanMode: true,
                    ),
                  ),
                );
              },
              child: Text(
                isUrdu ? 'تفصیل دیکھیں' : 'Details',
                style: TextStyle(fontFamily: fontFamily, color: iconColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String fontFamily,
    required bool isUrdu,
    String? hint,
    bool isNumber = false,
    bool isPhone = false,
    int maxLines = 1,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: isNumber
          ? TextInputType.number
          : (isPhone ? TextInputType.phone : TextInputType.text),
      style: TextStyle(fontFamily: fontFamily, fontSize: 15, color: readOnly ? Colors.grey : AppTheme.darkColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: isUrdu ? fontFamily : '',
          color: Colors.grey[600],
        ),
        prefixIcon: Icon(icon, size: 20, color: readOnly ? Colors.grey : AppTheme.themeColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isUrdu ? 'یہ فیلڈ ضروری ہے' : 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildProfessionSelector(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
    final currentProfession = professions.firstWhere(
      (p) => p['id'] == _selectedProfession,
      orElse: () => professions.first,
    );

    return InkWell(
      onTap: () => _showAllProfessionsPicker(isUrdu, fontFamily),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(currentProfession['icon'], color: AppTheme.themeColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isUrdu ? currentProfession['name'] : currentProfession['id'],
                style: TextStyle(fontFamily: fontFamily, fontSize: 15),
              ),
            ),
            Icon(PhosphorIcons.caretDown(), color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  void _showAllProfessionsPicker(bool isUrdu, String fontFamily) {
    final professions = ArtisanService.getProfessions();
    
    // Group professions by category
    final Map<String, List<Map<String, dynamic>>> groupedProfessions = {};
    for (var p in professions) {
      final cat = isUrdu ? p['categoryUrdu'] : p['category'];
      if (!groupedProfessions.containsKey(cat)) {
        groupedProfessions[cat] = [];
      }
      groupedProfessions[cat]!.add(p);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                isUrdu ? 'پیشہ منتخب کریں' : 'Select Profession',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedProfessions.keys.length,
                  itemBuilder: (context, index) {
                    final category = groupedProfessions.keys.elementAt(index);
                    final categoryItems = groupedProfessions[category]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.themeColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemCount: categoryItems.length,
                          itemBuilder: (context, idx) {
                            final p = categoryItems[idx];
                            final isSelected = _selectedProfession == p['id'];
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedProfession = p['id']!);
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.themeColor.withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.themeColor : Colors.grey[200]!,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(p['icon'], color: isSelected ? AppTheme.themeColor : Colors.grey[700], size: 28),
                                    const SizedBox(height: 8),
                                    Text(
                                      isUrdu ? p['name']! : p['id']!,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontFamily: fontFamily,
                                        color: isSelected ? AppTheme.themeColor : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkImagesGrid(bool isUrdu, String fontFamily) {
    final int totalCount = _remoteWorkImages.length + _workImages.length;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: totalCount + 1,
          itemBuilder: (context, index) {
            if (index == totalCount) {
              return GestureDetector(
                onTap: () => _pickImage(isProfile: false),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIcons.plus(),
                          size: 30,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUrdu ? 'شامل کریں' : 'Add',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Show Remote Images first
            if (index < _remoteWorkImages.length) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: _remoteWorkImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeWorkImage(index, isRemote: true),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Show Local (New) Images
            final localIndex = index - _remoteWorkImages.length;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _workImages[localIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeWorkImage(localIndex, isRemote: false),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        if (totalCount == 0)
          Text(
            isUrdu
                ? 'اپنے کام کی تصاویر شامل کریں (اختیاری)'
                : 'Add images of your work (optional)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontFamily: fontFamily,
            ),
          ),
      ],
    );
  }
}