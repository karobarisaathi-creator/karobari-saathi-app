import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_review_model.dart';

import 'database/account_service.dart';
import 'database/transaction_service.dart';
import 'database/profession_service.dart';
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
  Future<int> getPartiesCount() => _accountService.getPartiesCount();
  Future<int> getPendingDuesCount() => _accountService.getPendingDuesCount();
  Future<void> updateMyVerificationStatus(bool v) async { await _accountService.updateMyVerificationStatus(v); notifyListeners(); }
  Future<bool> isUserVerified(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists && doc.data()?['isVerified'] == true;
  }

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