// lib/core/services/stock_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/models/stock_movement_model.dart';
import 'package:account_app/core/models/stock_category_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;

class StockService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    if (item.id.isEmpty) return 0.0;

    double stock = item.initialQuantity;

    final itemMovements = _movements.where((m) => m.stockItemId == itemId);
    for (var movement in itemMovements) {
      if (movement.reason == 'Initial Opening Stock') continue;
      switch (movement.type) {
        case StockMovementType.purchase:
        case StockMovementType.customerReturn:
          stock += movement.quantity;
          break;
        case StockMovementType.sale:
        case StockMovementType.supplierReturn:
          stock -= movement.quantity;
          break;
        case StockMovementType.adjustment:
          // Quantity can be positive or negative for adjustments
          stock += movement.quantity;
          break;
      }
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
      switch (movement.type) {
        case StockMovementType.purchase:
        case StockMovementType.customerReturn:
          available -= movement.quantity;
          break;
        case StockMovementType.sale:
        case StockMovementType.supplierReturn:
          available += movement.quantity;
          break;
        case StockMovementType.adjustment:
          available -= movement.quantity;
          break;
      }
    }
    return available;
  }

  static Future<void> syncTransactionMovements(
    model.Transaction transaction, {
    bool deleteTransaction = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
        final quantity = entry.value.fold<double>(
          0,
          (sum, item) => sum + item.quantity,
        );
        final amount = entry.value.fold<double>(
          0,
          (sum, item) => sum + item.total,
        );
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
          unitPrice: quantity > 0 ? amount / quantity : 0,
          reason: transaction.type == 'income'
              ? 'Transaction sale'
              : 'Transaction purchase',
          note: 'Transaction ${transaction.id}',
          partyId: transaction.accountId,
          partyName: partyName,
          transactionId: transaction.id,
          timestamp: transaction.updatedAt,
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
    if (oldById.isNotEmpty || desired.isNotEmpty) await batch.commit();
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
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    await userDoc.collection('stock_items').doc(item.id).set(item.toMap());

    // If initial quantity > 0, record initial stock movement
    if (item.initialQuantity > 0) {
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
      await userDoc
          .collection('stock_movements')
          .doc(movement.id)
          .set(movement.toMap());
    }

    notifyListeners();
  }

  /// ✏️ Update Existing Stock Item
  Future<void> updateStockItem(StockItem item) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stock_items')
        .doc(item.id)
        .set(item.toMap(), SetOptions(merge: true));

    notifyListeners();
  }

  /// 🗑️ Delete Stock Item
  Future<void> deleteStockItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stock_items')
        .doc(itemId)
        .delete();

    notifyListeners();
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
    notifyListeners();
  }

  /// 📈 Get Stock Summary Statistics
  Map<String, dynamic> getStockSummary() {
    double totalPurchaseValue = 0.0;
    double totalSalesPotentialValue = 0.0;
    int lowStockCount = 0;
    int outOfStockCount = 0;

    for (var item in _items) {
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
      'totalItems': _items.length,
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
