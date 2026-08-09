// lib/features/artisans/services/artisan_service.dart
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';

class ArtisanService extends BaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ============================================================
  // 1. پروفائل بنانا / اپ ڈیٹ کرنا
  // ============================================================

  Future<void> saveProfile(ArtisanProfile profile) async {
    await firestore
        .collection('artisans')
        .doc(profile.id)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  // ============================================================
  // 1.5. پروفائل ڈیلیٹ کرنا
  // ============================================================

  Future<void> deleteProfile(String id) async {
    final profile = await getProfile(id);
    if (profile != null) {
      // 1. تصاویر ڈیلیٹ کریں (Storage)
      try {
        if (profile.profileImage != null && profile.profileImage!.startsWith('http')) {
          await _storage.refFromURL(profile.profileImage!).delete();
        }
        for (var imageUrl in profile.workImages) {
          if (imageUrl.startsWith('http')) {
            await _storage.refFromURL(imageUrl).delete();
          }
        }
      } catch (e) {
        print("Error deleting artisan images: $e");
      }
    }
    // 2. ڈیٹا بیس سے ڈیلیٹ کریں
    await firestore.collection('artisans').doc(id).delete();
  }

  // ============================================================
  // 1.7. تصاویر اپ لوڈ کرنا
  // ============================================================

  Future<String?> uploadImage(String userId, File file, String type) async {
    try {
      final fileName = "${userId}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final ref = _storage.ref().child('artisan_uploads').child(userId).child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }

  // ============================================================
  // 2. پروفائل حاصل کرنا
  // ============================================================

  Future<ArtisanProfile?> getProfile(String id) async {
    final doc = await firestore.collection('artisans').doc(id).get();
    if (doc.exists) {
      return ArtisanProfile.fromMap(doc.data()!);
    }
    return null;
  }

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

  Future<List<ArtisanProfile>> getAllArtisans() async {
    final snapshot = await firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => ArtisanProfile.fromMap(doc.data()))
        .toList();
  }

  Stream<List<ArtisanProfile>> streamAllArtisans() {
    return firestore
        .collection('artisans')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ArtisanProfile.fromMap(doc.data()))
            .toList());
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
    var query = firestore
        .collection('artisans')
        .where('profession', isEqualTo: profession)
        .where('isActive', isEqualTo: true);

    final snapshot = await query.get();
    var results = snapshot.docs
        .map((doc) => ArtisanProfile.fromMap(doc.data()))
        .toList();

    // قریبی لوکیشن کے حساب سے فلٹر
    if (latitude != null && longitude != null) {
      results = results.where((p) {
        if (p.latitude == null || p.longitude == null) return false;
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          p.latitude!,
          p.longitude!,
        ) / 1000;
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

  Future<void> addReview({
    required String artisanId,
    required String workOrderId,
    required double rating,
    required String comment,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final review = ArtisanReview(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      artisanId: artisanId,
      reviewerId: user.uid,
      reviewerName: user.displayName ?? 'User',
      rating: rating,
      comment: comment,
      timestamp: DateTime.now(),
    );

    // 1. ریویو محفوظ کریں
    await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('reviews')
        .doc(review.id)
        .set(review.toMap());

    // 2. کام کی آرڈر کو اپ ڈیٹ کریں
    await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(workOrderId)
        .update({
      'rating': rating,
      'review': comment,
      'isRated': true,
      'ratedAt': FieldValue.serverTimestamp(),
      'status': 'rated',
    });

    // 3. کاریگر کی اوسط ریٹنگ اپ ڈیٹ کریں
    await _updateArtisanRating(artisanId);
  }

  // ============================================================
  // 7. کاریگر کی اوسط ریٹنگ اپ ڈیٹ کریں
  // ============================================================

  Future<void> _updateArtisanRating(String artisanId) async {
    final reviews = await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('reviews')
        .get();

    if (reviews.docs.isEmpty) {
      await firestore.collection('artisans').doc(artisanId).update({
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

    await firestore.collection('artisans').doc(artisanId).update({
      'rating': double.parse(avg.toStringAsFixed(1)),
      'totalReviews': reviews.docs.length,
    });
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
  // 9. پیشوں کی فہرست
  // ============================================================

  static List<Map<String, dynamic>> getProfessions() {
    return [
      // --- تعمیرات اور ہارڈویئر (Construction & Hardware) ---
      {'id': 'mason', 'name': 'راج / مستری', 'icon': PhosphorIcons.wall(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'plumber', 'name': 'پلمبر', 'icon': PhosphorIcons.wrench(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'electrician', 'name': 'الیکٹریشن', 'icon': PhosphorIcons.lightning(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'carpenter', 'name': 'ترکھان (لکڑی کا کام)', 'icon': PhosphorIcons.hammer(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'painter', 'name': 'پینٹر', 'icon': PhosphorIcons.paintBrushBroad(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'welder', 'name': 'ویلڈر', 'icon': PhosphorIcons.fire(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'tile_fixer', 'name': 'ٹائل فکسر', 'icon': PhosphorIcons.gridFour(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'plaster', 'name': 'پلاسٹر ماہر', 'icon': PhosphorIcons.paintRoller(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'steel_fixer', 'name': 'سٹیل فکسر', 'icon': PhosphorIcons.stairs(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'aluminum_worker', 'name': 'ایلومینیم کا کام', 'icon': PhosphorIcons.frameCorners(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},
      {'id': 'glass_worker', 'name': 'شیشے کا کام', 'icon': PhosphorIcons.selectionAll(), 'category': 'Construction & Hardware', 'categoryUrdu': 'تعمیرات اور ہارڈویئر'},

      // --- آئی ٹی اور سافٹ ویئر (IT & Software) ---
      {'id': 'software_dev', 'name': 'سوفٹ ویئر ڈویلپر', 'icon': PhosphorIcons.code(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},
      {'id': 'web_designer', 'name': 'ویب ڈیزائنر', 'icon': PhosphorIcons.browser(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},
      {'id': 'graphic_designer', 'name': 'گرافک ڈیزائنر', 'icon': PhosphorIcons.palette(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},
      {'id': 'digital_marketer', 'name': 'ڈیجیٹل مارکیٹنگ', 'icon': PhosphorIcons.megaphone(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},
      {'id': 'video_editor', 'name': 'ویڈیو ایڈیٹر', 'icon': PhosphorIcons.videoCamera(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},
      {'id': 'data_entry', 'name': 'ڈیٹا اینٹری آپریٹر', 'icon': PhosphorIcons.keyboard(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},
      {'id': 'seo_expert', 'name': 'SEO ایکسپرٹ', 'icon': PhosphorIcons.magnifyingGlassPlus(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},
      {'id': 'content_writer', 'name': 'کونٹینٹ رائٹر', 'icon': PhosphorIcons.article(), 'category': 'IT & Software', 'categoryUrdu': 'آئی ٹی اور سافٹ ویئر'},

      // --- انجینئرنگ اور نقشہ نویسی (Engineering & Architecture) ---
      {'id': 'civil_engineer', 'name': 'سول انجینئر', 'icon': PhosphorIcons.buildings(), 'category': 'Engineering & Architecture', 'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'},
      {'id': 'mechanical_engineer', 'name': 'مکینیکل انجینئر', 'icon': PhosphorIcons.gear(), 'category': 'Engineering & Architecture', 'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'},
      {'id': 'electrical_engineer', 'name': 'الیکٹریکل انجینئر', 'icon': PhosphorIcons.plugCharging(), 'category': 'Engineering & Architecture', 'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'},
      {'id': 'architect', 'name': 'نقشہ نویس / آرکیٹیکٹ', 'icon': PhosphorIcons.sketchLogo(), 'category': 'Engineering & Architecture', 'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'},
      {'id': 'interior_designer', 'name': 'انٹیریئر ڈیزائنر', 'icon': PhosphorIcons.houseLine(), 'category': 'Engineering & Architecture', 'categoryUrdu': 'انجینئرنگ اور نقشہ نویسی'},

      // --- مرمت اور مکینک (Repair & Mechanics) ---
      {'id': 'mobile_repair', 'name': 'موبائل ریپیئرنگ', 'icon': PhosphorIcons.deviceMobile(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},
      {'id': 'laptop_repair', 'name': 'کمپیوٹر / لیپ ٹاپ ریپیئر', 'icon': PhosphorIcons.laptop(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},
      {'id': 'ac_technician', 'name': 'AC ٹیکنیشن', 'icon': PhosphorIcons.snowflake(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},
      {'id': 'solar_installer', 'name': 'سولر انسٹالر', 'icon': PhosphorIcons.sun(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},
      {'id': 'mechanic', 'name': 'گاڑیوں کا مکینک', 'icon': PhosphorIcons.engine(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},
      {'id': 'bike_mechanic', 'name': 'بائیک مکینک', 'icon': PhosphorIcons.bicycle(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},
      {'id': 'cctv_installer', 'name': 'کیمرہ انسٹالر (CCTV)', 'icon': PhosphorIcons.cameraPlus(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},
      {'id': 'generator_mechanic', 'name': 'جنریٹر مکینک', 'icon': PhosphorIcons.lightningSlash(), 'category': 'Repair & Mechanics', 'categoryUrdu': 'مرمت اور مکینک'},

      // --- زراعت اور مویشی (Agriculture & Livestock) ---
      {'id': 'agri_expert', 'name': 'ماہرِ زراعت', 'icon': PhosphorIcons.plant(), 'category': 'Agriculture & Livestock', 'categoryUrdu': 'زراعت اور مویشی'},
      {'id': 'gardener', 'name': 'مالی', 'icon': PhosphorIcons.leaf(), 'category': 'Agriculture & Livestock', 'categoryUrdu': 'زراعت اور مویشی'},
      {'id': 'tractor_driver', 'name': 'ٹریکٹر ڈرائیور', 'icon': PhosphorIcons.truck(), 'category': 'Agriculture & Livestock', 'categoryUrdu': 'زراعت اور مویشی'},
      {'id': 'pest_control', 'name': 'کیڑے مار ادویات ماہر', 'icon': PhosphorIcons.bug(), 'category': 'Agriculture & Livestock', 'categoryUrdu': 'زراعت اور مویشی'},
      {'id': 'livestock_expert', 'name': 'مویشی پال ماہر', 'icon': PhosphorIcons.cow(), 'category': 'Agriculture & Livestock', 'categoryUrdu': 'زراعت اور مویشی'},
      {'id': 'poultry_expert', 'name': 'پولٹری فارم ماہر', 'icon': PhosphorIcons.bird(), 'category': 'Agriculture & Livestock', 'categoryUrdu': 'زراعت اور مویشی'},

      // --- بیوٹی اور صحت (Beauty & Wellness) ---
      {'id': 'barber', 'name': 'حجام / نائی', 'icon': PhosphorIcons.scissors(), 'category': 'Beauty & Wellness', 'categoryUrdu': 'بیوٹی اور صحت'},
      {'id': 'beautician', 'name': 'بیوٹیشن (میک اپ)', 'icon': PhosphorIcons.sparkle(), 'category': 'Beauty & Wellness', 'categoryUrdu': 'بیوٹی اور صحت'},
      {'id': 'gym_trainer', 'name': 'جم ٹرینر', 'icon': PhosphorIcons.barbell(), 'category': 'Beauty & Wellness', 'categoryUrdu': 'بیوٹی اور صحت'},
      {'id': 'physiotherapist', 'name': 'فزیو تھراپسٹ', 'icon': PhosphorIcons.handHeart(), 'category': 'Beauty & Wellness', 'categoryUrdu': 'بیوٹی اور صحت'},
      {'id': 'home_nurse', 'name': 'ہوم نرس', 'icon': PhosphorIcons.firstAidKit(), 'category': 'Beauty & Wellness', 'categoryUrdu': 'بیوٹی اور صحت'},

      // --- کھانا اور پکوان (Food & Hospitality) ---
      {'id': 'cook', 'name': 'باورچی / شیف', 'icon': PhosphorIcons.cookingPot(), 'category': 'Food & Hospitality', 'categoryUrdu': 'کھانا اور پکوان'},
      {'id': 'baker', 'name': 'بیکر / کیک ماہر', 'icon': PhosphorIcons.cake(), 'category': 'Food & Hospitality', 'categoryUrdu': 'کھانا اور پکوان'},
      {'id': 'catering_service', 'name': 'کیٹرنگ سروس', 'icon': PhosphorIcons.forkKnife(), 'category': 'Food & Hospitality', 'categoryUrdu': 'کھانا اور پکوان'},

      // --- ٹرانسپورٹ اور لاجسٹکس (Transport & Logistics) ---
      {'id': 'driver', 'name': 'کار ڈرائیور', 'icon': PhosphorIcons.car(), 'category': 'Transport & Logistics', 'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'},
      {'id': 'heavy_driver', 'name': 'ہیوی ڈرائیور (ٹرک/بس)', 'icon': PhosphorIcons.truck(), 'category': 'Transport & Logistics', 'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'},
      {'id': 'delivery_boy', 'name': 'ڈیلیوری بائے', 'icon': PhosphorIcons.moped(), 'category': 'Transport & Logistics', 'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'},
      {'id': 'mover_packer', 'name': 'موور اینڈ پیکر', 'icon': PhosphorIcons.package(), 'category': 'Transport & Logistics', 'categoryUrdu': 'ٹرانسپورٹ اور لاجسٹکس'},

      // --- تعلیم اور فنون (Education & Arts) ---
      {'id': 'teacher', 'name': 'ٹیچر / ٹیوٹر', 'icon': PhosphorIcons.bookOpen(), 'category': 'Education & Arts', 'categoryUrdu': 'تعلیم اور فنون'},
      {'id': 'quran_teacher', 'name': 'قاری صاحب / ٹیچر', 'icon': PhosphorIcons.mosque(), 'category': 'Education & Arts', 'categoryUrdu': 'تعلیم اور فنون'},
      {'id': 'photographer', 'name': 'فوٹوگرافر', 'icon': PhosphorIcons.camera(), 'category': 'Education & Arts', 'categoryUrdu': 'تعلیم اور فنون'},
      {'id': 'videographer', 'name': 'ویڈیوگرافر', 'icon': PhosphorIcons.videoCamera(), 'category': 'Education & Arts', 'categoryUrdu': 'تعلیم اور فنون'},
      {'id': 'calligrapher', 'name': 'خوش نویس (خطاط)', 'icon': PhosphorIcons.pencilCircle(), 'category': 'Education & Arts', 'categoryUrdu': 'تعلیم اور فنون'},

      // --- دیگر خدمات (Legal & Others) ---
      {'id': 'lawyer', 'name': 'وکیل', 'icon': PhosphorIcons.scales(), 'category': 'Other Services', 'categoryUrdu': 'دیگر خدمات'},
      {'id': 'accountant', 'name': 'اکاؤنٹنٹ', 'icon': PhosphorIcons.calculator(), 'category': 'Other Services', 'categoryUrdu': 'دیگر خدمات'},
      {'id': 'security', 'name': 'سیکیورٹی گارڈ', 'icon': PhosphorIcons.shieldCheck(), 'category': 'Other Services', 'categoryUrdu': 'دیگر خدمات'},
      {'id': 'cleaner', 'name': 'صفائی کارکن', 'icon': PhosphorIcons.broom(), 'category': 'Other Services', 'categoryUrdu': 'دیگر خدمات'},
    ];
  }
}
