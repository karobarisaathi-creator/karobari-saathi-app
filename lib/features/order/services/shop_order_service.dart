import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';

class ShopOrderService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ShopOrderService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<String> placeOrder({
    required Shop shop,
    required List<ShopItem> items,
    required double total,
  }) async {
    final customer = _auth.currentUser;
    if (customer == null) throw StateError('Sign in to place an order.');
    if (items.isEmpty) throw StateError('Add at least one item to the order.');
    if (!shop.isOpen) throw StateError('This shop is currently closed.');
    if (shop.id == customer.uid) {
      throw StateError('You cannot order from your own shop.');
    }
    for (final item in items) {
      if (item.quantity <= 0 || item.quantity > item.stock) {
        throw StateError(
            '${item.name} is no longer available in that quantity.');
      }
    }

    final orderRef = _firestore
        .collection('public_shops')
        .doc(shop.id)
        .collection('orders')
        .doc();
    await orderRef.set({
      'id': orderRef.id,
      'shopId': shop.id,
      'shopName': shop.name,
      'shopOwnerName': shop.owner,
      'customerId': customer.uid,
      'customerName': customer.displayName ?? '',
      'customerPhone': customer.phoneNumber ?? '',
      'status': 'pending',
      'items': items
          .map((item) => {
                'itemId': item.stockItemId.isEmpty ? item.id : item.stockItemId,
                'name': item.name,
                'nameUrdu': item.nameUrdu,
                'unit': item.unit,
                'rate': item.rate,
                'quantity': item.quantity,
                'total': item.total,
              })
          .toList(),
      'total': total,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return orderRef.id;
  }

  Future<String> reorderOrder({
    required String shopId,
    required String orderId,
  }) async {
    final customer = _auth.currentUser;
    if (customer == null) throw StateError('Sign in to reorder.');

    final oldOrderRef = _firestore
        .collection('public_shops')
        .doc(shopId)
        .collection('orders')
        .doc(orderId);
    final oldOrderSnapshot = await oldOrderRef.get();
    final oldOrder = oldOrderSnapshot.data();
    if (oldOrder == null || oldOrder['customerId'] != customer.uid) {
      throw StateError('This order is unavailable.');
    }

    final rawItems = oldOrder['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw StateError('This order has no items to reorder.');
    }

    final shopSnapshot =
        await _firestore.collection('public_shops').doc(shopId).get();
    final shopData = shopSnapshot.data();
    if (shopData == null) throw StateError('This shop is unavailable.');
    if (shopData['isOpen'] != true) {
      throw StateError('This shop is currently closed.');
    }

    final items = <ShopItem>[];
    for (final rawItem in rawItems.whereType<Map>()) {
      final oldItem = Map<String, dynamic>.from(rawItem);
      final itemId = (oldItem['itemId'] ?? oldItem['id'] ?? '').toString();
      final quantity = (oldItem['quantity'] as num?)?.toDouble() ?? 0;
      if (itemId.isEmpty || !quantity.isFinite || quantity <= 0) {
        throw StateError('This order contains an invalid item.');
      }

      final itemSnapshot = await _firestore
          .collection('public_shops')
          .doc(shopId)
          .collection('items')
          .doc(itemId)
          .get();
      final itemData = itemSnapshot.data();
      if (itemData == null || itemData['isAvailable'] == false) {
        throw StateError(
            '${oldItem['name']?.toString() ?? 'An item'} is unavailable.');
      }

      final tracksStock = itemData['trackStock'] != false;
      final available = tracksStock
          ? (itemData['availableQuantity'] as num?)?.toDouble() ?? 0
          : 1000000000.0;
      items.add(
        ShopItem(
          id: itemId,
          stockItemId: itemId,
          name: (itemData['name'] ?? oldItem['name'] ?? itemId).toString(),
          nameUrdu:
              (itemData['nameUrdu'] ?? oldItem['nameUrdu'] ?? '').toString(),
          description: (itemData['description'] ?? '').toString(),
          rate: (itemData['rate'] as num?)?.toDouble() ?? 0,
          oldRate: (itemData['oldRate'] as num?)?.toDouble(),
          unit: (itemData['unit'] ?? oldItem['unit'] ?? '').toString(),
          emoji: '📦',
          category: (itemData['category'] ?? '').toString(),
          imageUrl: (itemData['imageUrl'] ?? '').toString(),
          stock: available,
          quantity: quantity,
        ),
      );
    }

    final shop = Shop(
      id: shopId,
      name: (shopData['shopName'] ?? shopData['displayName'] ?? 'Shop')
          .toString(),
      logoEmoji: '🛒',
      owner: (shopData['ownerName'] ?? '').toString(),
      area: (shopData['businessAddress'] ?? '').toString(),
      distance: (shopData['distance'] ?? '').toString(),
      distanceVal:
          (shopData['distanceVal'] as num?)?.toDouble() ?? double.infinity,
      rating: (shopData['rating'] as num?)?.toDouble() ?? 0,
      reviews: (shopData['reviews'] as num?)?.toInt() ?? 0,
      deliveryTime: (shopData['deliveryTime'] ?? '').toString(),
      timeVal: (shopData['timeVal'] as num?)?.toInt() ?? 0,
      minOrder: (shopData['minOrder'] ?? '').toString(),
      deliveryFee: (shopData['deliveryFee'] ?? '').toString(),
      isOpen: true,
      tags: (shopData['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(),
      items: const [],
      itemCount: (shopData['itemCount'] as num?)?.toInt() ?? 0,
    );

    final total = items.fold<double>(0, (amount, item) => amount + item.total);
    return placeOrder(shop: shop, items: items, total: total);
  }

  Future<void> acceptOrder({
    required String shopId,
    required String orderId,
  }) async {
    final owner = _auth.currentUser;
    if (owner == null || owner.uid != shopId) {
      throw StateError('Only this shop owner can accept the order.');
    }

    final shopRef = _firestore.collection('public_shops').doc(shopId);
    final orderRef = shopRef.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      final order = orderSnapshot.data();
      if (order == null || order['status'] != 'pending') {
        throw StateError('This order is no longer pending.');
      }

      final rawItems = order['items'];
      if (rawItems is! List || rawItems.isEmpty) {
        throw StateError('This order has no valid items.');
      }

      final itemLines = rawItems
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      final quantityById = <String, double>{};
      for (final line in itemLines) {
        final id = line['itemId']?.toString() ?? '';
        final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
        if (id.isEmpty || !quantity.isFinite || quantity <= 0) {
          throw StateError('This order contains an invalid item quantity.');
        }
        quantityById.update(id, (current) => current + quantity,
            ifAbsent: () => quantity);
      }

      final publicRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final stockRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      for (final id in quantityById.keys) {
        publicRefs[id] = shopRef.collection('items').doc(id);
        stockRefs[id] = _firestore
            .collection('users')
            .doc(shopId)
            .collection('stock_items')
            .doc(id);
      }

      final publicSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final stockSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in quantityById.keys) {
        publicSnapshots[id] = await transaction.get(publicRefs[id]!);
        stockSnapshots[id] = await transaction.get(stockRefs[id]!);
      }

      final movementsRef = _firestore
          .collection('users')
          .doc(shopId)
          .collection('stock_movements');
      final now = DateTime.now();
      final trustedLines = <Map<String, dynamic>>[];
      var trustedTotal = 0.0;
      for (final entry in quantityById.entries) {
        final publicData = publicSnapshots[entry.key]!.data();
        final stockData = stockSnapshots[entry.key]!.data();
        if (publicData == null ||
            stockData == null ||
            stockData['isArchived'] == true) {
          throw StateError('An ordered item is no longer available.');
        }
        final tracksStock = stockData['trackStock'] != false;
        final rate = (publicData['rate'] as num?)?.toDouble() ?? 0;
        final itemTotal = rate * entry.value;
        trustedTotal += itemTotal;
        trustedLines.add({
          'itemId': entry.key,
          'name': publicData['name']?.toString() ?? entry.key,
          'nameUrdu': publicData['nameUrdu']?.toString() ?? '',
          'unit': publicData['unit']?.toString() ?? '',
          'rate': rate,
          'quantity': entry.value,
          'total': itemTotal,
        });
        if (tracksStock) {
          final available =
              (publicData['availableQuantity'] as num?)?.toDouble() ?? 0;
          if (available < entry.value) {
            throw StateError(
                'Not enough stock for ${publicData['name'] ?? entry.key}.');
          }
          final newAvailable = available - entry.value;
          transaction.update(publicRefs[entry.key]!, {
            'availableQuantity': newAvailable,
            'isAvailable': newAvailable > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final stockItem = StockItem.fromMap(stockData);
          final movement = StockMovement(
            id: 'order_${orderId}_${Uri.encodeComponent(entry.key)}',
            stockItemId: entry.key,
            stockItemName: stockItem.name,
            type: StockMovementType.sale,
            quantity: entry.value,
            unitPrice: rate,
            reason: 'Shop order sale',
            note: 'Order $orderId',
            partyId: order['customerId']?.toString() ?? '',
            partyName: order['customerName']?.toString() ?? '',
            transactionId: orderId,
            timestamp: now,
          );
          transaction.set(movementsRef.doc(movement.id), movement.toMap());
        }
      }
      transaction.update(orderRef, {
        'status': 'accepted',
        'items': trustedLines,
        'total': trustedTotal,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectOrder({
    required String shopId,
    required String orderId,
  }) async {
    final owner = _auth.currentUser;
    if (owner == null || owner.uid != shopId) {
      throw StateError('Only this shop owner can reject the order.');
    }
    final orderRef = _firestore
        .collection('public_shops')
        .doc(shopId)
        .collection('orders')
        .doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (snapshot.data()?['status'] != 'pending') {
        throw StateError('This order is no longer pending.');
      }
      transaction.update(orderRef, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelCustomerOrder({
    required String shopId,
    required String orderId,
  }) async {
    final customer = _auth.currentUser;
    if (customer == null) throw StateError('Sign in to cancel this order.');

    final orderRef = _firestore
        .collection('public_shops')
        .doc(shopId)
        .collection('orders')
        .doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      final order = snapshot.data();
      if (order == null ||
          order['customerId'] != customer.uid ||
          order['status'] != 'pending') {
        throw StateError('Only your pending orders can be cancelled.');
      }
      transaction.update(orderRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
