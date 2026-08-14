// lib/features/artisans/services/artisan_service.dart
import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';
import 'package:account_app/core/services/logging_service.dart';

class ArtisanService extends BaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _logger = LoggingService();

  // ============================================================
  // 1. پروفائل بنانا / اپ ڈیٹ کرنا
  // ============================================================

  /// کاریگر کی پروفائل کو ڈیٹا بیس میں محفوظ کرتا ہے
  /// 
  /// Parameters:
  ///   - [profile]: ArtisanProfile - محفوظ کی جانے والی پروفائل
  /// 
  /// Throws:
  ///   - FirebaseException: اگر Firestore میں خرابی ہو
  Future<void> saveProfile(ArtisanProfile profile) async {
    await firestore
        .collection('artisans')
        .doc(profile.id)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  // ============================================================
  // 1.5. پروفائل ڈیلیٹ کرنا
  // ============================================================

  /// کاریگر کی پروفائل اور اس سے منسلک تصاویر کو حذف کرتا ہے
  /// 
  /// Parameters:
  ///   - [id]: String - کاریگر کی منفرد آئی ڈی
  Future<void> deleteProfile(String id) async {
    final profile = await getProfile(id);
    if (profile != null) {
      // 1. تصاویر ڈیلیٹ کریں (Storage)
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
        _logger.error("Error deleting artisan images", e, stack);
      }
    }
    // 2. ڈیٹا بیس سے ڈیلیٹ کریں
    await firestore.collection('artisans').doc(id).delete();
  }

  // ============================================================
  // 1.7. تصاویر اپ لوڈ کرنا
  // ============================================================

  /// کاریگر کی تصویر (پروفائل یا کام کی تصویر) Firebase Storage پر اپ لوڈ کرتا ہے
  /// 
  /// Parameters:
  ///   - [userId]: String - صارف کی آئی ڈی
  ///   - [file]: File - اپ لوڈ کی جانے والی فائل
  ///   - [type]: String - تصویر کی قسم (مثلاً 'profile' یا 'work')
  /// 
  /// Returns:
  ///   - Future<String?>: تصویر کا ڈاؤن لوڈ URL، یا خرابی کی صورت میں null
  Future<String?> uploadImage(String userId, File file, String type) async {
    try {
      // 1. فائل سائز چیک (5MB سے کم ہونی چاہیے)
      final fileSizeInBytes = file.lengthSync();
      if (fileSizeInBytes > 5 * 1024 * 1024) {
        throw 'تصویر کا سائز 5MB سے زیادہ نہیں ہونا چاہیے';
      }

      // 2. فائل کی قسم چیک (صرف تصاویر قبول ہیں)
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

  /// کسی مخصوص آئی ڈی کے ذریعے کاریگر کی پروفائل حاصل کرتا ہے
  /// 
  /// Parameters:
  ///   - [id]: String - کاریگر کی آئی ڈی
  /// 
  /// Returns:
  ///   - Future<ArtisanProfile?>: کاریگر کی پروفائل یا null اگر موجود نہ ہو
  Future<ArtisanProfile?> getProfile(String id) async {
    final doc = await firestore.collection('artisans').doc(id).get();
    if (doc.exists) {
      return ArtisanProfile.fromMap(doc.data()!);
    }
    return null;
  }

  /// کسی مخصوص آئی ڈی کے لیے کاریگر کی پروفائل کی لائیو اسٹریم فراہم کرتا ہے
  /// 
  /// Parameters:
  ///   - [id]: String - کاریگر کی آئی ڈی
  /// 
  /// Returns:
  ///   - Stream<ArtisanProfile?>: پروفائل کی تبدیلیوں کی اسٹریم
  Stream<ArtisanProfile?> streamProfile(String id) {
    return firestore
        .collection('artisans')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? ArtisanProfile.fromMap(doc.data()!) : null);
  }

  // ============================================================
  // 3. تمام کاریگر حاصل کریں
  // ============================================================

  /// تمام فعال (Active) کاریگروں کی فہرست حاصل کرتا ہے
  /// 
  /// Returns:
  ///   - Future<List<ArtisanProfile>>: کاریگروں کی فہرست
  Future<List<ArtisanProfile>> getAllArtisans() async {
    final snapshot = await firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => ArtisanProfile.fromMap(doc.data()))
        .toList();
  }

  /// تمام فعال کاریگروں کی لائیو اسٹریم فراہم کرتا ہے
  /// 
  /// Returns:
  ///   - Stream<List<ArtisanProfile>>: کاریگروں کی فہرست کی اسٹریم
  Stream<List<ArtisanProfile>> streamAllArtisans() {
    return firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ArtisanProfile.fromMap(doc.data()))
            .toList());
  }

  /// تمام فعال کاریگروں کی لائیو اسٹریم فراہم کرتا ہے (پیجینیشن کے ساتھ)
  /// 
  /// Parameters:
  ///   - [limit]: int - کتنے کاریگر ایک وقت میں لوڈ کرنے ہیں
  /// 
  /// Returns:
  ///   - Stream<List<ArtisanProfile>>: کاریگروں کی فہرست کی اسٹریم
  Stream<List<ArtisanProfile>> streamArtisansPaginated({int limit = 20}) {
    return firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ArtisanProfile.fromMap(doc.data()))
            .toList());
  }

  // ============================================================
  // 4. پیشے کے حساب سے تلاش
  // ============================================================

  /// پیشے (Profession) اور لوکیشن کے حساب سے کاریگروں کو تلاش کرتا ہے
  /// 
  /// Parameters:
  ///   - [profession]: String - مطلوبہ پیشہ
  ///   - [latitude]: double? - صارف کی عرضِ بلد (اختیاری)
  ///   - [longitude]: double? - صارف کی طولِ بلد (اختیاری)
  ///   - [radiusKm]: double - تلاش کا دائرہ (کلو میٹر میں)
  /// 
  /// Returns:
  ///   - Future<List<ArtisanProfile>>: تلاش کے معیار پر پورا اترنے والے کاریگروں کی فہرست
  Future<List<ArtisanProfile>> searchByProfession(
    String profession, {
    double? latitude,
    double? longitude,
    double radiusKm = 10,
  }) async {
    var query = firestore
        .collection('artisans')
        .where('profession', isEqualTo: profession)
        .where('isActive', isEqualTo: true);

    final snapshot = await query.get();
    var results =
        snapshot.docs.map((doc) => ArtisanProfile.fromMap(doc.data())).toList();

    // قریبی لوکیشن کے حساب سے فلٹر
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

    // ریٹنگ کے حساب سے ترتیب
    results.sort((a, b) => b.rating.compareTo(a.rating));
    return results;
  }

  // ============================================================
  // 5. نام سے تلاش
  // ============================================================

  /// نام کے ذریعے کاریگروں کو تلاش کرتا ہے
  /// 
  /// Parameters:
  ///   - [query]: String - تلاش کے لیے نام یا نام کا حصہ
  /// 
  /// Returns:
  ///   - Future<List<ArtisanProfile>>: ملتے جلتے ناموں والے کاریگروں کی فہرست
  Future<List<ArtisanProfile>> searchByName(String query) async {
    final snapshot = await firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .startAt([query])
        .endAt([query + '\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => ArtisanProfile.fromMap(doc.data()))
        .toList();
  }

  // ============================================================
  // 6. ریویو شامل کرنا
  // ============================================================

  /// کاریگر کے لیے ایک نیا ریویو (Review) شامل کرتا ہے اور اوسط ریٹنگ اپ ڈیٹ کرتا ہے
  /// 
  /// Parameters:
  ///   - [artisanId]: String - کاریگر کی آئی ڈی
  ///   - [workOrderId]: String? - متعلقہ کام کے آرڈر کی آئی ڈی (اگر ہو)
  ///   - [rating]: double - دی جانے والی ریٹنگ (1 سے 5)
  ///   - [comment]: String - صارف کے تاثرات
  Future<void> addReview({
    required String artisanId,
    String? workOrderId,
    required double rating,
    required String comment,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('User not logged in');

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
    final workOrderRef = workOrderId != null && workOrderId.isNotEmpty
        ? artisanRef.collection('work_orders').doc(workOrderId)
        : null;

    // Use transaction for adding review and updating work order
    await firestore.runTransaction((transaction) async {
      // 1. ریویو محفوظ کریں
      transaction.set(reviewRef, review.toMap());

      // 2. کام کی آرڈر کو اپ ڈیٹ کریں جب ورک آرڈر دستیاب ہو
      if (workOrderRef != null) {
        transaction.update(workOrderRef, {
          'rating': rating,
          'review': comment,
          'isRated': true,
          'ratedAt': FieldValue.serverTimestamp(),
          'status': 'rated',
        });
      }
    });

    // 3. کاریگر کی اوسط ریٹنگ اپ ڈیٹ کریں
    await _updateArtisanRating(artisanId);
  }

  // ============================================================
  // 7. کاریگر کی اوسط ریٹنگ اپ ڈیٹ کریں
  // ============================================================

  /// کاریگر کی اوسط ریٹنگ اور کل ریویوز کی تعداد کو اپ ڈیٹ کرتا ہے
  /// 
  /// Parameters:
  ///   - [artisanId]: String - کاریگر کی آئی ڈی
  Future<void> _updateArtisanRating(String artisanId) async {
    final artisanRef = firestore.collection('artisans').doc(artisanId);
    final reviews = await artisanRef.collection('reviews').get();

    if (reviews.docs.isEmpty) {
      await firestore.runTransaction((transaction) async {
        transaction.update(artisanRef, {
          'rating': 0.0,
          'totalReviews': 0,
        });
      });
      return;
    }

    double total = 0;
    for (var doc in reviews.docs) {
      total += (doc.data()['rating'] as num).toDouble();
    }
    final avg = total / reviews.docs.length;
    final finalAvg = double.parse(avg.toStringAsFixed(1));
    final count = reviews.docs.length;

    await firestore.runTransaction((transaction) async {
      transaction.update(artisanRef, {
        'rating': finalAvg,
        'totalReviews': count,
      });
    });
  }

  // ============================================================
  // 8. کاریگر کے تمام ریویوز
  // ============================================================

  /// کسی کاریگر کے تمام ریویوز کی لائیو اسٹریم فراہم کرتا ہے
  /// 
  /// Parameters:
  ///   - [artisanId]: String - کاریگر کی آئی ڈی
  /// 
  /// Returns:
  ///   - Stream<List<ArtisanReview>>: ریویوز کی فہرست کی اسٹریم
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
  // 9. پیشوں کی فہرست
  // ============================================================

  /// سسٹم میں موجود تمام پیشوں (Professions) کی فہرست فراہم کرتا ہے
  /// 
  /// Returns:
  ///   - List<Map<String, dynamic>>: پیشوں کی تفصیلات بشمول نام، آئی ڈی اور آئیکون
  static List<Map<String, dynamic>> getProfessions() {
    return [
      // --- تعمیرات اور ہارڈویئر (Construction & Hardware) ---
      {
        'id': 'mason',
        'name': 'راج / مستری',
        'icon': PhosphorIcons.wall(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'plumber',
        'name': 'پلمبر',
        'icon': PhosphorIcons.wrench(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'electrician',
        'name': 'الیکٹریشن',
        'icon': PhosphorIcons.lightning(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'carpenter',
        'name': 'ترکھان (لکڑی کا کام)',
        'icon': PhosphorIcons.hammer(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'painter',
        'name': 'پینٹر',
        'icon': PhosphorIcons.paintBrushBroad(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'welder',
        'name': 'ویلڈر',
        'icon': PhosphorIcons.fire(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'tile_fixer',
        'name': 'ٹائل فکسر',
        'icon': PhosphorIcons.gridFour(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'plaster',
        'name': 'پلاسٹر ماہر',
        'icon': PhosphorIcons.paintRoller(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'steel_fixer',
        'name': 'سٹیل فکسر',
        'icon': PhosphorIcons.stairs(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'aluminum_worker',
        'name': 'ایلومینیم کا کام',
        'icon': PhosphorIcons.frameCorners(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'glass_worker',
        'name': 'شیشے کا کام',
        'icon': PhosphorIcons.selectionAll(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'roofing_specialist',
        'name': 'چھت کا ماہر',
        'icon': PhosphorIcons.houseLine(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'fence_builder',
        'name': 'باڑ بنانے والا',
        'icon': PhosphorIcons.wall(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },
      {
        'id': 'flooring_specialist',
        'name': 'فرش بنانے والا',
        'icon': PhosphorIcons.gridFour(),
        'category': 'Construction & Hardware',
        'categoryUrdu': 'تعمیرات اور ہارڈویئر'
      },

      // --- آئی ٹی اور سافٹ ویئر (IT & Software) ---
      {
        'id': 'software_dev',
        'name': 'سوفٹ ویئر ڈویلپر',
        'icon': PhosphorIcons.code(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'web_designer',
        'name': 'ویب ڈیزائنر',
        'icon': PhosphorIcons.browser(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'graphic_designer',
        'name': 'گرافک ڈیزائنر',
        'icon': PhosphorIcons.palette(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'digital_marketer',
        'name': 'ڈیجیٹل مارکیٹنگ',
        'icon': PhosphorIcons.megaphone(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'video_editor',
        'name': 'ویڈیو ایڈیٹر',
        'icon': PhosphorIcons.videoCamera(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'data_entry',
        'name': 'ڈیٹا اینٹری آپریٹر',
        'icon': PhosphorIcons.keyboard(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'seo_expert',
        'name': 'SEO ایکسپرٹ',
        'icon': PhosphorIcons.magnifyingGlassPlus(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'content_writer',
        'name': 'کونٹینٹ رائٹر',
        'icon': PhosphorIcons.article(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'mobile_app_developer',
        'name': 'موبائل ایپ ڈویلپر',
        'icon': PhosphorIcons.deviceMobile(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'network_admin',
        'name': 'نیٹ ورک ایڈمن',
        'icon': PhosphorIcons.database(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'it_support',
        'name': 'آئی ٹی سپورٹ',
        'icon': PhosphorIcons.userGear(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },
      {
        'id': 'cyber_security',
        'name': 'سائبر سیکیورٹی ماہر',
        'icon': PhosphorIcons.shieldCheck(),
        'category': 'IT & Software',
        'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'
      },

      // --- انجینئرنگ اور نقشہ نویسی (Engineering & Architecture) ---
      {
        'id': 'civil_engineer',
        'name': 'سول انجینئر',
        'icon': PhosphorIcons.buildings(),
        'category': 'Engineering & Architecture',
        'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'
      },
      {
        'id': 'mechanical_engineer',
        'name': 'مکینیکل انجینئر',
        'icon': PhosphorIcons.gear(),
        'category': 'Engineering & Architecture',
        'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'
      },
      {
        'id': 'electrical_engineer',
        'name': 'الیکٹریکل انجینئر',
        'icon': PhosphorIcons.plugCharging(),
        'category': 'Engineering & Architecture',
        'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'
      },
      {
        'id': 'architect',
        'name': 'نقشہ نویس / آرکیٹیکٹ',
        'icon': PhosphorIcons.sketchLogo(),
        'category': 'Engineering & Architecture',
        'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'
      },
      {
        'id': 'interior_designer',
        'name': 'انٹیریئر ڈیزائنر',
        'icon': PhosphorIcons.houseLine(),
        'category': 'Engineering & Architecture',
        'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'
      },
      {
        'id': 'site_supervisor',
        'name': 'سائٹ سپروائزر',
        'icon': PhosphorIcons.hardDrive(),
        'category': 'Engineering & Architecture',
        'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'
      },

      // --- مرمت اور مکینک (Repair & Mechanics) ---
      {
        'id': 'mobile_repair',
        'name': 'موبائل ریپیئرنگ',
        'icon': PhosphorIcons.deviceMobile(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'laptop_repair',
        'name': 'کمپیوٹر / لیپ ٹاپ ریپیئر',
        'icon': PhosphorIcons.laptop(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'ac_technician',
        'name': 'AC ٹیکنیشن',
        'icon': PhosphorIcons.snowflake(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'solar_installer',
        'name': 'سولر انسٹالر',
        'icon': PhosphorIcons.sun(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'mechanic',
        'name': 'گاڑیوں کا مکینک',
        'icon': PhosphorIcons.engine(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'bike_mechanic',
        'name': 'بائیک مکینک',
        'icon': PhosphorIcons.bicycle(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'cctv_installer',
        'name': 'کیمرہ انسٹالر (CCTV)',
        'icon': PhosphorIcons.cameraPlus(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'generator_mechanic',
        'name': 'جنریٹر مکینک',
        'icon': PhosphorIcons.lightningSlash(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'watch_repair',
        'name': 'گھڑی مرمت',
        'icon': PhosphorIcons.watch(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },
      {
        'id': 'printer_technician',
        'name': 'پرنٹر ٹیکنیشن',
        'icon': PhosphorIcons.printer(),
        'category': 'Repair & Mechanics',
        'categoryUrdu': 'مرمت اور مکینک'
      },

      // --- زراعت اور مویشی (Agriculture & Livestock) ---
      {
        'id': 'agri_expert',
        'name': 'ماہرِ زراعت',
        'icon': PhosphorIcons.plant(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },
      {
        'id': 'gardener',
        'name': 'مالی',
        'icon': PhosphorIcons.leaf(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },
      {
        'id': 'tractor_driver',
        'name': 'ٹریکٹر ڈرائیور',
        'icon': PhosphorIcons.truck(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },
      {
        'id': 'pest_control',
        'name': 'کیڑے مار ادویات ماہر',
        'icon': PhosphorIcons.bug(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },
      {
        'id': 'livestock_expert',
        'name': 'مویشی پال ماہر',
        'icon': PhosphorIcons.cow(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },
      {
        'id': 'poultry_expert',
        'name': 'پولٹری فارم ماہر',
        'icon': PhosphorIcons.bird(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },
      {
        'id': 'bee_keeper',
        'name': 'مکھی پالنے والا',
        'icon': PhosphorIcons.bug(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },
      {
        'id': 'orchard_specialist',
        'name': 'باغات کا ماہر',
        'icon': PhosphorIcons.appleLogo(),
        'category': 'Agriculture & Livestock',
        'categoryUrdu': 'زراعت اور مویشی'
      },

      // --- بیوٹی اور صحت (Beauty & Wellness) ---
      {
        'id': 'barber',
        'name': 'حجام / نائی',
        'icon': PhosphorIcons.scissors(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },
      {
        'id': 'beautician',
        'name': 'بیوٹیشن (میک اپ)',
        'icon': PhosphorIcons.sparkle(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },
      {
        'id': 'gym_trainer',
        'name': 'جم ٹرینر',
        'icon': PhosphorIcons.barbell(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },
      {
        'id': 'physiotherapist',
        'name': 'فزیو تھراپسٹ',
        'icon': PhosphorIcons.handHeart(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },
      {
        'id': 'home_nurse',
        'name': 'ہوم نرس',
        'icon': PhosphorIcons.firstAidKit(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },
      {
        'id': 'makeup_artist',
        'name': 'میک اپ آرٹسٹ',
        'icon': PhosphorIcons.sparkle(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },
      {
        'id': 'nail_technician',
        'name': 'نیل ٹیکنیشن',
        'icon': PhosphorIcons.handbag(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },
      {
        'id': 'massage_therapist',
        'name': 'مساج تھراپسٹ',
        'icon': PhosphorIcons.handsClapping(),
        'category': 'Beauty & Wellness',
        'categoryUrdu': 'بیوٹی اور صحت'
      },

      // --- کھانا اور پکوان (Food & Hospitality) ---
      {
        'id': 'cook',
        'name': 'باورچی / شیف',
        'icon': PhosphorIcons.cookingPot(),
        'category': 'Food & Hospitality',
        'categoryUrdu': 'کھانا اور پکوان'
      },
      {
        'id': 'baker',
        'name': 'بیکر / کیک ماہر',
        'icon': PhosphorIcons.cake(),
        'category': 'Food & Hospitality',
        'categoryUrdu': 'کھانا اور پکوان'
      },
      {
        'id': 'catering_service',
        'name': 'کیٹرنگ سروس',
        'icon': PhosphorIcons.forkKnife(),
        'category': 'Food & Hospitality',
        'categoryUrdu': 'کھانا اور پکوان'
      },
      {
        'id': 'barista',
        'name': 'بارسٹا',
        'icon': PhosphorIcons.coffee(),
        'category': 'Food & Hospitality',
        'categoryUrdu': 'کھانا اور پکوان'
      },
      {
        'id': 'food_delivery',
        'name': 'فوڈ ڈیلیوری',
        'icon': PhosphorIcons.bellRinging(),
        'category': 'Food & Hospitality',
        'categoryUrdu': 'کھانا اور پکوان'
      },

      // --- ٹرانسپورٹ اور لاجسٹکس (Transport & Logistics) ---
      {
        'id': 'driver',
        'name': 'کار ڈرائیور',
        'icon': PhosphorIcons.car(),
        'category': 'Transport & Logistics',
        'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'
      },
      {
        'id': 'heavy_driver',
        'name': 'ہیوی ڈرائیور (ٹرک/بس)',
        'icon': PhosphorIcons.truck(),
        'category': 'Transport & Logistics',
        'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'
      },
      {
        'id': 'delivery_boy',
        'name': 'ڈیلیوری بائے',
        'icon': PhosphorIcons.moped(),
        'category': 'Transport & Logistics',
        'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'
      },
      {
        'id': 'mover_packer',
        'name': 'موور اینڈ پیکر',
        'icon': PhosphorIcons.package(),
        'category': 'Transport & Logistics',
        'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'
      },
      {
        'id': 'chauffeur',
        'name': 'چوفیر',
        'icon': PhosphorIcons.steeringWheel(),
        'category': 'Transport & Logistics',
        'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'
      },
      {
        'id': 'warehouse_worker',
        'name': 'ویئر ہاؤس ورکر',
        'icon': PhosphorIcons.package(),
        'category': 'Transport & Logistics',
        'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'
      },

      // --- تعلیم اور فنون (Education & Arts) ---
      {
        'id': 'teacher',
        'name': 'ٹیچر / ٹیوٹر',
        'icon': PhosphorIcons.bookOpen(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },
      {
        'id': 'quran_teacher',
        'name': 'قاری صاحب / ٹیچر',
        'icon': PhosphorIcons.mosque(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },
      {
        'id': 'photographer',
        'name': 'فوٹوگرافر',
        'icon': PhosphorIcons.camera(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },
      {
        'id': 'videographer',
        'name': 'ویڈیوگرافر',
        'icon': PhosphorIcons.videoCamera(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },
      {
        'id': 'calligrapher',
        'name': 'خوش نویس (خطاط)',
        'icon': PhosphorIcons.pencilCircle(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },
      {
        'id': 'music_teacher',
        'name': 'موسیقی استاد',
        'icon': PhosphorIcons.musicNotes(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },
      {
        'id': 'dance_instructor',
        'name': 'ڈانس انسٹرکٹر',
        'icon': PhosphorIcons.musicNote(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },
      {
        'id': 'language_tutor',
        'name': 'زبان کا ٹیوٹر',
        'icon': PhosphorIcons.translate(),
        'category': 'Education & Arts',
        'categoryUrdu': 'تعلیم اور فنون'
      },

      // --- گھر اور طرزِ زندگی (Home & Lifestyle) ---
      {
        'id': 'home_appliance_repair',
        'name': 'گھریلو آلات کی مرمت',
        'icon': PhosphorIcons.television(),
        'category': 'Home & Lifestyle',
        'categoryUrdu': 'گھر اور طرزِ زندگی'
      },
      {
        'id': 'internet_technician',
        'name': 'انٹرنیٹ ٹیکنیشن',
        'icon': PhosphorIcons.wifiHigh(),
        'category': 'Home & Lifestyle',
        'categoryUrdu': 'گھر اور طرزِ زندگی'
      },
      {
        'id': 'cleaning_service',
        'name': 'صفائی سروس',
        'icon': PhosphorIcons.houseSimple(),
        'category': 'Home & Lifestyle',
        'categoryUrdu': 'گھر اور طرزِ زندگی'
      },
      {
        'id': 'interior_decorator',
        'name': 'انٹیریئر ڈیکوریٹر',
        'icon': PhosphorIcons.paintBrush(),
        'category': 'Home & Lifestyle',
        'categoryUrdu': 'گھر اور طرزِ زندگی'
      },
      {
        'id': 'pool_cleaner',
        'name': 'پول کلینر',
        'icon': PhosphorIcons.drop(),
        'category': 'Home & Lifestyle',
        'categoryUrdu': 'گھر اور طرزِ زندگی'
      },
      {
        'id': 'pet_groomer',
        'name': 'پالتو جانوروں کا گرومر',
        'icon': PhosphorIcons.pawPrint(),
        'category': 'Home & Lifestyle',
        'categoryUrdu': 'گھر اور طرزِ زندگی'
      },

      // --- مالیاتی اور مشاورتی خدمات (Finance & Consulting) ---
      {
        'id': 'tax_advisor',
        'name': 'ٹیکس ایڈوائزر',
        'icon': PhosphorIcons.coins(),
        'category': 'Finance & Consulting',
        'categoryUrdu': 'مالیاتی اور مشاورتی خدمات'
      },
      {
        'id': 'business_consultant',
        'name': 'بزنس کنسلٹنٹ',
        'icon': PhosphorIcons.briefcase(),
        'category': 'Finance & Consulting',
        'categoryUrdu': 'مالیاتی اور مشاورتی خدمات'
      },
      {
        'id': 'accounting_advisor',
        'name': 'اکاؤنٹنگ ایڈوائزر',
        'icon': PhosphorIcons.calculator(),
        'category': 'Finance & Consulting',
        'categoryUrdu': 'مالیاتی اور مشاورتی خدمات'
      },
      {
        'id': 'insurance_agent',
        'name': 'انشورنس ایجنٹ',
        'icon': PhosphorIcons.shieldCheck(),
        'category': 'Finance & Consulting',
        'categoryUrdu': 'مالیاتی اور مشاورتی خدمات'
      },

      // --- پالتو اور باغبانی (Pet & Garden) ---
      {
        'id': 'pet_sitter',
        'name': 'پالتو جانور سنبھالنے والا',
        'icon': PhosphorIcons.pawPrint(),
        'category': 'Pet & Garden',
        'categoryUrdu': 'پالتو اور باغبانی'
      },
      {
        'id': 'garden_maintenance',
        'name': 'باغبانی کا ماہر',
        'icon': PhosphorIcons.leaf(),
        'category': 'Pet & Garden',
        'categoryUrdu': 'پالتو اور باغبانی'
      },
      {
        'id': 'tree_cutter',
        'name': 'درخت کاٹنے والا',
        'icon': PhosphorIcons.tree(),
        'category': 'Pet & Garden',
        'categoryUrdu': 'پالتو اور باغبانی'
      },
      {
        'id': 'landscaper',
        'name': 'لینڈ سکیپر',
        'icon': PhosphorIcons.leaf(),
        'category': 'Pet & Garden',
        'categoryUrdu': 'پالتو اور باغبانی'
      },

      // --- تقریبات اور جشن (Events & Celebrations) ---
      {
        'id': 'event_planner',
        'name': 'تقریبات کا آرگنائزر',
        'icon': PhosphorIcons.calendarPlus(),
        'category': 'Events & Celebrations',
        'categoryUrdu': 'تقریبات اور جشن'
      },
      {
        'id': 'photography_assistant',
        'name': 'فوٹوگرافی اسسٹنٹ',
        'icon': PhosphorIcons.camera(),
        'category': 'Events & Celebrations',
        'categoryUrdu': 'تقریبات اور جشن'
      },
      {
        'id': 'dj',
        'name': 'ڈی جے',
        'icon': PhosphorIcons.musicNotes(),
        'category': 'Events & Celebrations',
        'categoryUrdu': 'تقریبات اور جشن'
      },
      {
        'id': 'flower_designer',
        'name': 'فلور ڈیزائنر',
        'icon': PhosphorIcons.flower(),
        'category': 'Events & Celebrations',
        'categoryUrdu': 'تقریبات اور جشن'
      },
      {
        'id': 'stage_designer',
        'name': 'اسٹیج ڈیزائنر',
        'icon': PhosphorIcons.sketchLogo(),
        'category': 'Events & Celebrations',
        'categoryUrdu': 'تقریبات اور جشن'
      },

      // --- دیگر خدمات (Legal & Others) ---
      {
        'id': 'lawyer',
        'name': 'وکیل',
        'icon': PhosphorIcons.scales(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
      {
        'id': 'accountant',
        'name': 'اکاؤنٹنٹ',
        'icon': PhosphorIcons.calculator(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
      {
        'id': 'security',
        'name': 'سیکیورٹی گارڈ',
        'icon': PhosphorIcons.shieldCheck(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
      {
        'id': 'cleaner',
        'name': 'صفائی کارکن',
        'icon': PhosphorIcons.broom(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
      {
        'id': 'translator',
        'name': 'مترجم',
        'icon': PhosphorIcons.translate(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
      {
        'id': 'travel_agent',
        'name': 'ٹریول ایجنٹ',
        'icon': PhosphorIcons.airplane(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
      {
        'id': 'locksmith',
        'name': 'تالا ساز',
        'icon': PhosphorIcons.key(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
      {
        'id': 'tattoo_artist',
        'name': 'ٹیٹو آرٹسٹ',
        'icon': PhosphorIcons.pencilCircle(),
        'category': 'Other Services',
        'categoryUrdu': 'دیگر خدمات'
      },
    ];
  }
}
