// lib/services/recommendation_engine.dart
import 'package:flutter/material.dart'; // Import Material for Colors and Icons
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as transaction_model;
import 'package:account_app/l10n/app_localizations.dart';

// Define BudgetAlert class here or import it if defined elsewhere
class BudgetAlert {
  final String category;
  final double percentage;

  BudgetAlert({required this.category, required this.percentage});
}

class RecommendationEngine {
  // AI سفارشات جنریٹ کریں
  static List<Recommendation> generateRecommendations(
      BuildContext context,
      Profession profession,
      List<transaction_model.Transaction> transactions,
      List<BudgetAlert> budgetAlerts,
      ) {
    final recommendations = <Recommendation>[];
    final l10n = AppLocalizations.of(context);

    // 1. لاگت کی سفارشات
    _addCostRecommendations(l10n, profession, recommendations);

    // 2. پیداوار کی سفارشات
    _addProductionRecommendations(l10n, profession, recommendations);

    // 3. منافع کی سفارشات
    _addProfitRecommendations(l10n, profession, recommendations);

    // 4. بجٹ کی سفارشات
    _addBudgetRecommendations(l10n, budgetAlerts, recommendations);

    // 5. عمومی کارکردگی سفارشات
    _addPerformanceRecommendations(l10n, profession, recommendations);

    // ترتیب دیں: پہلے اہم سفارشات
    recommendations.sort((a, b) => b.priority.compareTo(a.priority));

    return recommendations.take(5).toList(); // صرف 5 اہم سفارشات
  }

  static void _addCostRecommendations(AppLocalizations l10n, Profession profession, List<Recommendation> recommendations) {
    if (profession.benchmarkCostPerUnit > 0 && profession.costPerUnit > 0) {
      final diffPercent = ((profession.costPerUnit - profession.benchmarkCostPerUnit) /
          profession.benchmarkCostPerUnit * 100);

      if (diffPercent > 30) {
        recommendations.add(Recommendation(
          title: l10n.get('recCostHigh'),
          description: l10n.format('recCostHighDesc', [diffPercent.toStringAsFixed(1)]),
          category: RecommendationCategory.cost,
          priority: 9,
          actionSteps: [
            l10n.get('recActionDiscussRates'),
            l10n.get('recActionAltSuppliers'),
            l10n.get('recActionReviewCategories'),
          ],
        ));
      } else if (diffPercent > 15) {
        recommendations.add(Recommendation(
          title: l10n.get('recCostMed'),
          description: l10n.format('recCostMedDesc', [diffPercent.toStringAsFixed(1)]),
          category: RecommendationCategory.cost,
          priority: 7,
          actionSteps: [
            l10n.get('recActionReduceConsumption'),
            l10n.get('recActionOptimizeLabor'),
          ],
        ));
      } else if (diffPercent < -10) {
        recommendations.add(Recommendation(
          title: l10n.get('recCostOk'),
          description: l10n.format('recCostOkDesc', [diffPercent.abs().toStringAsFixed(1)]),
          category: RecommendationCategory.cost,
          priority: 3,
          actionSteps: [
            l10n.get('recActionContinue'),
            l10n.get('recActionImprovement'),
          ],
        ));
      }
    }
  }

  static void _addProductionRecommendations(AppLocalizations l10n, Profession profession, List<Recommendation> recommendations) {
    if (profession.targetProduction > 0) {
      final progress = profession.productionProgress;

      if (progress < 40) {
        recommendations.add(Recommendation(
          title: l10n.get('recProdLow'),
          description: l10n.format('recProdLowDesc', [progress.toStringAsFixed(1)]),
          category: RecommendationCategory.production,
          priority: 8,
          actionSteps: [
            l10n.get('recActionCheckSeed'),
            l10n.get('recActionReviewFertilizer'),
            l10n.get('recActionCheckIrrigation'),
          ],
        ));
      } else if (progress < 70) {
        recommendations.add(Recommendation(
          title: l10n.get('recProdMed'),
          description: l10n.format('recProdMedDesc', [progress.toStringAsFixed(1)]),
          category: RecommendationCategory.production,
          priority: 6,
          actionSteps: [
            l10n.get('recActionModernMethods'),
            l10n.get('recActionExpertAdvice'),
            l10n.get('recActionPlantHealth'),
          ],
        ));
      } else if (progress > 120) {
        recommendations.add(Recommendation(
          title: l10n.get('recProdHigh'),
          description: l10n.format('recProdHighDesc', [(progress - 100).toStringAsFixed(1)]),
          category: RecommendationCategory.production,
          priority: 2,
          actionSteps: [
            l10n.get('recActionShareTech'),
            l10n.get('recActionKeepRecord'),
            l10n.get('recActionPlanNext'),
          ],
        ));
      }
    }
  }

