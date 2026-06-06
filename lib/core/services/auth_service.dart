import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database_service.dart';
import 'package:account_app/features/settings/login_screen.dart'; // For navigation

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update Profile
  Future<void> updateProfile({String? displayName, String? photoUrl, String? address, String? slogan}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }
      
      // Update Firestore as well
      Map<String, dynamic> updateData = {
        'displayName': displayName ?? user.displayName,
        'photoURL': photoUrl ?? user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (address != null) updateData['address'] = address;
      if (slogan != null) updateData['slogan'] = slogan;

      await _firestore.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      throw Exception("Failed to update profile: $e");
    }
  }

  // Sign Out
  Future<void> signOut(BuildContext context) async {
    try {
      // 1. Prepare for logout (Stop listeners and clear data while boxes are open)
      if (context.mounted) {
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        await dbService.prepareForLogout();
      }

      // 2. Small delay to ensure all async operations finish
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Finally sign out from Firebase
      await _auth.signOut();

      // Navigate to login screen
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      debugPrint("Sign out error: $e");
      // Fallback signout
      await _auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  // Deactivate account
  Future<void> deactivateAccount(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Directly update Firestore to avoid dependency issues
      await _firestore.collection('users').doc(user.uid).update({
        'isDeactivated': true,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      // Sign out the user
      await _auth.signOut();

      // Clear local data
      if (context.mounted) {
         final dbService = Provider.of<DatabaseService>(context, listen: false);
         await dbService.clearLocalData();
      }
      
      // Navigate to login screen and remove all previous routes
      if (!context.mounted) return; 
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );

    } catch (e) {
      throw Exception("Failed to deactivate account: $e");
    }
  }

  // Activate account - This would typically be an admin function.
  Future<void> activateAccount(BuildContext context, String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeactivated': false,
        'deactivatedAt': null,
      });
    } catch (e) {
      throw Exception("Failed to activate account: $e");
    }
  }
}
