import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/models/review_model.dart';
import 'package:account_app/core/models/ad_report_model.dart';
import 'base_service.dart';

class InventoryService extends BaseService {
  Future<void> addInventoryItem(InventoryItem item) async {
    final now = DateTime.now();
    final daily = itemsBox?.values.where((i) => i.createdAt.isAfter(DateTime(now.year, now.month, now.day))).length ?? 0;
    if (daily >= 10) throw Exception("Daily limit reached (10 ads).");

    final recent = itemsBox?.values.where((i) => i.createdAt.isAfter(now.subtract(const Duration(minutes: 5)))).length ?? 0;
    if (recent >= 3) throw Exception("Please wait a few minutes before posting again.");

    final expiry = item.adExpiryDate ?? now.add(const Duration(days: 30));
    await itemsBox?.put(item.id, item.copyWith(createdAt: now, updatedAt: now, adExpiryDate: expiry));
    notifyListeners();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final old = itemsBox?.get(item.id);
    if (old != null && item.defaultRate < old.defaultRate) await _triggerPriceDrop(item);
    await itemsBox?.put(item.id, item);
    notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    final item = itemsBox?.get(id);
    if (item != null) {
      for (var p in item.imagePaths) if (p.startsWith('http')) await FirebaseStorage.instance.refFromURL(p).delete().catchError((_){});
      await itemsBox?.delete(id);
      if (auth.currentUser != null) await firestore.collection('users').doc(auth.currentUser!.uid).collection('inventory_items').doc(id).delete();
      notifyListeners();
    }
  }

  List<InventoryItem> getInventoryItems() => itemsBox?.values.toList() ?? [];
  InventoryItem? getInventoryItem(String id) => itemsBox?.get(id);

  Future<List<InventoryItem>> getRemoteInventoryItems(String uid, {int limit = 50}) async {
    final q = await firestore.collection('users').doc(uid).collection('inventory_items').orderBy('createdAt', descending: true).limit(limit).get();
    final list = q.docs.map((d) => InventoryItem.fromMap({...d.data(), 'id': d.id})).toList();
    await saveRemoteCachedItems(uid, list);
    return list;
  }

  /// Global Search across all sellers (Robust Implementation)
  Future<List<InventoryItem>> searchGlobalInventory(String query, {int limit = 15}) async {
    if (query.isEmpty) return [];

    final trimmedQuery = query.trim();
    final lowerQuery = trimmedQuery.toLowerCase();
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(trimmedQuery);

    try {
      // 1. Search by Name (Prefix)
      final nameQuery = firestore
          .collectionGroup('inventory_items')
          .where('name', isGreaterThanOrEqualTo: trimmedQuery)
          .where('name', isLessThanOrEqualTo: '$trimmedQuery\uf8ff')
          .limit(limit)
          .get();

      // 2. Search by SKU/Barcode (Exact)
      final skuQuery = firestore
          .collectionGroup('inventory_items')
          .where('sku', isEqualTo: trimmedQuery)
          .limit(limit)
          .get();

      // Execute queries in parallel
      final results = await Future.wait([nameQuery, skuQuery]);

      Map<String, InventoryItem> uniqueItems = {};
      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          final item = InventoryItem.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
          uniqueItems[item.id] = item;
        }
      }

      // 3. English Case Sensitivity (Capitalization check)
      if (!isUrdu && uniqueItems.length < limit) {
        String capitalizedQuery = lowerQuery[0].toUpperCase() + lowerQuery.substring(1);
        final capQuery = await firestore
            .collectionGroup('inventory_items')
            .where('name', isGreaterThanOrEqualTo: capitalizedQuery)
            .where('name', isLessThanOrEqualTo: '$capitalizedQuery\uf8ff')
            .limit(limit)
            .get();

        for (var doc in capQuery.docs) {
          final item = InventoryItem.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
          uniqueItems[item.id] = item;
        }
      }

