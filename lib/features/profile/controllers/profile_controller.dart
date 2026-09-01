// lib/features/profile/controllers/profile_controller.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'package:account_app/core/utils/artisan_validators.dart';
import 'package:account_app/core/services/location_service.dart';
import 'package:account_app/core/config/professions_config.dart';

enum ProfileSaveStatus { idle, loading, success, error }

class ProfileController extends ChangeNotifier {
  final _logger = LoggingService();
  final ArtisanService _artisanService = ArtisanService();
  bool _isDisposed = false;
  
  // Form Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final List<TextEditingController> qualificationControllers = [];
  final List<TextEditingController> descriptionControllers = [];
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController skillInputController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();

  // State Variables
  String selectedProfession = ProfessionsConfig.allProfessions.isNotEmpty 
      ? ProfessionsConfig.allProfessions.first.id 
      : 'mason';
  String rateUnit = 'fixed';
  String availability = 'available';
  String verificationStatus = 'none';
  String descriptionBulletStyle = 'dot';
  String qualificationBulletStyle = 'dot';
  
  bool showPhone = true;
  bool showWhatsApp = true;
  bool isLoading = false;
  bool isEditing = false;
  bool isVerified = false;
  bool showExpertFields = false;
  List<String> customSkills = [];
  double? jobLatitude;
  double? jobLongitude;

  String? remoteProfileImage;
  List<String> remoteWorkImages = [];

  File? profileImage;
  List<File> workImages = [];

  ProfileSaveStatus saveStatus = ProfileSaveStatus.idle;
  String? errorMessage;

  Future<void> loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isLoading = true;
    notifyListeners();

    phoneController.text = user.phoneNumber ?? '';

    // ابتدائی خانوں کا اضافہ
    if (descriptionControllers.isEmpty) addDescriptionField();
    if (qualificationControllers.isEmpty) addQualificationField();

    try {
      final profile = await _artisanService.getProfile(user.uid);

      if (profile != null && profile.name.isNotEmpty) {
        _populateFromProfile(profile);
      } else {
        await _loadFromOtherSources(user);
      }
    } catch (e, stack) {
      _logger.error("Error fetching profile data", e, stack);
      errorMessage = 'Failed to load profile data';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _populateFromProfile(ArtisanProfile profile) {
    isEditing = true;
    nameController.text = profile.name;
    emailController.text = profile.email ?? '';
    remoteProfileImage = profile.profileImage;
    remoteWorkImages = List.from(profile.workImages);
    if (profile.phone.isNotEmpty) phoneController.text = profile.phone;
    locationController.text = profile.location;
    jobLatitude = profile.latitude;
    jobLongitude = profile.longitude;
    
    // تعلیمی قابلیت لوڈ کریں
    _parseTextToControllers(profile.qualification ?? '', qualificationControllers, (style) {
      qualificationBulletStyle = style;
    });

    // تعارف لوڈ کریں
    _parseTextToControllers(profile.description, descriptionControllers, (style) {
      descriptionBulletStyle = style;
    });

    experienceController.text = profile.experience.toString();
    rateController.text = profile.rate ?? '';
    rateUnit = profile.rateUnit ?? 'fixed';
    selectedProfession = profile.profession;
    availability = profile.availability;
    showPhone = profile.showPhone;
    showWhatsApp = profile.showWhatsApp;
    verificationStatus = profile.verificationStatus;
    isVerified = profile.isVerified;
    showExpertFields = true;
    customSkills = List.from(profile.skills);
    websiteController.text = profile.website ?? '';
  }

  void _parseTextToControllers(String text, List<TextEditingController> controllers, Function(String) onStyleDetected) {
    if (text.isEmpty) return;
    
    final lines = text.split('\n');
    if (lines.isEmpty) return;

    // اسٹائل پہچانیں
    if (lines.first.startsWith('★')) {
      onStyleDetected('star');
    } else if (lines.first.startsWith('✓')) {
      onStyleDetected('tick');
    } else if (RegExp(r'^\d+\.').hasMatch(lines.first)) {
      onStyleDetected('number');
    } else {
      onStyleDetected('dot');
    }

    // پرانے صاف کریں
    for (var c in controllers) {
      c.dispose();
    }
    controllers.clear();

    for (var line in lines) {
      final clean = line.replaceAll(RegExp(r'^(•|★|✓|\d+\.)\s*'), '').trim();
      if (clean.isNotEmpty) {
        controllers.add(TextEditingController(text: clean));
      }
    }
    if (controllers.isEmpty) controllers.add(TextEditingController());
  }

  void addDescriptionField() {
    descriptionControllers.add(TextEditingController());
    notifyListeners();
  }

  void removeDescriptionField(int index) {
    if (descriptionControllers.length <= 1) return;
    descriptionControllers.removeAt(index).dispose();
    notifyListeners();
  }

  void addQualificationField() {
    qualificationControllers.add(TextEditingController());
    notifyListeners();
  }

  void removeQualificationField(int index) {
    if (qualificationControllers.length <= 1) return;
    qualificationControllers.removeAt(index).dispose();
    notifyListeners();
  }

  void setDescriptionStyle(String style) {
    descriptionBulletStyle = style;
    notifyListeners();
  }

  void setQualificationStyle(String style) {
    qualificationBulletStyle = style;
    notifyListeners();
  }

  Future<void> _loadFromOtherSources(User user) async {
    // Try FirebaseAuth display name
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      nameController.text = user.displayName!;
    }
    if (user.email != null && user.email!.isNotEmpty) {
      emailController.text = user.email!;
    }

    // Try Firestore users collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (userDoc.exists) {
      final data = userDoc.data();
      final name = data?['displayName'] ?? data?['name'] ?? '';
      final email = data?['email'] ?? '';
      if (name.toString().isNotEmpty && nameController.text.isEmpty) {
        nameController.text = name.toString();
      }
      if (email.toString().isNotEmpty && emailController.text.isEmpty) {
        emailController.text = email.toString();
      }
    }

