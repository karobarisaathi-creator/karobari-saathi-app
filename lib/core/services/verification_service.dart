import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:account_app/core/utils/image_utils.dart';

enum VerificationStatus { none, pending, approved, rejected }

class VerificationService with ChangeNotifier {
  static const Set<String> _trustedAdminEmails = {
    'karobarisaathi@gmail.com',
    'admin@accountapp.com',
  };

  static const Set<String> _trustedAdminUids = {
    'trusted-admin',
  };

  static const int _maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  VerificationStatus _currentStatus = VerificationStatus.none;
  String? _adminNote;
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;

  VerificationStatus get currentStatus => _currentStatus;
  VerificationStatus get artisanStatus =>
      _currentStatus; // Both point to the same unified status
  String? get adminNote => _adminNote;
  String? get artisanAdminNote => _adminNote;
  bool get isLoading => _isLoading;

  static bool canAccessAdminPanel({
    required Map<String, dynamic>? userData,
    required String? uid,
    required String? email,
    required String? phone,
  }) {
    final data = userData ?? const <String, dynamic>{};
    final normalizedEmail = email?.trim().toLowerCase();
    final normalizedPhone = phone?.trim();
    final rawRole = data['role'];
    final rawAdminFlag = data['isAdmin'];

    final isAdminFlag = rawAdminFlag is bool
        ? rawAdminFlag
        : rawAdminFlag is String && rawAdminFlag.toLowerCase() == 'true';
    final isAdminRole = rawRole is String && rawRole.toLowerCase() == 'admin';

    return isAdminFlag ||
        isAdminRole ||
        (_trustedAdminEmails.contains(normalizedEmail) ||
            _trustedAdminUids.contains(uid) ||
            normalizedPhone == '+923036363520');
  }

