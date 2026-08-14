import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/category_model.dart';
import 'dart:async';
import 'base_service.dart';
import 'account_service.dart';
import 'profession_service.dart';

class SyncService extends BaseService {
  final AccountService _accountService = AccountService();
  final ProfessionService _professionService = ProfessionService();

  StreamSubscription? _accountsSub, _txSub, _proSub, _catSub, _userSub;

  void startRealtimeSync() {
    final user = auth.currentUser;
    if (user == null) return;
    stopRealtimeSync();

    final userDoc = firestore.collection('users').doc(user.uid);

    // User Profile Listener for verification status
    _userSub = userDoc.snapshots().listen((doc) async {
      if (doc.exists) {
        final data = doc.data()!;
        final isVerified = data['isVerified'] == true;
        try {
          final myAccount = accountsBox?.values.firstWhere((a) => a.phone == user.phoneNumber);
          if (myAccount != null && myAccount.isVerified != isVerified) {
            await accountsBox?.put(myAccount.id, myAccount.copyWith(isVerified: isVerified));
            notifyListeners();
          }
        } catch (_) {}
      }
    });

    _accountsSub = userDoc.collection('accounts').snapshots().listen((snap) {
      for (var c in snap.docChanges) {
        if (c.doc.data() == null) continue;
        final a = Account.fromMap(c.doc.data()!);
        if (c.type == DocumentChangeType.removed) accountsBox?.delete(a.id);
        else accountsBox?.put(a.id, a);
      }
      notifyListeners();
    });

    _txSub = userDoc.collection('transactions').snapshots().listen((snap) async {
      for (var c in snap.docChanges) {
        if (c.doc.data() == null) continue;
        final t = model.Transaction.fromMap(c.doc.data()!);
        if (c.type == DocumentChangeType.removed) await transactionsBox?.delete(t.id);
        else await transactionsBox?.put(t.id, t);
        await _accountService.recalculateAccountBalance(t.accountId);
        if (t.professionId != null) await _professionService.recalculateProfessionFinance(t.professionId!);
      }
      notifyListeners();
    });

    _catSub = userDoc.collection('categories').snapshots().listen((snap) {
      for (var c in snap.docChanges) {
        if (c.doc.data() == null) continue;
        final cat = Category.fromMap(c.doc.data()!);
        if (c.type == DocumentChangeType.removed) categoriesBox?.delete(cat.id);
        else categoriesBox?.put(cat.id, cat);
      }
      notifyListeners();
    });

    _proSub = userDoc.collection('professions').snapshots().listen((snap) {
      for (var c in snap.docChanges) {
        if (c.doc.data() == null) continue;
        final p = Profession.fromMap(c.doc.data()!);
        if (c.type == DocumentChangeType.removed) professionsBox?.delete(p.id);
        else professionsBox?.put(p.id, p);
      }
      notifyListeners();
    });
  }

  void stopRealtimeSync() {
    _accountsSub?.cancel(); _txSub?.cancel(); _proSub?.cancel(); _catSub?.cancel(); _userSub?.cancel();
  }

  Future<void> syncWithFirebase() async {
    final user = auth.currentUser;
    if (user == null) return;
    
    final batch = firestore.batch();
    final userDoc = firestore.collection('users').doc(user.uid);

    bool isVerified = false;
    final uDoc = await userDoc.get();
    if (uDoc.exists) isVerified = uDoc.data()?['isVerified'] == true;

    if (accountsBox != null) {
      for (var a in accountsBox!.values) batch.set(userDoc.collection('accounts').doc(a.id), a.toMap());
    }
    if (transactionsBox != null) {
      for (var t in transactionsBox!.values) batch.set(userDoc.collection('transactions').doc(t.id), t.toMap());
    }
    if (professionsBox != null) {
      for (var p in professionsBox!.values) batch.set(userDoc.collection('professions').doc(p.id), p.toMap());
    }
    if (categoriesBox != null) {
      for (var c in categoriesBox!.values) batch.set(userDoc.collection('categories').doc(c.id), c.toMap());
    }
    await batch.commit();
  }

  Future<void> fetchFromFirebase() async {
    final user = auth.currentUser;
    if (user == null) return;
    final userDoc = firestore.collection('users').doc(user.uid);

    final snaps = await Future.wait([
      userDoc.collection('accounts').get(),
      userDoc.collection('transactions').get(),
      userDoc.collection('professions').get(),
      userDoc.collection('categories').get(),
    ]);

    for (var d in snaps[0].docs) await accountsBox?.put(d.id, Account.fromMap(d.data()));
    for (var d in snaps[1].docs) await transactionsBox?.put(d.id, model.Transaction.fromMap(d.data()));
    for (var d in snaps[2].docs) await professionsBox?.put(d.id, Profession.fromMap(d.data()));
    for (var d in snaps[3].docs) await categoriesBox?.put(d.id, Category.fromMap(d.data()));

    notifyListeners();
  }

  void setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) syncWithFirebase();
    });
  }

  Future<void> prepareForLogout() async {
    stopRealtimeSync();
    await clearAllBoxes();
  }
}