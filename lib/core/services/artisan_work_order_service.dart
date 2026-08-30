// lib/features/artisans/services/artisan_work_order_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/services/database/profession_service.dart';
import 'package:account_app/core/services/database/account_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';

class ArtisanWorkOrderService extends BaseService {
  // ============================================================
  // 1. نیا کام شامل کریں
  // ============================================================

  Future<void> addWorkOrder(ArtisanWorkOrder order) async {
    // 1. Save locally
    await workOrdersBox?.put(order.id, order);
    notifyListeners();

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
  // 2.5. گاہک کے تمام کام حاصل کریں (ریئل ٹائم)
  // ============================================================

  Stream<List<ArtisanWorkOrder>> streamCustomerWorkOrders(String customerId) {
    return firestore
        .collectionGroup('work_orders')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => ArtisanWorkOrder.fromMap(doc.data()))
          .toList();

      // لوکل کیش کو بھی اپ ڈیٹ کریں
      for (var order in orders) {
        workOrdersBox?.put(order.id, order);
      }

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  // ============================================================
  // 3. گاہک کے تمام کام حاصل کریں (فیوچر)
  // ============================================================

  Future<List<ArtisanWorkOrder>> getCustomerWorkOrders(
      String customerId) async {
    // 1. Return Local First
    final localOrders = workOrdersBox?.values
            .where((o) => o.customerId == customerId)
            .toList() ??
        [];

    // 2. Trigger Background Sync
    _syncCustomerOrdersFromCloud(customerId);

    return localOrders;
  }

  Future<void> _syncCustomerOrdersFromCloud(String customerId) async {
    try {
      final snapshot = await firestore
          .collectionGroup('work_orders')
          .where('customerId', isEqualTo: customerId)
          .get();

      for (var doc in snapshot.docs) {
        final order = ArtisanWorkOrder.fromMap(doc.data());
        await workOrdersBox?.put(order.id, order);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error syncing customer orders: $e");
    }
  }

  // ============================================================
  // 4. کام کی حیثیت اپ ڈیٹ کریں
  // ============================================================

  Future<void> updateStatus(
    String artisanId,
    String orderId,
    String status,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Unauthorized');
    if (user.uid != artisanId) {
      throw Exception('Only the artisan can update work status');
    }

    const allowedStatuses = {
      'negotiating',
      'quoted',
      'confirmed',
      'in_progress',
      'completed',
      'rated',
      'rejected',
    };
    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Invalid work order status: $status');
    }

    final orderRef = firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(orderId);
    final orderSnapshot = await orderRef.get();
    final currentStatus = orderSnapshot.data()?['status']?.toString();
    final validTransition =
        (currentStatus == 'negotiating' && status == 'quoted') ||
            (currentStatus == 'confirmed' && status == 'in_progress') ||
            (currentStatus == 'pending' && status == 'in_progress') ||
            (currentStatus == 'in_progress' && status == 'completed') ||
            (status == 'completed'); // Allow marking completed from any active state
    if (!orderSnapshot.exists || !validTransition) {
      throw StateError('Invalid work order status transition');
    }

    // Only the artisan or the customer (if linked) should update status.
    // For now, we strictly check if the artisan is the one updating it
    // or if the customer is updating (e.g. for ratings/agreement).
    // In this simple check, we ensure the caller is at least logged in.

    final data = <String, dynamic>{
      'status': status,
    };

    if (status == 'completed') {
      data['completedAt'] = FieldValue.serverTimestamp();
      // کاریگر کی پروفائل میں کام کی تعداد بڑھائیں
      firestore.collection('artisans').doc(artisanId).update({
        'workCount': FieldValue.increment(1),
      }).catchError((e) => debugPrint("Error incrementing workCount: $e"));

      // پیشے میں خودکار ٹرانزیکشن شامل کریں
      await _syncJobToProfession(orderId, artisanId);
    }

    await orderRef.update(data);

    final localOrder = workOrdersBox?.get(orderId);
    if (localOrder != null) {
      final updatedOrder = localOrder.copyWith(status: status);
      await workOrdersBox?.put(orderId, updatedOrder);
      notifyListeners();
      _sendWorkStatusNotification(updatedOrder);
    }
  }

  // ============================================================
  // 4.1. ریٹنگ اپ ڈیٹ کریں
  // ============================================================

  Future<void> rateWorkOrder(
    String artisanId,
    String orderId,
    double rating,
    String review,
  ) async {
    final orderRef = firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(orderId);

    await orderRef.update({
      'rating': rating,
      'review': review,
      'isRated': true,
      'ratedAt': FieldValue.serverTimestamp(),
    });

    final localOrder = workOrdersBox?.get(orderId);
    if (localOrder != null) {
      final updatedOrder = localOrder.copyWith(
        rating: rating,
        review: review,
        isRated: true,
        ratedAt: DateTime.now(),
      );
      await workOrdersBox?.put(orderId, updatedOrder);
      notifyListeners();
    }
  }

  // ============================================================
  // 4.5. کام کی تصاویر اپ ڈیٹ کریں
  // ============================================================

  Future<void> updateWorkImages(
    String artisanId,
    String orderId,
    List<String> imageUrls,
  ) async {
    final orderRef = firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(orderId);

    await orderRef.update({
      'workImages': imageUrls,
    });

    // کاریگر کی مین گیلری میں بھی شامل کریں (اگر پہلے سے موجود نہ ہوں)
    final artisanRef = firestore.collection('artisans').doc(artisanId);
    await artisanRef.update({
      'workImages': FieldValue.arrayUnion(imageUrls),
    });

    final localOrder = workOrdersBox?.get(orderId);
    if (localOrder != null) {
      final updatedOrder = localOrder.copyWith(workImages: imageUrls);
      await workOrdersBox?.put(orderId, updatedOrder);
      notifyListeners();
    }
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
    try {
      final snapshot = await firestore
          .collection('artisans')
          .doc(artisanId)
          .collection('work_orders')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint("Error fetching work count: $e");
      // اگر پرمیشن نہیں ہے تو لوکل ڈیٹا سے گنتی کریں
      final localCount =
          workOrdersBox?.values.where((o) => o.artisanId == artisanId).length ??
              0;
      return localCount;
    }
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

  // ============================================================
  // نوٹیفکیشن ہیلپر
  // ============================================================

  void _sendWorkStatusNotification(ArtisanWorkOrder order) async {
    try {
      final String notifId =
          "work_${order.status}_${DateTime.now().millisecondsSinceEpoch}";
      String title = "";
      String message = "";

      if (order.status == 'in_progress') {
        title = "🚀 کام شروع ہو گیا!";
        message = "کاریگر نے آپ کے کام پر کام شروع کر دیا ہے۔";
      } else if (order.status == 'completed') {
        title = "✅ کام مکمل ہو گیا!";
        message =
            "کاریگر نے کام مکمل کر دیا ہے۔ اب آپ اپنی رائے (ریٹنگ) دے سکتے ہیں۔";
      } else {
        return;
      }

      await firestore
          .collection('users')
          .doc(order.customerId)
          .collection('notifications')
          .doc(notifId)
          .set({
        'id': notifId,
        'title': title,
        'message': message,
        'type': 'general',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'type': 'work_status_update',
          'orderId': order.id,
          'status': order.status,
        },
      });
    } catch (e) {
      debugPrint("Error sending work status notification: $e");
    }
  }

  /// مکمل شدہ کام کی رقم کو پیشے میں بطور آمدنی شامل کرتا ہے
  Future<void> _syncJobToProfession(String orderId, String artisanId) async {
    try {
      final order = workOrdersBox?.get(orderId);
      if (order == null || order.amount == null || order.amount! <= 0) return;

      final artisanProfile = artisansBox?.get(artisanId);
      if (artisanProfile == null) return;

      final String professionId = "artisan_prof_${artisanProfile.profession}";
      
      // اگر سیزن اسکرین پر کوئی فعال سیزن ہے تو وہاں بھیجیں، ورنہ ماسٹر پیشے میں
      String targetId = professionId;
      final seasons = professionsBox?.values.where((p) => p.parentId == professionId && (p.isActive ?? true)).toList() ?? [];
      if (seasons.isNotEmpty) {
        targetId = seasons.first.id;
      }

      // ہم کسی کھاتہ میں انٹری نہیں کریں گے، صرف پیشے کے لیے ایک ٹرانزیکشن بنائیں گے
      // اکاؤنٹ آئی ڈی میں ایک مخصوص 'internal' آئی ڈی استعمال کریں گے جو عام کھاتوں میں نظر نہیں آتی
      const String internalAccountId = "artisan_internal_income";

      final transaction = model.Transaction(
        id: "artisan_job_${order.id}",
        accountId: internalAccountId, 
        amount: order.amount!,
        type: 'income',
        category: order.customerName, 
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: order.title ?? order.workDescription, // یہاں عنوان استعمال کریں، اگر نہ ہو تو تفصیل
        professionId: targetId,
      );

      // ٹرانزیکشن کو محفوظ کریں (صرف پیشے کے ریکارڈ کے لیے)
      await transactionsBox?.put(transaction.id, transaction);
      
      // پیشے کا حساب اپ ڈیٹ کریں
      final profService = ProfessionService();
      await profService.recalculateProfessionFinance(targetId);
      if (targetId != professionId) {
        await profService.recalculateProfessionFinance(professionId);
      }

      // نوٹ: ہم اکاؤنٹ کا بیلنس اپ ڈیٹ نہیں کریں گے کیونکہ صارف نے منع کیا ہے

      // Cloud Sync
      await firestore
          .collection('users')
          .doc(artisanId)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap());
          
    } catch (e) {
      debugPrint("Error syncing job to profession: $e");
    }
  }
}
