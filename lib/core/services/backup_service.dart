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

class BackupService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create complete backup
  Future<void> createBackup() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get all data from Hive
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox = await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');
    final settingsBox = await Hive.openBox('settings');

    final backupData = {
      'accounts': accountsBox.values.map((a) => a.toMap()).toList(),
      'transactions': transactionsBox.values.map((t) => t.toMap()).toList(),
      'categories': categoriesBox.values.map((c) => c.toMap()).toList(),
      'professions': professionsBox.values.map((p) => p.toMap()).toList(),
      'settings': settingsBox.toMap(),
      'backupDate': DateTime.now(),
      'appVersion': '1.0.0',
    };

    // Upload to Firebase
    await _firestore
        .collection('backups')
        .doc(user.uid)
        .set(backupData, SetOptions(merge: true));

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

    // Clear existing data
    await _clearLocalData();

    // Restore accounts
    final accountsBox = await Hive.openBox<Account>('accounts');
    for (var accountData in backupData['accounts'] as List) {
      final account = Account.fromMap(accountData);
      await accountsBox.put(account.id, account);
    }

    // Restore transactions
    final transactionsBox = await Hive.openBox<model.Transaction>('transactions');
    for (var transactionData in backupData['transactions'] as List) {
      final transaction = model.Transaction.fromMap(transactionData);
      await transactionsBox.put(transaction.id, transaction);
    }

    // Restore categories
    final categoriesBox = await Hive.openBox<Category>('categories');
    for (var categoryData in backupData['categories'] as List) {
      final category = Category.fromMap(categoryData);
      await categoriesBox.put(category.id, category);
    }

    // Restore professions
    final professionsBox = await Hive.openBox<Profession>('professions');
    for (var professionData in backupData['professions'] as List) {
      final profession = Profession.fromMap(professionData);
      await professionsBox.put(profession.id, profession);
    }

    // Restore settings
    final settingsBox = await Hive.openBox('settings');
    final settings = backupData['settings'] as Map;
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
    final transactionsBox = await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');

    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'data': {
        'accounts': accountsBox.values.map((a) => a.toMap()).toList(),
        'transactions': transactionsBox.values.map((t) => t.toMap()).toList(),
        'categories': categoriesBox.values.map((c) => c.toMap()).toList(),
        'professions': professionsBox.values.map((p) => p.toMap()).toList(),
      },
    };

    return json.encode(exportData);
  }

  // Import from JSON file
  Future<void> importFromJson(String jsonData) async {
    final importData = json.decode(jsonData);
    final data = importData['data'] as Map;

    // Clear existing data
    await _clearLocalData();

    // Import accounts
    final accountsBox = await Hive.openBox<Account>('accounts');
    for (var accountData in data['accounts'] as List) {
      final account = Account.fromMap(accountData);
      await accountsBox.put(account.id, account);
    }

    // Import transactions
    final transactionsBox = await Hive.openBox<model.Transaction>('transactions');
    for (var transactionData in data['transactions'] as List) {
      final transaction = model.Transaction.fromMap(transactionData);
      await transactionsBox.put(transaction.id, transaction);
    }

    // Import categories
    final categoriesBox = await Hive.openBox<Category>('categories');
    for (var categoryData in data['categories'] as List) {
      final category = Category.fromMap(categoryData);
      await categoriesBox.put(category.id, category);
    }

    // Import professions
    final professionsBox = await Hive.openBox<Profession>('professions');
    for (var professionData in data['professions'] as List) {
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
    final transactionsBox = await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');

    await accountsBox.clear();
    await transactionsBox.clear();
    await categoriesBox.clear();
    await professionsBox.clear();
    notifyListeners();
  }

  // Get backup info
  Future<Map<String, dynamic>> getBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup');
    final lastRestore = prefs.getString('last_restore');

    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox = await Hive.openBox<model.Transaction>('transactions');

    return {
      'lastBackup': lastBackup != null ? DateTime.parse(lastBackup) : null,
      'lastRestore': lastRestore != null ? DateTime.parse(lastRestore) : null,
      'totalAccounts': accountsBox.length,
      'totalTransactions': transactionsBox.length,
      'backupSize': await _calculateBackupSize(),
    };
  }

  // Calculate approximate backup size
  Future<int> _calculateBackupSize() async {
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox = await Hive.openBox<model.Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');

    // Rough estimation
    return (accountsBox.length * 100) +
        (transactionsBox.length * 200) +
        (categoriesBox.length * 50) +
        (professionsBox.length * 80);
  }

  // Auto backup if needed
  Future<void> autoBackupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup');
    final autoBackupEnabled = prefs.getBool('auto_backup') ?? false;

    if (!autoBackupEnabled) return;

    final now = DateTime.now();
    final lastBackupDate = lastBackup != null
        ? DateTime.parse(lastBackup)
        : DateTime(2000);

    // Backup if more than 7 days have passed
    if (now.difference(lastBackupDate).inDays > 7) {
      await createBackup();
    }
  }

  // Schedule automatic backups
  Future<void> scheduleAutoBackup(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', enable);

    if (enable) {
      await autoBackupIfNeeded();
    }
    notifyListeners();
  }

  // Backup to local file
  Future<void> backupToLocalFile() async {
    final exportData = await exportToJson();
    // Implementation for saving to local file system
    // This would use path_provider to get directory and write file
  }

  // Restore from local file
  Future<void> restoreFromLocalFile() async {
    // Implementation for reading from local file system
    // This would use file picker to select file and read data
  }
}