    // Try Hive accounts box
    if (nameController.text.isEmpty) {
      try {
        final accountsBox = Hive.box<Account>('accounts');
        final myAccount = accountsBox.values.firstWhere(
          (a) => a.phone == user.phoneNumber,
        );
        nameController.text = myAccount.name;
      } catch (_) {}
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        if (_isDisposed) return;
        locationController.text = "${p.locality}, ${p.subLocality}";
        jobLatitude = position.latitude;
        jobLongitude = position.longitude;
        notifyListeners();
      }
    } catch (e, stack) {
      if (_isDisposed) return;
      _logger.error("Location error", e, stack);
      errorMessage = 'Failed to get current location';
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.length < 3) return [];
    try {
      return await LocationService.searchLocations(query);
    } catch (e) {
      _logger.error("Location search error", e);
      return [];
    }
  }

  void onLocationChanged(String value) {
    locationController.text = value;
    if (jobLatitude != null || jobLongitude != null) {
      jobLatitude = null;
      jobLongitude = null;
      notifyListeners();
    }
  }

  Future<bool> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      errorMessage = 'Please login first';
      notifyListeners();
      return false;
    }

    saveStatus = ProfileSaveStatus.loading;
    notifyListeners();

    try {
      // Validate expert fields if shown
      if (showExpertFields) {
        if (!await _validateExpertFields()) {
          saveStatus = ProfileSaveStatus.error;
          notifyListeners();
          return false;
        }
      }

      // Upload profile image
      String? profileImageUrl = remoteProfileImage;
      if (profileImage != null) {
        profileImageUrl = await _artisanService.uploadImage(
          user.uid, 
          profileImage!, 
          'profile'
        );
      }

      if (profileImageUrl == null || profileImageUrl.trim().isEmpty) {
        profileImageUrl = _getAvatarForName(nameController.text);
      }

      // Upload work images if expert mode
      List<String> finalWorkImages = [];
      if (showExpertFields) {
        finalWorkImages = List.from(remoteWorkImages);
        final uploadFutures = workImages.map((file) => 
          _artisanService.uploadImage(user.uid, file, 'work')
        );
        final uploadedUrls = await Future.wait(uploadFutures);
        finalWorkImages.addAll(uploadedUrls.whereType<String>());
      }

      // Update Firebase Auth
      await user.updateDisplayName(nameController.text.trim());

      // Update Firestore users collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'photoURL': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save artisan profile if expert mode
      if (showExpertFields) {
        await _saveArtisanProfile(user.uid, profileImageUrl, finalWorkImages);
      }

      saveStatus = ProfileSaveStatus.success;
      isEditing = true;
      notifyListeners();
      return true;

    } catch (e, stack) {
      _logger.error("Profile save error", e, stack);
      errorMessage = 'Failed to save profile: $e';
      saveStatus = ProfileSaveStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _validateExpertFields() async {
    // Try to get coordinates from address if not selected
    if ((jobLatitude == null || jobLongitude == null) &&
        locationController.text.isNotEmpty) {
      try {
        final locations = await locationFromAddress(locationController.text.trim());
        if (locations.isNotEmpty) {
          jobLatitude = locations.first.latitude;
          jobLongitude = locations.first.longitude;
        }
      } catch (_) {}
    }

    // صرف تعارف (Description) لازمی ہے
    final validDesc = descriptionControllers.where((c) => c.text.trim().isNotEmpty).toList();
    if (validDesc.isEmpty) {
      errorMessage = 'براہ کرم اپنے کام کی تفصیل (تعارف) درج کریں';
      return false;
    }

    final fullDesc = _formatWithStyle(validDesc, descriptionBulletStyle);
    if (!ArtisanValidators.isValidDescription(fullDesc)) {
      errorMessage = ArtisanValidators.getErrorMessage('description');
      return false;
    }

    return true;
  }

  String _formatWithStyle(List<TextEditingController> controllers, String style) {
    final validLines = controllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();
    
    if (validLines.isEmpty) return "";
    if (validLines.length == 1) return validLines.first;

    if (style == 'star') {
      return validLines.map((d) => '★ $d').join('\n');
    } else if (style == 'tick') {
      return validLines.map((d) => '✓ $d').join('\n');
    } else if (style == 'number') {
      return List.generate(validLines.length, (i) => '${i + 1}. ${validLines[i]}').join('\n');
    } else {
      return validLines.map((d) => '• $d').join('\n');
    }
  }

  Future<void> _saveArtisanProfile(
    String userId, 
    String? profileImageUrl, 
    List<String> workImages
  ) async {
    final existingProfile = await _artisanService.getProfile(userId);

    final profile = ArtisanProfile(
      id: userId,
      name: nameController.text.trim(),
      profession: selectedProfession,
      professionUrdu: _getProfessionUrdu(selectedProfession),
      location: locationController.text.trim(),
      latitude: jobLatitude,
      longitude: jobLongitude,
      experience: int.tryParse(experienceController.text) ?? 0,
      rate: rateController.text.trim().isEmpty
          ? null
          : rateController.text.trim(),
      rateUnit: rateUnit,
      availability: availability,
      qualification: _formatWithStyle(qualificationControllers, qualificationBulletStyle),
      phone: phoneController.text.trim(),
      email: emailController.text.trim().isEmpty
          ? null
          : emailController.text.trim(),
      showPhone: showPhone,
      showWhatsApp: showWhatsApp,
      description: _formatWithStyle(descriptionControllers, descriptionBulletStyle),
      profileImage: profileImageUrl,
      workImages: workImages,
      rating: existingProfile?.rating ?? 0.0,
      totalReviews: existingProfile?.totalReviews ?? 0,
      isVerified: existingProfile?.isVerified ?? false,
      isActive: true,
      createdAt: existingProfile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      skills: customSkills,
      website: websiteController.text.trim().isEmpty ? null : websiteController.text.trim(),
    );

    await _artisanService.saveProfile(profile);
  }

  Future<bool> deleteProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    isLoading = true;
    notifyListeners();

    try {
      // Delete artisan profile
      await _artisanService.deleteProfile(user.uid);

      // Update users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isArtisan': false,
        'artisanProfileId': FieldValue.delete(),
      });

      // Reset state
      showExpertFields = false;
      remoteWorkImages = [];
      workImages = [];
      
      // تعارف کے خانوں کو صاف کریں
      for (var c in descriptionControllers) {
        c.dispose();
      }
      descriptionControllers.clear();
      addDescriptionField();

      // تعلیمی قابلیت کے خانوں کو صاف کریں
      for (var c in qualificationControllers) {
        c.dispose();
      }
      qualificationControllers.clear();
      addQualificationField();

      experienceController.clear();
      locationController.clear();
      verificationStatus = 'none';
      isVerified = false;
      
      isLoading = false;
      notifyListeners();
      return true;

    } catch (e, stack) {
      _logger.error("Profile delete error", e, stack);
      errorMessage = 'Failed to delete profile: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void addSkill() {
    final skill = skillInputController.text.trim();
    if (skill.isNotEmpty && !customSkills.contains(skill)) {
      customSkills.add(skill);
      skillInputController.clear();
      notifyListeners();
    }
  }

  void removeSkill(String skill) {
    customSkills.remove(skill);
    notifyListeners();
  }

  String _getProfessionUrdu(String profession) {
    final config = ProfessionsConfig.allProfessions.firstWhere(
      (p) => p.id == profession,
      orElse: () => ProfessionsConfig.allProfessions.first,
    );
    return config.name;
  }

  String _getAvatarForName(String name) {
    if (name.isEmpty) return 'assets/avatars/avatar.svg';
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % 8;
    if (index == 0) return 'assets/avatars/avatar.svg';
    return 'assets/avatars/avatar ($index).svg';
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    locationController.dispose();
    for (var c in qualificationControllers) {
      c.dispose();
    }
    for (var c in descriptionControllers) {
      c.dispose();
    }
    experienceController.dispose();
    rateController.dispose();
    skillInputController.dispose();
    websiteController.dispose();
    super.dispose();
  }
}
