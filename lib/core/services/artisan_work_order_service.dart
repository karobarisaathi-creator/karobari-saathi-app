// lib/features/artisans/services/artisan_work_order_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/services/database/profession_service.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/database/job_service.dart';

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

  Future<void> updateWorkOrderItems({
    required String artisanId,
    required String orderId,
    required List<TransactionItem> items,
    required double laborFee,
    required double total,
  }) async {
    final orderRef = firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(orderId);

    await orderRef.update({
      'items': items.map((e) => e.toMap()).toList(),
      'laborFee': laborFee,
      'amount': total,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final localOrder = workOrdersBox?.get(orderId);
    if (localOrder != null) {
      final updatedOrder = localOrder.copyWith(
        items: items,
        laborFee: laborFee,
        amount: total,
      );
      await workOrdersBox?.put(orderId, updatedOrder);
      notifyListeners();
    }
  }

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
    if (!orderSnapshot.exists) {
      throw Exception('Work order not found');
    }

    final latestData = orderSnapshot.data() as Map<String, dynamic>;
    final currentStatus = latestData['status']?.toString();
    
    final validTransition =
        (currentStatus == 'negotiating' && (status == 'quoted' || status == 'confirmed' || status == 'in_progress')) ||
            (currentStatus == 'confirmed' && status == 'in_progress') ||
            (currentStatus == 'pending' && status == 'in_progress') ||
            (currentStatus == 'in_progress' && status == 'completed') ||
            (status == 'completed'); // Allow marking completed from any active state

    if (!validTransition) {
      throw StateError('Invalid work order status transition from $currentStatus to $status');
    }

    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'completed') {
      data['completedAt'] = FieldValue.serverTimestamp();
      // کاریگر کی پروفائل میں کام کی تعداد بڑھائیں (سرور پر)
      firestore.collection('artisans').doc(artisanId).update({
        'workCount': FieldValue.increment(1),
      }).catchError((e) => debugPrint("Error incrementing workCount: $e"));

      // کاریگر کی پروفائل میں کام کی تعداد بڑھائیں (لوکل کیش میں)
      final artisanProfile = artisansBox?.get(artisanId);
      if (artisanProfile != null) {
        final updatedArtisan = artisanProfile.copyWith(
          workCount: artisanProfile.workCount + 1,
        );
        await artisansBox?.put(artisanId, updatedArtisan);
      }
    }

    await orderRef.update(data);

    // لوکل ڈیٹا اپ ڈیٹ کریں (سرور سے تازہ ترین ڈیٹا لے کر)
    final updatedOrder = ArtisanWorkOrder.fromMap({
      ...latestData,
      ...data,
      'updatedAt': DateTime.now().toIso8601String(),
      if (status == 'completed') 'completedAt': DateTime.now().toIso8601String(),
    });

    await workOrdersBox?.put(orderId, updatedOrder);

    // اگر کام شروع ہو گیا ہے تو اصل جاب پوسٹ کو براؤز سے ہٹائیں
    if (status == 'confirmed' || status == 'in_progress') {
      if (orderId.startsWith('job_neg_')) {
        final jobId = orderId.replaceFirst('job_neg_', '');
        JobService().updateJobStatus(jobId, 'in_progress');
      }
    }

    if (status == 'completed') {
      // پیشے میں خودکار ٹرانزیکشن شامل کریں
      await _syncJobToProfession(updatedOrder);
    }

    notifyListeners();
    _sendWorkStatusNotification(updatedOrder);
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
  Future<void> _syncJobToProfession(ArtisanWorkOrder order) async {
    try {
      if (order.amount == null || order.amount! <= 0) {
        debugPrint("❌ Sync skipped: Order amount is null or zero (${order.amount})");
        return;
      }

      final artisanService = ArtisanService();
      ArtisanProfile? artisanProfile = artisansBox?.get(order.artisanId);
      
      // اگر لوکل میموری میں پروفائل نہیں ہے تو سرور سے حاصل کریں
      if (artisanProfile == null) {
        debugPrint("Artisan profile not in box, fetching from server...");
        artisanProfile = await artisanService.getProfile(order.artisanId);
      }
      
      if (artisanProfile == null) {
        debugPrint("❌ Sync failed: Could not find artisan profile for ID: ${order.artisanId}");
        return;
      }

      // وہی مستقل آئی ڈی جو ہم نے سروس میں رکھی ہے
      const String professionId = "artisan_main_work";
      debugPrint("✅ Syncing job to stable profession ID: $professionId with amount: ${order.amount}");

      // اگر سیزن اسکرین پر کوئی جاری (Active) سیزن ہے تو وہاں بھیجیں، مکمل شدہ (Completed) میں نہیں
      String targetId = professionId;
      final seasons = professionsBox?.values.where((p) => 
        p.parentId == professionId && (p.isActive == true)
      ).toList() ?? [];
      
      if (seasons.isNotEmpty) {
        // سیزنز کو تاریخ کے حساب سے ترتیب دیں اور تازہ ترین جاری سیزن لیں
        seasons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        targetId = seasons.first.id;
        debugPrint("✅ Using active season for entry: $targetId");
      } else {
        debugPrint("ℹ️ No active season found, using master profession record.");
      }

      // ہم کسی کھاتہ میں انٹری نہیں کریں گے، صرف پیشے کے لیے ایک ٹرانزیکشن بنائیں گے
      const String internalAccountId = "artisan_internal_income";
      
      // انکم کیٹیگری کا تعین کریں (پیشہ کے زمروں سے میل کھانا چاہیے)
      String category = "INC:کام کی اجرت";

      final transaction = model.Transaction(
        id: "artisan_job_${order.id}",
        accountId: internalAccountId, 
        amount: order.amount!,
        type: 'income',
        category: category, 
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: "${order.customerName}: ${order.title ?? order.workDescription}", 
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

      // Cloud Sync
      await firestore
          .collection('users')
          .doc(order.artisanId)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap());
      
      debugPrint("🚀 Transaction synced successfully: ${transaction.id}");
          
    } catch (e, stack) {
      debugPrint("❌ Error syncing job to profession: $e");
      debugPrint(stack.toString());
    }
  }
}
