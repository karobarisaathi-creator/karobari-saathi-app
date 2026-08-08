import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';

/// بیس سروس - تمام سروسز کے لیے مشترکہ کوڈ
class BaseService extends ChangeNotifier {
  final cf.FirebaseFirestore firestore = cf.FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // Getters for Hive Boxes with explicit typing
  Box<Account>? get accountsBox => Hive.isBoxOpen('accounts') ? Hive.box<Account>('accounts') : null;
  Box<model.Transaction>? get transactionsBox => Hive.isBoxOpen('transactions') ? Hive.box<model.Transaction>('transactions') : null;
  Box<Category>? get categoriesBox => Hive.isBoxOpen('categories') ? Hive.box<Category>('categories') : null;
  Box<Profession>? get professionsBox => Hive.isBoxOpen('professions') ? Hive.box<Profession>('professions') : null;
  Box<InventoryItem>? get itemsBox => Hive.isBoxOpen('inventory_items') ? Hive.box<InventoryItem>('inventory_items') : null;
  Box<List>? get remoteCachedItemsBox => Hive.isBoxOpen('remote_cached_items') ? Hive.box<List>('remote_cached_items') : null;
  Box<InventoryItem>? get recentlyViewedBox => Hive.isBoxOpen('recently_viewed') ? Hive.box<InventoryItem>('recently_viewed') : null;
  Box<ArtisanProfile>? get artisansBox => Hive.isBoxOpen('artisans') ? Hive.box<ArtisanProfile>('artisans') : null;
  Box<ArtisanWorkOrder>? get workOrdersBox => Hive.isBoxOpen('work_orders') ? Hive.box<ArtisanWorkOrder>('work_orders') : null;
  Box? get settingsBox => Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

  // Hive Boxes کو کھولیں
  Future<void> openBoxes() async {
    await Hive.openBox<Account>('accounts');
    await Hive.openBox<model.Transaction>('transactions');
    await Hive.openBox<Category>('categories');
    await Hive.openBox<Profession>('professions');
    await Hive.openBox<InventoryItem>('inventory_items');
    await Hive.openBox<List>('remote_cached_items');
    await Hive.openBox<InventoryItem>('recently_viewed');
    await Hive.openBox<ArtisanProfile>('artisans');
    await Hive.openBox<ArtisanWorkOrder>('work_orders');
    await Hive.openBox('settings');
  }

  // Hive Boxes بند کریں
  Future<void> closeBoxes() async {
    if (Hive.isBoxOpen('accounts')) await Hive.box<Account>('accounts').close();
    if (Hive.isBoxOpen('transactions')) await Hive.box<model.Transaction>('transactions').close();
    if (Hive.isBoxOpen('categories')) await Hive.box<Category>('categories').close();
    if (Hive.isBoxOpen('professions')) await Hive.box<Profession>('professions').close();
    if (Hive.isBoxOpen('inventory_items')) await Hive.box<InventoryItem>('inventory_items').close();
    if (Hive.isBoxOpen('remote_cached_items')) await Hive.box<List>('remote_cached_items').close();
    if (Hive.isBoxOpen('recently_viewed')) await Hive.box<InventoryItem>('recently_viewed').close();
    if (Hive.isBoxOpen('artisans')) await Hive.box<ArtisanProfile>('artisans').close();
    if (Hive.isBoxOpen('work_orders')) await Hive.box<ArtisanWorkOrder>('work_orders').close();
    if (Hive.isBoxOpen('settings')) await Hive.box('settings').close();
  }

  // Hive Boxes صاف کریں
  Future<void> clearAllBoxes() async {
    if (Hive.isBoxOpen('accounts')) await Hive.box<Account>('accounts').clear();
    if (Hive.isBoxOpen('transactions')) await Hive.box<model.Transaction>('transactions').clear();
    if (Hive.isBoxOpen('categories')) await Hive.box<Category>('categories').clear();
    if (Hive.isBoxOpen('professions')) await Hive.box<Profession>('professions').clear();
    if (Hive.isBoxOpen('inventory_items')) await Hive.box<InventoryItem>('inventory_items').clear();
    if (Hive.isBoxOpen('remote_cached_items')) await Hive.box<List>('remote_cached_items').clear();
    if (Hive.isBoxOpen('recently_viewed')) await Hive.box<InventoryItem>('recently_viewed').clear();
    if (Hive.isBoxOpen('artisans')) await Hive.box<ArtisanProfile>('artisans').clear();
    if (Hive.isBoxOpen('work_orders')) await Hive.box<ArtisanWorkOrder>('work_orders').clear();
    if (Hive.isBoxOpen('settings')) await Hive.box('settings').clear();
  }
}
