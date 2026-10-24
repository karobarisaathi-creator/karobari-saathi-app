import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';

class AutoSyncService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Hive Boxes تک براہ راست رسائی حاصل کرنے کے لیے (یا DatabaseService کا استعمال کریں)
  // یہاں سادگی کے لیے براہ راست Hive استعمال کر رہے ہیں کیونکہ یہ سروس ہے

  Future<List<Account>> _getAllAccounts() async {
    final box = await Hive.openBox<Account>('accounts');
    return box.values.toList();
  }

  Future<List<model.Transaction>> _getAllTransactions() async {
    final box = await Hive.openBox<model.Transaction>('transactions');
    return box.values.toList();
  }

  Future<List<Category>> _getAllCategories() async {
    final box = await Hive.openBox<Category>('categories');
    return box.values.toList();
  }

  Future<List<Profession>> _getAllProfessions() async {
    final box = await Hive.openBox<Profession>('professions');
    return box.values.toList();
  }

  Future<String> _getUserIdentifier() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in');
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final profileEmail = userDoc.data()?['email']?.toString().trim();
        if (profileEmail != null && profileEmail.isNotEmpty) {
          return profileEmail;
        }
      }
    } catch (_) {}

    if (user.email != null && user.email!.trim().isNotEmpty) {
      return user.email!.trim();
    }

    if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
      return user.phoneNumber!.trim();
    }

    throw Exception('User email or phone number not available');
  }

  Future<void> syncAllDataToCloud() async {
    final identifier = await _getUserIdentifier();

    try {
      // Hive سے اصلی ڈیٹا حاصل کریں
      final accounts = await _getAllAccounts();
      final transactions = await _getAllTransactions();
      final categories = await _getAllCategories();
      final professions = await _getAllProfessions();

      print('اکاؤنٹس: ${accounts.length}');
      print('لین دین: ${transactions.length}');

      await _firestore.collection('userData').doc(identifier).set({
        'accounts': accounts.map((a) => a.toMap()).toList(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'professions': professions.map((p) => p.toMap()).toList(),
        'lastSync': DateTime.now().toIso8601String(),
        'identifier': identifier,
        'email': identifier.contains('@') ? identifier : null,
        'phoneNumber': _auth.currentUser?.phoneNumber,
      }, SetOptions(merge: true));

      print('تمام ڈیٹا کلاؤڈ پر کامیابی سے سینک ہوگیا ($identifier)');
      notifyListeners();
    } catch (e) {
      print('سینک میں خرابی: $e');
      rethrow; // UI کو ایرر دکھانے کے لیے
    }
  }

  Future<void> restoreAllDataFromPhone(String? key) async {
    try {
      final targetKey = key ?? await _getUserIdentifier();
      final snapshot =
          await _firestore.collection('userData').doc(targetKey).get();

      if (snapshot.exists) {
        final data = snapshot.data()!;

        print('کلاؤڈ سے ڈیٹا ملا، بحال کیا جا رہا ہے...');

        // Accounts بحال کریں
        if (data['accounts'] != null) {
          final accountsBox = await Hive.openBox<Account>('accounts');
          await accountsBox.clear(); // پرانا ڈیٹا صاف کریں (اختیاری)
          final accountsList = (data['accounts'] as List)
              .map((item) => Account.fromMap(item))
              .toList();
          for (var account in accountsList) {
            await accountsBox.put(account.id, account);
          }
        }

        // Transactions بحال کریں
        if (data['transactions'] != null) {
          final transactionsBox =
              await Hive.openBox<model.Transaction>('transactions');
          await transactionsBox.clear();
          final transactionsList = (data['transactions'] as List)
              .map((item) => model.Transaction.fromMap(item))
              .toList();
          for (var transaction in transactionsList) {
            await transactionsBox.put(transaction.id, transaction);
          }
        }

        // Categories بحال کریں
        if (data['categories'] != null) {
          final categoriesBox = await Hive.openBox<Category>('categories');
          await categoriesBox.clear();
          final categoriesList = (data['categories'] as List)
              .map((item) => Category.fromMap(item))
              .toList();
          for (var category in categoriesList) {
            await categoriesBox.put(category.id, category);
          }
        }

        // Professions بحال کریں
        if (data['professions'] != null) {
          final professionsBox = await Hive.openBox<Profession>('professions');
          await professionsBox.clear();
          final professionsList = (data['professions'] as List)
              .map((item) => Profession.fromMap(item))
              .toList();
          for (var profession in professionsList) {
            await professionsBox.put(profession.id, profession);
          }
        }

        print('تمام ڈیٹا کامیابی سے واپس آگیا اور لوکل محفوظ ہوگیا');
        notifyListeners();
      } else {
        print('اس شناخت (ایمیل/فون) کا کوئی ڈیٹا کلاؤڈ پر نہیں ملا');
      }
    } catch (e) {
      print('ڈیٹا واپس لینے میں خرابی: $e');
      throw e;
    }
  }

  Future<void> syncNewAccount(Account account) async {
    try {
      final key = await _getUserIdentifier();
      await _firestore.collection('userData').doc(key).update({
        'accounts': FieldValue.arrayUnion([account.toMap()]),
        'lastSync': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('نئے اکاؤنٹ سینک میں خرابی (شاید پہلی بار ہے): $e');
      await syncAllDataToCloud();
    }
  }

  Future<void> syncNewTransaction(model.Transaction transaction) async {
    try {
      final key = await _getUserIdentifier();
      await _firestore.collection('userData').doc(key).update({
        'transactions': FieldValue.arrayUnion([transaction.toMap()]),
        'lastSync': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('نئے ٹرانزیکشن سینک میں خرابی: $e');
      await syncAllDataToCloud();
    }
  }

  Future<void> syncNewProfession(Profession profession) async {
    try {
      final key = await _getUserIdentifier();
      await _firestore.collection('userData').doc(key).update({
        'professions': FieldValue.arrayUnion([profession.toMap()]),
        'lastSync': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await syncAllDataToCloud();
    }
  }

  Future<void> syncDeletedTransaction(String transactionId) async {
    // ڈیلیٹ کرنے کا منطق (Firebase سے مخصوص آئٹم ہٹانا مشکل ہے arrayRemove کے ساتھ اگر پورا object نہ ہو)
    // بہتر ہے کہ پورا ڈیٹا دوبارہ سینک کر دیں
    await syncAllDataToCloud();
  }
}
