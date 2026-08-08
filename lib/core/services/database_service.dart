import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/models/review_model.dart';
import 'package:account_app/core/models/ad_report_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';

import 'database/account_service.dart';
import 'database/transaction_service.dart';
import 'database/profession_service.dart';
import 'database/inventory_service.dart';
import 'database/sync_service.dart';
import 'database/category_service.dart';
import 'database/settings_service.dart';
import 'database/profile_service.dart';
import 'artisan_service.dart';
import 'artisan_work_order_service.dart';

class DatabaseService extends ChangeNotifier {
  final AccountService _accountService = AccountService();
  final TransactionService _transactionService = TransactionService();
  final ProfessionService _professionService = ProfessionService();
  final InventoryService _inventoryService = InventoryService();
  final SyncService _syncService = SyncService();
  final CategoryService _categoryService = CategoryService();
  final SettingsService _settingsService = SettingsService();
  final ProfileService _profileService = ProfileService();
  final ArtisanService _artisanService = ArtisanService();
  final ArtisanWorkOrderService _artisanWorkOrderService = ArtisanWorkOrderService();

  // پراپرٹیز
  bool get isInitialized => true; 
  List<Account> get accounts => _accountService.getAccounts();
  List<model.Transaction> get transactions => _transactionService.getAllTransactions();

  // Helper for Auto-Sync (Mimicking original _triggerSync)
  void _triggerSync() {
    _syncService.syncWithFirebase().catchError((e) => debugPrint("Auto-sync error: $e"));
  }

  // ACCOUNT OPERATIONS
  Future<void> addAccount(Account a) async { await _accountService.addAccount(a); notifyListeners(); _triggerSync(); }
  Future<void> updateAccount(Account a) async { await _accountService.updateAccount(a); notifyListeners(); _triggerSync(); }
  Future<void> deleteAccount(String id) async { await _accountService.deleteAccount(id); notifyListeners(); _triggerSync(); }
  List<Account> getAccounts() => _accountService.getAccounts();
  Account? getAccount(String id) => _accountService.getAccount(id);
  Future<void> recalculateAccountBalance(String id) async { await _accountService.recalculateAccountBalance(id); notifyListeners(); }
  Future<void> addSharedWith(String id, String phone) async { await _accountService.addSharedWith(id, phone); notifyListeners(); _triggerSync(); }
  Future<int> getPartiesCount() => _accountService.getPartiesCount();
  Future<int> getPendingDuesCount() => _accountService.getPendingDuesCount();
  Future<void> updateMyVerificationStatus(bool v) async { await _accountService.updateMyVerificationStatus(v); notifyListeners(); }

  // TRANSACTION OPERATIONS
  Future<void> addTransaction(model.Transaction t) async { await _transactionService.addTransaction(t); notifyListeners(); _triggerSync(); }
  Future<void> updateTransaction(model.Transaction t) async { await _transactionService.updateTransaction(t); notifyListeners(); _triggerSync(); }
  Future<void> deleteTransaction(String id) async { await _transactionService.deleteTransaction(id); notifyListeners(); _triggerSync(); }
  List<model.Transaction> getTransactions(String aId) => _transactionService.getTransactions(aId);
  List<model.Transaction> getAllTransactions() => _transactionService.getAllTransactions();
  model.Transaction? getTransaction(String id) => _transactionService.getTransaction(id);

