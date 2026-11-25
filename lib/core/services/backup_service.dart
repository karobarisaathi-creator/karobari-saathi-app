import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/worker_service.dart';
import 'package:account_app/features/marketplace/models/marketplace_listing.dart';

class BackupService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _autoBackupInProgress = false;

  static const String _accountsSnapshotsCollection = 'accountsSnapshots';
  static const String _transactionsSnapshotsCollection = 'transactionsSnapshots';
  static const String _accountsCollection = 'accounts';
  static const String _transactionsCollection = 'transactions';
  static const String _stockSnapshotsCollection = 'stockSnapshots';
  static const String _stockItemsCollection = 'stock_items';
  static const String _stockMovementsCollection = 'stock_movements';
  static const String _contractSnapshotsCollection = 'contractSnapshots';
  static const String _contractsCollection = 'contracts';
  static const String _marketplaceSnapshotsCollection = 'marketplaceSnapshots';
  static const String _marketplaceListingsCollection = 'listings';
  static const String _workerPayrollSnapshotsCollection =
      'workerPayrollSnapshots';
  static const String _workerPayrollRecordsCollection = 'records';
  static const String _workerPayrollBoxName = 'worker_payroll_box_v1';
  static const String _workersBoxName = 'workers_box_v1';
  static const int _firestoreBatchLimit = 400;

  // Helper to get user profile email
  Future<String?> _getUserEmail() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final email = userDoc.data()?['email']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    } catch (_) {}
    if (user.email != null && user.email!.trim().isNotEmpty) {
      return user.email!.trim();
    }
    return null;
  }

  // Create complete backup
  Future<void> createBackup({bool isUrdu = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(isUrdu ? 'صارف لاگ ان نہیں ہے' : 'User not logged in');
    }

    // Check if email is added in profile
    final profileEmail = await _getUserEmail();
    if (profileEmail == null || profileEmail.isEmpty) {
      throw Exception(
        isUrdu
            ? 'براہ کرم پہلے پروفائل میں ای میل درج کریں تاکہ بیک اپ جڑ سکے'
            : 'Please add an email in your profile before creating a backup',
      );
    }

    // Get locally stored data and the Firestore-backed stock records.
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');
    final settingsBox = await Hive.openBox('settings');
    final contractsBox = await Hive.openBox(ContractService.boxName);
    final workerPayrollBox = await Hive.openBox(_workerPayrollBoxName);
    final workersBox = await Hive.openBox(_workersBoxName);

    final accountsRecords = accountsBox.values.map((a) => a.toMap()).toList();
    final transactionsRecords =
        transactionsBox.values.map((t) => t.toMap()).toList();
    final contractRecords = contractsBox.values
        .whereType<Map>()
        .map((record) => _normalizeMap(record))
        .toList();
    _validateContractDocumentOwners(contractRecords, user.uid);
    final workerPayrollRecords = workerPayrollBox.values
        .whereType<Map>()
        .map((record) => _normalizeMap(record))
        .toList();
    final workersRecords = workersBox.values
        .whereType<Map>()
        .map((record) => _normalizeMap(record))
        .toList();
    final marketplaceRecords = await _loadMarketplaceRecords(user.uid);
    final stockRecords = await _loadStockRecords(user.uid);

    final backupRef = _firestore.collection('backups').doc(user.uid);
    final previousBackup = await backupRef.get();

    final previousAccountsSnapshotId =
        previousBackup.data()?['accountsBackupId']?.toString();
    final previousTransactionsSnapshotId =
        previousBackup.data()?['transactionsBackupId']?.toString();
    final previousSnapshotId =
        previousBackup.data()?['stockBackupId']?.toString();
    final previousContractSnapshotId =
        previousBackup.data()?['contractBackupId']?.toString();
    final previousMarketplaceSnapshotId =
        previousBackup.data()?['marketplaceBackupId']?.toString();
    final previousWorkerPayrollSnapshotId =
        previousBackup.data()?['workerPayrollBackupId']?.toString();

    final accountsSnapshotId =
        backupRef.collection(_accountsSnapshotsCollection).doc().id;
    final accountsSnapshotRef =
        backupRef.collection(_accountsSnapshotsCollection).doc(accountsSnapshotId);

    final transactionsSnapshotId =
        backupRef.collection(_transactionsSnapshotsCollection).doc().id;
    final transactionsSnapshotRef = backupRef
        .collection(_transactionsSnapshotsCollection)
        .doc(transactionsSnapshotId);

    final snapshotId =
        backupRef.collection(_stockSnapshotsCollection).doc().id;
    final snapshotRef =
        backupRef.collection(_stockSnapshotsCollection).doc(snapshotId);

    final contractSnapshotId =
        backupRef.collection(_contractSnapshotsCollection).doc().id;
    final contractSnapshotRef = backupRef
        .collection(_contractSnapshotsCollection)
        .doc(contractSnapshotId);

    final marketplaceSnapshotId =
        backupRef.collection(_marketplaceSnapshotsCollection).doc().id;
    final marketplaceSnapshotRef = backupRef
        .collection(_marketplaceSnapshotsCollection)
        .doc(marketplaceSnapshotId);

    final workerPayrollSnapshotId =
        backupRef.collection(_workerPayrollSnapshotsCollection).doc().id;
    final workerPayrollSnapshotRef = backupRef
        .collection(_workerPayrollSnapshotsCollection)
        .doc(workerPayrollSnapshotId);

    var snapshotContractRecords = <Map<String, dynamic>>[];
    var snapshotMarketplaceRecords = <Map<String, dynamic>>[];

    try {
      // 1. Write Accounts Subcollection Snapshot
      await accountsSnapshotRef.set({
        'createdAt': DateTime.now(),
        'accountCount': accountsRecords.length,
      });
      await _writeDocuments(
        accountsSnapshotRef.collection(_accountsCollection),
        accountsRecords,
      );

      // 2. Write Transactions Subcollection Snapshot
      await transactionsSnapshotRef.set({
        'createdAt': DateTime.now(),
        'transactionCount': transactionsRecords.length,
      });
      await _writeDocuments(
        transactionsSnapshotRef.collection(_transactionsCollection),
        transactionsRecords,
      );

      // 3. Write Stock Subcollection Snapshot
      await snapshotRef.set({
        'createdAt': DateTime.now(),
        'stockItemCount': stockRecords[_stockItemsCollection]!.length,
        'stockMovementCount': stockRecords[_stockMovementsCollection]!.length,
      });
      await _writeDocuments(
        snapshotRef.collection(_stockItemsCollection),
        stockRecords[_stockItemsCollection]!,
      );
      await _writeDocuments(
        snapshotRef.collection(_stockMovementsCollection),
        stockRecords[_stockMovementsCollection]!,
      );

      // 4. Write Contracts Subcollection Snapshot
      await contractSnapshotRef.set({
        'createdAt': DateTime.now(),
        'contractCount': contractRecords.length,
      });
      snapshotContractRecords = await _prepareContractSnapshotRecords(
        contractRecords,
        user.uid,
        contractSnapshotId,
      );
      await _writeDocuments(
        contractSnapshotRef.collection(_contractsCollection),
        snapshotContractRecords,
      );

      // 5. Write Worker Payroll Subcollection Snapshot
      await workerPayrollSnapshotRef.set({
        'createdAt': DateTime.now(),
        'recordCount': workerPayrollRecords.length,
      });
      await _writeDocuments(
        workerPayrollSnapshotRef.collection(_workerPayrollRecordsCollection),
        workerPayrollRecords,
      );

      // 6. Write Marketplace Subcollection Snapshot
      await marketplaceSnapshotRef.set({
        'createdAt': DateTime.now(),
        'listingCount': marketplaceRecords.length,
      });
      snapshotMarketplaceRecords = await _prepareMarketplaceSnapshotRecords(
        marketplaceRecords,
        user.uid,
        marketplaceSnapshotId,
      );
      await _writeDocuments(
        marketplaceSnapshotRef.collection(_marketplaceListingsCollection),
        snapshotMarketplaceRecords,
      );

      // 7. Write Main Backup Document Metadata
      final backupData = {
        'schemaVersion': 2,
        'categories': categoriesBox.values.map((c) => c.toMap()).toList(),
        'professions': professionsBox.values.map((p) => p.toMap()).toList(),
        'settings': settingsBox.toMap(),
        'workers': workersRecords,
        'email': profileEmail,
        'backupDate': DateTime.now(),
        'appVersion': '1.0.0',
        'accountsBackupId': accountsSnapshotId,
        'totalAccounts': accountsRecords.length,
        'transactionsBackupId': transactionsSnapshotId,
        'totalTransactions': transactionsRecords.length,
        'stockBackupId': snapshotId,
        'totalStockItems': stockRecords[_stockItemsCollection]!.length,
        'totalStockMovements': stockRecords[_stockMovementsCollection]!.length,
        'contractBackupId': contractSnapshotId,
        'totalContracts': contractRecords.length,
        'workerPayrollBackupId': workerPayrollSnapshotId,
        'totalWorkerPayrollRecords': workerPayrollRecords.length,
        'marketplaceBackupId': marketplaceSnapshotId,
        'totalMarketplaceListings': marketplaceRecords.length,
      };

      await backupRef.set(backupData, SetOptions(merge: true));
    } catch (error) {
      // Atomic Cleanup on failure: delete any newly created snapshots
      try {
        await _deleteSimpleSnapshot(
          accountsSnapshotRef,
          _accountsCollection,
        );
        await _deleteSimpleSnapshot(
          transactionsSnapshotRef,
          _transactionsCollection,
        );
        await _deleteStockSnapshot(snapshotRef);
        await _deleteContractSnapshot(
          contractSnapshotRef,
          additionalStoragePaths:
              _contractBackupPaths(snapshotContractRecords),
        );
        await _deleteWorkerPayrollSnapshot(workerPayrollSnapshotRef);
        await _deleteMarketplaceSnapshot(
          marketplaceSnapshotRef,
          additionalStoragePaths:
              _marketplaceBackupPaths(snapshotMarketplaceRecords),
        );
      } catch (cleanupError) {
        debugPrint(
          'BackupService: Could not remove incomplete backup snapshots: '
          '$cleanupError',
        );
      }
      rethrow;
    }

    // Purge old backup snapshots if available
    if (previousAccountsSnapshotId != null &&
        previousAccountsSnapshotId.isNotEmpty &&
        previousAccountsSnapshotId != accountsSnapshotId) {
      try {
        await _deleteSimpleSnapshot(
          backupRef
              .collection(_accountsSnapshotsCollection)
              .doc(previousAccountsSnapshotId),
          _accountsCollection,
        );
      } catch (e) {
        debugPrint('BackupService: Could not remove old accounts snapshot: $e');
      }
    }
    if (previousTransactionsSnapshotId != null &&
        previousTransactionsSnapshotId.isNotEmpty &&
        previousTransactionsSnapshotId != transactionsSnapshotId) {
      try {
        await _deleteSimpleSnapshot(
          backupRef
              .collection(_transactionsSnapshotsCollection)
              .doc(previousTransactionsSnapshotId),
          _transactionsCollection,
        );
      } catch (e) {
        debugPrint('BackupService: Could not remove old transactions snapshot: $e');
      }
    }
    if (previousSnapshotId != null &&
        previousSnapshotId.isNotEmpty &&
        previousSnapshotId != snapshotId) {
      try {
        await _deleteStockSnapshot(
          backupRef
              .collection(_stockSnapshotsCollection)
              .doc(previousSnapshotId),
        );
      } catch (e) {
        debugPrint('BackupService: Could not remove old stock snapshot: $e');
      }
    }
    if (previousContractSnapshotId != null &&
        previousContractSnapshotId.isNotEmpty &&
        previousContractSnapshotId != contractSnapshotId) {
      try {
        await _deleteContractSnapshot(
          backupRef
              .collection(_contractSnapshotsCollection)
              .doc(previousContractSnapshotId),
        );
      } catch (error) {
        debugPrint(
            'BackupService: Could not remove old contract snapshot: $error');
      }
    }
    if (previousMarketplaceSnapshotId != null &&
        previousMarketplaceSnapshotId.isNotEmpty &&
        previousMarketplaceSnapshotId != marketplaceSnapshotId) {
      try {
        await _deleteMarketplaceSnapshot(
          backupRef
              .collection(_marketplaceSnapshotsCollection)
              .doc(previousMarketplaceSnapshotId),
        );
      } catch (error) {
        debugPrint(
          'BackupService: Could not remove old marketplace snapshot: $error',
        );
      }
    }
    if (previousWorkerPayrollSnapshotId != null &&
        previousWorkerPayrollSnapshotId.isNotEmpty &&
        previousWorkerPayrollSnapshotId != workerPayrollSnapshotId) {
      try {
        await _deleteWorkerPayrollSnapshot(
          backupRef
              .collection(_workerPayrollSnapshotsCollection)
              .doc(previousWorkerPayrollSnapshotId),
        );
      } catch (error) {
        debugPrint(
          'BackupService: Could not remove old worker payroll snapshot: '
          '$error',
        );
      }
    }

    // Save backup info locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_backup', DateTime.now().toIso8601String());
    notifyListeners();
  }

  // Restore from backup
  Future<void> restoreBackup() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final doc = await _firestore.collection('backups').doc(user.uid).get();

    if (!doc.exists) throw Exception('No backup found');

    final backupData = doc.data()!;

    // 1. Fetch Accounts (from snapshot subcollection or fallback to main doc)
    List<Map<String, dynamic>> accountsData;
    final accountsSnapshotId = backupData['accountsBackupId']?.toString();
    if (accountsSnapshotId != null && accountsSnapshotId.isNotEmpty) {
      final snapshotRef = _firestore
          .collection('backups')
          .doc(user.uid)
          .collection(_accountsSnapshotsCollection)
          .doc(accountsSnapshotId);
      accountsData = await _loadSimpleSnapshot(snapshotRef, _accountsCollection);
    } else {
      accountsData = _readRecordList(backupData['accounts'], 'accounts');
    }

    // 2. Fetch Transactions (from snapshot subcollection or fallback to main doc)
    List<Map<String, dynamic>> transactionsData;
    final transactionsSnapshotId =
        backupData['transactionsBackupId']?.toString();
    if (transactionsSnapshotId != null && transactionsSnapshotId.isNotEmpty) {
      final snapshotRef = _firestore
          .collection('backups')
          .doc(user.uid)
          .collection(_transactionsSnapshotsCollection)
          .doc(transactionsSnapshotId);
      transactionsData =
          await _loadSimpleSnapshot(snapshotRef, _transactionsCollection);
    } else {
      transactionsData =
          _readRecordList(backupData['transactions'], 'transactions');
    }

    final categoriesData =
        _readRecordList(backupData['categories'], 'categories');
    final professionsData =
        _readRecordList(backupData['professions'], 'professions');
    final workersData = backupData.containsKey('workers')
        ? _readRecordList(backupData['workers'], 'workers')
        : <Map<String, dynamic>>[];
    final settings = Map<String, dynamic>.from(
      backupData['settings'] as Map? ?? const {},
    );

    final stockSnapshotId = backupData['stockBackupId']?.toString();
    Map<String, List<Map<String, dynamic>>>? stockRecords;
    final contractSnapshotId = backupData['contractBackupId']?.toString();
    List<Map<String, dynamic>>? contractRecords;
    final marketplaceSnapshotId = backupData['marketplaceBackupId']?.toString();
    List<Map<String, dynamic>>? marketplaceRecords;
    final workerPayrollSnapshotId =
        backupData['workerPayrollBackupId']?.toString();
    List<Map<String, dynamic>>? workerPayrollRecords;

    if (stockSnapshotId != null && stockSnapshotId.isNotEmpty) {
      final snapshotRef = _firestore
          .collection('backups')
          .doc(user.uid)
          .collection(_stockSnapshotsCollection)
          .doc(stockSnapshotId);
      final snapshot = await snapshotRef.get();
      if (!snapshot.exists) {
        throw StateError('The stock data for this backup could not be found.');
      }
      stockRecords = await _loadStockSnapshot(snapshotRef);
    }

    if (contractSnapshotId != null && contractSnapshotId.isNotEmpty) {
      final snapshotRef = _firestore
          .collection('backups')
          .doc(user.uid)
          .collection(_contractSnapshotsCollection)
          .doc(contractSnapshotId);
      final snapshot = await snapshotRef.get();
      if (!snapshot.exists) {
        throw StateError(
            'The contract data for this backup could not be found.');
      }
      contractRecords = await _loadContractSnapshot(snapshotRef);
      _validateContractDocumentOwners(contractRecords, user.uid);
      contractRecords = await _restoreContractSnapshotDocuments(
        contractRecords,
        user.uid,
      );
    }

    if (marketplaceSnapshotId != null && marketplaceSnapshotId.isNotEmpty) {
      final snapshotRef = _firestore
          .collection('backups')
          .doc(user.uid)
          .collection(_marketplaceSnapshotsCollection)
          .doc(marketplaceSnapshotId);
      final snapshot = await snapshotRef.get();
      if (!snapshot.exists) {
        throw StateError(
            'The marketplace data for this backup could not be found.');
      }
      marketplaceRecords = await _loadMarketplaceSnapshot(snapshotRef);
    }

    if (workerPayrollSnapshotId != null && workerPayrollSnapshotId.isNotEmpty) {
      final snapshotRef = _firestore
          .collection('backups')
          .doc(user.uid)
          .collection(_workerPayrollSnapshotsCollection)
          .doc(workerPayrollSnapshotId);
      final snapshot = await snapshotRef.get();
      if (!snapshot.exists) {
        throw StateError(
            'The worker payroll data for this backup could not be found.');
      }
      workerPayrollRecords = await _loadWorkerPayrollSnapshot(snapshotRef);
    }

    // 3. PARSE AND MAP ALL OBJECTS IN MEMORY FIRST BEFORE CLEARING LOCAL DATA!
    final parsedAccounts = accountsData.map(Account.fromMap).toList();
    final parsedTransactions =
        transactionsData.map(model.Transaction.fromMap).toList();
    final parsedCategories = categoriesData.map(Category.fromMap).toList();
    final parsedProfessions = professionsData.map(Profession.fromMap).toList();

    // 4. Safe Clear of Local Hive Storage
    await _clearLocalData();

    // 5. Restore Local Hive Storage
    final accountsBox = await Hive.openBox<Account>('accounts');
    for (var account in parsedAccounts) {
      await accountsBox.put(account.id, account);
    }

    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    for (var transaction in parsedTransactions) {
      await transactionsBox.put(transaction.id, transaction);
    }

    final categoriesBox = await Hive.openBox<Category>('categories');
    for (var category in parsedCategories) {
      await categoriesBox.put(category.id, category);
    }

    final professionsBox = await Hive.openBox<Profession>('professions');
    for (var profession in parsedProfessions) {
      await professionsBox.put(profession.id, profession);
    }

    final settingsBox = await Hive.openBox('settings');
    for (var key in settings.keys) {
      await settingsBox.put(key, settings[key]);
    }

    if (contractRecords != null) {
      await _replaceContractRecords(contractRecords);
    }
    if (workerPayrollRecords != null) {
      await _replaceWorkerPayrollRecords(workerPayrollRecords);
    }
    if (workersData.isNotEmpty) {
      await _replaceWorkersRecords(workersData);
    }

    // 6. Replace Remote Firestore Data Last
    if (stockRecords != null) {
      await _replaceStockRecords(
        user.uid,
        stockRecords[_stockItemsCollection]!,
        stockRecords[_stockMovementsCollection]!,
      );
    }
    if (marketplaceRecords != null) {
      await _replaceMarketplaceRecords(user.uid, marketplaceRecords);
    }

    // Update last restore time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_restore', DateTime.now().toIso8601String());
    notifyListeners();
  }

  // Export data to JSON file
  Future<String> exportToJson() async {
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');
    final contractsBox = await Hive.openBox(ContractService.boxName);
    final workerPayrollBox = await Hive.openBox(_workerPayrollBoxName);
    final workersBox = await Hive.openBox(_workersBoxName);

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to export stock data.');
    }
    final stockRecords = await _loadStockRecords(user.uid);
    final contractRecords = contractsBox.values
        .whereType<Map>()
        .map((record) => _normalizeMap(record))
        .toList();
    _validateContractDocumentOwners(contractRecords, user.uid);
    final workerPayrollRecords = workerPayrollBox.values
        .whereType<Map>()
        .map((record) => _normalizeMap(record))
        .toList();
    final workersRecords = workersBox.values
        .whereType<Map>()
        .map((record) => _normalizeMap(record))
        .toList();
    final marketplaceRecords = await _loadMarketplaceRecords(user.uid);

    final exportData = {
      'schemaVersion': 2,
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'data': {
        'accounts': accountsBox.values.map((a) => a.toMap()).toList(),
        'transactions': transactionsBox.values.map((t) => t.toMap()).toList(),
        'categories': categoriesBox.values.map((c) => c.toMap()).toList(),
        'professions': professionsBox.values.map((p) => p.toMap()).toList(),
        'workers': workersRecords,
        'contracts': contractRecords,
        'workerPayroll': workerPayrollRecords,
        'marketplaceListings': marketplaceRecords,
        'stockItems': stockRecords[_stockItemsCollection],
        'stockMovements': stockRecords[_stockMovementsCollection],
      },
    };

    return json.encode(exportData);
  }

  // Import from JSON file
  Future<void> importFromJson(String jsonData) async {
    final decoded = json.decode(jsonData);
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const FormatException('Invalid backup JSON format.');
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    final accountsData = _readRecordList(data['accounts'], 'accounts');
    final transactionsData =
        _readRecordList(data['transactions'], 'transactions');
    final categoriesData = _readRecordList(data['categories'], 'categories');
    final professionsData = _readRecordList(data['professions'], 'professions');
    final workersData = data.containsKey('workers')
        ? _readRecordList(data['workers'], 'workers')
        : <Map<String, dynamic>>[];
    final contractsData = data.containsKey('contracts')
        ? _readRecordList(data['contracts'], 'contracts')
        : null;
    final workerPayrollData = data.containsKey('workerPayroll')
        ? _readRecordList(data['workerPayroll'], 'workerPayroll')
        : null;
    final marketplaceData = data.containsKey('marketplaceListings')
        ? _readRecordList(data['marketplaceListings'], 'marketplaceListings')
        : null;

    if (contractsData != null) {
      final user = _auth.currentUser;
      final hasDocuments = contractsData.any(
        (contract) =>
            contract['documents'] is List &&
            (contract['documents'] as List).isNotEmpty,
      );
      if (hasDocuments && user == null) {
        throw StateError('Sign in before importing contract documents.');
      }
      if (user != null) {
        _validateContractDocumentOwners(contractsData, user.uid);
      }
    }
    if (marketplaceData != null) {
      final user = _auth.currentUser;
      if (user == null) {
        throw StateError('Sign in before importing marketplace listings.');
      }
      _validateMarketplaceOwners(marketplaceData, user.uid);
    }
    final includesStock =
        data.containsKey('stockItems') || data.containsKey('stockMovements');

    // Parse all memory objects FIRST before wiping local boxes!
    final parsedAccounts = accountsData.map(Account.fromMap).toList();
    final parsedTransactions =
        transactionsData.map(model.Transaction.fromMap).toList();
    final parsedCategories = categoriesData.map(Category.fromMap).toList();
    final parsedProfessions = professionsData.map(Profession.fromMap).toList();

    if (includesStock) {
      final user = _auth.currentUser;
      if (user == null) {
        throw StateError('Sign in to import stock data.');
      }
      await _replaceStockRecords(
        user.uid,
        _readRecordList(data['stockItems'], 'stockItems'),
        _readRecordList(data['stockMovements'], 'stockMovements'),
      );
    }
    if (marketplaceData != null) {
      await _replaceMarketplaceRecords(
        _auth.currentUser!.uid,
        marketplaceData,
      );
    }

    // Clear existing local data
    await _clearLocalData();

    if (contractsData != null) {
      await _replaceContractRecords(contractsData);
    }
    if (workerPayrollData != null) {
      await _replaceWorkerPayrollRecords(workerPayrollData);
    }
    if (workersData.isNotEmpty) {
      await _replaceWorkersRecords(workersData);
    }

    // Import accounts
    final accountsBox = await Hive.openBox<Account>('accounts');
    for (var account in parsedAccounts) {
      await accountsBox.put(account.id, account);
    }

    // Import transactions
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    for (var transaction in parsedTransactions) {
      await transactionsBox.put(transaction.id, transaction);
    }

    // Import categories
    final categoriesBox = await Hive.openBox<Category>('categories');
    for (var category in parsedCategories) {
      await categoriesBox.put(category.id, category);
    }

    // Import professions
    final professionsBox = await Hive.openBox<Profession>('professions');
    for (var profession in parsedProfessions) {
      await professionsBox.put(profession.id, profession);
    }

    // Update last import time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_import', DateTime.now().toIso8601String());
    notifyListeners();
  }

  // Clear all local data
  Future<void> _clearLocalData() async {
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');
    final contractsBox = await Hive.openBox(ContractService.boxName);
    final workerPayrollBox = await Hive.openBox(_workerPayrollBoxName);
    final workersBox = await Hive.openBox(_workersBoxName);

    await accountsBox.clear();
    await transactionsBox.clear();
    await categoriesBox.clear();
    await professionsBox.clear();
    await contractsBox.clear();
    await workerPayrollBox.clear();
    await workersBox.clear();
    notifyListeners();
  }

  // Get backup info
  Future<Map<String, dynamic>> getBackupInfo({
    int stockItemCount = 0,
    int stockMovementCount = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup');
    final lastRestore = prefs.getString('last_restore');

    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    final contractsBox = await Hive.openBox(ContractService.boxName);
    final workerPayrollBox = await Hive.openBox(_workerPayrollBoxName);
    final workersBox = await Hive.openBox(_workersBoxName);

    final user = _auth.currentUser;
    final marketplaceCount =
        user == null ? 0 : (await _loadMarketplaceRecords(user.uid)).length;

    final profileEmail = await _getUserEmail();

    return {
      'lastBackup': lastBackup == null ? null : DateTime.tryParse(lastBackup),
      'lastRestore':
          lastRestore == null ? null : DateTime.tryParse(lastRestore),
      'autoBackupEnabled': prefs.getBool('auto_backup') ?? false,
      'totalAccounts': accountsBox.length,
      'totalTransactions': transactionsBox.length,
      'totalStockItems': stockItemCount,
      'totalContracts': contractsBox.length,
      'totalWorkerPayrollRecords': workerPayrollBox.length,
      'totalWorkers': workersBox.length,
      'totalMarketplaceListings': marketplaceCount,
      'backupSize': await _calculateBackupSize(
        stockItemCount: stockItemCount,
        stockMovementCount: stockMovementCount,
        contractCount: contractsBox.length,
        workerPayrollRecordCount: workerPayrollBox.length,
        workerCount: workersBox.length,
        marketplaceListingCount: marketplaceCount,
      ),
      'email': profileEmail,
    };
  }

  // Calculate approximate backup size
  Future<int> _calculateBackupSize({
    required int stockItemCount,
    required int stockMovementCount,
    required int contractCount,
    required int workerPayrollRecordCount,
    required int workerCount,
    required int marketplaceListingCount,
  }) async {
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');

    return (accountsBox.length * 150) +
        (transactionsBox.length * 300) +
        (categoriesBox.length * 80) +
        (professionsBox.length * 120) +
        (stockItemCount * 500) +
        (stockMovementCount * 250) +
        (contractCount * 800) +
        (workerPayrollRecordCount * 200) +
        (workerCount * 250) +
        (marketplaceListingCount * 1500);
  }

  Future<List<Map<String, dynamic>>> _loadSimpleSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
    String collectionName,
  ) async {
    final snapshot = await snapshotRef.collection(collectionName).get();
    return snapshot.docs
        .map((doc) => _documentData(doc.id, doc.data()))
        .toList();
  }

  Future<void> _deleteSimpleSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
    String collectionName,
  ) async {
    await _deleteCollection(snapshotRef.collection(collectionName));
    await snapshotRef.delete();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadStockRecords(
    String uid,
  ) async {
    final userRef = _firestore.collection('users').doc(uid);
    final results = await Future.wait([
      userRef.collection(_stockItemsCollection).get(),
      userRef.collection(_stockMovementsCollection).get(),
    ]);

    return {
      _stockItemsCollection: results[0]
          .docs
          .map((doc) => _documentData(doc.id, doc.data()))
          .toList(),
      _stockMovementsCollection: results[1]
          .docs
          .map((doc) => _documentData(doc.id, doc.data()))
          .toList(),
    };
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadStockSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
  ) async {
    final results = await Future.wait([
      snapshotRef.collection(_stockItemsCollection).get(),
      snapshotRef.collection(_stockMovementsCollection).get(),
    ]);

    return {
      _stockItemsCollection: results[0]
          .docs
          .map((doc) => _documentData(doc.id, doc.data()))
          .toList(),
      _stockMovementsCollection: results[1]
          .docs
          .map((doc) => _documentData(doc.id, doc.data()))
          .toList(),
    };
  }

  Future<List<Map<String, dynamic>>> _loadContractSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
  ) async {
    final contracts = await snapshotRef.collection(_contractsCollection).get();
    return contracts.docs
        .map((doc) => _documentData(doc.id, doc.data()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadMarketplaceRecords(
    String uid,
  ) async {
    final snapshot = await _firestore
        .collection('marketplace_listings')
        .where('ownerId', isEqualTo: uid)
        .get();
    return snapshot.docs
        .map((doc) => _documentData(doc.id, doc.data()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadMarketplaceSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
  ) async {
    final listings =
        await snapshotRef.collection(_marketplaceListingsCollection).get();
    return listings.docs
        .map((doc) => _documentData(doc.id, doc.data()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadWorkerPayrollSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
  ) async {
    final records =
        await snapshotRef.collection(_workerPayrollRecordsCollection).get();
    return records.docs
        .map((doc) => _documentData(doc.id, doc.data()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _prepareContractSnapshotRecords(
    List<Map<String, dynamic>> contracts,
    String uid,
    String snapshotId,
  ) async {
    final copiedPaths = <String>[];
    try {
      final result = <Map<String, dynamic>>[];
      for (final contractRecord in contracts) {
        final contract = _normalizeMap(contractRecord);
        final documents = contract['documents'];
        if (documents is List) {
          final backedUpDocuments = <Map<String, dynamic>>[];
          for (var index = 0; index < documents.length; index++) {
            final value = documents[index];
            if (value is! Map) {
              throw const FormatException(
                  'Invalid contract document in backup.');
            }
            final document = _normalizeMap(value);
            final sourcePath = document['storagePath']?.toString() ?? '';
            final contentType = document['contentType']?.toString() ?? '';
            final fileName = _safeStorageSegment(
              document['fileName']?.toString() ?? 'document',
            );
            final targetPath = 'users/$uid/contract_backups/$snapshotId/'
                '${_safeStorageSegment(contract['id']?.toString() ?? 'contract')}_'
                '${_safeStorageSegment(document['id']?.toString() ?? '$index')}_'
                '$fileName';
            await _copyStorageObject(
              sourcePath: sourcePath,
              targetPath: targetPath,
              contentType: contentType,
              maxBytes: 10 * 1024 * 1024,
            );
            copiedPaths.add(targetPath);
            document['backupStoragePath'] = targetPath;
            backedUpDocuments.add(document);
          }
          contract['documents'] = backedUpDocuments;
        }
        result.add(contract);
      }
      return result;
    } catch (error, stackTrace) {
      await _deleteStoragePaths(copiedPaths, 'incomplete contract snapshot');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<List<Map<String, dynamic>>> _restoreContractSnapshotDocuments(
    List<Map<String, dynamic>> contracts,
    String uid,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final contractRecord in contracts) {
      final contract = _normalizeMap(contractRecord);
      final documents = contract['documents'];
      if (documents is List) {
        final restoredDocuments = <Map<String, dynamic>>[];
        for (final value in documents) {
          if (value is! Map) {
            throw const FormatException('Invalid contract document in backup.');
          }
          final document = _normalizeMap(value);
          final backupPath = document.remove('backupStoragePath')?.toString();
          if (backupPath != null && backupPath.isNotEmpty) {
            if (!backupPath.startsWith('users/$uid/contract_backups/')) {
              throw StateError(
                  'A contract backup document belongs to a different account.');
            }
            final sourcePath = document['storagePath']?.toString() ?? '';
            final contentType = document['contentType']?.toString() ?? '';
            await _copyStorageObject(
              sourcePath: backupPath,
              targetPath: sourcePath,
              contentType: contentType,
              maxBytes: 10 * 1024 * 1024,
            );
          }
          restoredDocuments.add(document);
        }
        contract['documents'] = restoredDocuments;
      }
      result.add(contract);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _prepareMarketplaceSnapshotRecords(
    List<Map<String, dynamic>> listings,
    String uid,
    String snapshotId,
  ) async {
    _validateMarketplaceOwners(listings, uid);
    final copiedPaths = <String>[];
    try {
      final result = <Map<String, dynamic>>[];
      for (final listingRecord in listings) {
        final listing = _normalizeMap(listingRecord);
        final imagePaths = _stringList(listing['imagePaths']);
        final imageUrls = _stringList(listing['imageUrls']);
        if (imagePaths.length != imageUrls.length) {
          throw const FormatException(
              'Marketplace photo paths and URLs do not match.');
        }
        final backupImagePaths = <String>[];
        for (var index = 0; index < imagePaths.length; index++) {
          final sourcePath = imagePaths[index];
          if (!sourcePath.startsWith('marketplace/$uid/')) {
            throw StateError(
                'A marketplace photo belongs to a different account.');
          }
          final extension = _storageExtension(sourcePath);
          final targetPath = 'marketplace/$uid/backups/$snapshotId/'
              '${_safeStorageSegment(listing['id']?.toString() ?? 'listing')}_'
              '$index.$extension';
          await _copyStorageObject(
            sourcePath: sourcePath,
            targetPath: targetPath,
            contentType: _contentTypeForExtension(extension),
            maxBytes: 5 * 1024 * 1024,
          );
          copiedPaths.add(targetPath);
          backupImagePaths.add(targetPath);
        }
        listing['backupImagePaths'] = backupImagePaths;
        result.add(listing);
      }
      return result;
    } catch (error, stackTrace) {
      await _deleteStoragePaths(copiedPaths, 'incomplete marketplace snapshot');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _replaceMarketplaceRecords(
    String uid,
    List<Map<String, dynamic>> records,
  ) async {
    _validateMarketplaceOwners(records, uid);
    final uniqueRecords = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final id = record['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException(
            'A marketplace backup listing is missing its ID.');
      }
      if (uniqueRecords.containsKey(id)) {
        throw FormatException('Duplicate marketplace listing: $id');
      }
      uniqueRecords[id] = _normalizeMap(record);
    }

    final collection = _firestore.collection('marketplace_listings');
    final current = await collection.where('ownerId', isEqualTo: uid).get();
    final currentById = {for (final doc in current.docs) doc.id: doc};
    final restoredIds = uniqueRecords.keys.toSet();

    for (final entry in uniqueRecords.entries) {
      final id = entry.key;
      final record = entry.value;
      final existing = currentById[id];
      final reference = collection.doc(id);

      if (existing == null) {
        final collision = await reference.get();
        if (collision.exists) {
          throw StateError(
              'A marketplace listing ID is already owned by another account.');
        }
      }

      final listing = await _restoreMarketplaceImages(uid, record);
      final data = listing.toMap();
      if (existing != null) {
        data['createdAt'] = existing.data()['createdAt'];
        data['updatedAt'] = FieldValue.serverTimestamp();
        await reference.set(data);
        continue;
      }

      final restoredStatus = data['status']?.toString() ?? 'active';
      data['status'] = 'active';
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await reference.set(data);
      if (restoredStatus != 'active') {
        await reference.update({
          'status': restoredStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final removedListings =
        current.docs.where((doc) => !restoredIds.contains(doc.id)).toList();
    for (var offset = 0;
        offset < removedListings.length;
        offset += _firestoreBatchLimit) {
      final end =
          (offset + _firestoreBatchLimit).clamp(0, removedListings.length);
      final batch = _firestore.batch();
      for (final listing in removedListings.sublist(offset, end)) {
        batch.delete(listing.reference);
      }
      await batch.commit();
    }
    await _deleteStoragePaths(
      removedListings.expand(
        (listing) => _stringList(listing.data()['imagePaths']),
      ),
      'marketplace listings removed during restore',
    );
  }

  Future<MarketplaceListing> _restoreMarketplaceImages(
    String uid,
    Map<String, dynamic> record,
  ) async {
    final listing = MarketplaceListing.fromMap(
      record['id']?.toString() ?? '',
      record,
    );
    final backupImagePaths = _stringList(record['backupImagePaths']);
    if (backupImagePaths.isEmpty) return listing;
    if (backupImagePaths.length != listing.imagePaths.length) {
      throw const FormatException(
          'Marketplace backup photo data is incomplete.');
    }

    final restoredUrls = <String>[];
    for (var index = 0; index < backupImagePaths.length; index++) {
      final backupPath = backupImagePaths[index];
      final targetPath = listing.imagePaths[index];
      if (!backupPath.startsWith('marketplace/$uid/backups/') ||
          !targetPath.startsWith('marketplace/$uid/')) {
        throw StateError(
            'A marketplace backup photo belongs to a different account.');
      }
      final extension = _storageExtension(targetPath);
      restoredUrls.add(await _copyStorageObject(
        sourcePath: backupPath,
        targetPath: targetPath,
        contentType: _contentTypeForExtension(extension),
        maxBytes: 5 * 1024 * 1024,
      ));
    }
    return listing.copyWith(imageUrls: restoredUrls);
  }

  void _validateMarketplaceOwners(
    List<Map<String, dynamic>> listings,
    String uid,
  ) {
    for (final listing in listings) {
      if (listing['ownerId'] != uid) {
        throw StateError(
            'A marketplace listing belongs to a different account.');
      }
      final imagePaths = _stringList(listing['imagePaths']);
      final imageUrls = _stringList(listing['imageUrls']);
      if (imagePaths.length != imageUrls.length) {
        throw const FormatException(
            'Marketplace photo paths and URLs do not match.');
      }
      if (imagePaths.any((path) => !path.startsWith('marketplace/$uid/'))) {
        throw StateError('A marketplace photo belongs to a different account.');
      }
    }
  }

  Future<void> _replaceWorkerPayrollRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final uniqueRecords = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final id = record['id']?.toString();
      final kind = record['kind']?.toString();
      if (id == null ||
          id.isEmpty ||
          !const {'attendance', 'rate', 'payment'}.contains(kind)) {
        throw const FormatException('Invalid worker payroll backup record.');
      }
      if (uniqueRecords.containsKey(id)) {
        throw FormatException('Duplicate worker payroll record: $id');
      }
      uniqueRecords[id] = record;
    }

    final box = await Hive.openBox(_workerPayrollBoxName);
    await box.clear();
    for (final entry in uniqueRecords.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<void> _replaceWorkersRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final uniqueRecords = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final id = record['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException('Invalid worker backup record.');
      }
      if (uniqueRecords.containsKey(id)) {
        throw FormatException('Duplicate worker record: $id');
      }
      uniqueRecords[id] = record;
    }

    final box = await Hive.openBox(_workersBoxName);
    await box.clear();
    for (final entry in uniqueRecords.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<String> _copyStorageObject({
    required String sourcePath,
    required String targetPath,
    required String contentType,
    required int maxBytes,
  }) async {
    if (sourcePath.isEmpty ||
        targetPath.isEmpty ||
        contentType.isEmpty ||
        sourcePath == targetPath) {
      throw const FormatException('Invalid storage backup file reference.');
    }
    final bytes = await _storage.ref(sourcePath).getData(maxBytes);
    if (bytes == null || bytes.isEmpty) {
      throw StateError(
          'A file required by the backup is empty or unavailable.');
    }
    final target = _storage.ref(targetPath);
    try {
      await target.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return await target.getDownloadURL();
    } catch (error, stackTrace) {
      try {
        await target.delete();
      } catch (cleanupError) {
        debugPrint(
          'BackupService: Could not remove incomplete storage copy: '
          '$cleanupError',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _deleteStoragePaths(
    Iterable<String> paths,
    String operation,
  ) async {
    for (final path in paths.toSet()) {
      try {
        await _storage.ref(path).delete();
      } catch (error) {
        debugPrint(
          'BackupService: Could not remove storage object during '
          '$operation: $error',
        );
      }
    }
  }

  List<String> _stringList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _safeStorageSegment(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  String _storageExtension(String path) {
    final fileName = path.split('/').last;
    final separator = fileName.lastIndexOf('.');
    if (separator < 0 || separator == fileName.length - 1) {
      throw const FormatException('Unsupported marketplace photo format.');
    }
    final extension = fileName.substring(separator + 1).toLowerCase();
    _contentTypeForExtension(extension);
    return extension;
  }

  String _contentTypeForExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const FormatException('Unsupported backup image format.'),
    };
  }

  Map<String, dynamic> _documentData(
    String id,
    Map<String, dynamic> data,
  ) {
    return {
      ..._normalizeMap(data),
      'id': id,
    };
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> value) {
    return value.map(
      (key, entryValue) => MapEntry(
        key.toString(),
        _normalizeValue(entryValue),
      ),
    );
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) return _normalizeMap(value);
    if (value is List) return value.map(_normalizeValue).toList();
    return value;
  }

  List<Map<String, dynamic>> _readRecordList(Object? value, String name) {
    if (value == null) return [];
    if (value is! List) {
      throw FormatException('Invalid $name data in backup.');
    }

    return value.map((record) {
      if (record is! Map) {
        throw FormatException('Invalid record in $name data.');
      }
      return _normalizeMap(record);
    }).toList();
  }

  void _validateContractDocumentOwners(
    List<Map<String, dynamic>> contracts,
    String uid,
  ) {
    final expectedPathPrefix = 'users/$uid/contracts/';
    for (final contract in contracts) {
      final documents = contract['documents'];
      if (documents == null) continue;
      if (documents is! List) {
        throw const FormatException('Invalid contract documents in backup.');
      }
      for (final document in documents) {
        if (document is! Map ||
            document['ownerId'] != uid ||
            !(document['storagePath']?.toString() ?? '')
                .startsWith(expectedPathPrefix)) {
          throw StateError(
              'A contract document belongs to a different account.');
        }
      }
    }
  }

  Future<void> _writeDocuments(
    CollectionReference<Map<String, dynamic>> collection,
    List<Map<String, dynamic>> records,
  ) async {
    for (var offset = 0;
        offset < records.length;
        offset += _firestoreBatchLimit) {
      final end =
          (offset + _firestoreBatchLimit).clamp(0, records.length).toInt();
      final batch = _firestore.batch();
      for (final record in records.sublist(offset, end)) {
        final id = record['id']?.toString();
        if (id == null || id.isEmpty) {
          throw const FormatException('A backup record is missing its ID.');
        }
        batch.set(collection.doc(id), record);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteDocuments(
    CollectionReference<Map<String, dynamic>> collection,
    Iterable<String> ids,
  ) async {
    final documentIds = ids.toList();
    for (var offset = 0;
        offset < documentIds.length;
        offset += _firestoreBatchLimit) {
      final end =
          (offset + _firestoreBatchLimit).clamp(0, documentIds.length).toInt();
      final batch = _firestore.batch();
      for (final id in documentIds.sublist(offset, end)) {
        batch.delete(collection.doc(id));
      }
      await batch.commit();
    }
  }

  Future<void> _replaceStockRecords(
    String uid,
    List<Map<String, dynamic>> stockItems,
    List<Map<String, dynamic>> stockMovements,
  ) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _replaceCollection(
      userRef.collection(_stockItemsCollection),
      stockItems,
    );
    await _replaceCollection(
      userRef.collection(_stockMovementsCollection),
      stockMovements,
    );
  }

  Future<void> _replaceContractRecords(
    List<Map<String, dynamic>> contracts,
  ) async {
    final uniqueContracts = <String, Map<String, dynamic>>{};
    for (final contract in contracts) {
      final id = contract['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException('A contract backup record is missing ID.');
      }
      if (uniqueContracts.containsKey(id)) {
        throw FormatException('Duplicate contract backup record: $id');
      }
      uniqueContracts[id] = contract;
    }

    final box = await Hive.openBox(ContractService.boxName);
    await box.clear();
    for (final entry in uniqueContracts.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<void> _replaceCollection(
    CollectionReference<Map<String, dynamic>> collection,
    List<Map<String, dynamic>> records,
  ) async {
    final uniqueRecords = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final id = record['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException('A stock record is missing its ID.');
      }
      uniqueRecords[id] = record;
    }

    final existing = await collection.get();
    await _writeDocuments(collection, uniqueRecords.values.toList());
    await _deleteDocuments(
      collection,
      existing.docs
          .map((doc) => doc.id)
          .where((id) => !uniqueRecords.containsKey(id)),
    );
  }

  Future<void> _deleteStockSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
  ) async {
    await _deleteCollection(snapshotRef.collection(_stockItemsCollection));
    await _deleteCollection(snapshotRef.collection(_stockMovementsCollection));
    await snapshotRef.delete();
  }

  Future<void> _deleteContractSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef, {
    Iterable<String> additionalStoragePaths = const [],
  }) async {
    final snapshot = await snapshotRef.collection(_contractsCollection).get();
    final backupPaths = <String>[...additionalStoragePaths];
    for (final contract in snapshot.docs) {
      final documents = contract.data()['documents'];
      if (documents is! List) continue;
      for (final document in documents) {
        if (document is Map) {
          final path = document['backupStoragePath']?.toString();
          if (path != null && path.isNotEmpty) backupPaths.add(path);
        }
      }
    }
    await _deleteStoragePaths(backupPaths, 'contract snapshot cleanup');
    await _deleteCollection(snapshotRef.collection(_contractsCollection));
    await snapshotRef.delete();
  }

  Future<void> _deleteMarketplaceSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef, {
    Iterable<String> additionalStoragePaths = const [],
  }) async {
    final snapshot =
        await snapshotRef.collection(_marketplaceListingsCollection).get();
    final backupPaths = <String>[...additionalStoragePaths];
    for (final listing in snapshot.docs) {
      backupPaths.addAll(
        _stringList(listing.data()['backupImagePaths']),
      );
    }
    await _deleteStoragePaths(backupPaths, 'marketplace snapshot cleanup');
    await _deleteCollection(
      snapshotRef.collection(_marketplaceListingsCollection),
    );
    await snapshotRef.delete();
  }

  List<String> _contractBackupPaths(
    List<Map<String, dynamic>> contracts,
  ) {
    final paths = <String>[];
    for (final contract in contracts) {
      final documents = contract['documents'];
      if (documents is! List) continue;
      for (final document in documents) {
        if (document is Map) {
          final path = document['backupStoragePath']?.toString();
          if (path != null && path.isNotEmpty) paths.add(path);
        }
      }
    }
    return paths;
  }

  List<String> _marketplaceBackupPaths(
    List<Map<String, dynamic>> listings,
  ) =>
      listings
          .expand((listing) => _stringList(listing['backupImagePaths']))
          .toList();

  Future<void> _deleteWorkerPayrollSnapshot(
    DocumentReference<Map<String, dynamic>> snapshotRef,
  ) async {
    await _deleteCollection(
      snapshotRef.collection(_workerPayrollRecordsCollection),
    );
    await snapshotRef.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    await _deleteDocuments(
      collection,
      snapshot.docs.map((doc) => doc.id),
    );
  }

  // Auto backup if needed
  Future<void> autoBackupIfNeeded() async {
    if (_autoBackupInProgress) return;
    _autoBackupInProgress = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('auto_backup') ?? false)) return;

      final profileEmail = await _getUserEmail();
      if (profileEmail == null || profileEmail.isEmpty) {
        debugPrint(
          'BackupService: Auto backup skipped because the profile email is missing.',
        );
        return;
      }

      final lastBackup = prefs.getString('last_backup');
      final lastBackupDate =
          lastBackup == null ? null : DateTime.tryParse(lastBackup);
      if (lastBackup != null && lastBackupDate == null) {
        debugPrint(
          'BackupService: Invalid last backup timestamp; a new backup will be created.',
        );
      }

      final isDue = lastBackupDate == null ||
          DateTime.now().difference(lastBackupDate) >= const Duration(days: 7);
      if (isDue) {
        await createBackup(isUrdu: false);
      }
    } finally {
      _autoBackupInProgress = false;
    }
  }

  // Schedule automatic backups
  Future<void> scheduleAutoBackup(bool enable, {bool isUrdu = false}) async {
    if (enable) {
      final profileEmail = await _getUserEmail();
      if (profileEmail == null || profileEmail.isEmpty) {
        throw Exception(
          isUrdu
              ? 'خودکار بیک اپ فعال کرنے کے لیے پہلے پروفائل میں ای میل درج کریں'
              : 'Please add an email in your profile before enabling auto backup',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', enable);

    if (enable) {
      await autoBackupIfNeeded();
    }
    notifyListeners();
  }

  // Backup to local file
  Future<void> backupToLocalFile() async {
    throw UnimplementedError('Local file backup is not implemented.');
  }

  // Restore from local file
  Future<void> restoreFromLocalFile() async {
    throw UnimplementedError('Local file restore is not implemented.');
  }
}
