// lib/core/services/stock_service.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/models/stock_category_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;

class StockService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<StockItem> _items = [];
  List<StockMovement> _movements = [];
  List<StockCategory> _categories = [];
  bool _isLoading = false;

  StreamSubscription? _itemsSub;
  StreamSubscription? _movementsSub;
  StreamSubscription<User?>? _authSub;
  String? _activeUserId;
  bool _itemsLoaded = false;
  bool _movementsLoaded = false;

  List<StockItem> get items => _items;
  List<StockMovement> get movements => _movements;
  List<StockCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  StockService() {
    _authSub = _auth.authStateChanges().listen(_handleAuthStateChange);
  }

  void _handleAuthStateChange(User? user) {
    if (user?.uid == _activeUserId) return;

    _itemsSub?.cancel();
    _movementsSub?.cancel();
    _itemsSub = null;
    _movementsSub = null;

    _activeUserId = user?.uid;
    _items = [];
    _movements = [];
    _itemsLoaded = user == null;
    _movementsLoaded = user == null;
    _isLoading = user != null;
    notifyListeners();
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);

    _itemsSub?.cancel();
    _itemsSub =
        userDoc.collection('stock_items').snapshots().listen((snapshot) {
      _items =
          snapshot.docs.map((doc) => StockItem.fromMap(doc.data())).toList();
      _itemsLoaded = true;
      _updateLoadingState();
    });

    _movementsSub?.cancel();
    _movementsSub = userDoc
        .collection('stock_movements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _movements = snapshot.docs
          .map((doc) => StockMovement.fromMap(doc.data()))
          .toList();
      _movementsLoaded = true;
      _updateLoadingState();
    });
  }

  void _updateLoadingState() {
    _isLoading = !_itemsLoaded || !_movementsLoaded;
    notifyListeners();
  }

  /// 🧮 Pure Arithmetic Computed Stock Calculation:
  /// `Current Stock = Initial Quantity + Purchases + Customer Returns - Sales - Supplier Returns + Adjustments`
  static bool canApplyMovement({
    required double availableStock,
    required StockMovement movement,
    bool stopWhenOut = true,
  }) {
    if (!availableStock.isFinite ||
        !movement.quantity.isFinite ||
        !movement.unitPrice.isFinite ||
        movement.unitPrice < 0) {
      return false;
    }
    if (movement.type != StockMovementType.adjustment &&
        movement.quantity < 0) {
      return false;
    }
    if (movement.type == StockMovementType.sale) {
      return canSellQuantity(
        availableStock: availableStock,
        quantity: movement.quantity,
        stopWhenOut: stopWhenOut,
      );
    }
    final stockDelta = movement.stockDelta;
    return stockDelta >= 0 || availableStock + stockDelta >= -0.000001;
  }

  static double stockAdjustmentDelta({
    required double currentStock,
    required double targetStock,
  }) {
    if (!currentStock.isFinite || !targetStock.isFinite || targetStock < 0) {
      throw ArgumentError('Stock values must be finite and target stock non-negative.');
    }
    return targetStock - currentStock;
  }

  static bool canSellQuantity({
    required double availableStock,
    required double quantity,
    bool stopWhenOut = true,
  }) {
    if (!availableStock.isFinite || !quantity.isFinite || quantity < 0) {
      return false;
    }
    return !stopWhenOut || availableStock - quantity >= -0.000001;
  }

  double calculateCurrentStock(String itemId) {
    final item = _items.firstWhere(
      (i) => i.id == itemId,
      orElse: () => StockItem(
        id: '',
        name: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (item.id.isEmpty || !item.trackStock) return 0.0;

    double stock = item.initialQuantity;

    final itemMovements = _movements.where((m) => m.stockItemId == itemId);
    for (var movement in itemMovements) {
      if (movement.reason == 'Initial Opening Stock') continue;
      stock += movement.stockDelta;
    }

    return stock;
  }

  double availableStockForTransaction(
    String itemId, {
    String? excludingTransactionId,
  }) {
    var available = calculateCurrentStock(itemId);
    if (excludingTransactionId == null) return available;

    for (final movement in _movements) {
      final belongsToTransaction =
          movement.transactionId == excludingTransactionId ||
              movement.note == 'Transaction $excludingTransactionId';
      if (movement.stockItemId != itemId || !belongsToTransaction) continue;
      available -= movement.stockDelta;
    }
    return available;
  }

  static Future<void> syncTransactionMovements(
    model.Transaction transaction, {
    bool deleteTransaction = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to sync transaction stock movements.');
    }

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final movementsRef = userDoc.collection('stock_movements');
    final oldById = <String, dynamic>{};
    final oldByTransactionId = await movementsRef
        .where('transactionId', isEqualTo: transaction.id)
        .get();
    final oldByLegacyNote = await movementsRef
        .where('note', isEqualTo: 'Transaction ${transaction.id}')
        .get();
    for (final document in oldByTransactionId.docs) {
      oldById[document.id] = document;
    }
    for (final document in oldByLegacyNote.docs) {
      oldById[document.id] = document;
    }

    final desired = <String, StockMovement>{};
    if (!deleteTransaction) {
      final groupedItems = <String, List<TransactionItem>>{};
      for (final item in transaction.items) {
        final stockItemId = item.stockItemId;
        if (stockItemId == null || stockItemId.isEmpty || item.quantity <= 0) {
          continue;
        }
        groupedItems.putIfAbsent(stockItemId, () => []).add(item);
      }

      final account =
          await userDoc.collection('accounts').doc(transaction.accountId).get();
      final partyName = account.data()?['name']?.toString() ?? '';

      for (final entry in groupedItems.entries) {
        final stockItemDoc =
            await userDoc.collection('stock_items').doc(entry.key).get();
        if (stockItemDoc.data()?['trackStock'] == false) continue;

        final quantity = entry.value.fold<double>(
          0,
          (total, item) => total + item.quantity,
        );
        final subtotal = entry.value.fold<double>(
          0,
          (total, item) =>
              total + (item.total > 0 ? item.total : item.quantity * item.rate),
        );
        final transactionSubtotal = transaction.subtotal > 0
            ? transaction.subtotal
            : transaction.items.fold<double>(
                0,
                (total, item) =>
                    total +
                    (item.total > 0 ? item.total : item.quantity * item.rate),
              );
        final discountShare = transaction.type == 'income' &&
                transaction.discountAmount > 0 &&
                transactionSubtotal > 0
            ? (transaction.discountAmount * (subtotal / transactionSubtotal))
                .clamp(0.0, subtotal)
                .toDouble()
            : 0.0;
        final discountedAmount = subtotal - discountShare;
        final stockItemId = entry.key;
        final encodedStockItemId = Uri.encodeComponent(stockItemId);
        final movementId = 'tx_${transaction.id}_$encodedStockItemId';
        desired[movementId] = StockMovement(
          id: movementId,
          stockItemId: stockItemId,
          stockItemName: entry.value.first.description,
          type: transaction.type == 'income'
              ? StockMovementType.sale
              : StockMovementType.purchase,
          quantity: quantity,
          unitPrice: quantity > 0 ? discountedAmount / quantity : 0,
          reason: transaction.type == 'income'
              ? 'Transaction sale'
              : 'Transaction purchase',
          note: 'Transaction ${transaction.id}',
          partyId: transaction.accountId,
          partyName: partyName,
          transactionId: transaction.id,
          timestamp: transaction.date,
        );
      }
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final entry in oldById.entries) {
      if (!desired.containsKey(entry.key)) {
        batch.delete(entry.value.reference);
      }
    }
    for (final movement in desired.values) {
      batch.set(movementsRef.doc(movement.id), movement.toMap());
    }
    if (oldById.isNotEmpty || desired.isNotEmpty) {
      await batch.commit();
      final impactedItemIds = <String>{
        ...desired.values.map((movement) => movement.stockItemId),
        ...oldById.values.map(
          (document) => (document.data() as Map<String, dynamic>)['stockItemId']
              ?.toString() ?? '',
        ),
      }..remove('');
      for (final itemId in impactedItemIds) {
        await _refreshPublicAvailability(user.uid, itemId);
      }
    }
  }

  static Future<void> _refreshPublicAvailability(
    String userId,
    String itemId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(userId);
    final stockDoc = await userDoc.collection('stock_items').doc(itemId).get();
    if (!stockDoc.exists) return;
    final shopItemRef =
        firestore.collection('public_shops').doc(userId).collection('items').doc(itemId);
    final publicItem = await shopItemRef.get();
    if (!publicItem.exists) return;

    final stockData = stockDoc.data()!;
    if (stockData['trackStock'] == false) {
      await shopItemRef.update({
        'availableQuantity': null,
        'isAvailable': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final movements = await userDoc
        .collection('stock_movements')
        .where('stockItemId', isEqualTo: itemId)
        .get();
    var available = (stockData['initialQuantity'] as num?)?.toDouble() ?? 0;
    for (final document in movements.docs) {
      final movement = StockMovement.fromMap(document.data());
      if (movement.reason != 'Initial Opening Stock') {
        available += movement.stockDelta;
      }
    }
    await shopItemRef.update({
      'availableQuantity': available,
      'isAvailable': available > 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 📊 Calculate Weighted Average Purchase Cost
  double calculateWeightedAverageCost(String itemId) {
    final item = _items.firstWhere(
      (i) => i.id == itemId,
      orElse: () => StockItem(
        id: '',
        name: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (item.id.isEmpty) return 0.0;

    double totalCost = item.initialQuantity * item.purchasePrice;
    double totalQty = item.initialQuantity;

    final purchases = _movements.where((m) =>
        m.stockItemId == itemId &&
        m.type == StockMovementType.purchase &&
        m.reason != 'Initial Opening Stock');

    for (var p in purchases) {
      totalCost += (p.quantity * p.unitPrice);
      totalQty += p.quantity;
    }

    if (totalQty <= 0) return item.purchasePrice;
    return totalCost / totalQty;
  }

  /// ➕ Add New Stock Item
  Future<void> addStockItem(StockItem item) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to add a stock item.');

    final userDoc = _firestore.collection('users').doc(user.uid);
    final batch = _firestore.batch();
    batch.set(userDoc.collection('stock_items').doc(item.id), item.toMap());

    if (item.trackStock && item.initialQuantity > 0) {
      final movement = StockMovement(
        id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
        stockItemId: item.id,
        stockItemName: item.name,
        type: StockMovementType.purchase,
        quantity: item.initialQuantity,
        unitPrice: item.purchasePrice,
        reason: 'Initial Opening Stock',
        timestamp: DateTime.now(),
      );
      batch.set(
        userDoc.collection('stock_movements').doc(movement.id),
        movement.toMap(),
      );
    }

    await batch.commit();
    await _syncPublicItem(
      user.uid,
      item,
      availableStock: item.trackStock ? item.initialQuantity : null,
    );
    notifyListeners();
  }

  /// ✏️ Update Existing Stock Item
  Future<void> updateStockItem(StockItem item) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to update this stock item.');

    final availableStock =
        item.trackStock ? calculateCurrentStock(item.id) : null;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stock_items')
        .doc(item.id)
        .set(item.toMap(), SetOptions(merge: true));

    await _syncPublicItem(user.uid, item, availableStock: availableStock);
    notifyListeners();
  }

  /// 🗑️ Delete Stock Item
  Future<void> deleteStockItem(String itemId) async {
    await archiveStockItem(itemId);
  }

  Future<void> archiveStockItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to archive this stock item.');
    final item = _items.where((candidate) => candidate.id == itemId).firstOrNull;
    if (item == null) throw StateError('Stock item $itemId is unavailable.');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stock_items')
        .doc(itemId)
        .set(
          item.copyWith(isArchived: true, updatedAt: DateTime.now()).toMap(),
          SetOptions(merge: true),
        );
    await _syncPublicItem(user.uid, item.copyWith(isArchived: true));
    notifyListeners();
  }

  Future<void> _syncPublicItem(
    String userId,
    StockItem item, {
    double? availableStock,
  }) async {
    final shopRef = _firestore.collection('public_shops').doc(userId);
    final shop = await shopRef.get();
    if (!shop.exists) return;

    final itemRef = shopRef.collection('items').doc(item.id);
    final previous = await itemRef.get();
    if (item.isArchived) {
      if (previous.exists) {
        await itemRef.delete();
        await shopRef.update({'itemCount': FieldValue.increment(-1)});
      }
      return;
    }

    await itemRef.set({
      'id': item.id,
      'name': item.name,
      'nameUrdu': item.nameUrdu,
      'description': item.description,
      'rate': item.sellingPrice,
      'oldRate': item.mrp > item.sellingPrice ? item.mrp : null,
      'unit': item.unit,
      'category': item.categoryName,
      'imageUrl': item.imagePath ?? '',
      'availableQuantity': availableStock,
      'trackStock': item.trackStock,
      'isAvailable': !item.trackStock || (availableStock ?? 0) > 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!previous.exists) {
      await shopRef.update({'itemCount': FieldValue.increment(1)});
    }
  }

  Future<void> syncPublicCatalog() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to publish shop items.');
    final shop = await _firestore.collection('public_shops').doc(user.uid).get();
    if (!shop.exists) return;

    final batch = _firestore.batch();
    final publicItems = await shop.reference.collection('items').get();
    final userDoc = _firestore.collection('users').doc(user.uid);
    final stockSnapshot = await userDoc.collection('stock_items').get();
    final movementSnapshot = await userDoc.collection('stock_movements').get();
    final activeItems = stockSnapshot.docs
        .map((doc) => StockItem.fromMap(doc.data()))
        .where((item) => !item.isArchived)
        .toList();
    final movements = movementSnapshot.docs
        .map((doc) => StockMovement.fromMap(doc.data()))
        .toList();
    final activeIds = activeItems.map((item) => item.id).toSet();
    for (final doc in publicItems.docs) {
      if (!activeIds.contains(doc.id)) batch.delete(doc.reference);
    }

    for (final item in activeItems) {
      double? available;
      if (item.trackStock) {
        var currentAvailable = item.initialQuantity;
        for (final movement in movements.where((m) => m.stockItemId == item.id)) {
          if (movement.reason != 'Initial Opening Stock') {
            currentAvailable += movement.stockDelta;
          }
        }
        available = currentAvailable;
      }
      batch.set(
        shop.reference.collection('items').doc(item.id),
        {
          'id': item.id,
          'name': item.name,
          'nameUrdu': item.nameUrdu,
          'description': item.description,
          'rate': item.sellingPrice,
          'oldRate': item.mrp > item.sellingPrice ? item.mrp : null,
          'unit': item.unit,
          'category': item.categoryName,
          'imageUrl': item.imagePath ?? '',
          'availableQuantity': available,
          'trackStock': item.trackStock,
          'isAvailable': !item.trackStock || (available ?? 0) > 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    batch.set(
      shop.reference,
      {'itemCount': activeItems.length},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<String> uploadStockImage(File image, String itemId) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to upload a stock image.');
    if (!await image.exists()) {
      throw FileSystemException(
          'The selected stock image is unavailable.', image.path);
    }

    final extension = image.path.split('.').last.toLowerCase();
    final imageRef = _storage
        .ref()
        .child('users/${user.uid}/stock_items/$itemId/image.$extension');
    await imageRef.putFile(image);
    return imageRef.getDownloadURL();
  }

  /// 📦 Record Stock Movement (In / Out / Adjustment / Return)
  Future<void> recordMovement(StockMovement movement) async {
    await recordMovements([movement]);
  }

  /// Save every stock movement from one bill in a single Firestore batch.
  Future<void> recordMovements(List<StockMovement> movements) async {
    if (movements.isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to update stock.');

    final pendingDeltas = <String, double>{};
    for (final movement in movements) {
      final matchingItems =
          _items.where((item) => item.id == movement.stockItemId);
      if (matchingItems.isEmpty) {
        throw StateError('Stock item ${movement.stockItemId} is unavailable.');
      }
      final item = matchingItems.first;
      if (item.isArchived) {
        throw StateError('${item.name} is archived.');
      }
      if (!item.trackStock) {
        throw StateError('${item.name} is configured not to track stock.');
      }
      if (movement.type == StockMovementType.customerReturn &&
          !item.allowReturn) {
        throw StateError('${item.name} does not allow customer returns.');
      }

      final available =
          calculateCurrentStock(item.id) + (pendingDeltas[item.id] ?? 0);
      if (!canApplyMovement(
        availableStock: available,
        movement: movement,
        stopWhenOut: item.stopWhenOut,
      )) {
        throw StateError(
          'Stock reduction exceeds available stock for ${item.name}.',
        );
      }
      pendingDeltas.update(
        item.id,
        (delta) => delta + movement.stockDelta,
        ifAbsent: () => movement.stockDelta,
      );
    }

    final userDoc = _firestore.collection('users').doc(user.uid);
    final batch = _firestore.batch();
    for (final movement in movements) {
      batch.set(
        userDoc.collection('stock_movements').doc(movement.id),
        movement.toMap(),
      );
    }
    await batch.commit();

    _movements = [...movements, ..._movements];
    final changedItemIds = movements.map((movement) => movement.stockItemId).toSet();
    for (final itemId in changedItemIds) {
      await _refreshPublicAvailability(user.uid, itemId);
    }
    notifyListeners();
  }

  /// 📈 Get Stock Summary Statistics
  Map<String, dynamic> getStockSummary() {
    double totalPurchaseValue = 0.0;
    double totalSalesPotentialValue = 0.0;
    int lowStockCount = 0;
    int outOfStockCount = 0;

    for (var item in _items) {
      if (item.isArchived || !item.trackStock) continue;
      final qty = calculateCurrentStock(item.id);
      final avgCost = calculateWeightedAverageCost(item.id);

      totalPurchaseValue += (qty * avgCost);
      totalSalesPotentialValue += (qty * item.sellingPrice);

      if (qty <= 0) {
        outOfStockCount++;
      } else if (qty <= item.minStockAlert) {
        lowStockCount++;
      }
    }

    return {
      'totalItems': _items.where((item) => !item.isArchived).length,
      'totalPurchaseValue': totalPurchaseValue,
      'totalSalesPotentialValue': totalSalesPotentialValue,
      'expectedProfit': totalSalesPotentialValue - totalPurchaseValue,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
    };
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _itemsSub?.cancel();
    _movementsSub?.cancel();
    super.dispose();
  }
}
