import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:account_app/core/utils/image_utils.dart';

enum ProfileSaveStatus { idle, loading, success, error }

class ProfileController extends ChangeNotifier {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false;
  bool isEditing = false;
  bool _isDisposed = false;
  String? remoteProfileImage;
  File? profileImage;
  ProfileSaveStatus saveStatus = ProfileSaveStatus.idle;
  String? errorMessage;

  Future<void> loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isLoading = true;
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
      remoteProfileImage = (data?['photoURL'] ?? user.photoURL)?.toString();
      isEditing = nameController.text.trim().isNotEmpty;
    } catch (error) {
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

      await user.updateDisplayName(nameController.text.trim());
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        await user.updatePhotoURL(profileImageUrl);
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'photoURL': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
    super.dispose();
  }
}
