// Unified basic user and artisan profile screen.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/utils/image_utils.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/services/location_service.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/utils/artisan_validators.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'package:account_app/core/services/verification_service.dart';
import 'package:account_app/features/settings/verification_request_screen.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';

const String _defaultProfileImage =
    'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  final _logger = LoggingService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _skillInputController = TextEditingController();

  String _selectedProfession = 'electrician';
  String _rateUnit = 'fixed'; // 'hour', 'day', 'fixed', 'month'
  String _availability = 'available';
  String _verificationStatus = 'none';
  bool _showPhone = true;
  bool _showWhatsApp = true;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isVerified = false;
  bool _showExpertFields = false; // To toggle expert section
  List<String> _customSkills = [];
  double? _jobLatitude;
  double? _jobLongitude;

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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _qualificationController.dispose();
    _descriptionController.dispose();
    _experienceController.dispose();
    _rateController.dispose();
    _skillInputController.dispose();
    super.dispose();
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
            _jobLatitude = profile.latitude;
            _jobLongitude = profile.longitude;
            _qualificationController.text = profile.qualification ?? '';
            _descriptionController.text = profile.description;
            _experienceController.text = profile.experience.toString();
            _rateController.text = profile.rate ?? '';
            _rateUnit = profile.rateUnit ?? 'fixed';
            _selectedProfession = profile.profession;
            _availability = profile.availability;
            _showPhone = profile.showPhone;
            _showWhatsApp = profile.showWhatsApp;
            _verificationStatus = profile.verificationStatus;
            _isVerified = profile.isVerified;
            _showExpertFields = true;
            _customSkills = List.from(profile.skills);
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
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
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
    } catch (e, stack) {
      _logger.error("Error fetching profile data", e, stack);
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
          _jobLatitude = position.latitude;
          _jobLongitude = position.longitude;
        });
      }
    } catch (e, stack) {
      _logger.error("Location error", e, stack);
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
              toolbarTitle:
                  isProfile ? 'Crop Profile Image' : 'Crop Work Image',
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
    } catch (e, stack) {
      _logger.error("Image pick error", e, stack);
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

    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (_showExpertFields) {
      // 🆕 اگر لوکیشن منتخب نہیں ہے تو لکھے ہوئے پتے سے کوآرڈینیٹس نکالنے کی کوشش کریں
      if ((_jobLatitude == null || _jobLongitude == null) &&
          _locationController.text.isNotEmpty) {
        try {
          final locations =
              await locationFromAddress(_locationController.text.trim());
          if (locations.isNotEmpty) {
            _jobLatitude = locations.first.latitude;
            _jobLongitude = locations.first.longitude;
          }
        } catch (_) {}
      }

      final hasSkill = _customSkills.any((skill) => skill.trim().isNotEmpty);
      final hasLocation = ArtisanValidators.isValidLocation(
        _jobLatitude,
        _jobLongitude,
      );

      String? requirementMessage;
      if (!hasSkill) {
        requirementMessage = isUrdu
            ? 'براہ کرم کم از کم ایک ہنر شامل کریں'
            : 'Please add at least one skill';
      } else if (!hasLocation) {
        requirementMessage = isUrdu
            ? 'براہ کرم درست مقام منتخب کریں'
            : 'Please select a valid location';
      }

      if (requirementMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(requirementMessage)),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final service = ArtisanService();

      // 1. Upload Profile Image (Always allowed)
      String? profileImageUrl = _remoteProfileImage;
      if (_profileImage != null) {
        profileImageUrl =
            await service.uploadImage(user.uid, _profileImage!, 'profile');
      }

      // اگر تصویر موجود نہیں ہے تو ڈیفالٹ تصویر استعمال کریں
      if (profileImageUrl == null || profileImageUrl.trim().isEmpty) {
        profileImageUrl = _defaultProfileImage;
      }

      // 2. Upload Work Images (ONLY if Expert mode is ON)
      List<String> finalWorkImages = [];
      if (_showExpertFields) {
        finalWorkImages = List.from(_remoteWorkImages);
        for (var file in _workImages) {
          final url = await service.uploadImage(user.uid, file, 'work');
          if (url != null) finalWorkImages.add(url);
        }
      }

      // 3. Update Personal Info in Firebase Auth and Users Collection
      await user.updateDisplayName(_nameController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': _nameController.text.trim(),
        'photoURL': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. اگر ایکسپرٹ فیلڈز آن ہیں تو کاریگر پروفائل سیو کریں
      if (_showExpertFields) {
        final existingProfile = await service.getProfile(user.uid);

        final profile = ArtisanProfile(
          id: user.uid,
          name: _nameController.text.trim(),
          profession: _selectedProfession,
          professionUrdu: _getProfessionUrdu(_selectedProfession),
          location: _locationController.text.trim(),
          latitude: _jobLatitude,
          longitude: _jobLongitude,
          experience: int.tryParse(_experienceController.text) ?? 0,
          rate: _rateController.text.trim().isEmpty
              ? null
              : _rateController.text.trim(),
          rateUnit: _rateUnit,
          availability: _availability,
          qualification: _qualificationController.text.trim().isEmpty
              ? null
              : _qualificationController.text.trim(),
          phone: _phoneController.text.trim(),
          showPhone: _showPhone,
          showWhatsApp: _showWhatsApp,
          description: _descriptionController.text.trim(),
          profileImage: profileImageUrl,
          workImages: finalWorkImages,
          rating: existingProfile?.rating ?? 0.0,
          totalReviews: existingProfile?.totalReviews ?? 0,
          isVerified: existingProfile?.isVerified ?? false,
          isActive: true,
          createdAt: existingProfile?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
          skills: _customSkills,
        );

        await service.saveProfile(profile);
      }

      if (mounted) {
        setState(() => _isEditing = true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isUrdu ? 'پروفائل محفوظ ہوگیا' : 'Profile saved successfully'),
            backgroundColor: AppTheme.incomeColor,
          ),
        );

        // اگر یہ لاگ ان کے فوراً بعد ہے تو ڈیش بورڈ پر لے جائیں، ورنہ پاپ کریں
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const MainNavigationScreen()));
        }
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
          style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
              color: Colors.red),
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
            child: Text(isUrdu ? 'کینسل' : 'Cancel',
                style: TextStyle(fontFamily: fontFamily)),
          ),
          AppButton(
            text: isUrdu ? 'ہاں، ڈیلیٹ کریں' : 'Yes, Delete',
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // 1. کاریگر کلیکشن سے پروفائل ڈیلیٹ کریں
                  await ArtisanService().deleteProfile(user.uid);

                  // 2. صارفین (users) کلیکشن میں کاریگر کا نشان ختم کریں
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'isArtisan': false,
                    'artisanProfileId': FieldValue.delete(),
                  });

                  if (mounted) {
                    setState(() {
                      _showExpertFields = false;
                      _remoteWorkImages = [];
                      _workImages = [];
                      _descriptionController.clear();
                      _experienceController.clear();
                      _locationController.clear();
                      _verificationStatus = 'none';
                      _isVerified = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isUrdu
                            ? 'پروفائل ختم کر دی گئی'
                            : 'Profile deleted successfully'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    Navigator.pop(context);
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            color: Colors.red,
            size: AppButtonSize.small,
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
                      _buildVerificationBanner(
                          isUrdu, fontFamily, verificationService),
                      const SizedBox(height: 16),
                    ],
                    // پروفائل تصویر (اب یہ اختیاری ہے)
                    ImageSelectorField(
                      isProfile: true,
                      selectedFiles:
                          _profileImage != null ? [_profileImage!] : [],
                      remoteUrls: _remoteProfileImage != null &&
                              _remoteProfileImage!.isNotEmpty
                          ? [_remoteProfileImage!]
                          : (_profileImage == null
                              ? [_defaultProfileImage]
                              : []),
                      onFilesChanged: (files) {
                        setState(() {
                          _profileImage = files.isNotEmpty ? files.first : null;
                        });
                      },
                      onRemoteRemoved: (_) =>
                          setState(() => _remoteProfileImage = null),
                    ),


                    const SizedBox(height: 24),

                    // --- SECTION 1: PERSONAL INFO ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.themeColor.withOpacity(0.3),
                            width: 1.5),
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
                          _buildSectionHeader(
                              isUrdu
                                  ? 'ذاتی معلومات (کھاتہ اکاؤنٹ)'
                                  : 'Personal Account Info',
                              fontFamily,
                              isUrdu,
                              topPadding: 0),
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
                          const SizedBox(height: 16),
                          _buildSwitchTile(
                            title: isUrdu
                                ? 'واٹس ایپ بٹن دکھائیں'
                                : 'Show WhatsApp Button',
                            subtitle: isUrdu
                                ? 'بولی کارڈ پر واٹس ایپ کا نشان نظر آئے گا'
                                : 'Show WhatsApp icon on bid cards',
                            value: _showWhatsApp,
                            onChanged: (val) =>
                                setState(() => _showWhatsApp = val),
                            fontFamily: fontFamily,
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
                        border: Border.all(
                            color: AppTheme.themeColor.withOpacity(0.3),
                            width: 1.5),
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

                                  // لوکیشن (آٹو کمپلیٹ کے ساتھ)
                                  _buildLocationField(isUrdu, fontFamily),

                                  const SizedBox(height: 16),

                                  // تجربہ
                                  _buildTextField(
                                    controller: _experienceController,
                                    label:
                                        isUrdu ? 'تجربہ (سال)' : 'Exp (Years)',
                                    icon: PhosphorIcons.calendar(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                    isNumber: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return isUrdu
                                            ? 'یہ فیلڈ ضروری ہے'
                                            : 'This field is required';
                                      }
                                      final years = int.tryParse(value);
                                      if (years == null ||
                                          !ArtisanValidators.isValidExperience(
                                              years)) {
                                        return ArtisanValidators
                                            .getErrorMessage('experience',
                                                isUrdu: isUrdu);
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // ریٹ (Rate)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildTextField(
                                          controller: _rateController,
                                          label: isUrdu
                                              ? 'اجرت / ریٹ'
                                              : 'Rate / Price',
                                          icon: PhosphorIcons
                                              .currencyCircleDollar(),
                                          fontFamily: fontFamily,
                                          isUrdu: isUrdu,
                                          isNumber: true,
                                          hint: '1000',
                                          validator: (val) => null, // Optional
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: _buildRateUnitDropdown(
                                            isUrdu, fontFamily),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // کوالیفیکیشن (Qualification)
                                  _buildTextField(
                                    controller: _qualificationController,
                                    label: isUrdu
                                        ? 'تعلیمی قابلیت / کوالیفیکیشن'
                                        : 'Qualification',
                                    icon: PhosphorIcons.graduationCap(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                    hint: isUrdu
                                        ? 'مثلاً: میٹرک، ڈپلومہ ہولڈر'
                                        : 'e.g. Matric, Diploma',
                                    validator: (val) => null, // Optional
                                  ),

                                  const SizedBox(height: 16),

                                  // تفصیل
                                  _buildTextField(
                                    controller: _descriptionController,
                                    label: isUrdu
                                        ? 'اپنے کام کی تفصیل'
                                        : 'Work Description',
                                    icon: PhosphorIcons.note(),
                                    fontFamily: fontFamily,
                                    isUrdu: isUrdu,
                                    maxLines: 4,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return isUrdu
                                            ? 'یہ فیلڈ ضروری ہے'
                                            : 'This field is required';
                                      }
                                      if (!ArtisanValidators.isValidDescription(
                                          value)) {
                                        return ArtisanValidators
                                            .getErrorMessage('description',
                                                isUrdu: isUrdu);
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // کام کی تصاویر
                                  ImageSelectorField(
                                    label: isUrdu
                                        ? 'کام کی تصاویر (اختیاری)'
                                        : 'Work Images (Optional)',
                                    selectedFiles: _workImages,
                                    remoteUrls: _remoteWorkImages,
                                    onFilesChanged: (files) =>
                                        setState(() => _workImages = files),
                                    onRemoteRemoved: (index) => setState(() =>
                                        _remoteWorkImages.removeAt(index)),
                                    maxTotal: 6,
                                  ),

                                  const SizedBox(height: 24),
                                  _buildSkillsSection(isUrdu, fontFamily),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // محفوظ کریں بٹن
                    AppButton(
                      text: _isEditing
                          ? (isUrdu ? 'اپ ڈیٹ کریں' : 'Update Profile')
                          : (isUrdu ? 'پروفائل بنائیں' : 'Create Profile'),
                      color: AppTheme.darkColor,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.large,
                      isFullWidth: true,
                      onPressed: _saveProfile,
                    ),

                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      AppButton(
                        text: isUrdu
                            ? 'کاریگر پروفائل ختم کریں'
                            : 'Delete Artisan Profile',
                        icon: Icons.delete_forever,
                        color: Colors.red,
                        variant: AppButtonVariant.ghost,
                        isFullWidth: true,
                        onPressed: () =>
                            _showDeleteConfirmation(isUrdu, fontFamily),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title,
            style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontFamily: fontFamily, fontSize: 11, color: Colors.grey[600])),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.themeColor,
        contentPadding: EdgeInsets.zero,
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
                  child: Icon(
                      _showExpertFields
                          ? PhosphorIcons.briefcase(PhosphorIconsStyle.fill)
                          : PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                      color: AppTheme.themeColor,
                      size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUrdu
                        ? 'کیا آپ ایک ماہر کاریگر ہیں؟'
                        : 'Are you an Expert Artisan?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.themeColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                Switch(
                  value: _showExpertFields,
                  onChanged: (val) => setState(() => _showExpertFields = val),
                  activeColor: AppTheme.themeColor,
                ),
              ],
            ),
            if (!_showExpertFields) ...[
              const SizedBox(height: 10),
              Text(
                isUrdu
                    ? 'اگر آپ بجلی، پلمبنگ، پینٹ یا کسی بھی ہنر کے ماہر ہیں، تو اسے آن کریں تاکہ گاہک آپ کو ڈھونڈ سکیں اور آپ کو کام مل سکے۔'
                    : 'If you are an expert in electricity, plumbing, painting or any skill, turn this on so customers can find you and you get work.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkColor.withOpacity(0.7),
                  fontFamily: fontFamily,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String fontFamily, bool isUrdu,
      {double topPadding = 20}) {
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

  Widget _buildVerificationBanner(
      bool isUrdu, String fontFamily, VerificationService service) {
    final status = service.artisanStatus;

    Color bgColor;
    Color iconColor;
    String text;
    IconData icon;
    bool showButton = false;

    if (status == VerificationStatus.approved || _isVerified) {
      bgColor = Colors.green[50]!;
      iconColor = Colors.green;
      text =
          isUrdu ? 'آپ کا پروفائل ویریفائیڈ ہے!' : 'Your profile is verified!';
      icon = PhosphorIcons.sealCheck(PhosphorIconsStyle.fill);
    } else if (status == VerificationStatus.pending ||
        _verificationStatus == 'pending') {
      bgColor = Colors.amber[50]!;
      iconColor = Colors.amber[800]!;
      text =
          isUrdu ? 'تصدیق کا عمل جاری ہے...' : 'Verification is in progress...';
      icon = PhosphorIcons.clock();
      showButton = true;
    } else if (status == VerificationStatus.rejected ||
        _verificationStatus == 'rejected') {
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: isNumber
          ? TextInputType.number
          : (isPhone ? TextInputType.phone : TextInputType.text),
      style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          color: readOnly ? Colors.grey : AppTheme.darkColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontFamily: isUrdu ? fontFamily : '',
          color: Colors.grey[600],
        ),
        prefixIcon: Icon(icon,
            size: 20, color: readOnly ? Colors.grey : AppTheme.themeColor),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator ??
          (value) {
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
            Icon(currentProfession['icon'],
                color: AppTheme.themeColor, size: 22),
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

  Widget _buildSkillsSection(bool isUrdu, String fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isUrdu ? 'تکنیکی مہارتیں (Skills)' : 'Technical Skills',
          fontFamily,
          isUrdu,
          topPadding: 0,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _skillInputController,
                label: isUrdu ? 'مہارت لکھیں' : 'Add a skill',
                icon: PhosphorIcons.hammer(),
                fontFamily: fontFamily,
                isUrdu: isUrdu,
                validator: (_) => null, // Optional
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () {
                final skill = _skillInputController.text.trim();
                if (skill.isNotEmpty && !_customSkills.contains(skill)) {
                  setState(() {
                    _customSkills.add(skill);
                    _skillInputController.clear();
                  });
                }
              },
              icon: Icon(PhosphorIcons.plus()),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.themeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        if (_customSkills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customSkills.map((skill) {
              return Chip(
                label: Text(
                  skill,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 12,
                    color: AppTheme.themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppTheme.themeColor.withOpacity(0.1),
                side: BorderSide(color: AppTheme.themeColor.withOpacity(0.3)),
                deleteIcon:
                    Icon(PhosphorIcons.xCircle(), size: 16, color: Colors.red),
                onDeleted: () {
                  setState(() => _customSkills.remove(skill));
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
        ],
      ],
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
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                isUrdu ? 'پیشہ منتخب کریں' : 'Select Profession',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
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
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  color: isSelected
                                      ? AppTheme.themeColor.withOpacity(0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.themeColor
                                        : Colors.grey[200]!,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(p['icon'],
                                        color: isSelected
                                            ? AppTheme.themeColor
                                            : Colors.grey[700],
                                        size: 28),
                                    const SizedBox(height: 8),
                                    Text(
                                      isUrdu ? p['name']! : p['id']!,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontFamily: fontFamily,
                                        color: isSelected
                                            ? AppTheme.themeColor
                                            : Colors.black87,
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

  Widget _buildRateUnitDropdown(bool isUrdu, String fontFamily) {
    final units = [
      {'id': 'fixed', 'en': 'Fixed', 'ur': 'مکمل کام'},
      {'id': 'hour', 'en': 'Per Hour', 'ur': 'فی گھنٹہ'},
      {'id': 'day', 'en': 'Per Day', 'ur': 'فی دیہاڑی'},
      {'id': 'month', 'en': 'Per Month', 'ur': 'فی مہینہ'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _rateUnit,
          isExpanded: true,
          icon: Icon(PhosphorIcons.caretDown(), size: 16, color: Colors.grey),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _rateUnit = newValue);
            }
          },
          items:
              units.map<DropdownMenuItem<String>>((Map<String, String> unit) {
            return DropdownMenuItem<String>(
              value: unit['id'],
              child: Text(
                isUrdu ? unit['ur']! : unit['en']!,
                style: TextStyle(fontFamily: fontFamily, fontSize: 14),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLocationField(bool isUrdu, String fontFamily) {
    return RawAutocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.length < 3) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        return await LocationService.searchLocations(textEditingValue.text);
      },
      displayStringForOption: (option) => option['display_name'],
      onSelected: (option) {
        setState(() {
          _locationController.text = option['display_name'];
          _jobLatitude = option['lat'];
          _jobLongitude = option['lon'];
        });
      },
      fieldViewBuilder:
          (context, controller, focusNode, onEditingComplete) {
        if (controller.text != _locationController.text && _locationController.text.isNotEmpty && controller.text.isEmpty) {
           controller.text = _locationController.text;
        }
        
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontSize: 16),
          decoration: InputDecoration(
            labelText: isUrdu ? 'شہر / علاقہ' : 'City / Area',
            hintText: isUrdu ? 'مثال: لاہور، گلبرگ' : 'e.g. Lahore, Gulberg',
            labelStyle: TextStyle(
                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            fillColor: const Color(0xFFF5F7F9),
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey.shade400)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey.shade400)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
            prefixIcon: Icon(PhosphorIcons.mapPin(), color: AppTheme.themeColor, size: 20),
            suffixIcon: IconButton(
              icon: Icon(Icons.my_location, color: AppTheme.themeColor),
              onPressed: () async {
                await _getCurrentLocation();
                controller.text = _locationController.text;
              },
            ),
          ),
          onChanged: (val) {
             _locationController.text = val;
             if (_jobLatitude != null || _jobLongitude != null) {
                setState(() {
                  _jobLatitude = null;
                  _jobLongitude = null;
                });
             }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return isUrdu ? 'یہ فیلڈ ضروری ہے' : 'Required';
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: isUrdu ? Alignment.topLeft : Alignment.topRight,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width - 72,
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option['display_name'],
                      style: TextStyle(fontSize: 13, fontFamily: fontFamily),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
