// lib/features/artisans/services/artisan_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';

class ArtisanService extends BaseService {
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

  static List<Map<String, String>> getProfessions() {
    return [
      {'id': 'electrician', 'name': 'الیکٹریشن', 'icon': '⚡'},
      {'id': 'plumber', 'name': 'پلمبر', 'icon': '🔧'},
      {'id': 'mason', 'name': 'راج/مستری', 'icon': '🧱'},
      {'id': 'carpenter', 'name': 'ترکھان/درزی', 'icon': '🪚'},
      {'id': 'painter', 'name': 'پینٹر', 'icon': '🎨'},
      {'id': 'welder', 'name': 'ویلڈر', 'icon': '🔥'},
      {'id': 'tailor', 'name': 'درزی', 'icon': '🧵'},
      {'id': 'driver', 'name': 'ڈرائیور', 'icon': '🚗'},
      {'id': 'mobile_repair', 'name': 'موبائل ریپیئر', 'icon': '📱'},
      {'id': 'ac_technician', 'name': 'AC ٹیکنیشن', 'icon': '❄️'},
      {'id': 'solar_installer', 'name': 'سولر انسٹالر', 'icon': '☀️'},
      {'id': 'tile_fixer', 'name': 'ٹائیل فکسر', 'icon': '🧱'},
      {'id': 'plaster', 'name': 'پلاسٹر', 'icon': '🧱'},
      {'id': 'gardener', 'name': 'مالی', 'icon': '🌿'},
      {'id': 'mechanic', 'name': 'مکینک', 'icon': '🔧'},
      {'id': 'cook', 'name': 'باورچی', 'icon': '🍳'},
      {'id': 'cleaner', 'name': 'صفائی کارکن', 'icon': '🧹'},
      {'id': 'security', 'name': 'سیکیورٹی گارڈ', 'icon': '🛡️'},
      {'id': 'teacher', 'name': 'ٹیچر', 'icon': '📚'},
      {'id': 'tutor', 'name': 'ٹیوٹر', 'icon': '📝'},
      {'id': 'photographer', 'name': 'فوٹوگرافر', 'icon': '📷'},
      {'id': 'videographer', 'name': 'ویڈیوگرافر', 'icon': '🎥'},
      {'id': 'graphic_designer', 'name': 'گرافک ڈیزائنر', 'icon': '🎨'},
    ];
  }
}