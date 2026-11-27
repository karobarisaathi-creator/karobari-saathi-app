import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'base_service.dart';

class ProfessionService extends BaseService {
  @visibleForTesting
  static Set<String> professionTreeIds(
    Iterable<Profession> professions,
    String rootId,
  ) {
    final childrenByParent = <String, List<Profession>>{};
    for (final profession in professions) {
      final parentId = profession.parentId?.trim();
      if (parentId == null || parentId.isEmpty) continue;
      childrenByParent.putIfAbsent(parentId, () => []).add(profession);
    }

    final ids = <String>{rootId};
    final pending = <String>[rootId];
    while (pending.isNotEmpty) {
      final parentId = pending.removeLast();
      for (final child in childrenByParent[parentId] ?? const <Profession>[]) {
        if (ids.add(child.id)) pending.add(child.id);
      }
    }
    return ids;
  }

  @visibleForTesting
  static List<Profession> activeSeasonsToDeactivate(
    Iterable<Profession> seasons,
    Profession selectedSeason,
  ) {
    return seasons
        .where(
          (season) =>
              season.id != selectedSeason.id &&
              season.parentId == selectedSeason.parentId &&
              (season.isActive ?? true),
        )
        .toList();
  }

  Future<void> _deactivateOtherSeasons(Profession season) async {
    final parentId = season.parentId?.trim();
    if (parentId == null || parentId.isEmpty || !(season.isActive ?? true)) {
      return;
    }

    final box = professionsBox;
    for (final current in activeSeasonsToDeactivate(
      getSeasons(parentId),
      season,
    )) {
      final inactive = current.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );
      await box?.put(current.id, inactive);
      final userId = auth.currentUser?.uid;
      if (userId != null) {
        firestore
            .collection('users')
            .doc(userId)
            .collection('professions')
            .doc(current.id)
            .set(inactive.toMap(), SetOptions(merge: true))
            .catchError((error) {
          debugPrint('Offline Sync: Previous season update delayed: $error');
        });
      }
    }
  }

  Future<void> addProfession(Profession profession) async {
    await _deactivateOtherSeasons(profession);
    // 1. Save locally
    await professionsBox?.put(profession.id, profession);
    notifyListeners();

    // 2. Cloud Sync
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('professions')
          .doc(profession.id)
          .set(profession.toMap())
          .catchError(
              (e) => debugPrint("Offline Sync: Profession addition delayed"));
    }
  }

  Future<void> updateProfession(Profession profession) async {
    await _deactivateOtherSeasons(profession);
    final updated = profession.copyWith(updatedAt: DateTime.now());
    // 1. Update locally
    await professionsBox?.put(profession.id, updated);
    notifyListeners();

    // 2. Cloud Sync
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('professions')
          .doc(profession.id)
          .update(updated.toMap())
          .catchError(
              (e) => debugPrint("Offline Sync: Profession update delayed"));
    }
  }

  Future<void> deleteProfession(String professionId) async {
    final profession = professionsBox?.get(professionId);
    final String? parentId = profession?.parentId;
    final professionIds = professionTreeIds(getProfessions(), professionId);

    final transactionsToKeep = transactionsBox?.values
            .where((transaction) =>
                professionIds.contains(transaction.professionId))
            .toList() ??
        [];
    final userId = auth.currentUser?.uid;
    for (final transaction in transactionsToKeep) {
      final unlinkedTransaction = transaction.withoutProfession();
      await transactionsBox?.put(unlinkedTransaction.id, unlinkedTransaction);
      if (userId != null) {
        firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(transaction.id)
            .update(unlinkedTransaction.toMap())
            .catchError((error) {
          debugPrint('Offline Sync: Transaction update delayed: $error');
        });
      }
    }

    for (final id in professionIds) {
      await professionsBox?.delete(id);
    }

    // If this was a season, recalculate the master profession
    if (parentId != null) {
      await _recalculateMasterProfessionFinance(parentId);
    }

    if (userId != null) {
      for (final id in professionIds) {
        firestore
            .collection('users')
            .doc(userId)
            .collection('professions')
            .doc(id)
            .delete()
            .catchError((error) {
          debugPrint('Offline Sync: Profession deletion delayed: $error');
        });
      }
    }
    notifyListeners();
  }

  List<Profession> getProfessions() => professionsBox?.values.toList() ?? [];

  List<Profession> getMasterProfessions() {
    // ہر وہ پیشہ جس کا کوئی پیرنٹ نہیں ہے یا isMaster سچ ہے اسے ماسٹر سمجھا جائے گا
    return professionsBox?.values
            .where((p) =>
                (p.isMaster ?? false) ||
                p.parentId == null ||
                p.parentId!.trim().isEmpty)
            .toList() ??
        [];
  }

  List<Profession> getSeasons(String parentId) {
    return professionsBox?.values
            .where((p) => p.parentId == parentId)
            .toList() ??
        [];
  }

  Profession? getProfession(String id) => professionsBox?.get(id);

  Future<void> recalculateProfessionFinance(String professionId) async {
    final profession = professionsBox?.get(professionId);
    if (profession != null) {
      if (profession.parentId != null) {
        // 1. This is a Season. Calculate its own finance first.
        final txs = transactionsBox?.values
                .where((t) => t.professionId == professionId)
                .toList() ??
            [];

        double income = txs
            .where((t) => t.professionSide == 'income')
            .fold(0.0, (sum, t) => sum + t.amount);
        double expense = txs
            .where((t) => t.professionSide == 'expense')
            .fold(0.0, (sum, t) => sum + t.amount);

        final updatedSeason = profession.copyWith(
            totalIncome: income,
            totalExpense: expense,
            updatedAt: DateTime.now());
        await professionsBox?.put(profession.id, updatedSeason);

        // 2. Now update the Master Profession.
        await _recalculateMasterProfessionFinance(profession.parentId!);
      } else {
        // This is a Master Profession.
        await _recalculateMasterProfessionFinance(professionId);
      }

      notifyListeners();
    }
  }

  Future<void> _recalculateMasterProfessionFinance(String masterId) async {
    final master = professionsBox?.get(masterId);
    if (master == null) return;

    final seasons = getSeasons(masterId);
    final masterTxs = transactionsBox?.values
            .where((t) => t.professionId == masterId)
            .toList() ??
        [];

    double totalIncome = 0;
    double totalExpense = 0;

    // 1. Sum up all seasons' calculated totals
    for (var season in seasons) {
      totalIncome += season.totalIncome;
      totalExpense += season.totalExpense;
    }

    // 2. Add transactions directly linked to master (if any)
    for (var t in masterTxs) {
      if (t.professionSide == 'income') {
        totalIncome += t.amount;
      } else if (t.professionSide == 'expense') {
        totalExpense += t.amount;
      }
    }

    final updatedMaster = master.copyWith(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      updatedAt: DateTime.now(),
    );
    await professionsBox?.put(masterId, updatedMaster);

    // Cloud Sync Master
    if (auth.currentUser != null) {
      firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('professions')
          .doc(masterId)
          .update(updatedMaster.toMap())
          .catchError((_) {});
    }
  }

  List<model.Transaction> getProfessionTransactions(String pId) =>
      transactionsBox?.values.where((t) => t.professionId == pId).toList() ??
      [];
  Future<double> calculateCostPerUnit(String pId) async =>
      getProfession(pId)?.costPerUnit ?? 0.0;

  Future<Map<String, bool>> checkBudgetAlerts(String pId) async {
    final p = getProfession(pId);
    if (p == null || p.budgetLimits == null) return {};
    final txs = getProfessionTransactions(pId);
    Map<String, bool> alerts = {};
    for (var entry in p.budgetLimits!.entries) {
      double spent = txs.where((t) {
        if (t.type != 'expense' && t.professionSide != 'expense') return false;
        // Normalize: "Seed" or "EXP:Seed" both should match entry.key "Seed"
        final category = t.category.startsWith('EXP:')
            ? t.category.substring(4)
            : t.category;
        return category.trim().toLowerCase() == entry.key.trim().toLowerCase();
      }).fold(0.0, (s, t) => s + t.amount);
      alerts[entry.key] = spent > entry.value;
    }
    return alerts;
  }

  Future<Map<String, dynamic>> getSeasonComparison(
    String name, {
    required String parentId,
  }) async {
    final list = professionsBox?.values
            .where((p) =>
                p.name == name && p.parentId == parentId && p.season.isNotEmpty)
            .toList() ??
        [];
    if (list.length < 2) return {'hasComparison': false};
    list.sort((a, b) => b.season.compareTo(a.season));
    final latest = list[0], prev = list[1];
    return {
      'hasComparison': true,
      'latestSeason': latest.season,
      'previousSeason': prev.season,
      'costChange': latest.costPerUnit - prev.costPerUnit,
      'profitChange': latest.netProfit - prev.netProfit,
      'productionChange': latest.totalProduction - prev.totalProduction,
      'costChangePercent': prev.costPerUnit > 0
          ? ((latest.costPerUnit - prev.costPerUnit) / prev.costPerUnit * 100)
          : 0,
      'profitChangePercent': prev.netProfit.abs() > 0
          ? ((latest.netProfit - prev.netProfit) / prev.netProfit.abs() * 100)
          : 0,
    };
  }

  Future<List<String>> generateRecommendations(String pId) async {
    final p = getProfession(pId);
    final recommendations = <String>{};

    if (p == null) return recommendations.toList();

    // 1. Cost recommendations
    if (p.benchmarkCostPerUnit > 0 && p.costPerUnit > 0) {
      final diffPercent = ((p.costPerUnit - p.benchmarkCostPerUnit) /
          p.benchmarkCostPerUnit *
          100);
      if (diffPercent > 20) {
        recommendations.add(
            'لاگت ${diffPercent.toStringAsFixed(1)}% زیادہ ہے۔ سپلائرز سے ریٹ کم کریں۔');
      } else if (diffPercent < -10) {
        recommendations.add(
            'لاگت ${diffPercent.abs().toStringAsFixed(1)}% کم ہے۔ بہترین!');
      }
    }

    // 2. Production recommendations
    if (p.targetProduction > 0) {
      final progress = p.productionProgress;
      if (progress < 50) {
        recommendations.add(
            'پیداوار صرف ${progress.toStringAsFixed(1)}% ہے۔ کوالٹی بیج اور کھاد استعمال کریں۔');
      } else if (progress > 100) {
        recommendations.add(
            'پیداوار ہدف سے ${(progress - 100).toStringAsFixed(1)}% زیادہ ہے۔ بہترین!');
      }
    }

    // 3. Profit recommendations
    if (p.netProfit < 0) {
      recommendations.add('نقصان ہو رہا ہے۔ خرچ کم کریں یا قیمتیں بڑھائیں۔');
    } else if (p.netProfit > p.totalIncome * 0.3) {
      recommendations.add(
          'منافع اچھا ہے (${(p.netProfit / p.totalIncome * 100).toStringAsFixed(1)}%)۔');
    }

    // 4. Budget recommendations
    final budgetAlerts = await checkBudgetAlerts(pId);
    final exceededCategories =
        budgetAlerts.entries.where((e) => e.value).map((e) => e.key).toList();
    if (exceededCategories.isNotEmpty) {
      recommendations
          .add('${exceededCategories.join(', ')} میں بجٹ سے زیادہ خرچ ہوا ہے۔');
    }

    // 5. Performance score based
    final score = p.performanceScore;
    if (score < 40) {
      recommendations.add(
          'کارکردگی کم ہے (${score.toStringAsFixed(0)}%)۔ بہتری کی ضرورت ہے۔');
    } else if (score > 80) {
      recommendations.add('شاندار کارکردگی! (${score.toStringAsFixed(0)}%)');
    }

    if (recommendations.isEmpty && p.performanceScore > 60) {
      recommendations.add('کارکردگی اچھی ہے۔ اسی طرح جاری رکھیں۔');
    }

    return recommendations.toList();
  }

  Future<Profession> createProfessionWithDefaults(
      {required String name,
      required String season,
      String? description,
      double totalProduction = 0.0,
      String productionUnit = 'kg',
      double targetProduction = 0.0,
      Map<String, double>? budgetLimits,
      double benchmarkCostPerUnit = 0.0,
      ProfessionCategory categoryType = ProfessionCategory.general}) async {
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
        targetProduction: targetProduction,
        budgetLimits: budgetLimits,
        benchmarkCostPerUnit: benchmarkCostPerUnit,
        categoryType: categoryType);
  }

  Future<int> getProfessionsCount() async => professionsBox?.length ?? 0;
}
