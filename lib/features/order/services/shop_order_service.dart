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

  static double parseConfiguredAmount(String value) {
    final normalized =
        value.replaceAll('٬', ',').replaceAll('٫', '.').replaceAllMapped(
      RegExp('[۰-۹٠-٩]'),
      (match) {
        final codeUnit = match.group(0)!.codeUnitAt(0);
        final digit =
            codeUnit >= 0x06F0 ? codeUnit - 0x06F0 : codeUnit - 0x0660;
        return digit.toString();
      },
    );
    if (normalized.trimLeft().startsWith('-')) return 0;
    final match = RegExp(r'-?\d[\d,]*(?:\.\d+)?').firstMatch(normalized);
    if (match == null) return 0;
    final matchedText = match.group(0)!;
    if (matchedText.startsWith('-')) return 0;
    final amount = double.tryParse(matchedText.replaceAll(',', ''));
    return amount != null && amount.isFinite && amount >= 0 ? amount : 0;
  }

  Future<String> placeOrder({
    required Shop shop,
    required List<ShopItem> items,
    String note = '',
  }) async {
    final customer = _auth.currentUser;
    if (customer == null) throw StateError('Sign in to place an order.');
    if (items.isEmpty) throw StateError('Add at least one item to the order.');
    if (!shop.isOpen) throw StateError('This shop is currently closed.');
    if (shop.id == customer.uid) {
      throw StateError('You cannot order from your own shop.');
    }
    if (note.trim().length > 500) {
      throw StateError('Order instructions must be 500 characters or fewer.');
    }

    final quantities = <String, double>{};
    final selectedRates = <String, double>{};
    for (final item in items) {
      final itemId = item.stockItemId.isEmpty ? item.id : item.stockItemId;
      if (itemId.isEmpty || !item.quantity.isFinite || item.quantity <= 0) {
        throw StateError('The order contains an invalid item quantity.');
      }
      if (!item.rate.isFinite || item.rate < 0) {
        throw StateError('The order contains an invalid item price.');
      }
      final selectedRate = selectedRates.putIfAbsent(itemId, () => item.rate);
      if ((selectedRate - item.rate).abs() > 0.000001) {
        throw StateError('The order contains conflicting item prices.');
      }
      quantities.update(
        itemId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
      if (!quantities[itemId]!.isFinite) {
        throw StateError('The order contains an invalid item quantity.');
      }
    }

    final shopRef = _firestore.collection('public_shops').doc(shop.id);
    final orderRef = shopRef.collection('orders').doc();
    final itemRefs = {
      for (final itemId in quantities.keys)
        itemId: shopRef.collection('items').doc(itemId),
    };

    await _firestore.runTransaction((transaction) async {
      final shopSnapshot = await transaction.get(shopRef);
      final shopData = shopSnapshot.data();
      if (shopData == null || shopData['isOpen'] != true) {
        throw StateError('This shop is currently closed.');
      }

      final itemSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in itemRefs.entries) {
        itemSnapshots[entry.key] = await transaction.get(entry.value);
      }

      final orderItems = <Map<String, dynamic>>[];
      var subtotal = 0.0;
      for (final entry in quantities.entries) {
        final data = itemSnapshots[entry.key]!.data();
        if (data == null) {
          throw StateError('An ordered item is no longer available.');
        }
        final tracksStock = data['trackStock'] != false;
        final available = (data['availableQuantity'] as num?)?.toDouble() ?? 0;
        final rate = (data['rate'] as num?)?.toDouble() ?? 0;
        if (!rate.isFinite || rate < 0) {
          throw StateError('An ordered item has an invalid price.');
        }
        if (data['isAvailable'] == false ||
            (tracksStock &&
                (!available.isFinite ||
                    available < 0 ||
                    available < entry.value))) {
          throw StateError(
              '${data['name']?.toString() ?? 'An item'} is no longer available in that quantity.');
        }
        if ((rate - selectedRates[entry.key]!).abs() > 0.000001) {
          throw StateError(
            'The price of ${data['name']?.toString() ?? 'an item'} has changed. Review your order again.',
          );
        }

        final lineTotal = rate * entry.value;
        subtotal += lineTotal;
        if (!lineTotal.isFinite || !subtotal.isFinite) {
          throw StateError('The order total is too large.');
        }
        orderItems.add({
          'itemId': entry.key,
          'name': (data['name'] ?? entry.key).toString(),
          'nameUrdu': (data['nameUrdu'] ?? '').toString(),
          'unit': (data['unit'] ?? '').toString(),
          'rate': rate,
          'quantity': entry.value,
          'total': lineTotal,
        });
      }

      final minimumOrder =
          parseConfiguredAmount((shopData['minOrder'] ?? '').toString());
      if (minimumOrder > 0 && subtotal < minimumOrder) {
        throw StateError(
          'Minimum order amount is Rs ${minimumOrder.toStringAsFixed(0)}.',
        );
      }
      final deliveryFee =
          parseConfiguredAmount((shopData['deliveryFee'] ?? '').toString());
      final total = subtotal + deliveryFee;
      if (!total.isFinite) throw StateError('The order total is too large.');
      if ((deliveryFee - parseConfiguredAmount(shop.deliveryFee)).abs() >
              0.000001 ||
          (minimumOrder - parseConfiguredAmount(shop.minOrder)).abs() >
              0.000001) {
        throw StateError(
            'The shop delivery terms changed. Review your order again.');
      }

      transaction.set(orderRef, {
        'id': orderRef.id,
        'shopId': shop.id,
        'shopName':
            (shopData['shopName'] ?? shopData['displayName'] ?? shop.name)
                .toString(),
        'shopOwnerName': (shopData['ownerName'] ?? shop.owner).toString(),
        'customerId': customer.uid,
        'customerName': customer.displayName ?? '',
        'customerPhone': customer.phoneNumber ?? '',
        'status': 'pending',
        'items': orderItems,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'minimumOrder': minimumOrder,
        'total': total,
        'note': note.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
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
      final available =
          (itemData['availableQuantity'] as num?)?.toDouble() ?? 0;
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
          stock: tracksStock ? available : 1000000000.0,
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
      customerCount: (shopData['customerCount'] as num?)?.toInt() ?? 0,
      satisfiedCustomerPercent:
          (shopData['quickBillSatisfactionPercent'] as num?)?.toInt() ?? 0,
      billCount: (shopData['quickBillCount'] as num?)?.toInt() ?? 0,
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

    return placeOrder(shop: shop, items: items);
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
      final shopSnapshot = await transaction.get(shopRef);
      final shopData = shopSnapshot.data();
      if (shopData == null) {
        throw StateError('This shop is no longer available.');
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
        if (!quantityById[id]!.isFinite) {
          throw StateError('This order contains an invalid item quantity.');
        }
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
        if (!rate.isFinite || rate < 0) {
          throw StateError('An ordered item has an invalid price.');
        }
        final itemTotal = rate * entry.value;
        trustedTotal += itemTotal;
        if (!itemTotal.isFinite || !trustedTotal.isFinite) {
          throw StateError('The order total is too large.');
        }
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
          if (publicData['isAvailable'] == false ||
              !available.isFinite ||
              available < entry.value) {
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
      final minimumOrder =
          parseConfiguredAmount((shopData['minOrder'] ?? '').toString());
      if (minimumOrder > 0 && trustedTotal < minimumOrder) {
        throw StateError(
          'The order is below the shop minimum of Rs ${minimumOrder.toStringAsFixed(0)}.',
        );
      }
      final deliveryFee =
          parseConfiguredAmount((shopData['deliveryFee'] ?? '').toString());
      final trustedGrandTotal = trustedTotal + deliveryFee;
      if (!trustedGrandTotal.isFinite) {
        throw StateError('The order total is too large.');
      }
      transaction.update(orderRef, {
        'status': 'accepted',
        'items': trustedLines,
        'subtotal': trustedTotal,
        'deliveryFee': deliveryFee,
        'minimumOrder': minimumOrder,
        'total': trustedGrandTotal,
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

  Future<void> markOrderDelivered({
    required String shopId,
    required String orderId,
  }) async {
    final owner = _auth.currentUser;
    if (owner == null || owner.uid != shopId) {
      throw StateError('Only this shop owner can complete the order.');
    }
    final orderRef = _firestore
        .collection('public_shops')
        .doc(shopId)
        .collection('orders')
        .doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (snapshot.data()?['status'] != 'accepted') {
        throw StateError('Only accepted orders can be marked delivered.');
      }
      transaction.update(orderRef, {
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
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
