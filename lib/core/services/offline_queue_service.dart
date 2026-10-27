// lib/core/services/offline_queue_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// ═══════════════════════════════════════════════════════════════
/// OfflineQueueService — مدیریت آفلاین ٹرانزیکشنز اور سنکنگ کیو
/// ═══════════════════════════════════════════════════════════════
class OfflineQueueService extends ChangeNotifier {
  static const String _boxName = 'offline_queue_v1';
  bool _isSyncing = false;
  int _pendingCount = 0;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;

  OfflineQueueService() {
    _init();
  }

  Future<void> _init() async {
    await updatePendingCount();
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  /// ═══ 1. Enqueue Offline Operation ═══
  Future<void> enqueueOperation({
    required String module, // 'account', 'profession', 'quick_bill', 'stock'
    required String action, // 'create', 'update', 'delete'
    required Map<String, dynamic> payload,
  }) async {
    try {
      final box = await _getBox();
      final op = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'module': module,
        'action': action,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await box.add(op);
      await updatePendingCount();
      debugPrint('OfflineQueueService: Enqueued operation [$module/$action]');
    } catch (e) {
      debugPrint('OfflineQueueService.enqueueOperation error: $e');
    }
  }

  /// ═══ 2. Update Pending Count ═══
  Future<void> updatePendingCount() async {
    try {
      final box = await _getBox();
      _pendingCount = box.length;
      notifyListeners();
    } catch (e) {
      debugPrint('OfflineQueueService.updatePendingCount error: $e');
    }
  }

  /// ═══ 3. Process Queue & Sync to Firestore ═══
  Future<void> processQueue() async {
    if (_isSyncing) return;

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final box = await _getBox();
      final keys = box.keys.toList();

      for (final key in keys) {
        final rawOp = box.get(key);
        if (rawOp == null) continue;

        final op = Map<String, dynamic>.from(rawOp as Map);
        final module = op['module'] as String?;
        final action = op['action'] as String?;
        final payload = Map<String, dynamic>.from(op['payload'] as Map);

        bool success = false;

        if (module == 'account') {
          success = await _syncAccountOp(user.uid, action, payload);
        } else if (module == 'profession') {
          success = await _syncProfessionOp(user.uid, action, payload);
        } else if (module == 'quick_bill' || module == 'stock') {
          success = await _syncStockOrBillOp(user.uid, action, payload);
        } else {
          // Unknown module, remove to avoid blocking
          success = true;
        }

        if (success) {
          await box.delete(key);
          debugPrint('OfflineQueueService: Synced & removed op [$module/$action]');
        }
      }

      await updatePendingCount();
    } catch (e) {
      debugPrint('OfflineQueueService.processQueue error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> _syncAccountOp(String uid, String? action, Map<String, dynamic> payload) async {
    try {
      final collection = FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions');
      final id = payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      await collection.doc(id).set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('_syncAccountOp error: $e');
      return false;
    }
  }

  Future<bool> _syncProfessionOp(String uid, String? action, Map<String, dynamic> payload) async {
    try {
      final collection = FirebaseFirestore.instance.collection('users').doc(uid).collection('professions');
      final id = payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      await collection.doc(id).set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('_syncProfessionOp error: $e');
      return false;
    }
  }

  Future<bool> _syncStockOrBillOp(String uid, String? action, Map<String, dynamic> payload) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      final id = payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

      if (action == 'delete') {
        await userDoc.collection('stock_items').doc(id).delete();
      } else {
        await userDoc.collection('stock_items').doc(id).set(payload, SetOptions(merge: true));

        // Sync public shop catalog item if public shop exists
        final shopRef = FirebaseFirestore.instance.collection('public_shops').doc(uid);
        final shopDoc = await shopRef.get();
        if (shopDoc.exists) {
          final isArchived = payload['isArchived'] == true;
          final itemRef = shopRef.collection('items').doc(id);
          if (isArchived) {
            final prev = await itemRef.get();
            if (prev.exists) {
              await itemRef.delete();
              await shopRef.update({'itemCount': FieldValue.increment(-1)});
            }
          } else {
            final prev = await itemRef.get();
            await itemRef.set({
              'id': id,
              'name': payload['name'] ?? '',
              'nameUrdu': payload['nameUrdu'] ?? '',
              'description': payload['description'] ?? '',
              'brand': payload['brand'] ?? '',
              'model': payload['model'] ?? '',
              'allowReturn': payload['allowReturn'] == true,
              'rate': payload['sellingPrice'] ?? payload['rate'] ?? 0,
              'oldRate': (payload['mrp'] != null && payload['sellingPrice'] != null && (payload['mrp'] as num) > (payload['sellingPrice'] as num)) ? payload['mrp'] : null,
              'unit': payload['unit'] ?? '',
              'category': payload['categoryName'] ?? payload['category'] ?? 'عام',
              'imageUrl': payload['imagePath'] ?? payload['imageUrl'] ?? '',
              'availableQuantity': payload['initialQuantity'] ?? payload['availableQuantity'],
              'trackStock': payload['trackStock'] != false,
              'isAvailable': payload['trackStock'] == false || (((payload['initialQuantity'] ?? 0) as num) > 0),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            if (!prev.exists) {
              await shopRef.update({'itemCount': FieldValue.increment(1)});
            }
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('_syncStockOrBillOp error: $e');
      return false;
    }
  }
}
