import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';

class BackupService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _autoBackupInProgress = false;

  static const String _stockSnapshotsCollection = 'stockSnapshots';
  static const String _stockItemsCollection = 'stock_items';
  static const String _stockMovementsCollection = 'stock_movements';
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
    final stockRecords = await _loadStockRecords(user.uid);
    final backupRef = _firestore.collection('backups').doc(user.uid);
    final previousBackup = await backupRef.get();
    final previousSnapshotId =
        previousBackup.data()?['stockBackupId']?.toString();
    final snapshotId = backupRef.collection(_stockSnapshotsCollection).doc().id;
    final snapshotRef =
        backupRef.collection(_stockSnapshotsCollection).doc(snapshotId);

    try {
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
    } catch (e) {
      try {
        await _deleteStockSnapshot(snapshotRef);
      } catch (cleanupError) {
        debugPrint(
          'BackupService: Could not remove incomplete stock snapshot: '
          '$cleanupError',
        );
      }
      rethrow;
    }

    final backupData = {
      'accounts': accountsBox.values.map((a) => a.toMap()).toList(),
      'transactions': transactionsBox.values.map((t) => t.toMap()).toList(),
      'categories': categoriesBox.values.map((c) => c.toMap()).toList(),
      'professions': professionsBox.values.map((p) => p.toMap()).toList(),
      'settings': settingsBox.toMap(),
      'email': profileEmail,
      'backupDate': DateTime.now(),
      'appVersion': '1.0.0',
      'stockBackupId': snapshotId,
      'totalStockItems': stockRecords[_stockItemsCollection]!.length,
      'totalStockMovements': stockRecords[_stockMovementsCollection]!.length,
    };

    // Stock is stored in a versioned subcollection to avoid the Firestore
    // document-size limit for shops with long movement histories.
    await backupRef.set(backupData, SetOptions(merge: true));

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
    final accountsData = _readRecordList(backupData['accounts'], 'accounts');
    final transactionsData =
        _readRecordList(backupData['transactions'], 'transactions');
    final categoriesData =
        _readRecordList(backupData['categories'], 'categories');
    final professionsData =
        _readRecordList(backupData['professions'], 'professions');
    final settings = Map<String, dynamic>.from(
      backupData['settings'] as Map? ?? const {},
    );
    final stockSnapshotId = backupData['stockBackupId']?.toString();
    Map<String, List<Map<String, dynamic>>>? stockRecords;

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

    if (stockRecords != null) {
      await _replaceStockRecords(
        user.uid,
        stockRecords[_stockItemsCollection]!,
        stockRecords[_stockMovementsCollection]!,
      );
    }

    // Clear existing data after all remote stock records have been read.
    await _clearLocalData();

    // Restore accounts
    final accountsBox = await Hive.openBox<Account>('accounts');
    for (var accountData in accountsData) {
      final account = Account.fromMap(accountData);
      await accountsBox.put(account.id, account);
    }

    // Restore transactions
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    for (var transactionData in transactionsData) {
      final transaction = model.Transaction.fromMap(transactionData);
      await transactionsBox.put(transaction.id, transaction);
    }

    // Restore categories
    final categoriesBox = await Hive.openBox<Category>('categories');
    for (var categoryData in categoriesData) {
      final category = Category.fromMap(categoryData);
      await categoriesBox.put(category.id, category);
    }

    // Restore professions
    final professionsBox = await Hive.openBox<Profession>('professions');
    for (var professionData in professionsData) {
      final profession = Profession.fromMap(professionData);
      await professionsBox.put(profession.id, profession);
    }

    // Restore settings
    final settingsBox = await Hive.openBox('settings');
    for (var key in settings.keys) {
      await settingsBox.put(key, settings[key]);
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
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to export stock data.');
    }
    final stockRecords = await _loadStockRecords(user.uid);

    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'data': {
        'accounts': accountsBox.values.map((a) => a.toMap()).toList(),
        'transactions': transactionsBox.values.map((t) => t.toMap()).toList(),
        'categories': categoriesBox.values.map((c) => c.toMap()).toList(),
        'professions': professionsBox.values.map((p) => p.toMap()).toList(),
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
    final includesStock =
        data.containsKey('stockItems') || data.containsKey('stockMovements');

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

    // Clear existing data
    await _clearLocalData();

    // Import accounts
    final accountsBox = await Hive.openBox<Account>('accounts');
    for (var accountData in accountsData) {
      final account = Account.fromMap(accountData);
      await accountsBox.put(account.id, account);
    }

    // Import transactions
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    for (var transactionData in transactionsData) {
      final transaction = model.Transaction.fromMap(transactionData);
      await transactionsBox.put(transaction.id, transaction);
    }

    // Import categories
    final categoriesBox = await Hive.openBox<Category>('categories');
    for (var categoryData in categoriesData) {
      final category = Category.fromMap(categoryData);
      await categoriesBox.put(category.id, category);
    }

    // Import professions
    final professionsBox = await Hive.openBox<Profession>('professions');
    for (var professionData in professionsData) {
      final profession = Profession.fromMap(professionData);
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

    await accountsBox.clear();
    await transactionsBox.clear();
    await categoriesBox.clear();
    await professionsBox.clear();
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

    final profileEmail = await _getUserEmail();

    return {
      'lastBackup': lastBackup == null ? null : DateTime.tryParse(lastBackup),
      'lastRestore':
          lastRestore == null ? null : DateTime.tryParse(lastRestore),
      'autoBackupEnabled': prefs.getBool('auto_backup') ?? false,
      'totalAccounts': accountsBox.length,
      'totalTransactions': transactionsBox.length,
      'totalStockItems': stockItemCount,
      'backupSize': await _calculateBackupSize(
        stockItemCount: stockItemCount,
        stockMovementCount: stockMovementCount,
      ),
      'email': profileEmail,
    };
  }

  // Calculate approximate backup size
  Future<int> _calculateBackupSize({
    required int stockItemCount,
    required int stockMovementCount,
  }) async {
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox =
        await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');

    // Rough estimation
    return (accountsBox.length * 100) +
        (transactionsBox.length * 200) +
        (categoriesBox.length * 50) +
        (professionsBox.length * 80) +
        (stockItemCount * 500) +
        (stockMovementCount * 250);
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
          throw const FormatException('A stock record is missing its ID.');
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
    await exportToJson();
    // Implementation for saving to local file system
    // This would use path_provider to get directory and write file
  }

  // Restore from local file
  Future<void> restoreFromLocalFile() async {
    // Implementation for reading from local file system
    // This would use file picker to select file and read data
  }
}
