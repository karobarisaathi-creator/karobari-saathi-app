import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'base_service.dart';

class ProfessionService extends BaseService {
  Future<void> addProfession(Profession profession) async {
    await professionsBox?.put(profession.id, profession);
    notifyListeners();
  }

  Future<void> updateProfession(Profession profession) async {
    await professionsBox?.put(profession.id, profession.copyWith(updatedAt: DateTime.now()));
    notifyListeners();
  }

  Future<void> deleteProfession(String professionId) async {
    final transactionsToDelete = transactionsBox?.values.where((t) => t.professionId == professionId).toList() ?? [];
    for (var transaction in transactionsToDelete) {
      await transactionsBox?.delete(transaction.id);
      if (auth.currentUser != null) {
        await firestore.collection('users').doc(auth.currentUser!.uid).collection('transactions').doc(transaction.id).delete();
      }
    }
    await professionsBox?.delete(professionId);
    if (auth.currentUser != null) {
      await firestore.collection('users').doc(auth.currentUser!.uid).collection('professions').doc(professionId).delete();
    }
    notifyListeners();
  }

  List<Profession> getProfessions() => professionsBox?.values.toList() ?? [];
  Profession? getProfession(String id) => professionsBox?.get(id);

  Future<void> recalculateProfessionFinance(String professionId) async {
    final profession = professionsBox?.get(professionId);
    if (profession != null) {
      final txs = transactionsBox?.values.where((t) => t.professionId == professionId).toList() ?? [];
      double income = txs.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
      double expense = txs.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
      final updated = profession.copyWith(totalIncome: income, totalExpense: expense, updatedAt: DateTime.now());
      await professionsBox?.put(profession.id, updated);
      if (auth.currentUser != null) {
        await firestore.collection('users').doc(auth.currentUser!.uid).collection('professions').doc(profession.id).set(updated.toMap());
      }
    }
  }

  List<model.Transaction> getProfessionTransactions(String pId) => transactionsBox?.values.where((t) => t.professionId == pId).toList() ?? [];
  Future<double> calculateCostPerUnit(String pId) async => getProfession(pId)?.costPerUnit ?? 0.0;

  Future<Map<String, bool>> checkBudgetAlerts(String pId) async {
    final p = getProfession(pId);
    if (p == null || p.budgetLimits == null) return {};
    final txs = getProfessionTransactions(pId);
    Map<String, bool> alerts = {};
    for (var entry in p.budgetLimits!.entries) {
      double spent = txs.where((t) => t.type == 'expense' && t.category == entry.key).fold(0.0, (s, t) => s + t.amount);
      alerts[entry.key] = spent > entry.value;
    }
    return alerts;
  }

  Future<Map<String, dynamic>> getSeasonComparison(String name) async {
    final list = professionsBox?.values.where((p) => p.name == name && p.season.isNotEmpty).toList() ?? [];
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
      'costChangePercent': prev.costPerUnit > 0 ? ((latest.costPerUnit - prev.costPerUnit) / prev.costPerUnit * 100) : 0,
      'profitChangePercent': prev.netProfit.abs() > 0 ? ((latest.netProfit - prev.netProfit) / prev.netProfit.abs() * 100) : 0,
    };
  }

  Future<List<String>> generateRecommendations(String pId) async {
    final p = getProfession(pId);
    final recommendations = <String>{};

    if (p == null) return recommendations.toList();

    // 1. Cost recommendations
    if (p.benchmarkCostPerUnit > 0 && p.costPerUnit > 0) {
      final diffPercent = ((p.costPerUnit - p.benchmarkCostPerUnit) / p.benchmarkCostPerUnit * 100);
      if (diffPercent > 20) {
        recommendations.add('لاگت ${diffPercent.toStringAsFixed(1)}% زیادہ ہے۔ سپلائرز سے ریٹ کم کریں۔');
      } else if (diffPercent < -10) {
        recommendations.add('لاگت ${diffPercent.abs().toStringAsFixed(1)}% کم ہے۔ بہترین!');
      }
    }

    // 2. Production recommendations
    if (p.targetProduction > 0) {
      final progress = p.productionProgress;
      if (progress < 50) {
        recommendations.add('پیداوار صرف ${progress.toStringAsFixed(1)}% ہے۔ کوالٹی بیج اور کھاد استعمال کریں۔');
      } else if (progress > 100) {
        recommendations.add('پیداوار ہدف سے ${(progress - 100).toStringAsFixed(1)}% زیادہ ہے۔ بہترین!');
      }
    }

    // 3. Profit recommendations
    if (p.netProfit < 0) {
      recommendations.add('نقصان ہو رہا ہے۔ خرچ کم کریں یا قیمتیں بڑھائیں۔');
    } else if (p.netProfit > p.totalIncome * 0.3) {
      recommendations.add('منافع اچھا ہے (${(p.netProfit / p.totalIncome * 100).toStringAsFixed(1)}%)۔');
    }

    // 4. Budget recommendations
    final budgetAlerts = await checkBudgetAlerts(pId);
    final exceededCategories = budgetAlerts.entries.where((e) => e.value).map((e) => e.key).toList();
    if (exceededCategories.isNotEmpty) {
      recommendations.add('${exceededCategories.join(', ')} میں بجٹ سے زیادہ خرچ ہوا ہے۔');
    }

    // 5. Performance score based
    final score = p.performanceScore;
    if (score < 40) {
      recommendations.add('کارکردگی کم ہے (${score.toStringAsFixed(0)}%)۔ بہتری کی ضرورت ہے۔');
    } else if (score > 80) {
      recommendations.add('شاندار کارکردگی! (${score.toStringAsFixed(0)}%)');
    }

    if (recommendations.isEmpty && p.performanceScore > 60) {
      recommendations.add('کارکردگی اچھی ہے۔ اسی طرح جاری رکھیں۔');
    }

    return recommendations.toList();
  }

  Future<Profession> createProfessionWithDefaults({required String name, required String season, String? description, double totalProduction = 0.0, String productionUnit = 'kg', double targetProduction = 0.0, Map<String, double>? budgetLimits, double benchmarkCostPerUnit = 0.0, ProfessionCategory categoryType = ProfessionCategory.general}) async {
    return Profession(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, categories: [], isActive: true, totalIncome: 0.0, totalExpense: 0.0, createdAt: DateTime.now(), updatedAt: DateTime.now(), description: description, totalProduction: totalProduction, productionUnit: productionUnit, season: season, targetProduction: targetProduction, budgetLimits: budgetLimits, benchmarkCostPerUnit: benchmarkCostPerUnit, categoryType: categoryType);
  }

  Future<int> getProfessionsCount() async => professionsBox?.length ?? 0;
}