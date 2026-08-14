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