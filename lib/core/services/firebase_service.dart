import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';

// GroupActivity کو ہٹا دیں کیونکہ اب Partnership استعمال ہو رہا ہے

import 'package:account_app/core/utils/image_utils.dart';

class FirebaseService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // User Management
  Future<void> saveUserProfile(String phoneNumber, String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'phoneNumber': phoneNumber,
        'name': name,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    }
    return null;
  }

  // Accounts Management
  Future<void> syncAccountToCloud(Account account) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .doc(account.id)
          .set(account.toMap(), SetOptions(merge: true));
      print("✅ Account synced to Firebase: ${account.name}");
    }
  }

  Future<List<Account>> getAccountsFromCloud() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .get();

      return snapshot.docs.map((doc) => Account.fromMap(doc.data())).toList();
    }
    return [];
  }

  // Transactions Management
  Future<void> syncTransactionToCloud(model.Transaction transaction) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap(), SetOptions(merge: true));
      print("✅ Transaction synced to Firebase");
    }
  }

  Future<List<model.Transaction>> getTransactionsFromCloud(String accountId) async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('accountId', isEqualTo: accountId)
          .get();

      return snapshot.docs
          .map((doc) => model.Transaction.fromMap(doc.data()))
          .toList();
    }
    return [];
  }

  // Professions Management
  Future<void> syncProfessionToCloud(Profession profession) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('professions')
          .doc(profession.id)
          .set(profession.toMap(), SetOptions(merge: true));
      print("✅ Profession synced to Firebase: ${profession.name}");
    }
  }

  Future<List<Profession>> getProfessionsFromCloud() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('professions')
          .get();

      return snapshot.docs
          .map((doc) => Profession.fromMap(doc.data()))
          .toList();
    }
    return [];
  }



  // File Storage
  Future<String> uploadFile(String filePath, String fileName) async {
    try {
      File fileToUpload = File(filePath);
      
      // If it's an image, compress it
      final ext = filePath.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        fileToUpload = await ImageUtils.compressImage(fileToUpload);
      }

      final ref = _storage.ref().child('files/$fileName');
      await ref.putFile(fileToUpload);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('File upload failed: $e');
    }
  }

  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      print("✅ File deleted from Firebase Storage");
    } catch (e) {
      print('❌ File delete error: $e');
    }
  }

  // Notifications
  Future<String?> getFCMToken() async {
    return await _messaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print("✅ Subscribed to topic: $topic");
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print("✅ Unsubscribed from topic: $topic");
  }

  // Data Backup & Restore
  Future<void> backupAllData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('backups').doc(user.uid).set({
        ...data,
        'backupDate': DateTime.now(),
        'userId': user.uid,
      });
      print("✅ Data backup created successfully");
    }
  }

  Future<Map<String, dynamic>?> restoreBackup() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('backups').doc(user.uid).get();
      if (doc.exists) {
        print("✅ Backup restored successfully");
        return doc.data();
      }
    }
    return null;
  }

  // Sharing System
  Future<void> shareAccountWithUser(
      String accountId,
      String targetPhoneNumber,
      ) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Find user by phone number
      final usersSnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: targetPhoneNumber)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        final targetUserId = usersSnapshot.docs.first.id;

        await _firestore
            .collection('shared_accounts')
            .doc('${accountId}_$targetPhoneNumber')
            .set({
          'accountId': accountId,
          'ownerId': user.uid,
          'sharedWith': targetUserId,
          'sharedAt': DateTime.now(),
          'permissions': ['view', 'chat'],
        });
        print("✅ Account shared with: $targetPhoneNumber");
      } else {
        throw Exception('User with phone number $targetPhoneNumber not found');
      }
    }
  }

  // Real-time Listeners
  Stream<QuerySnapshot> getAccountsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .snapshots();
    }
    return const Stream.empty();
  }

  Stream<QuerySnapshot> getTransactionsStream(String accountId) {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('accountId', isEqualTo: accountId)
          .snapshots();
    }
    return const Stream.empty();
  }

  Stream<QuerySnapshot> getPartnershipsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('partnerships')
          .snapshots();
    }
    return const Stream.empty();
  }

  // Data Cleanup Operations
  Future<void> deletePartnershipData(String partnershipId) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Delete partnership
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('partnerships')
          .doc(partnershipId)
          .delete();

      print("✅ Partnership data deleted from Firebase: $partnershipId");
    }
  }

  // Bulk Operations

  // Cleanup
  Future<void> deleteUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Delete all user data from Firestore
      final collections = [
        'accounts',
        'transactions',
        'professions',
        'backups',
        'partnerships', // groups سے partnerships میں تبدیل
      ];

      for (var collection in collections) {
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection(collection)
            .get();

        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Delete user document
      await _firestore.collection('users').doc(user.uid).delete();
      print("✅ All user data deleted from Firebase");
    }
  }

  // Utility Methods
  Future<bool> checkConnection() async {
    try {
      await _firestore.collection('users').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> waitForConnection({int maxRetries = 3, Duration delay = const Duration(seconds: 2)}) async {
    for (int i = 0; i < maxRetries; i++) {
      if (await checkConnection()) {
        return;
      }
      await Future.delayed(delay);
    }
    throw Exception('Unable to connect to Firebase after $maxRetries attempts');
  }
}