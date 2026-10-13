import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:account_app/core/config/app_roles.dart';
import 'package:account_app/core/utils/image_utils.dart';

enum ProfileSaveStatus { idle, loading, success, error }

class ProfileController extends ChangeNotifier {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController shopNameController = TextEditingController();

  AppRole selectedRole = AppRole.simple;

  bool isLoading = false;
  bool isEditing = false;
  bool hasLoadError = false;
  bool _isDisposed = false;
  String? remoteProfileImage;
  File? profileImage;
  String? remoteBannerImage;
  File? bannerImage;
  ProfileSaveStatus saveStatus = ProfileSaveStatus.idle;
  String? errorMessage;

  void setRole(AppRole role) {
    if (selectedRole != role) {
      selectedRole = role;
      notifyListeners();
    }
  }

  Future<void> loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isLoading = true;
    hasLoadError = false;
    errorMessage = null;
    notifyListeners();
    phoneController.text = user.phoneNumber ?? '';
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
      selectedRole = AppRoleExtension.fromString(data?['role']?.toString());
      remoteProfileImage = (data?['photoURL'] ?? user.photoURL)?.toString();
      remoteBannerImage = (data?['shopBannerUrl'] ?? data?['bannerUrl'])?.toString();
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
      errorMessage = 'Profile could not be loaded. Reopen this screen and try again before saving.';
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

      String? bannerImageUrl = remoteBannerImage;
      if (bannerImage != null) {
        final compressed = await ImageUtils.compressImage(bannerImage!);
        final extension = bannerImage!.path.split('.').last.toLowerCase();
        final imageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/banner.$extension');
        await imageRef.putFile(compressed);
        bannerImageUrl = await imageRef.getDownloadURL();
      }

      await user.updateDisplayName(nameController.text.trim());
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        await user.updatePhotoURL(profileImageUrl);
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'businessAddress': addressController.text.trim(),
        'shopName': shopNameController.text.trim(),
        'role': selectedRole.id,
        'photoURL': profileImageUrl,
        'shopBannerUrl': bannerImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (selectedRole == AppRole.shopkeeper &&
          shopNameController.text.trim().isNotEmpty) {
        final publicShopData = {
          'uid': user.uid,
          'displayName': nameController.text.trim(),
          'ownerName': nameController.text.trim(),
          'shopName': shopNameController.text.trim(),
          'businessAddress': addressController.text.trim(),
          'role': selectedRole.id,
          'photoURL': profileImageUrl,
          'profileImageUrl': profileImageUrl,
          'shopBannerUrl': bannerImageUrl,
          'bannerImageUrl': bannerImageUrl,
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
        await FirebaseFirestore.instance.collection('public_shops').doc(user.uid).delete();
      }

      remoteProfileImage = profileImageUrl;
      remoteBannerImage = bannerImageUrl;
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
    super.dispose();
  }
}
