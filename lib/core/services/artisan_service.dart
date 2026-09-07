// lib/features/artisans/services/artisan_service.dart
import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/services/database/profession_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'package:account_app/core/config/professions_config.dart';

class ArtisanService extends BaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProfessionService _professionService = ProfessionService();
  final _logger = LoggingService();

  // Cache for professions list
  static List<Map<String, dynamic>>? _cachedProfessions;

  // ============================================================
  // 1. پروفائل بنانا / اپ ڈیٹ کرنا
  // ============================================================
  Future<void> saveProfile(ArtisanProfile profile) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('صارف لاگ ان نہیں ہے');

    if (user.uid != profile.id) {
      _logger.warning(
        "Security Alert: User ${user.uid} tried to update profile of ${profile.id}",
      );
      throw Exception('آپ کو یہ پروفائل تبدیل کرنے کا اختیار نہیں ہے');
    }

    try {
      await firestore
          .collection('artisans')
          .doc(profile.id)
          .set(profile.toMap(), SetOptions(merge: true));

      await _ensureArtisanProfession(profile);

      // Update local cache
      await artisansBox?.put(profile.id, profile);
      notifyListeners();
    } catch (e, stack) {
      _logger.error("Save profile error", e, stack);
      throw Exception('پروفائل محفوظ کرنے میں ناکامی');
    }
  }

  Future<void> _ensureArtisanProfession(ArtisanProfile profile) async {
    try {
      final user = auth.currentUser;
      if (user == null) return;

      // مستقل آئی ڈی تاکہ پیشہ بدلنے پر بھی ریکارڈ ایک ہی رہے
      const String professionId = "artisan_main_work";

      final professions = getProfessions();
      final pData = professions.firstWhere(
        (p) => p['id'] == profile.profession,
        orElse: () => {},
      );
      if (pData.isEmpty) return;

      final iconKey = _getProfessionIconKey(profile.profession);
      final String professionName = pData['name'] ?? profile.profession;

      // چیک کریں کہ کیا پہلے سے موجود ہے
      Profession? existing;
      if (professionsBox?.containsKey(professionId) ?? false) {
        existing = professionsBox!.get(professionId);
      }

      if (existing != null) {
        // اگر موجود ہے تو صرف نام اور آئیکن اپ ڈیٹ کریں
        final updated = existing.copyWith(
          name: professionName,
          description:
              "ICON:$iconKey|یہ پیشہ کاریگر پروفائل سے خودکار طور پر بنایا گیا ہے۔",
          updatedAt: DateTime.now(),
        );
        await _professionService.updateProfession(updated);

        _logger.info("Updated existing artisan profession: $professionName");
        return;
      }

      // اگر بالکل نہیں ہے تو نیا بنائیں
      final masterProfession = Profession(
        id: professionId,
        name: professionName,
        categories: [
          'INC:کام کی اجرت',
          'INC:دیگر آمدنی',
          'EXP:مٹیریل',
          'EXP:لیبر',
          'EXP:ٹرانسپورٹ',
        ],
        isActive: true,
        isMaster: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description:
            "ICON:$iconKey|یہ پیشہ کاریگر پروفائل سے خودکار طور پر بنایا گیا ہے۔",
        season: "عمومی",
      );

      await _professionService.addProfession(masterProfession);

      notifyListeners();
    } catch (e, stack) {
      _logger.error("Ensure profession error", e, stack);
    }
  }

  String _getProfessionIconKey(String profession) {
    final config = ProfessionsConfig.allProfessions.firstWhere(
      (p) => p.id == profession,
      orElse: () => ProfessionsConfig.allProfessions.first,
    );

    switch (config.id) {
      case 'mason':
        return 'hammer';
      case 'agri_expert':
        return 'agriculture';
      case 'livestock_expert':
        return 'livestock';
      case 'driver':
        return 'transport';
      case 'software_dev':
        return 'tech';
      default:
        return 'tools';
    }
  }

  // ============================================================
  // 1.5. پروفائل ڈیلیٹ کرنا
  // ============================================================
  Future<void> deleteProfile(String id) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('صارف لاگ ان نہیں ہے');

    if (user.uid != id) {
      throw Exception('آپ کو یہ پروفائل حذف کرنے کا اختیار نہیں ہے');
    }

    try {
      final profile = await getProfile(id);
      if (profile != null) {
        await _deleteProfileImages(profile);
      }

      await firestore.collection('artisans').doc(id).delete();
      await artisansBox?.delete(id);
      notifyListeners();
    } catch (e, stack) {
      _logger.error("Delete profile error", e, stack);
      throw Exception('پروفائل حذف کرنے میں ناکامی');
    }
  }

  Future<void> _deleteProfileImages(ArtisanProfile profile) async {
    try {
      if (profile.profileImage != null &&
          profile.profileImage!.startsWith('http')) {
        await _storage.refFromURL(profile.profileImage!).delete();
      }

      for (var imageUrl in profile.workImages) {
        if (imageUrl.startsWith('http')) {
          await _storage.refFromURL(imageUrl).delete();
        }
      }
    } catch (e, stack) {
      _logger.error("Delete profile images error", e, stack);
      // Continue even if image deletion fails
    }
  }

  // ============================================================
  // 1.7. تصاویر اپ لوڈ کرنا
  // ============================================================
  Future<String?> uploadImage(String userId, File file, String type) async {
    try {
      // Check file size using async method
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw 'تصویر کا سائز 5MB سے زیادہ نہیں ہونا چاہیے';
      }

      final extension = file.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        throw 'صرف تصاویر (JPG, PNG, GIF, WEBP) اپ لوڈ کی جا سکتی ہیں';
      }

      final fileName =
          "${userId}_${type}_${DateTime.now().millisecondsSinceEpoch}.$extension";
      final ref =
          _storage.ref().child('artisan_uploads').child(userId).child(fileName);

      _logger.info("Uploading $type image for user: $userId");
      await ref.putFile(file);

      final url = await ref.getDownloadURL();
      _logger.info("Upload successful: $url");
      return url;
    } on FirebaseException catch (e, stack) {
      _logger.error("Firebase Storage Error", e, stack);
      throw 'سرور پر تصویر اپ لوڈ کرنے میں خرابی ہوئی: ${e.message}';
    } catch (e, stack) {
      _logger.error("Unexpected Upload Error", e, stack);
      if (e is String) throw e;
      throw 'تصویر اپ لوڈ کرنے میں ناکامی ہوئی';
    }
  }

  // ============================================================
  // 2. پروفائل حاصل کرنا
  // ============================================================
  Future<ArtisanProfile?> getProfile(String id) async {
    try {
      // Check local cache first
      if (artisansBox?.containsKey(id) ?? false) {
        return artisansBox!.get(id);
      }

      final doc = await firestore.collection('artisans').doc(id).get();
      if (doc.exists) {
        final profile =
            ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>);
        await artisansBox?.put(id, profile);
        return profile;
      }
      return null;
    } catch (e, stack) {
      _logger.error("Get profile error", e, stack);
      return null;
    }
  }

  Stream<ArtisanProfile?> streamProfile(String id) {
    return firestore.collection('artisans').doc(id).snapshots().map((doc) {
      if (doc.exists) {
        final profile =
            ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>);
        artisansBox?.put(id, profile);
        return profile;
      }
      return null;
    });
  }

  // ============================================================
  // 3. تمام کاریگر حاصل کریں
  // ============================================================
  Future<List<ArtisanProfile>> getAllArtisans() async {
    final localArtisans = artisansBox?.values.toList() ?? [];
    _syncAllArtisansFromCloud();
    return localArtisans;
  }

  Future<void> _syncAllArtisansFromCloud() async {
    try {
      final snapshot = await firestore
          .collection('artisans')
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        final profile =
            ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>);
        await artisansBox?.put(profile.id, profile);
      }
      notifyListeners();
    } catch (e, stack) {
      _logger.error("Sync artisans error", e, stack);
    }
  }

  Stream<List<ArtisanProfile>> streamAllArtisans() {
    return firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<ArtisanProfile>> streamArtisansPaginated({int limit = 20}) {
    return firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<List<ArtisanProfile>> getArtisansBatch({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = firestore
          .collection('artisans')
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) =>
              ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.error("Get artisans batch error", e, stack);
      return [];
    }
  }

  // ============================================================
  // 4. پیشے کے حساب سے تلاش
  // ============================================================
  Future<List<ArtisanProfile>> searchByProfession(
    String profession, {
    double? latitude,
    double? longitude,
    double radiusKm = 10,
  }) async {
    try {
      final query =
          firestore.collection('artisans').where('isActive', isEqualTo: true);

      final snapshot = await query.get();
      var results = snapshot.docs
          .map((doc) =>
              ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      results = results
          .where((p) =>
              p.profession == profession || p.skills.contains(profession))
          .toList();

      if (latitude != null && longitude != null) {
        results = results.where((p) {
          if (p.latitude == null || p.longitude == null) return false;
          final distance = Geolocator.distanceBetween(
                latitude,
                longitude,
                p.latitude!,
                p.longitude!,
              ) /
              1000;
          return distance <= radiusKm;
        }).toList();
      }

      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results;
    } catch (e, stack) {
      _logger.error("Search by profession error", e, stack);
      return [];
    }
  }

  // ============================================================
  // 5. نام سے تلاش
  // ============================================================
  Future<List<ArtisanProfile>> searchByName(String query) async {
    try {
      final snapshot = await firestore
          .collection('artisans')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) =>
              ArtisanProfile.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.error("Search by name error", e, stack);
      return [];
    }
  }

  // ============================================================
  // 6. ریویو شامل کرنا
  // ============================================================
  Future<void> addReview({
    required String artisanId,
    required String workOrderId,
    required double rating,
    required String comment,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5');
    }

    try {
      final reviewId = DateTime.now().millisecondsSinceEpoch.toString();
      final review = ArtisanReview(
        id: reviewId,
        artisanId: artisanId,
        reviewerId: user.uid,
        reviewerName: user.displayName ?? 'User',
        rating: rating,
        comment: comment,
        timestamp: DateTime.now(),
      );

      final artisanRef = firestore.collection('artisans').doc(artisanId);
      final reviewRef = artisanRef.collection('reviews').doc(reviewId);
      if (workOrderId.isEmpty) {
        throw ArgumentError('A work order is required for a review');
      }
      final workOrderRef =
          artisanRef.collection('work_orders').doc(workOrderId);

      await firestore.runTransaction((transaction) async {
        if (workOrderRef != null) {
          final orderSnapshot = await transaction.get(workOrderRef);
          final orderData = orderSnapshot.data();
          if (!orderSnapshot.exists ||
              orderData?['customerId'] != user.uid ||
              orderData?['status'] != 'completed' ||
              orderData?['isRated'] == true) {
            throw StateError('Only completed, unrated work can be reviewed');
          }
        }

        transaction.set(reviewRef, {
          ...review.toMap(),
          'workOrderId': workOrderId,
        });

        transaction.update(workOrderRef, {
          'rating': rating,
          'review': comment,
          'isRated': true,
          'ratedAt': FieldValue.serverTimestamp(),
          'status': 'rated',
        });
      });

      await _updateArtisanRating(artisanId);
    } catch (e, stack) {
      _logger.error("Add review error", e, stack);
      throw Exception('ریویو شامل کرنے میں ناکامی');
    }
  }

  // ============================================================
  // 7. کاریگر کی اوسط ریٹنگ اپ ڈیٹ کریں
  // ============================================================
  Future<void> _updateArtisanRating(String artisanId) async {
    try {
      final artisanRef = firestore.collection('artisans').doc(artisanId);
      final reviews = await artisanRef.collection('reviews').get();

      if (reviews.docs.isEmpty) {
        await artisanRef.update({
          'rating': 0.0,
          'totalReviews': 0,
        });
        return;
      }

      double total = 0;
      for (var doc in reviews.docs) {
        total += (doc.data()['rating'] as num).toDouble();
      }
      final avg = total / reviews.docs.length;
      final finalAvg = double.parse(avg.toStringAsFixed(1));

      await artisanRef.update({
        'rating': finalAvg,
        'totalReviews': reviews.docs.length,
      });
    } catch (e, stack) {
      _logger.error("Update artisan rating error", e, stack);
    }
  }

  // ============================================================
  // 8. کاریگر کے تمام ریویوز
  // ============================================================
  Stream<List<ArtisanReview>> getReviews(String artisanId) {
    return firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ArtisanReview.fromMap(doc.data()))
            .toList());
  }

  // ============================================================
  // 8.5. پسندیدہ کاریگر (Favorites)
  // ============================================================
  Future<void> toggleFavorite(String artisanId) async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final favoriteRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_artisans')
          .doc(artisanId);

      final doc = await favoriteRef.get();
      if (doc.exists) {
        await favoriteRef.delete();
      } else {
        await favoriteRef.set({
          'artisanId': artisanId,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e, stack) {
      _logger.error("Toggle favorite error", e, stack);
    }
  }

  Stream<bool> isFavorite(String artisanId) {
    final user = auth.currentUser;
    if (user == null) return Stream.value(false);

    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorite_artisans')
        .doc(artisanId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<String>> getFavoriteArtisanIds() {
    final user = auth.currentUser;
    if (user == null) return Stream.value([]);

    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorite_artisans')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // ============================================================
  // 9. پیشوں کی فہرست
  // ============================================================
  static List<Map<String, dynamic>> getProfessions() {
    return ProfessionsConfig.allProfessions
        .map((p) => <String, dynamic>{
              'id': p.id,
              'name': p.name,
              'icon': p.icon,
              'category': p.categoryName,
              'categoryUrdu': p.categoryUrdu,
            })
        .toList();
  }
}