  static void _addProfitRecommendations(AppLocalizations l10n, Profession profession, List<Recommendation> recommendations) {
    if (profession.netProfit < 0) {
      recommendations.add(Recommendation(
        title: l10n.get('recProfitLoss'),
        description: l10n.format('recProfitLossDesc', [profession.netProfit.abs().toStringAsFixed(0)]),
        category: RecommendationCategory.profit,
        priority: 10,
        actionSteps: [
          l10n.get('recActionReduceExpense20'),
          l10n.get('recActionIncreasePrice'),
          l10n.get('recActionStopUnnecessary'),
          l10n.get('recActionExpertAdvice'),
        ],
      ));
    } else {
      final profitMargin = (profession.netProfit / profession.totalIncome.clamp(1, double.infinity)) * 100;

      if (profitMargin > 40) {
        recommendations.add(Recommendation(
          title: l10n.get('recProfitHigh'),
          description: l10n.format('recProfitHighDesc', [profitMargin.toStringAsFixed(1)]),
          category: RecommendationCategory.profit,
          priority: 1,
          actionSteps: [
            l10n.get('recActionInvest'),
            l10n.get('recActionShareTech'),
            l10n.get('recActionPlanNext'),
          ],
        ));
      } else if (profitMargin < 10) {
        recommendations.add(Recommendation(
          title: l10n.get('recProfitLow'),
          description: l10n.format('recProfitLowDesc', [profitMargin.toStringAsFixed(1)]),
          category: RecommendationCategory.profit,
          priority: 5,
          actionSteps: [
            l10n.get('recActionReduceExpense10'),
            l10n.get('recActionIncreasePrice5'),
            l10n.get('recActionImproveEfficiency'),
          ],
        ));
      }
    }
  }

  static void _addBudgetRecommendations(AppLocalizations l10n, List<BudgetAlert> budgetAlerts, List<Recommendation> recommendations) {
    for (final alert in budgetAlerts) {
      recommendations.add(Recommendation(
        title: l10n.get('recBudgetOver'),
        description: l10n.format('recBudgetOverDesc', [
          alert.percentage.toStringAsFixed(1),
          l10n.get(alert.category),
        ]),
        category: RecommendationCategory.budget,
        priority: alert.percentage > 150 ? 9 : 7,
        actionSteps: [
          l10n.get('recActionReduceNextMonth'),
          l10n.get('recActionReviewCategory'),
          l10n.get('recActionAltWays'),
        ],
      ));
    }
  }

  static void _addPerformanceRecommendations(AppLocalizations l10n, Profession profession, List<Recommendation> recommendations) {
    final score = profession.performanceScore;

    if (score < 40) {
      recommendations.add(Recommendation(
        title: l10n.get('recPerfRisk'),
        description: l10n.format('recPerfRiskDesc', [score.toStringAsFixed(0)]),
        category: RecommendationCategory.performance,
        priority: 8,
        actionSteps: [
          l10n.get('recActionExpertAdvice'),
          l10n.get('recActionWayChange'),
          l10n.get('recActionDeepReview'),
        ],
      ));
    } else if (score > 85) {
      recommendations.add(Recommendation(
        title: l10n.get('recPerfHigh'),
        description: l10n.format('recPerfHighDesc', [score.toStringAsFixed(0)]),
        category: RecommendationCategory.performance,
        priority: 1,
        actionSteps: [
          l10n.get('recActionShareTech'),
          l10n.get('recActionCelebrate'),
          l10n.get('recActionSetNext'),
        ],
      ));
    }
  }

  // سفارش کا خلاصہ
  static String getSummary(BuildContext context, List<Recommendation> recommendations) {
    final l10n = AppLocalizations.of(context);
    if (recommendations.isEmpty) {
      return l10n.get('recSummaryNone');
    }

    final highPriority = recommendations.where((r) => r.priority >= 8).length;
    final mediumPriority = recommendations.where((r) => r.priority >= 5 && r.priority < 8).length;

    if (highPriority > 0) {
      return l10n.format('recSummaryHigh', [highPriority]);
    }

    if (mediumPriority > 0) {
      return l10n.format('recSummaryMed', [mediumPriority]);
    }

    return l10n.get('recSummaryOpportunities');
  }
}

class Recommendation {
  final String title;
  final String description;
  final RecommendationCategory category;
  final int priority; // 1-10, 10 is highest
  final List<String> actionSteps;

  Recommendation({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.actionSteps,
  });

  Color get color {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    if (priority >= 3) return Colors.blue;
    return Colors.green;
  }

  IconData get icon {
    switch (category) {
      case RecommendationCategory.cost:
        return Icons.savings;
      case RecommendationCategory.production:
        return Icons.agriculture;
      case RecommendationCategory.profit:
        return Icons.attach_money;
      case RecommendationCategory.budget:
        return Icons.account_balance_wallet;
      case RecommendationCategory.performance:
        return Icons.assessment;
      default:
        return Icons.lightbulb;
    }
  }
}

enum RecommendationCategory {
  cost,
  production,
  profit,
  budget,
  performance,
}