  // PROFESSION OPERATIONS
  Future<void> addProfession(Profession p) async { await _professionService.addProfession(p); notifyListeners(); _triggerSync(); }
  Future<void> updateProfession(Profession p) async { await _professionService.updateProfession(p); notifyListeners(); _triggerSync(); }
  Future<void> deleteProfession(String id) async { await _professionService.deleteProfession(id); notifyListeners(); _triggerSync(); }
  List<Profession> getProfessions() => _professionService.getProfessions();
  Profession? getProfession(String id) => _professionService.getProfession(id);
  Future<void> recalculateProfessionFinance(String id) async { await _professionService.recalculateProfessionFinance(id); notifyListeners(); _triggerSync(); }
  List<model.Transaction> getProfessionTransactions(String pId) => _professionService.getProfessionTransactions(pId);
  Future<double> calculateCostPerUnit(String pId) => _professionService.calculateCostPerUnit(pId);
  Future<Map<String, bool>> checkBudgetAlerts(String pId) => _professionService.checkBudgetAlerts(pId);
  Future<Map<String, dynamic>> getSeasonComparison(String name) => _professionService.getSeasonComparison(name);
  Future<List<String>> generateRecommendations(String pId) => _professionService.generateRecommendations(pId);
  Future<Profession> createProfessionWithDefaults({required String name, required String season, String? description, double totalProduction = 0.0, String productionUnit = 'kg', double targetProduction = 0.0, Map<String, double>? budgetLimits, double benchmarkCostPerUnit = 0.0, ProfessionCategory categoryType = ProfessionCategory.general}) => _professionService.createProfessionWithDefaults(name: name, season: season, description: description, totalProduction: totalProduction, productionUnit: productionUnit, targetProduction: targetProduction, budgetLimits: budgetLimits, benchmarkCostPerUnit: benchmarkCostPerUnit, categoryType: categoryType);
  Future<int> getProfessionsCount() => _professionService.getProfessionsCount();

  // INVENTORY OPERATIONS
  Future<void> addInventoryItem(InventoryItem i) async { await _inventoryService.addInventoryItem(i); notifyListeners(); _triggerSync(); }
  Future<void> updateInventoryItem(InventoryItem i) async { await _inventoryService.updateInventoryItem(i); notifyListeners(); _triggerSync(); }
  Future<void> deleteInventoryItem(String id) async { await _inventoryService.deleteInventoryItem(id); notifyListeners(); _triggerSync(); }
  List<InventoryItem> getInventoryItems() => _inventoryService.getInventoryItems();
  InventoryItem? getInventoryItem(String id) => _inventoryService.getInventoryItem(id);
  Future<List<InventoryItem>> getRemoteInventoryItems(String uid, {int limit = 50}) => _inventoryService.getRemoteInventoryItems(uid, limit: limit);
  Future<List<InventoryItem>> searchGlobalInventory(String query, {int limit = 15}) => _inventoryService.searchGlobalInventory(query, limit: limit);
  Future<Map<String, dynamic>> getGlobalMarketplaceItemsPaginated({int limit = 20, DocumentSnapshot? lastDocument}) => _inventoryService.getGlobalMarketplaceItemsPaginated(limit: limit, lastDocument: lastDocument);
  Future<List<InventoryItem>> searchGlobalMarketplaceItems({required String searchQuery, int limit = 50}) => _inventoryService.searchGlobalMarketplaceItems(searchQuery: searchQuery, limit: limit);
  Future<void> toggleFirestoreFavorite(String id, bool fav) => _inventoryService.toggleFirestoreFavorite(id, fav);
  Future<void> addReview(Review r) => _inventoryService.addReview(r);
  Future<List<Review>> getItemReviews(String id) => _inventoryService.getItemReviews(id);
  Future<void> reportAd(AdReport r) => _inventoryService.reportAd(r);
  Future<void> logContactEvent({required String itemId, required String action, String? targetPhone}) => _inventoryService.logContactEvent(itemId: itemId, action: action, targetPhone: targetPhone);
  Future<void> incrementView(String id) => _inventoryService.incrementView(id);
  Future<void> incrementShare(String id) => _inventoryService.incrementShare(id);
  Future<void> addRecentlyViewed(InventoryItem i) async { await _inventoryService.addRecentlyViewed(i); notifyListeners(); }
  List<InventoryItem> getRecentlyViewed() => _inventoryService.getRecentlyViewed();
  Future<void> cleanupExpiredAds() async { await _inventoryService.cleanupExpiredAds(); notifyListeners(); }
  Future<bool> isSellerVerified(String uid) => _inventoryService.isSellerVerified(uid);
  Future<void> saveRemoteCachedItems(String uid, List<InventoryItem> items) => _inventoryService.saveRemoteCachedItems(uid, items);
  List<InventoryItem> getRemoteCachedItems(String uid) => _inventoryService.getRemoteCachedItems(uid);

