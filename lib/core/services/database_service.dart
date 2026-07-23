import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/models/review_model.dart';
import 'package:account_app/core/models/ad_report_model.dart';
import 'package:account_app/helpers/migration_helper.dart';

class DatabaseService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Box<Account>? _accountsBox;
  Box<model.Transaction>? _transactionsBox;
  Box<Category>? _categoriesBox;
  Box<Profession>? _professionsBox;
  Box<InventoryItem>? _itemsBox;
  Box<List>? _remoteCachedItemsBox;
  Box<InventoryItem>? _recentlyViewedBox;
  Box? _settingsBox;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<QuerySnapshot>? _accountsSubscription;
  StreamSubscription<QuerySnapshot>? _transactionsSubscription;
  StreamSubscription<QuerySnapshot>? _categoriesSubscription;
  StreamSubscription<QuerySnapshot>? _professionsSubscription;
  StreamSubscription<QuerySnapshot>? _itemsSubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  Completer<void>? _initCompleter;

  // Getters for lists
  List<Account> get accounts => _accountsBox?.values.toList() ?? [];
  List<model.Transaction> get transactions => _transactionsBox?.values.toList() ?? [];

  DatabaseService() {
    // init(); // Removing auto-init from constructor to better control lifecycle
  }

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      _accountsBox = await Hive.openBox<Account>('accounts');
      _transactionsBox = await Hive.openBox<model.Transaction>('transactions');
      _categoriesBox = await Hive.openBox<Category>('categories');
      _professionsBox = await Hive.openBox<Profession>('professions');
      _itemsBox = await Hive.openBox<InventoryItem>('inventory_items');
      _remoteCachedItemsBox = await Hive.openBox<List>('remote_cached_items');
      _recentlyViewedBox = await Hive.openBox<InventoryItem>('recently_viewed');
      _settingsBox = await Hive.openBox('settings');

      _isInitialized = true;

      // Start Realtime Sync if logged in
      if (_auth.currentUser != null) {
        _startRealtimeSync();
      }

      // Monitor Auth State
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          _startRealtimeSync();
          _triggerSync();
        } else {
          _stopRealtimeSync();
        }
      });

      _triggerSync();

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
        if (results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.ethernet)) {
          print("Connection restored. Syncing...");
          _triggerSync();
        }
      });

      _initCompleter!.complete();
      notifyListeners();
    } catch (e) {
      print("Database initialization failed: $e");
      _initCompleter!.completeError(e);
      _initCompleter = null; // Allow retry on failure
      rethrow;
    }
  }

  // --- Migration Method Removed (Moved to MigrationHelper) ---
  // Future<void> _migrateExistingProfessions() async { ... } 
  // Functionality is now covered by MigrationHelper.runAllMigrations

  // --- نئے حساب کتاب کے فنکشن ---

  // 1. فی اکائی لاگت کا حساب
  Future<double> calculateCostPerUnit(String professionId) async {
    final profession = getProfession(professionId);
    if (profession == null) return 0.0;

    return profession.costPerUnit;
  }

  // 2. بجٹ انتباہات چیک کریں
  Future<Map<String, bool>> checkBudgetAlerts(String professionId) async {
    final profession = getProfession(professionId);
    final alerts = <String, bool>{};

    if (profession == null || profession.budgetLimits == null) return alerts;

    final transactions = getProfessionTransactions(professionId);

    for (final budgetEntry in profession.budgetLimits!.entries) {
      final category = budgetEntry.key;
      final limit = budgetEntry.value;

      final categoryExpense = transactions
          .where((t) => t.type == 'expense' && t.category == category)
          .fold(0.0, (sum, t) => sum + t.amount);

      alerts[category] = categoryExpense > limit;
    }

    return alerts;
  }

  // 3. سیزن موازنہ ڈیٹا
  Future<Map<String, dynamic>> getSeasonComparison(String professionName) async {
    final sameNameProfessions = _professionsBox?.values
        .where((p) => p.name == professionName && p.season.isNotEmpty)
        .toList() ?? [];

    if (sameNameProfessions.length < 2) {
      return {'hasComparison': false};
    }

    // سیزن کے لحاظ سے ترتیب دیں
    sameNameProfessions.sort((a, b) => b.season.compareTo(a.season));

    final latest = sameNameProfessions.first;
    final previous = sameNameProfessions.length > 1 ? sameNameProfessions[1] : null;

    if (previous == null) {
      return {'hasComparison': false};
    }

    return {
      'hasComparison': true,
      'latestSeason': latest.season,
      'previousSeason': previous.season,
      'costChange': latest.costPerUnit - previous.costPerUnit,
      'profitChange': latest.netProfit - previous.netProfit,
      'productionChange': latest.totalProduction - previous.totalProduction,
      'costChangePercent': previous.costPerUnit > 0
          ? ((latest.costPerUnit - previous.costPerUnit) / previous.costPerUnit * 100)
          : 0,
      'profitChangePercent': previous.netProfit.abs() > 0
          ? ((latest.netProfit - previous.netProfit) / previous.netProfit.abs() * 100)
          : 0,
    };
  }

  // 4. AI سفارشات جنریٹ کریں
  Future<List<String>> generateRecommendations(String professionId) async {
    final profession = getProfession(professionId);
    final recommendations = <String>{};

    if (profession == null) return recommendations.toList();

    // 1. Cost recommendations
    if (profession.benchmarkCostPerUnit > 0 && profession.costPerUnit > 0) {
      final diffPercent = ((profession.costPerUnit - profession.benchmarkCostPerUnit) /
          profession.benchmarkCostPerUnit * 100);
      if (diffPercent > 20) {
        recommendations.add('لاگت ${diffPercent.toStringAsFixed(1)}% زیادہ ہے۔ سپلائرز سے ریٹ کم کریں۔');
      } else if (diffPercent < -10) {
        recommendations.add('لاگت ${diffPercent.abs().toStringAsFixed(1)}% کم ہے۔ بہترین!');
      }
    }

    // 2. Production recommendations
    if (profession.targetProduction > 0) {
      final progress = profession.productionProgress;
      if (progress < 50) {
        recommendations.add('پیداوار صرف ${progress.toStringAsFixed(1)}% ہے۔ کوالٹی بیج اور کھاد استعمال کریں۔');
      } else if (progress > 100) {
        recommendations.add('پیداوار ہدف سے ${(progress - 100).toStringAsFixed(1)}% زیادہ ہے۔ بہترین!');
      }
    }

    // 3. Profit recommendations
    if (profession.netProfit < 0) {
      recommendations.add('نقصان ہو رہا ہے۔ خرچ کم کریں یا قیمتیں بڑھائیں۔');
    } else if (profession.netProfit > profession.totalIncome * 0.3) {
      recommendations.add('منافع اچھا ہے (${(profession.netProfit / profession.totalIncome * 100).toStringAsFixed(1)}%)۔');
    }

    // 4. Budget recommendations
    final budgetAlerts = await checkBudgetAlerts(professionId);
    final exceededCategories = budgetAlerts.entries.where((e) => e.value).map((e) => e.key).toList();
    if (exceededCategories.isNotEmpty) {
      recommendations.add('${exceededCategories.join(', ')} میں بجٹ سے زیادہ خرچ ہوا ہے۔');
    }

    // 5. Performance score based
    final score = profession.performanceScore;
    if (score < 40) {
      recommendations.add('کارکردگی کم ہے (${score.toStringAsFixed(0)}%)۔ بہتری کی ضرورت ہے۔');
    } else if (score > 80) {
      recommendations.add('شاندار کارکردگی! (${score.toStringAsFixed(0)}%)');
    }

    // اگر کوئی مسئلہ نہیں تو مثبت تبصرہ
    if (recommendations.isEmpty && profession.performanceScore > 60) {
      recommendations.add('کارکردگی اچھی ہے۔ اسی طرح جاری رکھیں۔');
    }

    return recommendations.toList();
  }

  // 5. نئے profession بنانے کا helper
  Future<Profession> createProfessionWithDefaults({
    required String name,
    required String season,
    String? description,
    double totalProduction = 0.0,
    String productionUnit = 'kg',
    double targetProduction = 0.0,
    Map<String, double>? budgetLimits,
    double benchmarkCostPerUnit = 0.0,
    ProfessionCategory categoryType = ProfessionCategory.general,
  }) async {

    // Generate season key
    final seasonKey = season.isNotEmpty
        ? _generateSeasonKey(name, season)
        : "";

    return Profession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      categories: [],
      isActive: true,
      totalIncome: 0.0,
      totalExpense: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      description: description,
      totalProduction: totalProduction,
      productionUnit: productionUnit,
      season: season,
      // New fields
      targetProduction: targetProduction,
      budgetLimits: budgetLimits,
      seasonKey: seasonKey,
      benchmarkCostPerUnit: benchmarkCostPerUnit,
      categoryType: categoryType,
    );
  }

  // Helper just for creating new ones (migration uses helper class now)
  String _generateSeasonKey(String name, String season) {
    return "${name.toLowerCase().replaceAll(' ', '_')}_${season.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_')}";
  }

  // --- باقی کوڈ (آپ کا اصل کوڈ) ---

  void _triggerSync() {
    syncWithFirebase().catchError((e) {
      print("Auto-sync failed: $e");
    });
  }

  void _startRealtimeSync() {
    final user = _auth.currentUser;
    if (user == null) return;

    _stopRealtimeSync(); // Clear existing listeners

    print("Starting Realtime Sync...");

    // Accounts Listener
    _accountsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.doc.data() == null) continue;
        final account = Account.fromMap(change.doc.data()!);

        if (change.type == DocumentChangeType.removed) {
          _accountsBox?.delete(account.id);
        } else {
          _accountsBox?.put(account.id, account);
        }
      }
      if (snapshot.docChanges.isNotEmpty) notifyListeners();
    });

    // Transactions Listener
    _transactionsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .snapshots()
        .listen((snapshot) async {
      final affectedAccountIds = <String>{};
      final affectedProfessionIds = <String>{};

      for (var change in snapshot.docChanges) {
        if (change.doc.data() == null) continue;
        final transaction = model.Transaction.fromMap(change.doc.data()!);

        if (change.type == DocumentChangeType.removed) {
          await _transactionsBox?.delete(transaction.id);
        } else {
          await _transactionsBox?.put(transaction.id, transaction);
        }

        affectedAccountIds.add(transaction.accountId);
        if (transaction.professionId != null) {
          affectedProfessionIds.add(transaction.professionId!);
        }
      }

      // Recalculate balances for affected accounts
      for (var accountId in affectedAccountIds) {
        await recalculateAccountBalance(accountId);
      }

      // Recalculate finances for affected professions
      for (var professionId in affectedProfessionIds) {
        await recalculateProfessionFinance(professionId);
      }

      if (snapshot.docChanges.isNotEmpty) notifyListeners();
    });

    // Categories Listener
    _categoriesSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.doc.data() == null) continue;
        final category = Category.fromMap(change.doc.data()!);

        if (change.type == DocumentChangeType.removed) {
          _categoriesBox?.delete(category.id);
        } else {
          _categoriesBox?.put(category.id, category);
        }
      }
      if (snapshot.docChanges.isNotEmpty) notifyListeners();
    });

    // Professions Listener
    _professionsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('professions')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.doc.data() == null) continue;
        final profession = Profession.fromMap(change.doc.data()!);

        if (change.type == DocumentChangeType.removed) {
          _professionsBox?.delete(profession.id);
        } else {
          _professionsBox?.put(profession.id, profession);
        }
      }
      if (snapshot.docChanges.isNotEmpty) notifyListeners();
    });

    // Inventory Items Listener
    _itemsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('inventory_items')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.doc.data() == null) continue;
        final item = InventoryItem.fromMap(change.doc.data()!);

        if (change.type == DocumentChangeType.removed) {
          _itemsBox?.delete(item.id);
        } else {
          _itemsBox?.put(item.id, item);
        }
      }
      if (snapshot.docChanges.isNotEmpty) notifyListeners();
    }, onError: (e) => print("Inventory Sync Error: $e"));
  }

  void _stopRealtimeSync() {
    _accountsSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _professionsSubscription?.cancel();
    _itemsSubscription?.cancel();
    _accountsSubscription = null;
    _transactionsSubscription = null;
    _categoriesSubscription = null;
    _professionsSubscription = null;
    _itemsSubscription = null;
    print("Stopped Realtime Sync.");
  }

  // --- User Status Operations ---

  Future<void> markUserAsDeactivated(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeactivated': true,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      print("User $userId marked as deactivated.");
    } catch (e) {
      print("Error marking user as deactivated: $e");
      throw Exception("Failed to mark user as deactivated.");
    }
  }

  Future<void> markUserAsActivated(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeactivated': false,
        'deactivatedAt': null,
      });
      print("User $userId marked as activated.");
    } catch (e) {
      print("Error marking user as activated: $e");
      throw Exception("Failed to mark user as activated.");
    }
  }

  // --- Global Profile Lookup ---
  Future<Map<String, String>?> findPublicProfileByPhone(String phone) async {
    try {
      // Clean phone number for searching
      String clean = phone.replaceAll(RegExp(r'\D'), '');
      List<String> potentials = [];
      if (clean.startsWith('92')) {
        potentials.add('+$clean');
        potentials.add('0${clean.substring(2)}');
      } else if (clean.startsWith('03')) {
        potentials.add(clean);
        potentials.add('+92${clean.substring(1)}');
      } else {
        potentials.add(phone);
        if (!phone.startsWith('+')) potentials.add('+$phone');
      }

      for (String p in potentials) {
        final query = await _firestore.collection('users')
            .where('phoneNumber', isEqualTo: p)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final uid = query.docs.first.id;
          return {
            'uid': uid,
            'name': data['displayName'] ?? data['name'] ?? '',
            'photoUrl': data['photoURL'] ?? data['photoUrl'] ?? data['profileImage'] ?? '',
          };
        }
      }
    } catch (e) {
      print("Global lookup error: $e");
    }
    return null;
  }

  Future<List<InventoryItem>> getRemoteInventoryItems(String uid, {int limit = 50}) async {
    try {
      // Professional approach: Filter at the source (Firestore) and use limits for performance
      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('inventory_items')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      final items = querySnapshot.docs.map((doc) => InventoryItem.fromMap({
        ...doc.data(),
        'id': doc.id,
      })).toList();

      // Cache these items locally for offline access
      await saveRemoteCachedItems(uid, items);
      
      return items;
    } catch (e) {
      print("Error fetching remote inventory: $e");
      return getRemoteCachedItems(uid); // Fallback to cache on error
    }
  }

  /// Global Search across all sellers in the app (Name, Brand, Category, SKU)
  Future<List<InventoryItem>> searchGlobalInventory(String query, {int limit = 15}) async {
    if (query.isEmpty) return [];
    
    final trimmedQuery = query.trim();
    final lowerQuery = trimmedQuery.toLowerCase();
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(trimmedQuery);

    try {
      // 1. Search by Name (Prefix)
      final nameQuery = _firestore
          .collectionGroup('inventory_items')
          .where('name', isGreaterThanOrEqualTo: trimmedQuery)
          .where('name', isLessThanOrEqualTo: '$trimmedQuery\uf8ff')
          .limit(limit)
          .get();
      
      // 2. Search by SKU/Barcode (Exact)
      final skuQuery = _firestore
          .collectionGroup('inventory_items')
          .where('sku', isEqualTo: trimmedQuery)
          .limit(limit)
          .get();

      // Execute queries in parallel
      final results = await Future.wait([nameQuery, skuQuery]);
      
      Map<String, InventoryItem> uniqueItems = {};
      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          final item = InventoryItem.fromMap({...doc.data(), 'id': doc.id});
          uniqueItems[item.id] = item;
        }
      }

      // 3. Additional check for English Case Sensitivity if not Urdu
      if (!isUrdu && uniqueItems.length < limit) {
         String capitalizedQuery = lowerQuery[0].toUpperCase() + lowerQuery.substring(1);
         final capQuery = await _firestore
          .collectionGroup('inventory_items')
          .where('name', isGreaterThanOrEqualTo: capitalizedQuery)
          .where('name', isLessThanOrEqualTo: '$capitalizedQuery\uf8ff')
          .limit(limit)
          .get();
          
          for (var doc in capQuery.docs) {
            final item = InventoryItem.fromMap({...doc.data(), 'id': doc.id});
            uniqueItems[item.id] = item;
          }
      }

      return uniqueItems.values.toList();
    } catch (e) {
      print("Global multi-search error: $e");
      // PRO FALLBACK: Search everything in local cache (Handles "contains" search for Urdu/English)
      return _itemsBox?.values.where((item) {
        final n = item.name.toLowerCase();
        final b = (item.brand ?? '').toLowerCase();
        final s = (item.sku ?? '').toLowerCase();
        
        return n.contains(lowerQuery) || 
               b.contains(lowerQuery) || 
               s.contains(lowerQuery);
      }).take(limit).toList() ?? [];
    }
  }

  // --- Remote Item Caching ---
  Future<void> saveRemoteCachedItems(String partyUid, List<InventoryItem> items) async {
    if (_remoteCachedItemsBox == null) return;
    // Map items to Maps for storage if needed, or if they are HiveObjects ensure they don't conflict
    // Since InventoryItem is a HiveObject, it might be safer to store as Map to keep it simple and separate from local items box
    final data = items.map((e) => e.toMap()).toList();
    await _remoteCachedItemsBox!.put(partyUid, data);
  }

  List<InventoryItem> getRemoteCachedItems(String partyUid) {
    if (_remoteCachedItemsBox == null) return [];
    final data = _remoteCachedItemsBox!.get(partyUid);
    if (data == null) return [];
    
    return data.map((e) => InventoryItem.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  // --- Global Marketplace ---
  Future<Map<String, dynamic>> getGlobalMarketplaceItemsPaginated({
    int limit = 20, 
    DocumentSnapshot? lastDocument
  }) async {
    try {
      Query query = _firestore
          .collectionGroup('inventory_items')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();

      final items = querySnapshot.docs.map((doc) => InventoryItem.fromMap({
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      })).toList();

      return {
        'items': items,
        'lastDocument': querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        'hasMore': items.length == limit,
      };
    } catch (e) {
      debugPrint("Error fetching global marketplace paginated: $e");
      return {'items': <InventoryItem>[], 'lastDocument': null, 'hasMore': false};
    }
  }

  Future<List<InventoryItem>> getGlobalMarketplaceItems({int limit = 50}) async {
    try {
      // Using collectionGroup to fetch items from ALL users
      final querySnapshot = await _firestore
          .collectionGroup('inventory_items')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => InventoryItem.fromMap({
        ...doc.data(),
        'id': doc.id,
      })).toList();
    } catch (e) {
      print("Error fetching global marketplace: $e");
      return [];
    }
  }

  Future<bool> isSellerVerified(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['isVerified'] ?? false;
      }
    } catch (e) {
      debugPrint("Error checking seller verification: $e");
    }
    return false;
  }

  Future<Map<String, String>?> findPublicProfileByUid(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'uid': uid,
          'name': data['displayName'] ?? data['name'] ?? '',
          'photoUrl': data['photoURL'] ?? data['photoUrl'] ?? data['profileImage'] ?? '',
          'phone': data['phoneNumber'] ?? '',
          'slogan': data['slogan'] ?? '',
          'address': data['address'] ?? '',
          'isVerified': (data['isVerified'] ?? false).toString(),
          'storeName': data['storeName'] ?? '',
          'storeImage': data['storeImage'] ?? '',
        };
      }
    } catch (e) {
      print("UID lookup error: $e");
    }
    return null;
  }

  // --- Account Operations ---

  Future<void> addAccount(Account account) async {
    await _accountsBox?.put(account.id, account);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateAccount(Account account) async {
    await _accountsBox?.put(account.id, account);
    notifyListeners();
    _triggerSync();
  }

  Future<void> deleteAccount(String accountId) async {
    final account = _accountsBox?.get(accountId);
    if (account == null) return;

    final transactionsToDelete = _transactionsBox?.values
        .where((t) => t.accountId == accountId)
        .toList() ?? [];
    for (var transaction in transactionsToDelete) {
      await _transactionsBox?.delete(transaction.id);
      if (_auth.currentUser != null) {
        _firestore.collection('users').doc(_auth.currentUser!.uid)
            .collection('transactions').doc(transaction.id).delete().catchError((e) => print("Error deleting transaction: $e"));
      }
    }

    // Instead of just deactivating, we delete it completely
    await _accountsBox?.delete(accountId);

    _triggerSync();

    if (_auth.currentUser != null) {
      _firestore.collection('users').doc(_auth.currentUser!.uid)
          .collection('accounts').doc(accountId).delete().catchError((e) => print("Error deleting account: $e"));
    }

    notifyListeners();
  }

  List<Account> getAccounts() {
    return _accountsBox?.values.toList() ?? [];
  }

  Account? getAccount(String id) {
    return _accountsBox?.get(id);
  }

  // Helper to update sharedWith locally
  Future<void> addSharedWith(String accountId, String phoneNumber) async {
    final account = _accountsBox?.get(accountId);
    if (account != null) {
      List<String> updatedSharedWith = List.from(account.sharedWith);
      if (!updatedSharedWith.contains(phoneNumber)) {
        updatedSharedWith.add(phoneNumber);
        final updatedAccount = account.copyWith(
          isShared: true,
          sharedWith: updatedSharedWith,
          updatedAt: DateTime.now(),
        );
        await _accountsBox?.put(accountId, updatedAccount);
        notifyListeners();
      }
    }
  }

  // --- Transaction Operations ---

  Future<void> addTransaction(model.Transaction transaction) async {
    await _transactionsBox?.put(transaction.id, transaction);

    await recalculateAccountBalance(transaction.accountId);

    final account = _accountsBox?.get(transaction.accountId);
    if (account != null) {
      // Sync Transaction to Shared Users
      _syncTransactionToSharedUsers(transaction, account);
    }

    // Update Profession Finance
    if (transaction.professionId != null) {
      await recalculateProfessionFinance(transaction.professionId!);
    }

    notifyListeners();
    _triggerSync();
  }

  Future<void> _syncTransactionToSharedUsers(model.Transaction transaction, Account account) async {
    if (account.isShared && account.sharedWith.isNotEmpty) {
      try {
        for (String phone in account.sharedWith) {
          // Generate potential phone number formats
          String clean = phone.replaceAll(RegExp(r'\D'), '');
          List<String> potentials = [];

          if (clean.startsWith('92')) {
            potentials.add('+$clean');
            potentials.add('0${clean.substring(2)}');
          } else if (clean.startsWith('03')) {
            potentials.add(clean);
            potentials.add('+92${clean.substring(1)}');
          } else if (clean.startsWith('3') && clean.length == 10) {
            potentials.add('+92$clean');
            potentials.add('0$clean');
          } else {
            potentials.add(phone);
            if (phone.startsWith('+')) potentials.add(phone.substring(1));
            else potentials.add('+$phone');
          }

          String? targetUserId;

          // Try to find user with any of the formats
          for (String p in potentials) {
            final query = await _firestore.collection('users').where('phoneNumber', isEqualTo: p).limit(1).get();
            if (query.docs.isNotEmpty) {
              targetUserId = query.docs.first.id;
              break;
            }
          }

          if (targetUserId != null) {
            // Don't write to myself
            if (targetUserId == _auth.currentUser?.uid) continue;

            // Write to target's transactions
            await _firestore.collection('users').doc(targetUserId).collection('transactions').doc(transaction.id).set(transaction.toMap());

            // Update target's Account Balance (Optional/Risky - let target calculate)
            // We skip balance update here to avoid conflicts, target app calculates from txs
          }
        }
      } catch (e) {
        print("Error syncing shared transaction: $e");
      }
    }
  }

  Future<void> _syncDeleteToSharedUsers(String transactionId, Account account) async {
    if (account.isShared && account.sharedWith.isNotEmpty) {
      try {
        for (String phone in account.sharedWith) {
          String clean = phone.replaceAll(RegExp(r'\D'), '');
          List<String> potentials = [];
          if (clean.startsWith('92')) {
            potentials.add('+$clean');
            potentials.add('0${clean.substring(2)}');
          } else if (clean.startsWith('03')) {
            potentials.add(clean);
            potentials.add('+92${clean.substring(1)}');
          } else if (clean.startsWith('3') && clean.length == 10) {
            potentials.add('+92$clean');
            potentials.add('0$clean');
          } else {
            potentials.add(phone);
            if (phone.startsWith('+')) potentials.add(phone.substring(1));
            else potentials.add('+$phone');
          }

          String? targetUserId;
          for (String p in potentials) {
            final query = await _firestore.collection('users').where('phoneNumber', isEqualTo: p).limit(1).get();
            if (query.docs.isNotEmpty) {
              targetUserId = query.docs.first.id;
              break;
            }
          }

          if (targetUserId != null) {
            if (targetUserId == _auth.currentUser?.uid) continue;
            await _firestore.collection('users').doc(targetUserId).collection('transactions').doc(transactionId).delete();
          }
        }
      } catch (e) {
        print("Error syncing delete to shared users: $e");
      }
    }
  }

  model.Transaction? getTransaction(String id) {
    return _transactionsBox?.get(id);
  }

  Future<void> updateTransaction(model.Transaction transaction) async {
    // Check if profession changed to update old profession stats
    final oldTransaction = _transactionsBox?.get(transaction.id);
    String? oldProfessionId = oldTransaction?.professionId;

    await _transactionsBox?.put(transaction.id, transaction);
    await recalculateAccountBalance(transaction.accountId);

    // Sync Update to Shared Users
    final account = _accountsBox?.get(transaction.accountId);
    if (account != null) {
      _syncTransactionToSharedUsers(transaction, account);
    }

    // Update Profession Finance
    if (transaction.professionId != null) {
      await recalculateProfessionFinance(transaction.professionId!);
    }
    // If profession was changed/removed, recalculate old profession too
    if (oldProfessionId != null && oldProfessionId != transaction.professionId) {
      await recalculateProfessionFinance(oldProfessionId);
    }

    notifyListeners();
    _triggerSync();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final transaction = _transactionsBox?.get(transactionId);
    if(transaction != null) {
      // Sync Delete
      final account = _accountsBox?.get(transaction.accountId);
      if (account != null && account.isShared) {
        await _syncDeleteToSharedUsers(transactionId, account);
      }

      await _transactionsBox?.delete(transactionId);
      await recalculateAccountBalance(transaction.accountId);

      // Update Profession Finance
      if (transaction.professionId != null) {
        await recalculateProfessionFinance(transaction.professionId!);
      }

      if (_auth.currentUser != null) {
        _firestore.collection('users').doc(_auth.currentUser!.uid)
            .collection('transactions').doc(transactionId).delete().catchError((e) => print("Delete tx error: $e"));
      }

      notifyListeners();
    }
  }

  Future<void> recalculateAccountBalance(String accountId) async {
    final account = _accountsBox?.get(accountId);
    if (account != null) {
      final transactions = getTransactions(accountId);

      double pendingIncome = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.pendingAmount);

      double pendingExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.pendingAmount);

      double newBalance = account.initialBalance + pendingIncome - pendingExpense;

      final updatedAccount = account.copyWith(balance: newBalance);
      await _accountsBox?.put(updatedAccount.id, updatedAccount);
    }
  }

  Future<void> recalculateProfessionFinance(String professionId) async {
    final profession = _professionsBox?.get(professionId);
    if (profession != null) {
      final transactions = _transactionsBox?.values
          .where((t) => t.professionId == professionId)
          .toList() ?? [];

      double totalIncome = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount); // Using total amount (bill amount)

      double totalExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount); // Using total amount (bill amount)

      final updatedProfession = profession.copyWith(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        updatedAt: DateTime.now(),
      );

      await _professionsBox?.put(profession.id, updatedProfession);

      // Also sync updated profession to Firestore
      if (_auth.currentUser != null) {
        _firestore.collection('users').doc(_auth.currentUser!.uid)
            .collection('professions').doc(profession.id).set(updatedProfession.toMap());
      }
    }
  }

  List<model.Transaction> getTransactions(String accountId) {
    return _transactionsBox?.values
        .where((t) => t.accountId == accountId)
        .toList() ?? [];
  }

  List<model.Transaction> getAllTransactions() {
    return _transactionsBox?.values.toList() ?? [];
  }

  // --- Profession Operations ---

  Future<void> addProfession(Profession profession) async {
    await _professionsBox?.put(profession.id, profession);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateProfession(Profession profession) async {
    // Ensure updatedAt is current
    final updatedProfession = profession.copyWith(updatedAt: DateTime.now());

    // 1. Save to Local Hive first (Instant)
    await _professionsBox?.put(profession.id, updatedProfession);
    
    notifyListeners();

    // 2. Trigger background sync (Non-blocking)
    _triggerSync();
  }

  Future<void> deleteProfession(String professionId) async {
    // Delete associated transactions first
    final transactionsToDelete = _transactionsBox?.values
        .where((t) => t.professionId == professionId)
        .toList() ?? [];

    for (var transaction in transactionsToDelete) {
      await _transactionsBox?.delete(transaction.id);
      if (_auth.currentUser != null) {
        _firestore.collection('users').doc(_auth.currentUser!.uid)
            .collection('transactions').doc(transaction.id).delete()
            .catchError((e) => print("Error deleting profession transaction: $e"));
      }
    }

    await _professionsBox?.delete(professionId);

    if (_auth.currentUser != null) {
      _firestore.collection('users').doc(_auth.currentUser!.uid)
          .collection('professions').doc(professionId).delete();
    }

    notifyListeners();
  }

  List<Profession> getProfessions() {
    return _professionsBox?.values.toList() ?? [];
  }

  Profession? getProfession(String id) {
    return _professionsBox?.get(id);
  }

  Future<void> updateProfessionFinance(
      String professionId,
      String type,
      double amount,
      ) async {
    // This method is deprecated in favor of recalculateProfessionFinance
    // but kept for compatibility if used elsewhere, pointing to recalculate.
    await recalculateProfessionFinance(professionId);
  }

  List<model.Transaction> getProfessionTransactions(String professionId) {
    return _transactionsBox?.values
        .where((t) => t.professionId == professionId)
        .toList() ?? [];
  }

  // --- Category Operations ---

  Future<void> addCategory(Category category) async {
    await _categoriesBox?.put(category.id, category);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateCategory(Category category) async {
    await _categoriesBox?.put(category.id, category);
    notifyListeners();
    _triggerSync();
  }

  Future<void> deleteCategory(String categoryId) async {
    await _categoriesBox?.delete(categoryId);

    if (_auth.currentUser != null) {
      _firestore.collection('users').doc(_auth.currentUser!.uid)
          .collection('categories').doc(categoryId).delete();
    }

    notifyListeners();
  }

  List<Category> getCategories() {
    return _categoriesBox?.values.toList() ?? [];
  }

  // --- Dashboard Counts ---

  Future<int> getPartiesCount() async {
    if (!_isInitialized) await init();
    return _accountsBox?.length ?? 0;
  }

  Future<int> getPendingDuesCount() async {
    if (!_isInitialized) await init();
    final parties = _accountsBox?.values.where((party) => party.balance != 0).toList() ?? [];
    return parties.length;
  }

  Future<int> getProfessionsCount() async {
    if (!_isInitialized) await init();
    return _professionsBox?.length ?? 0;
  }

  // --- Settings ---

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox?.put(key, value);
    notifyListeners();
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue);
  }

  // --- Inventory Item Operations ---

  Future<void> addInventoryItem(InventoryItem item) async {
    await _itemsBox?.put(item.id, item);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    // Check for price drop before updating
    final oldItem = _itemsBox?.get(item.id);
    if (oldItem != null && item.defaultRate < oldItem.defaultRate) {
      _triggerPriceDropNotification(item);
    }

    await _itemsBox?.put(item.id, item);
    notifyListeners();
    _triggerSync();
  }

  Future<void> _triggerPriceDropNotification(InventoryItem item) async {
    try {
      // Find all users who favorited this item in Firestore
      final favs = await _firestore.collection('favorites')
          .where('itemId', isEqualTo: item.id)
          .get();
      
      for (var doc in favs.docs) {
        final userId = doc.data()['userId'];
        if (userId == _auth.currentUser?.uid) continue;
        
        // Add notification to their collection
        await _firestore.collection('users').doc(userId).collection('notifications').add({
          'title': 'قیمت کم ہو گئی! 🔥',
          'message': 'آپ کی پسندیدہ چیز "${item.name}" اب Rs. ${item.defaultRate} میں دستیاب ہے۔',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'price_drop',
          'isRead': false,
          'data': {'itemId': item.id},
        });
      }
    } catch (e) {
      debugPrint("Price drop notification error: $e");
    }
  }

  Future<void> toggleFirestoreFavorite(String itemId, bool isFav) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final favId = "${user.uid}_$itemId";
    if (isFav) {
      await _firestore.collection('favorites').doc(favId).set({
        'userId': user.uid,
        'itemId': itemId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('favorites').doc(favId).delete();
    }
  }

  // --- Review Operations ---

  Future<void> addReview(Review review) async {
    try {
      await _firestore.collection('reviews').doc(review.id).set(review.toMap());
      
      // Update item average rating in Firestore
      final reviews = await getItemReviews(review.itemId);
      if (reviews.isNotEmpty) {
        double totalRating = 0;
        for (var r in reviews) {
          totalRating += r.rating;
        }
        final double avgRating = totalRating / reviews.length;
        
        await _firestore.collection('inventory').doc(review.itemId).update({
          'rating': avgRating,
        });
      }
    } catch (e) {
      debugPrint("Add review error: $e");
    }
  }

  Future<List<Review>> getItemReviews(String itemId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('itemId', isEqualTo: itemId)
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => Review.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint("Get reviews error: $e");
    }
    return [];
  }

  Future<void> deleteInventoryItem(String id) async {
    final item = _itemsBox?.get(id);
    if (item != null && item.imagePaths.isNotEmpty) {
      for (String path in item.imagePaths) {
        if (path.startsWith('http')) {
          try {
            await FirebaseStorage.instance.refFromURL(path).delete();
            print("Inventory image deleted from Storage");
          } catch (e) {
            print("Error deleting inventory image: $e");
          }
        }
      }
    }
    
    await _itemsBox?.delete(id);
    notifyListeners();
    _triggerSync();

    if (_auth.currentUser != null) {
      _firestore.collection('users').doc(_auth.currentUser!.uid)
          .collection('inventory_items').doc(id).delete()
          .catchError((e) => print("Error deleting inventory item from Firestore: $e"));
    }
  }

  List<InventoryItem> getInventoryItems() {
    return _itemsBox?.values.toList() ?? [];
  }

  InventoryItem? getInventoryItem(String id) {
    return _itemsBox?.get(id);
  }

  // --- Ad Engagement & Reports ---

  Future<void> addRecentlyViewed(InventoryItem item) async {
    if (_recentlyViewedBox == null) return;
    
    // Remove if already exists to move to top
    await _recentlyViewedBox!.delete(item.id);
    
    // Add to box
    await _recentlyViewedBox!.put(item.id, item);
    
    // Maintain limit (e.g., 15 items)
    if (_recentlyViewedBox!.length > 15) {
      final keys = _recentlyViewedBox!.keys.toList();
      await _recentlyViewedBox!.delete(keys.first);
    }
    notifyListeners();
  }

  List<InventoryItem> getRecentlyViewed() {
    // Return in reverse order (most recent first)
    return _recentlyViewedBox?.values.toList().reversed.toList() ?? [];
  }

  Future<void> reportAd(AdReport report) async {
    try {
      await _firestore.collection('ad_reports').doc(report.id).set(report.toMap());
    } catch (e) {
      debugPrint("Report ad error: $e");
      rethrow;
    }
  }

  Future<void> incrementView(String itemId) async {
    try {
      // Find the document across all users using collectionGroup
      final query = await _firestore.collectionGroup('inventory_items')
          .where('id', isEqualTo: itemId)
          .limit(1)
          .get();
          
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'views': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint("Increment view error: $e");
    }
  }

  Future<void> incrementShare(String itemId) async {
    try {
      final query = await _firestore.collectionGroup('inventory_items')
          .where('id', isEqualTo: itemId)
          .limit(1)
          .get();
          
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'shares': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint("Increment share error: $e");
    }
  }

  // --- Sync Implementation ---

  Future<void> syncWithFirebase() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none) && connectivityResult.length == 1) {
        print("Offline: Skipping sync");
        return;
      }
      if (connectivityResult.isEmpty) return;

      final user = _auth.currentUser;
      if (user == null) return;

      print("Starting background sync...");
      final batch = _firestore.batch();

      if (_accountsBox != null) {
        for (var account in _accountsBox!.values) {
          final docRef = _firestore.collection('users').doc(user.uid).collection('accounts').doc(account.id);
          batch.set(docRef, account.toMap());
        }
      }

      if (_transactionsBox != null) {
        for (var transaction in _transactionsBox!.values) {
          final docRef = _firestore.collection('users').doc(user.uid).collection('transactions').doc(transaction.id);
          batch.set(docRef, transaction.toMap());
        }
      }

      if (_professionsBox != null) {
        for (var profession in _professionsBox!.values) {
          final docRef = _firestore.collection('users').doc(user.uid).collection('professions').doc(profession.id);
          batch.set(docRef, profession.toMap());
        }
      }

      if (_categoriesBox != null) {
        for (var category in _categoriesBox!.values) {
          final docRef = _firestore.collection('users').doc(user.uid).collection('categories').doc(category.id);
          batch.set(docRef, category.toMap());
        }
      }

      if (_itemsBox != null) {
        for (var item in _itemsBox!.values) {
          final docRef = _firestore.collection('users').doc(user.uid).collection('inventory_items').doc(item.id);
          batch.set(docRef, item.toMap());
        }
      }

      await batch.commit();
      print("✅ Sync successful");

    } catch (e) {
      print('❌ Sync error: $e');
    }
  }

  Future<void> fetchFromFirebase() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none) && connectivityResult.length == 1) {
        print("Offline: Skipping fetch");
        return;
      }

      final user = _auth.currentUser;
      if (user == null) return;

      print("🔄 Fetching data from Firebase...");

      if (_accountsBox == null) await init();

      final accountsSnapshot = await _firestore.collection('users').doc(user.uid).collection('accounts').get();
      for (var doc in accountsSnapshot.docs) {
        final account = Account.fromMap(doc.data());
        await _accountsBox?.put(account.id, account);
      }

      final transactionsSnapshot = await _firestore.collection('users').doc(user.uid).collection('transactions').get();
      for (var doc in transactionsSnapshot.docs) {
        final transaction = model.Transaction.fromMap(doc.data());
        await _transactionsBox?.put(transaction.id, transaction);
      }

      final professionsSnapshot = await _firestore.collection('users').doc(user.uid).collection('professions').get();
      for (var doc in professionsSnapshot.docs) {
        final profession = Profession.fromMap(doc.data());
        await _professionsBox?.put(profession.id, profession);
      }

      final categoriesSnapshot = await _firestore.collection('users').doc(user.uid).collection('categories').get();
      for (var doc in categoriesSnapshot.docs) {
        final category = Category.fromMap(doc.data());
        await _categoriesBox?.put(category.id, category);
      }

      // Inventory Items 
      final itemsSnapshot = await _firestore.collection('users').doc(user.uid).collection('inventory_items').get();
      for (var doc in itemsSnapshot.docs) {
        final item = InventoryItem.fromMap(doc.data());
        await _itemsBox?.put(item.id, item);
      }

      print("🎉 All data fetched and restored successfully!");
      notifyListeners();
    } catch (e) {
      print('❌ Fetch error: $e');
    }
  }

  // Add this new method to clear all local Hive data
  Future<void> clearLocalData() async {
    if (_accountsBox?.isOpen ?? false) await _accountsBox?.clear();
    if (_transactionsBox?.isOpen ?? false) await _transactionsBox?.clear();
    if (_categoriesBox?.isOpen ?? false) await _categoriesBox?.clear();
    if (_professionsBox?.isOpen ?? false) await _professionsBox?.clear();
    if (_itemsBox?.isOpen ?? false) await _itemsBox?.clear();
    if (_recentlyViewedBox?.isOpen ?? false) await _recentlyViewedBox?.clear();
    if (_remoteCachedItemsBox?.isOpen ?? false) await _remoteCachedItemsBox?.clear();
    
    notifyListeners();
    print("🧹 Local data cleared.");
  }

  // New method to handle logout safely
  Future<void> prepareForLogout() async {
    print("Preparing for logout...");
    _stopRealtimeSync(); // Stop Firestore listeners first
    await _connectivitySubscription?.cancel();
    await clearLocalData(); // Clear Hive boxes while they are still open
    // We don't close boxes here to avoid HiveError if some widget still references the service
  }

  // --- Cleanup Operations ---
  Future<void> cleanUnknownTransactions() async {
    if (!_isInitialized) await init();

    final transactions = getAllTransactions();
    int deletedCount = 0;
    final batch = _firestore.batch();
    final user = _auth.currentUser;

    for (var transaction in transactions) {
      final account = getAccount(transaction.accountId);
      final profession = transaction.professionId != null ? getProfession(transaction.professionId!) : null;

      bool isOrphaned = false;

      if (account == null) {
        isOrphaned = true;
      }

      if (transaction.professionId != null && profession == null) {
        isOrphaned = true;
      }

      if (isOrphaned) {
        await _transactionsBox?.delete(transaction.id);
        if (user != null) {
          final ref = _firestore.collection('users').doc(user.uid)
              .collection('transactions').doc(transaction.id);
          batch.delete(ref);
        }
        deletedCount++;
      }
    }

    if (user != null && deletedCount > 0) {
      await batch.commit().catchError((e) => print("Batch delete error: $e"));
    }

    notifyListeners();
    print("🧹 Cleaned $deletedCount unknown transactions.");
  }

  Future<void> close() async {
    await _connectivitySubscription?.cancel();
    _stopRealtimeSync();
    await _accountsBox?.close();
    await _transactionsBox?.close();
    await _categoriesBox?.close();
    await _professionsBox?.close();
    await _itemsBox?.close();
    await _recentlyViewedBox?.close();
    await _remoteCachedItemsBox?.close();
    await _settingsBox?.close();
    _isInitialized = false;
  }
}