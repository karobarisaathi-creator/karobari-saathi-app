// lib/features/artisans/services/artisan_work_order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';

class ArtisanWorkOrderService extends BaseService {
  // ============================================================
  // 1. نیا کام شامل کریں
  // ============================================================

  Future<void> addWorkOrder(ArtisanWorkOrder order) async {
    await firestore
        .collection('artisans')
        .doc(order.artisanId)
        .collection('work_orders')
        .doc(order.id)
        .set(order.toMap());
  }

  // ============================================================
  // 2. کاریگر کے تمام کام حاصل کریں
  // ============================================================

  Stream<List<ArtisanWorkOrder>> getArtisanWorkOrders(String artisanId) {
    return firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ArtisanWorkOrder.fromMap(doc.data()))
            .toList());
  }

  // ============================================================
  // 3. گاہک کے تمام کام حاصل کریں
  // ============================================================

  Future<List<ArtisanWorkOrder>> getCustomerWorkOrders(String customerId) async {
    // چونکہ ہر کام مختلف کاریگر کے پاس ہے، ہم collectionGroup استعمال کریں گے
    final snapshot = await firestore
        .collectionGroup('work_orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ArtisanWorkOrder.fromMap(doc.data()))
        .toList();
  }

  // ============================================================
  // 4. کام کی حیثیت اپ ڈیٹ کریں
  // ============================================================

  Future<void> updateStatus(
    String artisanId,
    String orderId,
    String status,
  ) async {
    final data = <String, dynamic>{
      'status': status,
    };

    if (status == 'completed') {
      data['completedAt'] = FieldValue.serverTimestamp();
    }

    if (status == 'rated') {
      data['ratedAt'] = FieldValue.serverTimestamp();
    }

    await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(orderId)
        .update(data);
  }

  // ============================================================
  // 5. کام کی تفصیل حاصل کریں
  // ============================================================

  Future<ArtisanWorkOrder?> getWorkOrder(
    String artisanId,
    String orderId,
  ) async {
    final doc = await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(orderId)
        .get();

    if (doc.exists) {
      return ArtisanWorkOrder.fromMap(doc.data()!);
    }
    return null;
  }

  // ============================================================
  // 6. کام ڈیلیٹ کریں
  // ============================================================

  Future<void> deleteWorkOrder(String artisanId, String orderId) async {
    await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(orderId)
        .delete();
  }

  // ============================================================
  // 7. ریٹنگ کے حساب سے کام
  // ============================================================

  Future<List<ArtisanWorkOrder>> getRatedWorkOrders(String artisanId) async {
    final snapshot = await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .where('isRated', isEqualTo: true)
        .orderBy('ratedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ArtisanWorkOrder.fromMap(doc.data()))
        .toList();
  }

  // ============================================================
  // 8. کام کی تعداد
  // ============================================================

  Future<int> getWorkCount(String artisanId) async {
    final snapshot = await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .get();

    return snapshot.docs.length;
  }

  Future<int> getCompletedWorkCount(String artisanId) async {
    final snapshot = await firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .where('status', isEqualTo: 'completed')
        .get();

    return snapshot.docs.length;
  }
}