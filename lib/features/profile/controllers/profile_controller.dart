import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:account_app/core/config/app_roles.dart';
import 'package:account_app/core/utils/image_utils.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/database/profile_service.dart';

enum ProfileSaveStatus { idle, loading, success, error }

class ProfileController extends ChangeNotifier {
  final UrduAwareTextEditingController nameController =
      UrduAwareTextEditingController();
  final UrduAwareTextEditingController phoneController =
      UrduAwareTextEditingController();
  final UrduAwareTextEditingController emailController =
      UrduAwareTextEditingController();
  final UrduAwareTextEditingController addressController =
      UrduAwareTextEditingController();
  final UrduAwareTextEditingController shopNameController =
      UrduAwareTextEditingController();
  final UrduAwareTextEditingController professionController =
      UrduAwareTextEditingController();
  final UrduAwareTextEditingController aboutController =
      UrduAwareTextEditingController();

  AppRole selectedRole = AppRole.simple;

  bool isLoading = false;
  bool isEditing = false;
  bool hasLoadError = false;
  bool _isDisposed = false;
  String? remoteProfileImage;
  File? profileImage;
  ProfileSaveStatus saveStatus = ProfileSaveStatus.idle;
  String? errorMessage;

  bool get isShopkeeper => shopNameController.text.trim().isNotEmpty;

  Future<void> loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isLoading = true;
    hasLoadError = false;
    errorMessage = null;
    notifyListeners();
    phoneController.text = Formatters.formatPhoneNumber(user.phoneNumber ?? '');
    emailController.text = user.email ?? '';
    remoteProfileImage = user.photoURL;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      nameController.text =
          (data?['displayName'] ?? data?['name'] ?? user.displayName ?? '')
              .toString();
      emailController.text = (data?['email'] ?? user.email ?? '').toString();
      addressController.text = (data?['businessAddress'] ?? '').toString();
      shopNameController.text = (data?['shopName'] ?? '').toString();
      professionController.text = (data?['profession'] ?? '').toString();
      aboutController.text = (data?['about'] ?? '').toString();
      selectedRole = isShopkeeper ? AppRole.shopkeeper : AppRole.simple;
      remoteProfileImage = (data?['photoURL'] ?? user.photoURL)?.toString();
      isEditing = nameController.text.trim().isNotEmpty;
    } catch (error) {
      hasLoadError = true;
      errorMessage = 'Failed to load profile: $error';
    } finally {
      isLoading = false;
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
    if (hasLoadError) {
      errorMessage =
          'Profile could not be loaded. Reopen this screen and try again before saving.';
      saveStatus = ProfileSaveStatus.error;
      notifyListeners();
      return false;
    }

    saveStatus = ProfileSaveStatus.loading;
    notifyListeners();

    try {
      String? profileImageUrl = remoteProfileImage;
      if (profileImage != null) {
        final compressed = await ImageUtils.compressImage(profileImage!);
        final extension = profileImage!.path.split('.').last.toLowerCase();
        final imageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/profile.$extension');
        await imageRef.putFile(compressed);
        profileImageUrl = await imageRef.getDownloadURL();
      }

      final hasShopName = shopNameController.text.trim().isNotEmpty;

      final effectiveShopkeeper = hasShopName;
      selectedRole = effectiveShopkeeper ? AppRole.shopkeeper : AppRole.simple;

      await user.updateDisplayName(nameController.text.trim());
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        await user.updatePhotoURL(profileImageUrl);
      }
      final userProfileData = {
        'displayName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phoneNumber': user.phoneNumber,
        'businessAddress': addressController.text.trim(),
        'shopName': shopNameController.text.trim(),
        'profession': professionController.text.trim(),
        'about': aboutController.text.trim(),
        'role': selectedRole.id,
        'photoURL': profileImageUrl,
        'latitude': FieldValue.delete(),
        'longitude': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(
        firestore.collection('users').doc(user.uid),
        userProfileData,
        SetOptions(merge: true),
      );
      batch.set(
        firestore.collection('public_profiles').doc(user.uid),
        ProfileService.publicProfileData(
          uid: user.uid,
          userData: userProfileData,
          verifiedPhoneNumber: user.phoneNumber,
        ),
      );
      await batch.commit();

      if (effectiveShopkeeper) {
        final publicShopData = {
          'uid': user.uid,
          'displayName': nameController.text.trim(),
          'ownerName': nameController.text.trim(),
          'shopName': shopNameController.text.trim(),
          'profession': professionController.text.trim(),
          'businessAddress': addressController.text.trim(),
          'latitude': FieldValue.delete(),
          'longitude': FieldValue.delete(),
          'role': selectedRole.id,
          'photoURL': profileImageUrl,
          'profileImageUrl': profileImageUrl,
          'isOpen': true,
          'rating': 0,
          'reviews': 0,
          'distance': '',
          'distanceVal': null,
          'deliveryTime': '',
          'timeVal': 0,
          'minOrder': '',
          'deliveryFee': '',
          'tags': [],
          'itemCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('public_shops')
            .doc(user.uid)
            .set(publicShopData, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance
            .collection('public_shops')
            .doc(user.uid)
            .delete();
      }

      remoteProfileImage = profileImageUrl;
      saveStatus = ProfileSaveStatus.success;
      isEditing = true;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = 'Failed to save profile: $error';
      saveStatus = ProfileSaveStatus.error;
      notifyListeners();
      return false;
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    shopNameController.dispose();
    professionController.dispose();
    aboutController.dispose();
    super.dispose();
  }
}
