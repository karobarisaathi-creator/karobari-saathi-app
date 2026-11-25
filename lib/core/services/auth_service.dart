import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/database/profile_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/features/settings/login_screen.dart'; // For navigation

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update Profile
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? address,
    String? slogan,
    String? storeName,
    String? storeImage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final sanitizedName =
          displayName != null ? Formatters.sanitizeText(displayName) : null;
      final sanitizedAddress =
          address != null ? Formatters.sanitizeText(address) : null;
      final sanitizedSlogan =
          slogan != null ? Formatters.sanitizeText(slogan) : null;
      final sanitizedStoreName =
          storeName != null ? Formatters.sanitizeText(storeName) : null;

      if (sanitizedName != null) {
        await user.updateDisplayName(sanitizedName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore as well
      Map<String, dynamic> updateData = {
        'displayName': sanitizedName ?? user.displayName,
        'photoURL': photoUrl ?? user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (sanitizedAddress != null) {
        updateData['address'] = sanitizedAddress;
        updateData['businessAddress'] = sanitizedAddress;
      }
      if (sanitizedSlogan != null) updateData['slogan'] = sanitizedSlogan;
      if (sanitizedStoreName != null) {
        updateData['storeName'] = sanitizedStoreName;
        updateData['shopName'] = sanitizedStoreName;
      }
      if (storeImage != null) updateData['storeImage'] = storeImage;

      final userRef = _firestore.collection('users').doc(user.uid);
      final existingProfile = await userRef.get();
      await userRef.set(updateData, SetOptions(merge: true));
      await _firestore.collection('public_profiles').doc(user.uid).set(
            ProfileService.publicProfileData(
              uid: user.uid,
              userData: {...?existingProfile.data(), ...updateData},
              verifiedPhoneNumber: user.phoneNumber,
            ),
          );
      ProfileService.clearCache();

      notifyListeners();
    } catch (e) {
      throw Exception("Failed to update profile: $e");
    }
  }

  // Sign Out
  Future<void> signOut(
    BuildContext context, {
    bool syncBeforeLogout = false,
  }) async {
    if (!context.mounted) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final autoSyncService = syncBeforeLogout
        ? Provider.of<AutoSyncService>(context, listen: false)
        : null;
    if (autoSyncService != null) {
      await dbService.syncWithFirebase();
      await autoSyncService.syncAllDataToCloud();
    }

    Object? cleanupError;
    try {
      await dbService.prepareForLogout();
    } catch (error, stackTrace) {
      cleanupError = error;
      debugPrint('Local data cleanup failed during sign-out: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    ProfileService.clearCache();

    await _auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }

    if (cleanupError != null) {
      throw Exception(
          'Signed out, but local data cleanup failed: $cleanupError');
    }
  }

  // Deactivate account
  Future<void> deactivateAccount(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null || !context.mounted) return;

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user.uid), {
        'isDeactivated': true,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'restoreDeadline':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });
      batch.delete(_firestore.collection('public_profiles').doc(user.uid));
      await batch.commit();

      Object? cleanupError;
      try {
        await dbService.prepareForLogout();
      } catch (error, stackTrace) {
        cleanupError = error;
        debugPrint('Local data cleanup failed during deactivation: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      ProfileService.clearCache();
      await _auth.signOut();

      // Navigate to login screen and remove all previous routes
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
      if (cleanupError != null) {
        throw Exception(
            'Account deactivated, but local data cleanup failed: $cleanupError');
      }
    } catch (e) {
      throw Exception("Failed to deactivate account: $e");
    }
  }
}
