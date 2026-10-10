import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/services/stock_service.dart';

import 'database/account_service.dart';
import 'database/transaction_service.dart';
import 'database/profession_service.dart';
import 'database/sync_service.dart';
import 'database/category_service.dart';
import 'database/settings_service.dart';
import 'database/profile_service.dart';

class DatabaseService extends ChangeNotifier {
  final AccountService _accountService = AccountService();
  final TransactionService _transactionService = TransactionService();
  final ProfessionService _professionService = ProfessionService();
  final SyncService _syncService = SyncService();
  final CategoryService _categoryService = CategoryService();
  final SettingsService _settingsService = SettingsService();
  final ProfileService _profileService = ProfileService();

  DatabaseService() {
    _syncService.addListener(_handleSyncUpdate);
  }

  void _handleSyncUpdate() {
    notifyListeners();
  }

  @override
  void dispose() {
    _syncService.removeListener(_handleSyncUpdate);
    _syncService.stopRealtimeSync();
    _syncService.stopConnectivityListener();
    super.dispose();
  }

  // پراپرٹیز
  bool _isInitialized = false;
  Future<void>? _initialization;
  bool get isInitialized => _isInitialized;
  List<Account> get accounts => _accountService.getAccounts();
  List<model.Transaction> get transactions =>
      _transactionService.getAllTransactions();

  // Helper for Auto-Sync (Mimicking original _triggerSync)
  void _triggerSync() {
    _syncService
        .syncWithFirebase()
        .catchError((e) => debugPrint("Auto-sync error: $e"));
  }