  VerificationService() {
    _init();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _init() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToStatus(user.uid);
      } else {
        _statusSubscription?.cancel();
        _currentStatus = VerificationStatus.none;
        _adminNote = null;
        notifyListeners();
      }
    });
  }

  void _listenToStatus(String uid) {
    VerificationStatus previousStatus = _currentStatus;

    _statusSubscription?.cancel();
    _statusSubscription = _firestore
        .collection('verification_requests')
        .doc(uid)
        .snapshots()
        .listen(
      (doc) async {
        try {
          if (doc.exists) {
            final data = doc.data();
            if (data == null) {
              _currentStatus = VerificationStatus.none;
              _adminNote = null;
              if (previousStatus == VerificationStatus.approved) {
                await _updateUserVerifiedFlag(uid, false);
                await _updateArtisanVerifiedFlag(uid, false);
              }
            } else {
              final statusStr = data['status'] as String?;
              _adminNote = data['adminNote'] as String?;

              switch (statusStr) {
                case 'pending':
                  _currentStatus = VerificationStatus.pending;
                  if (previousStatus == VerificationStatus.approved) {
                    await _updateUserVerifiedFlag(uid, false);
                    await _updateArtisanVerifiedFlag(uid, false);
                  }
                  break;
                case 'approved':
                  _currentStatus = VerificationStatus.approved;
                  if (previousStatus != VerificationStatus.approved) {
                    await _updateUserVerifiedFlag(uid, true);
                    await _updateArtisanVerifiedFlag(uid, true);
                    if (previousStatus == VerificationStatus.pending) {
                      _createVerificationNotification(uid, true);
                    }
                  }
                  break;
                case 'rejected':
                  _currentStatus = VerificationStatus.rejected;
                  if (previousStatus == VerificationStatus.approved) {
                    await _updateUserVerifiedFlag(uid, false);
                    await _updateArtisanVerifiedFlag(uid, false);
                  }
                  if (previousStatus == VerificationStatus.pending) {
                    _createVerificationNotification(uid, false);
                  }
                  break;
                default:
                  _currentStatus = VerificationStatus.none;
                  _adminNote = null;
                  if (previousStatus == VerificationStatus.approved) {
                    await _updateUserVerifiedFlag(uid, false);
                    await _updateArtisanVerifiedFlag(uid, false);
                  }
              }
            }
          } else {
            _currentStatus = VerificationStatus.none;
            _adminNote = null;
            if (previousStatus == VerificationStatus.approved) {
              await _updateUserVerifiedFlag(uid, false);
              await _updateArtisanVerifiedFlag(uid, false);
            }
          }
          previousStatus = _currentStatus;
          notifyListeners();
        } catch (e) {
          debugPrint('Error in _listenToStatus: $e');
          _currentStatus = VerificationStatus.none;
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('Stream error in _listenToStatus: $e');
        _currentStatus = VerificationStatus.none;
        notifyListeners();
      },
    );
  }

  Future<void> _updateArtisanVerifiedFlag(String uid, bool isVerified) async {
    try {
      await _firestore.collection('artisans').doc(uid).set({
        'isVerified': isVerified,
        'verificationStatus': isVerified ? 'approved' : 'none',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update artisan verification flag: $e');
    }
  }

  /// Unified method to submit verification requests (both artisans and regular users)
  Future<void> submitVerificationRequest({
    required File cnicFront,
    required File cnicBack,
    File? shopImage,
    required String businessName,
    required String businessType,
    bool isArtisanRequest = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('صارف لاگ ان نہیں ہے');

    _isLoading = true;
    notifyListeners();

    try {
      // Validate files
      _validateImageFile(cnicFront);
      _validateImageFile(cnicBack);
      if (shopImage != null) {
        _validateImageFile(shopImage);
      }

      final frontUrl = await _uploadImage(cnicFront, 'cnic_front_${user.uid}');
      final backUrl = await _uploadImage(cnicBack, 'cnic_back_${user.uid}');
      String? shopUrl;
      if (shopImage != null) {
        shopUrl = await _uploadImage(shopImage, 'shop_${user.uid}');
      }

      // Unified collection: verification_requests
      await _firestore.collection('verification_requests').doc(user.uid).set({
        'uid': user.uid,
        'name': isArtisanRequest ? (businessName) : (user.displayName ?? ''),
        'phone': user.phoneNumber ?? '',
        'businessName': businessName,
        'businessType': businessType,
        'cnicFront': frontUrl,
        'cnicBack': backUrl,
        'shopImageUrl': shopUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'adminNote': null,
        'reviewedBy': null,
        'reviewedAt': null,
        'isArtisanRequest': isArtisanRequest,
      }, SetOptions(merge: false));

      debugPrint('تصدیق درخواست کامیابی سے جمع ہوگئی');
    } catch (e) {
      debugPrint('تصدیق درخواست میں خرابی: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deprecated: Use submitVerificationRequest instead
  Future<void> submitArtisanRequest({
    required File cnicFront,
    required File cnicBack,
    File? shopImage,
    required String artisanName,
    required String profession,
  }) async {
    return submitVerificationRequest(
      cnicFront: cnicFront,
      cnicBack: cnicBack,
      shopImage: shopImage,
      businessName: artisanName,
      businessType: profession,
      isArtisanRequest: true,
    );
  }

  Future<void> _updateUserVerifiedFlag(String uid, bool isVerified) async {
    try {
      final data = <String, dynamic>{'isVerified': isVerified};
      if (isVerified) {
        data['verifiedAt'] = FieldValue.serverTimestamp();
      } else {
        data['verifiedAt'] = FieldValue.delete();
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      debugPrint('User $uid verification flag updated to $isVerified.');
    } catch (e) {
      debugPrint('Failed to update verification flag: $e');
    }
  }

  /// Deprecated: Use submitVerificationRequest instead
  Future<void> submitRequest({
    required File cnicFront,
    required File cnicBack,
    File? shopImage,
    required String businessName,
    required String businessType,
    bool isArtisan = false,
  }) async {
    return submitVerificationRequest(
      cnicFront: cnicFront,
      cnicBack: cnicBack,
      shopImage: shopImage,
      businessName: businessName,
      businessType: businessType,
      isArtisanRequest: isArtisan,
    );
  }

  /// Validate image file before upload
  void _validateImageFile(File file) {
    if (!file.existsSync()) {
      throw Exception('فائل موجود نہیں ہے: ${file.path}');
    }

    final fileSizeBytes = file.lengthSync();
    if (fileSizeBytes > _maxImageSizeBytes) {
      throw Exception(
          'فائل بہت بڑی ہے۔ زیادہ سے زیادہ سائز: ${_maxImageSizeBytes ~/ (1024 * 1024)} MB');
    }

    final allowedExtensions = {'jpg', 'jpeg', 'png', 'gif'};
    final extension = file.path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw Exception('غیر معاون فائل کی قسم: $extension');
    }
  }

  Future<String> _uploadImage(File file, String fileName) async {
    try {
      // Compress image before upload
      final compressedFile = await ImageUtils.compressImage(
        file,
        quality: 70,
        maxWidth: 1024,
      );

      final extension = file.path.split('.').last.toLowerCase();
      final ref = _storage
          .ref()
          .child('verification_documents')
          .child('$fileName.$extension');

      final uploadTask = await ref.putFile(compressedFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('تصویر کامیابی سے اپ لوڈ ہوگئی: $fileName');
      return downloadUrl;
    } catch (e) {
      debugPrint('تصویر اپ لوڈ میں خرابی: $e');
      rethrow;
    }
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
      debugPrint('Cancel request error: $e');
    }
  }

  // ==================== ADMIN FUNCTIONS ====================

  /// Fetch all pending verification requests
  Stream<List<Map<String, dynamic>>> getPendingRequests() {
    return _firestore
        .collection('verification_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();

      requests.sort((a, b) {
        final aDate = (a['submittedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = (b['submittedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return requests;
    });
  }

  /// Update request status (Approve/Reject)
  Future<void> processRequest({
    required String uid,
    required bool approve,
    String? adminNote,
  }) async {
    final adminUser = _auth.currentUser;
    if (adminUser == null) throw Exception('Admin not logged in');

    try {
      final status = approve ? 'approved' : 'rejected';

      await _firestore.collection('verification_requests').doc(uid).update({
        'status': status,
        'adminNote': adminNote,
        'reviewedBy': adminUser.email ?? adminUser.phoneNumber,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Verification flag update and notification creation is already handled by
      // the existing _listenToStatus listener which monitors this collection.

      debugPrint('Request for $uid processed: $status');
    } catch (e) {
      debugPrint('Process request error: $e');
      rethrow;
    }
  }

  // ==================== MASTER ADMIN FUNCTIONS ====================

  /// Get global app statistics
  Future<Map<String, dynamic>> getAppStats() async {
    try {
      final usersCount = await _firestore.collection('users').count().get();
      final itemsCount =
          await _firestore.collectionGroup('inventory_items').count().get();
      final verifiedCount = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .count()
          .get();
      final reportsCount =
          await _firestore.collection('seller_reports').count().get();

      return {
        'totalUsers': usersCount.count,
        'totalItems': itemsCount.count,
        'totalVerified': verifiedCount.count,
        'totalReports': reportsCount.count,
      };
    } catch (e) {
      debugPrint('Get stats error: $e');
      return {};
    }
  }

  /// Stream all registered users
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'uid': doc.id})
            .toList());
  }

  /// Search user by phone
  Future<List<Map<String, dynamic>>> searchUsers(String phone) async {
    final query = await _firestore
        .collection('users')
        .where('phoneNumber', isGreaterThanOrEqualTo: phone)
        .where('phoneNumber', isLessThanOrEqualTo: phone + '\uf8ff')
        .get();
    return query.docs.map((doc) => {...doc.data(), 'uid': doc.id}).toList();
  }

  /// Stream complaints/reports
  Stream<List<Map<String, dynamic>>> getReports() {
    return _firestore.collection('seller_reports').snapshots().map((snapshot) {
      final reports = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      reports.sort((a, b) {
        final aDate = (a['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = (b['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return reports;
    });
  }

  /// Block/Deactivate a user
  Future<void> toggleUserStatus(String uid, bool deactivate) async {
    await _firestore.collection('users').doc(uid).update({
      'isDeactivated': deactivate,
      'deactivatedAt': deactivate ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Revoke verification badge from a user
  Future<void> revokeVerification(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'isVerified': false,
      'verifiedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Send a notification to ALL users
  Future<void> sendBroadcastNotification({
    required String title,
    required String message,
  }) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (var doc in usersSnapshot.docs) {
        final notifId =
            "broadcast_${DateTime.now().millisecondsSinceEpoch}_${doc.id.substring(0, 4)}";
        final ref = _firestore
            .collection('users')
            .doc(doc.id)
            .collection('notifications')
            .doc(notifId);

        batch.set(ref, {
          'id': notifId,
          'title': title,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'system',
          'isRead': false,
        });
      }

      await batch.commit();
      debugPrint('Broadcast sent to ${usersSnapshot.docs.length} users');
    } catch (e) {
      debugPrint('Broadcast error: $e');
      rethrow;
    }
  }

  Future<void> _createVerificationNotification(
      String uid, bool isApproved) async {
    try {
      final notifId = "verify_${DateTime.now().millisecondsSinceEpoch}";
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notifId)
          .set({
        'id': notifId,
        'title': isApproved ? 'تصدیق مکمل! 🎉' : 'تصدیق مسترد ❌',
        'message': isApproved
            ? 'مبارک ہو! آپ کا اکاؤنٹ اب ویریفائیڈ ہو گیا ہے۔'
            : 'معذرت، آپ کی تصدیق کی درخواست مسترد کر دی گئی ہے۔ تفصیلات کے لیے سیٹنگز دیکھیں۔',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'isRead': false,
        'data': {'status': isApproved ? 'approved' : 'rejected'},
      });
    } catch (e) {
      debugPrint('Failed to create verification notification: $e');
    }
  }
}
