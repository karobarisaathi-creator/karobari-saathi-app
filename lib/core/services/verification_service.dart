import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum VerificationStatus { none, pending, approved, rejected }

class VerificationService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  VerificationStatus _currentStatus = VerificationStatus.none;
  String? _adminNote;
  bool _isLoading = false;

  VerificationStatus get currentStatus => _currentStatus;
  String? get adminNote => _adminNote;
  bool get isLoading => _isLoading;

  VerificationService() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToStatus(user.uid);
      } else {
        _currentStatus = VerificationStatus.none;
        _adminNote = null;
        notifyListeners();
      }
    });
  }

  void _listenToStatus(String uid) {
    VerificationStatus previousStatus = _currentStatus;

    _firestore
        .collection('verification_requests')
        .doc(uid)
        .snapshots()
        .listen((doc) async {
      if (doc.exists) {
        final data = doc.data()!;
        final statusStr = data['status'] as String?;
        _adminNote = data['adminNote'] as String?;

        switch (statusStr) {
          case 'pending':
            _currentStatus = VerificationStatus.pending;
            break;
          case 'approved':
            _currentStatus = VerificationStatus.approved;
            if (previousStatus != VerificationStatus.approved) {
              await _markUserVerified(uid);
            }
            break;
          case 'rejected':
            _currentStatus = VerificationStatus.rejected;
            break;
          default:
            _currentStatus = VerificationStatus.none;
        }
      } else {
        _currentStatus = VerificationStatus.none;
        _adminNote = null;
      }
      previousStatus = _currentStatus;
      notifyListeners();
    });
  }

  Future<void> _markUserVerified(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('User $uid marked as verified in users collection.');
    } catch (e) {
      debugPrint('Failed to mark user verified: $e');
    }
  }

  Future<void> submitRequest({
    required File shopImage,
    required File idImage,
    required String businessName,
    required String businessType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Upload Images
      final shopUrl = await _uploadImage(shopImage, 'shop_${user.uid}');
      final idUrl = await _uploadImage(idImage, 'id_${user.uid}');

      // 2. Save Request to Firestore
      await _firestore.collection('verification_requests').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName,
        'phone': user.phoneNumber,
        'businessName': businessName,
        'businessType': businessType,
        'shopImageUrl': shopUrl,
        'idImageUrl': idUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'adminNote': null,
      });
    } catch (e) {
      print('Verification submission error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _uploadImage(File file, String fileName) async {
    final ref =
        _storage.ref().child('verification_documents').child('$fileName.jpg');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> cancelRequest() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('verification_requests')
          .doc(user.uid)
          .delete();
    } catch (e) {
      print('Cancel request error: $e');
    }
  }
}