  // ACCOUNT OPERATIONS
  Future<void> addAccount(Account a) async {
    await _accountService.addAccount(a);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateAccount(Account a) async {
    await _accountService.updateAccount(a);
    notifyListeners();
    _triggerSync();
  }

  Future<void> deleteAccount(String id) async {
    await _accountService.deleteAccount(id);
    notifyListeners();
    _triggerSync();
  }

  List<Account> getAccounts() => _accountService.getAccounts();
  Account? getAccount(String id) => _accountService.getAccount(id);
  Future<void> recalculateAccountBalance(String id) async {
    await _accountService.recalculateAccountBalance(id);
    notifyListeners();
  }

  Future<int> getPartiesCount() => _accountService.getPartiesCount();
  Future<int> getPendingDuesCount() => _accountService.getPendingDuesCount();
  // TRANSACTION OPERATIONS
  Future<void> addTransaction(model.Transaction t) async {
    await _transactionService.addTransaction(t);
    await _syncTransactionStock(t);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateTransaction(model.Transaction t) async {
    await _transactionService.updateTransaction(t);
    await _syncTransactionStock(t);
    notifyListeners();
    _triggerSync();
  }

  Future<void> deleteTransaction(String id) async {
    final transaction = _transactionService.getTransaction(id);
    await _transactionService.deleteTransaction(id);
    if (transaction != null) {
      await _syncTransactionStock(transaction, deleteTransaction: true);
    }
    notifyListeners();
    _triggerSync();
  }

  List<model.Transaction> getTransactions(String aId) =>
      _transactionService.getTransactions(aId);
  List<model.Transaction> getAllTransactions() =>
      _transactionService.getAllTransactions();
  model.Transaction? getTransaction(String id) =>
      _transactionService.getTransaction(id);

  // PROFESSION OPERATIONS
  Future<void> addProfession(Profession p) async {
    await _professionService.addProfession(p);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateProfession(Profession p) async {
    await _professionService.updateProfession(p);
    notifyListeners();
    _triggerSync();
  }

  Future<void> deleteProfession(String id) async {
    await _professionService.deleteProfession(id);
    notifyListeners();
    _triggerSync();
  }

  List<Profession> getProfessions() => _professionService.getProfessions();
  List<Profession> getMasterProfessions() =>
      _professionService.getMasterProfessions();
  List<Profession> getSeasons(String parentId) =>
      _professionService.getSeasons(parentId);
  Profession? getProfession(String id) => _professionService.getProfession(id);
  Future<void> recalculateProfessionFinance(String id) async {
    await _professionService.recalculateProfessionFinance(id);
    notifyListeners();
    _triggerSync();
  }

  List<model.Transaction> getProfessionTransactions(String pId) =>
      _professionService.getProfessionTransactions(pId);
  Future<double> calculateCostPerUnit(String pId) =>
      _professionService.calculateCostPerUnit(pId);
  Future<Map<String, bool>> checkBudgetAlerts(String pId) =>
      _professionService.checkBudgetAlerts(pId);
  Future<Map<String, dynamic>> getSeasonComparison(
          String name, String parentId) =>
      _professionService.getSeasonComparison(name, parentId: parentId);
  Future<List<String>> generateRecommendations(String pId) =>
      _professionService.generateRecommendations(pId);
  Future<Profession> createProfessionWithDefaults(
          {required String name,
          required String season,
          String? description,
          double totalProduction = 0.0,
          String productionUnit = 'kg',
          double targetProduction = 0.0,
          Map<String, double>? budgetLimits,
          double benchmarkCostPerUnit = 0.0,
          ProfessionCategory categoryType = ProfessionCategory.general}) =>
      _professionService.createProfessionWithDefaults(
          name: name,
          season: season,
          description: description,
          totalProduction: totalProduction,
          productionUnit: productionUnit,
          targetProduction: targetProduction,
          budgetLimits: budgetLimits,
          benchmarkCostPerUnit: benchmarkCostPerUnit,
          categoryType: categoryType);
  Future<int> getProfessionsCount() => _professionService.getProfessionsCount();

  // CATEGORY OPERATIONS
  Future<void> addCategory(Category cat) async {
    await _categoryService.addCategory(cat);
    notifyListeners();
    _triggerSync();
  }

  Future<void> updateCategory(Category cat) async {
    await _categoryService.updateCategory(cat);
    notifyListeners();
    _triggerSync();
  }

  Future<void> deleteCategory(String id) async {
    await _categoryService.deleteCategory(id);
    notifyListeners();
    _triggerSync();
  }

  List<Category> getCategories() => _categoryService.getCategories();

  // GLOBAL LOOKUP & STATUS
  Future<Map<String, String>?> findPublicProfileByPhone(String p) =>
      _profileService.findPublicProfileByPhone(p);
  Future<Map<String, String>?> findPublicProfileByUid(String uid) =>
      _profileService.findPublicProfileByUid(uid);

  // SYNC OPERATIONS
  void startRealtimeSync() => _syncService.startRealtimeSync();
  void stopRealtimeSync() => _syncService.stopRealtimeSync();
  Future<void> syncWithFirebase() => _syncService.syncWithFirebase();
  Future<void> fetchFromFirebase() async {
    await _syncService.fetchFromFirebase();
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    await _syncService.clearAllBoxes();
    notifyListeners();
  }

  Future<void> prepareForLogout() async {
    await _syncService.prepareForLogout();
    _isInitialized = false;
    notifyListeners();
  }

  Future<void> close() => _syncService.closeBoxes();

  Future<void> _syncTransactionStock(
    model.Transaction transaction, {
    bool deleteTransaction = false,
  }) async {
    try {
      await StockService.syncTransactionMovements(
        transaction,
        deleteTransaction: deleteTransaction,
      );
    } catch (error) {
      debugPrint('Transaction stock sync failed: $error');
    }
  }

  Future<void> cleanUnknownTransactions() async {
    await _transactionService.cleanUnknownTransactions(
      accountIds: getAccounts().map((a) => a.id).toSet(),
      professionIds: getProfessions().map((p) => p.id).toSet(),
    );
    notifyListeners();
  }

  // SETTINGS
  Future<void> saveSetting(String k, dynamic v) async {
    await _settingsService.saveSetting(k, v);
    notifyListeners();
  }

  dynamic getSetting(String k, {dynamic defaultValue}) =>
      _settingsService.getSetting(k, defaultValue: defaultValue);

  // INITIALIZATION
  Future<void> init() async {
    if (_isInitialized) return;
    final existingInitialization = _initialization;
    if (existingInitialization != null) return existingInitialization;

    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initialize() async {
    await _syncService.openBoxes();
    _syncService.setupConnectivityListener();
    if (FirebaseAuth.instance.currentUser != null) {
      _syncService.startRealtimeSync();
    }
    _isInitialized = true;
  }
}