  // CATEGORY OPERATIONS
  Future<void> addCategory(Category cat) async { await _categoryService.addCategory(cat); notifyListeners(); _triggerSync(); }
  Future<void> updateCategory(Category cat) async { await _categoryService.updateCategory(cat); notifyListeners(); _triggerSync(); }
  Future<void> deleteCategory(String id) async { await _categoryService.deleteCategory(id); notifyListeners(); _triggerSync(); }
  List<Category> getCategories() => _categoryService.getCategories();

  // GLOBAL LOOKUP & STATUS
  Future<void> markUserAsDeactivated(String uid) async { await _profileService.markUserAsDeactivated(uid); }
  Future<void> markUserAsActivated(String uid) async { await _profileService.markUserAsActivated(uid); }
  Future<Map<String, String>?> findPublicProfileByPhone(String p) => _profileService.findPublicProfileByPhone(p);
  Future<Map<String, String>?> findPublicProfileByUid(String uid) => _profileService.findPublicProfileByUid(uid);

  // ARTISAN OPERATIONS
  Future<void> saveArtisanProfile(ArtisanProfile p) async { await _artisanService.saveProfile(p); notifyListeners(); }
  Future<ArtisanProfile?> getArtisanProfile(String id) => _artisanService.getProfile(id);
  Stream<ArtisanProfile?> streamArtisanProfile(String id) => _artisanService.streamProfile(id);
  Future<List<ArtisanProfile>> getAllArtisans() => _artisanService.getAllArtisans();
  Stream<List<ArtisanProfile>> streamAllArtisans() => _artisanService.streamAllArtisans();
  Future<void> addArtisanReview({required String artisanId, required String workOrderId, required double rating, required String comment}) async { await _artisanService.addReview(artisanId: artisanId, workOrderId: workOrderId, rating: rating, comment: comment); notifyListeners(); }
  Stream<List<ArtisanReview>> getArtisanReviews(String artisanId) => _artisanService.getReviews(artisanId);

  // ARTISAN WORK ORDER OPERATIONS
  Future<void> addArtisanWorkOrder(ArtisanWorkOrder o) async { await _artisanWorkOrderService.addWorkOrder(o); notifyListeners(); }
  Stream<List<ArtisanWorkOrder>> getArtisanWorkOrders(String id) => _artisanWorkOrderService.getArtisanWorkOrders(id);
  Future<List<ArtisanWorkOrder>> getCustomerWorkOrders(String id) => _artisanWorkOrderService.getCustomerWorkOrders(id);
  Future<void> updateArtisanWorkStatus(String aId, String oId, String s) async { await _artisanWorkOrderService.updateStatus(aId, oId, s); notifyListeners(); }

  // SYNC OPERATIONS
  void startRealtimeSync() => _syncService.startRealtimeSync();
  void stopRealtimeSync() => _syncService.stopRealtimeSync();
  Future<void> syncWithFirebase() => _syncService.syncWithFirebase();
  Future<void> fetchFromFirebase() async { await _syncService.fetchFromFirebase(); notifyListeners(); }
  Future<void> clearLocalData() async { await _syncService.clearAllBoxes(); notifyListeners(); }
  Future<void> prepareForLogout() async { await _syncService.prepareForLogout(); notifyListeners(); }
  Future<void> close() => _syncService.closeBoxes();

  Future<void> cleanUnknownTransactions() async {
    await _transactionService.cleanUnknownTransactions(
      accountIds: getAccounts().map((a) => a.id).toSet(),
      professionIds: getProfessions().map((p) => p.id).toSet(),
    );
    notifyListeners();
  }

  // SETTINGS
  Future<void> saveSetting(String k, dynamic v) async { await _settingsService.saveSetting(k, v); notifyListeners(); }
  dynamic getSetting(String k, {dynamic defaultValue}) => _settingsService.getSetting(k, defaultValue: defaultValue);

  // INITIALIZATION
  Future<void> init() async {
    await _syncService.openBoxes();
    _syncService.setupConnectivityListener();
    if (FirebaseAuth.instance.currentUser != null) {
      _syncService.startRealtimeSync();
      _triggerSync();
    }
  }
}