      return uniqueItems.values.toList();
    } catch (e) {
      debugPrint("Global multi-search error: $e");
      // 5. Fallback to Local Cache (Handles Urdu/English "contains" search)
      return itemsBox?.values.where((item) {
            final n = item.name.toLowerCase();
            final b = (item.brand ?? '').toLowerCase();
            final s = (item.sku ?? '').toLowerCase();
            final c = (item.category ?? '').toLowerCase();
            return n.contains(lowerQuery) || b.contains(lowerQuery) || s.contains(lowerQuery) || c.contains(lowerQuery);
          }).take(limit).toList() ?? [];
    }
  }

  Future<Map<String, dynamic>> getGlobalMarketplaceItemsPaginated({int limit = 20, DocumentSnapshot? lastDocument}) async {
    var q = firestore.collectionGroup('inventory_items').orderBy('createdAt', descending: true).limit(limit);
    if (lastDocument != null) q = q.startAfterDocument(lastDocument);
    final snap = await q.get();
    final items = snap.docs.map((d) => InventoryItem.fromMap({...d.data() as Map<String, dynamic>, 'id': d.id})).toList();
    return {'items': items, 'lastDocument': snap.docs.isNotEmpty ? snap.docs.last : null, 'hasMore': items.length == limit};
  }

  Future<List<InventoryItem>> searchGlobalMarketplaceItems({required String searchQuery, int limit = 50}) async {
    final q = await firestore.collectionGroup('inventory_items').where('name', isGreaterThanOrEqualTo: searchQuery).where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff').limit(limit).get();
    return q.docs.map((d) => InventoryItem.fromMap({...d.data() as Map<String, dynamic>, 'id': d.id})).toList();
  }

  Future<void> saveRemoteCachedItems(String uid, List<InventoryItem> items) async {
    await remoteCachedItemsBox?.put(uid, items.map((e) => e.toMap()).toList());
  }

  List<InventoryItem> getRemoteCachedItems(String uid) {
    final data = remoteCachedItemsBox?.get(uid);
    return data?.map((e) => InventoryItem.fromMap(Map<String, dynamic>.from(e))).toList() ?? [];
  }

  Future<void> toggleFirestoreFavorite(String id, bool isFav) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    if (isFav) await firestore.collection('favorites').doc('${uid}_$id').set({'userId': uid, 'itemId': id, 'timestamp': FieldValue.serverTimestamp()});
    else await firestore.collection('favorites').doc('${uid}_$id').delete();
  }

  Future<void> addReview(Review r) async {
    await firestore.collection('reviews').doc(r.id).set(r.toMap());
    
    // Recalculate average rating for the item
    final reviews = await getItemReviews(r.itemId);
    if (reviews.isNotEmpty) {
      double totalRating = 0;
      for (var review in reviews) {
        totalRating += review.rating;
      }
      double avgRating = double.parse((totalRating / reviews.length).toStringAsFixed(1));
      int reviewCount = reviews.length;
      
      // 1. Update Firestore
      final q = await firestore.collectionGroup('inventory_items').where('id', isEqualTo: r.itemId).limit(1).get();
      if (q.docs.isNotEmpty) {
        await q.docs.first.reference.update({
          'rating': avgRating,
          'reviewCount': reviewCount,
        });
      }

      // 2. Update Local Hive Box (for immediate UI response)
      final localItem = itemsBox?.get(r.itemId);
      if (localItem != null) {
        await itemsBox?.put(r.itemId, localItem.copyWith(
          rating: avgRating,
          reviewCount: reviewCount,
        ));
      }
      notifyListeners();
    }
  }

  Future<List<Review>> getItemReviews(String id) async {
    final q = await firestore.collection('reviews').where('itemId', isEqualTo: id).orderBy('timestamp', descending: true).get();
    return q.docs.map((d) => Review.fromMap(d.data())).toList();
  }

  Future<void> reportAd(AdReport r) async {
    await firestore.collection('ad_reports').doc(r.id).set(r.toMap());
  }

  Future<void> logContactEvent({required String itemId, required String action, String? targetPhone}) async {
    await firestore.collection('contact_logs').add({'itemId': itemId, 'action': action, 'targetPhone': targetPhone, 'userId': auth.currentUser?.uid, 'timestamp': FieldValue.serverTimestamp()});
    // Increment contacts count on the item
    final q = await firestore.collectionGroup('inventory_items').where('id', isEqualTo: itemId).limit(1).get();
    if (q.docs.isNotEmpty) await q.docs.first.reference.update({'contacts': FieldValue.increment(1)});
  }

  Future<void> incrementView(String id) async {
    final q = await firestore.collectionGroup('inventory_items').where('id', isEqualTo: id).limit(1).get();
    if (q.docs.isNotEmpty) await q.docs.first.reference.update({'views': FieldValue.increment(1)});
  }

  Future<void> incrementShare(String id) async {
    final q = await firestore.collectionGroup('inventory_items').where('id', isEqualTo: id).limit(1).get();
    if (q.docs.isNotEmpty) await q.docs.first.reference.update({'shares': FieldValue.increment(1)});
  }

  Future<void> addRecentlyViewed(InventoryItem item) async {
    await recentlyViewedBox?.delete(item.id);
    await recentlyViewedBox?.put(item.id, item);
    if ((recentlyViewedBox?.length ?? 0) > 15) await recentlyViewedBox?.delete(recentlyViewedBox?.keys.first);
    notifyListeners();
  }

  List<InventoryItem> getRecentlyViewed() => recentlyViewedBox?.values.toList().reversed.toList() ?? [];

  Future<void> cleanupExpiredAds() async {
    final threshold = DateTime.now().subtract(const Duration(days: 30));
    final expired = itemsBox?.values.where((i) => i.adExpiryDate != null && i.adExpiryDate!.isBefore(threshold)).toList() ?? [];
    for (var i in expired) await deleteInventoryItem(i.id);
    notifyListeners();
  }

  Future<bool> isSellerVerified(String uid) async {
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['isVerified'] ?? false;
      }
    } catch (e) {
      debugPrint("Error checking seller verification: $e");
    }
    return false;
  }

  Future<void> _triggerPriceDrop(InventoryItem item) async {
    final q = await firestore.collection('favorites').where('itemId', isEqualTo: item.id).get();
    for (var d in q.docs) {
      final u = d.data()['userId'];
      if (u != auth.currentUser?.uid) await firestore.collection('users').doc(u).collection('notifications').add({'title': 'قیمت کم ہو گئی! 🔥', 'message': 'آپ کی پسندیدہ چیز "${item.name}" اب Rs. ${item.defaultRate} میں دستیاب ہے۔', 'timestamp': FieldValue.serverTimestamp(), 'type': 'price_drop', 'isRead': false, 'data': {'itemId': item.id}});
    }
  }
}