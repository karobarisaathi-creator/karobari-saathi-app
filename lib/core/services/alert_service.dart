// lib/services/alert_service.dart
import 'package:flutter/material.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as transaction_model;
import 'package:intl/intl.dart';

class AlertService {

  // 🔥 سمارٹ انتباہات کا نظام

  // 1. تمام انتباہات کا جامع تجزیہ
  static AlertAnalysis analyzeProfessionAlerts(
      Profession profession,
      List<transaction_model.Transaction> transactions,
      {List<Profession>? previousSeasons}
      ) {

    final now = DateTime.now();
    final alerts = <Alert>[];
    int severityScore = 0;

    // A. بجٹ انتباہات (حقیقی وقت)
    alerts.addAll(_checkBudgetAlerts(profession, transactions));

    // B. لاگت انتباہات (بینچ مارک کے ساتھ)
    alerts.addAll(_checkCostAlerts(profession));

    // C. پیداوار انتباہات
    alerts.addAll(_checkProductionAlerts(profession));

    // D. مالی انتباہات
    alerts.addAll(_checkFinancialAlerts(profession));

    // E. سیزن موازنہ انتباہات (اگر پچھلا سیزن موجود ہو)
    if (previousSeasons != null && previousSeasons.isNotEmpty) {
      alerts.addAll(_checkSeasonComparisonAlerts(profession, previousSeasons));
    }

    // F. رجحان انتباہات (آخری 30 دن کے ٹرینڈز)
    alerts.addAll(_checkTrendAlerts(profession, transactions, now));

    // G. وقت پر مبنی انتباہات (سیزن کے اختتام کے قریب)
    alerts.addAll(_checkTimeBasedAlerts(profession, now));

    // خطرہ اسکور کا حساب
    for (var alert in alerts) {
      severityScore += alert.priority.value;
    }

    return AlertAnalysis(
      profession: profession,
      alerts: alerts,
      totalAlerts: alerts.length,
      highPriorityAlerts: alerts.where((a) => a.priority == AlertPriority.high).length,
      mediumPriorityAlerts: alerts.where((a) => a.priority == AlertPriority.medium).length,
      lowPriorityAlerts: alerts.where((a) => a.priority == AlertPriority.low).length,
      severityScore: severityScore,
      riskLevel: _calculateRiskLevel(severityScore, alerts.length),
      lastUpdated: now,
    );
  }

  // 2. بجٹ انتباہات (حقیقی وقت)
  static List<Alert> _checkBudgetAlerts(
      Profession profession,
      List<transaction_model.Transaction> transactions
      ) {

    final alerts = <Alert>[];

    if (profession.budgetLimits == null || profession.budgetLimits!.isEmpty) {
      return alerts;
    }

    final currencyFormat = NumberFormat.currency(locale: 'ur_PK', symbol: 'Rs ');

    for (final entry in profession.budgetLimits!.entries) {
      final categoryExpense = transactions
          .where((t) => t.type == 'expense' && t.category == entry.key)
          .fold(0.0, (sum, t) => sum + t.amount);

      final percentage = (categoryExpense / entry.value * 100);

      if (percentage >= 80) {
        final remainingBudget = entry.value - categoryExpense;
        final daysLeftInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0)
            .difference(DateTime.now()).inDays;

        String action = '';
        AlertPriority priority = AlertPriority.low;

        if (percentage >= 100) {
          priority = AlertPriority.high;
          action = 'خرچ بند کریں۔ بجٹ ${percentage.toStringAsFixed(1)}% تک پہنچ چکا ہے۔';
        } else if (percentage >= 90) {
          priority = AlertPriority.high;
          action = 'خرچ میں سختی کریں۔ صرف ${currencyFormat.format(remainingBudget)} باقی ہے۔';
        } else if (percentage >= 80) {
          priority = AlertPriority.medium;
          action = 'احتیاط سے خرچ کریں۔ $daysLeftInMonth دن باقی ہیں۔';
        }

        alerts.add(Alert(
          id: 'budget_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
          title: 'بجٹ انتباہ: ${entry.key}',
          message: '${entry.key} میں ${currencyFormat.format(categoryExpense)} خرچ ہوچکا ہے '
              '(بجٹ: ${currencyFormat.format(entry.value)})',
          details: 'استعمال: ${percentage.toStringAsFixed(1)}% | باقی: ${currencyFormat.format(remainingBudget)}',
          type: AlertType.budget,
          priority: priority,
          icon: Icons.account_balance_wallet,
          color: _getPercentageColor(percentage),
          timestamp: DateTime.now(),
          actionRequired: true,
          actionText: 'خرچ دیکھیں',
          suggestion: action,
        ));
      }
    }

    return alerts;
  }

  // 3. لاگت انتباہات (بینچ مارک تجزیہ)
  static List<Alert> _checkCostAlerts(Profession profession) {
    final alerts = <Alert>[];

    if (profession.benchmarkCostPerUnit > 0 && profession.costPerUnit > 0) {
      final diffPercent = ((profession.costPerUnit - profession.benchmarkCostPerUnit) /
          profession.benchmarkCostPerUnit * 100);

      if (diffPercent > 15) {
        final extraCost = (profession.costPerUnit - profession.benchmarkCostPerUnit) *
            profession.totalProduction;

        alerts.add(Alert(
          id: 'cost_high_${DateTime.now().millisecondsSinceEpoch}',
          title: 'اعلیٰ لاگت انتباہ',
          message: 'فی ${profession.productionUnit} لاگت بینچ مارک سے ${diffPercent.toStringAsFixed(1)}% زیادہ ہے',
          details: 'موجودہ: Rs ${profession.costPerUnit.toStringAsFixed(2)} | '
              'معیار: Rs ${profession.benchmarkCostPerUnit.toStringAsFixed(2)} | '
              'اضافی لاگت: Rs ${extraCost.toStringAsFixed(0)}',
          type: AlertType.cost,
          priority: diffPercent > 30 ? AlertPriority.high : AlertPriority.medium,
          icon: Icons.trending_up,
          color: Colors.orange,
          timestamp: DateTime.now(),
          actionRequired: true,
          actionText: 'لاگت کم کریں',
          suggestion: 'سپلائرز سے بات چیت کریں یا متبادل ذرائع تلاش کریں۔',
        ));
      }

      // کم لاگت کی مثبت اطلاع (بہتری)
      if (diffPercent < -10) {
        alerts.add(Alert(
          id: 'cost_low_${DateTime.now().millisecondsSinceEpoch}',
          title: 'لاگت میں بہتری 🎉',
          message: 'لاگت معیار سے ${diffPercent.abs().toStringAsFixed(1)}% کم ہے',
          details: 'بہترین کارکردگی! لاگت کنٹرول میں کامیابی۔',
          type: AlertType.positive,
          priority: AlertPriority.low,
          icon: Icons.trending_down,
          color: Colors.green,
          timestamp: DateTime.now(),
          actionRequired: false,
          actionText: 'تفصیل دیکھیں',
          suggestion: 'اسی طرح جاری رکھیں۔ آپ کی لاگت کنٹرول بہترین ہے۔',
        ));
      }
    }

    return alerts;
  }

  // 4. پیداوار انتباہات
  static List<Alert> _checkProductionAlerts(Profession profession) {
    final alerts = <Alert>[];

    if (profession.targetProduction > 0) {
      final progress = profession.productionProgress;
      final remaining = profession.targetProduction - profession.totalProduction;
      final dailyTarget = profession.targetProduction / 90; // Assume 90-day season
      final daysLeft = (remaining / dailyTarget).ceil();

      if (progress < 30) {
        alerts.add(Alert(
          id: 'production_low_${DateTime.now().millisecondsSinceEpoch}',
          title: 'کم پیداوار انتباہ',
          message: 'پیداوار ہدف کا صرف ${progress.toStringAsFixed(1)}% ہے',
          details: 'موجودہ پیداوار: ${profession.totalProduction} ${profession.productionUnit} | '
              'ہدف: ${profession.targetProduction} ${profession.productionUnit} | '
              'متبقی: $daysLeft دن',
          type: AlertType.production,
          priority: progress < 20 ? AlertPriority.high : AlertPriority.medium,
          icon: Icons.production_quantity_limits,
          color: Colors.red,
          timestamp: DateTime.now(),
          actionRequired: true,
          actionText: 'پیداوار بڑھائیں',
          suggestion: 'کوالٹی بیج، کھاد یا آبپاشی میں بہتری لائیں۔',
        ));
      }

      // پیداوار ہدف سے زیادہ ہونے پر مثبت اطلاع
      if (progress > 100) {
        final excess = profession.totalProduction - profession.targetProduction;
        alerts.add(Alert(
          id: 'production_excess_${DateTime.now().millisecondsSinceEpoch}',
          title: 'ہدف سے زیادہ پیداوار 🎯',
          message: 'پیداوار ہدف سے ${(progress - 100).toStringAsFixed(1)}% زیادہ ہے',
          details: 'اضافی پیداوار: $excess ${profession.productionUnit}',
          type: AlertType.positive,
          priority: AlertPriority.low,
          icon: Icons.emoji_events,
          color: Colors.green,
          timestamp: DateTime.now(),
          actionRequired: false,
          actionText: 'کارکردگی دیکھیں',
          suggestion: 'شاندار! اگلے سیزن کے لیے ہدف بڑھانے پر غور کریں۔',
        ));
      }
    }

    return alerts;
  }

  // 5. مالی انتباہات
  static List<Alert> _checkFinancialAlerts(Profession profession) {
    final alerts = <Alert>[];
    final currencyFormat = NumberFormat.currency(locale: 'ur_PK', symbol: 'Rs ');

    // نقصان کی اطلاع
    if (profession.netProfit < 0) {
      alerts.add(Alert(
        id: 'financial_loss_${DateTime.now().millisecondsSinceEpoch}',
        title: 'نقصان ہو رہا ہے ⚠️',
        message: 'اس سیزن میں نقصان: ${currencyFormat.format(profession.netProfit.abs())}',
        details: 'آمدنی: ${currencyFormat.format(profession.totalIncome)} | '
            'خرچ: ${currencyFormat.format(profession.totalExpense)}',
        type: AlertType.financial,
        priority: profession.netProfit < -10000 ? AlertPriority.high : AlertPriority.medium,
        icon: Icons.money_off,
        color: Colors.red,
        timestamp: DateTime.now(),
        actionRequired: true,
        actionText: 'کارروائی کریں',
        suggestion: 'خرچ کم کریں یا قیمتوں میں اضافہ کریں۔ فوری اقدامات ضروری ہیں۔',
      ));
    }

    // منافع کی مثبت اطلاع
    if (profession.netProfit > 10000) {
      final profitMargin = (profession.netProfit / profession.totalIncome * 100);
      if (profitMargin > 20) {
        alerts.add(Alert(
          id: 'financial_profit_${DateTime.now().millisecondsSinceEpoch}',
          title: 'اعلیٰ منافع 🏆',
          message: 'منافع کی شرح ${profitMargin.toStringAsFixed(1)}% ہے',
          details: 'کل منافع: ${currencyFormat.format(profession.netProfit)}',
          type: AlertType.positive,
          priority: AlertPriority.low,
          icon: Icons.attach_money,
          color: Colors.green,
          timestamp: DateTime.now(),
          actionRequired: false,
          actionText: 'تفصیل دیکھیں',
          suggestion: 'بہترین کارکردگی! اضافی سرمایہ کاری کے مواقع تلاش کریں۔',
        ));
      }
    }

    return alerts;
  }

  // 6. سیزن موازنہ انتباہات
  static List<Alert> _checkSeasonComparisonAlerts(
      Profession current,
      List<Profession> previousSeasons
      ) {

    final alerts = <Alert>[];

    if (previousSeasons.isEmpty) return alerts;

    final latestPrevious = previousSeasons.first; // Sort is handled outside

    // لاگت کا موازنہ
    if (latestPrevious.costPerUnit > 0) {
      final costChange = ((current.costPerUnit - latestPrevious.costPerUnit) /
          latestPrevious.costPerUnit * 100);

      if (costChange > 20) {
        alerts.add(Alert(
          id: 'comparison_cost_${DateTime.now().millisecondsSinceEpoch}',
          title: 'لاگت میں اضافہ 📈',
          message: 'لاگت پچھلے سیزن سے ${costChange.toStringAsFixed(1)}% زیادہ ہے',
          details: 'موجودہ: Rs ${current.costPerUnit.toStringAsFixed(2)} | '
              'پچھلا: Rs ${latestPrevious.costPerUnit.toStringAsFixed(2)}',
          type: AlertType.comparison,
          priority: costChange > 40 ? AlertPriority.high : AlertPriority.medium,
          icon: Icons.compare_arrows,
          color: Colors.orange,
          timestamp: DateTime.now(),
          actionRequired: true,
          actionText: 'وجہ تلاش کریں',
          suggestion: 'سپلائرز کے ریٹس یا پیداواری اخراجات کا جائزہ لیں۔',
        ));
      }
    }

    // منافع کا موازنہ
    if (latestPrevious.netProfit.abs() > 0) {
      final profitChange = ((current.netProfit - latestPrevious.netProfit) /
          latestPrevious.netProfit.abs() * 100);

      if (profitChange < -30) {
        alerts.add(Alert(
          id: 'comparison_profit_${DateTime.now().millisecondsSinceEpoch}',
          title: 'منافع میں کمی 📉',
          message: 'منافع پچھلے سیزن سے ${profitChange.abs().toStringAsFixed(1)}% کم ہے',
          details: 'موجودہ: Rs ${current.netProfit.toStringAsFixed(0)} | '
              'پچھلا: Rs ${latestPrevious.netProfit.toStringAsFixed(0)}',
          type: AlertType.comparison,
          priority: AlertPriority.high,
          icon: Icons.trending_down,
          color: Colors.red,
          timestamp: DateTime.now(),
          actionRequired: true,
          actionText: 'تجزیہ کریں',
          suggestion: 'خرچ اور آمدنی کا تفصیلی جائزہ لیں۔',
        ));
      }
    }

    return alerts;
  }

  // 7. رجحان انتباہات (آخری 30 دن)
  static List<Alert> _checkTrendAlerts(
      Profession profession,
      List<transaction_model.Transaction> transactions,
      DateTime now
      ) {

    final alerts = <Alert>[];
    final thirtyDaysAgo = now.subtract(Duration(days: 30));

    final recentTransactions = transactions.where((t) =>
        t.date.isAfter(thirtyDaysAgo)).toList();

    if (recentTransactions.length < 5) return alerts;

    // خرچ کا رجحان
    final recentExpenses = recentTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    final avgDailyExpense = recentExpenses / 30;

    if (avgDailyExpense > 1000) {
      alerts.add(Alert(
        id: 'trend_expense_${DateTime.now().millisecondsSinceEpoch}',
        title: 'اعلیٰ روزانہ خرچ',
        message: 'آخری 30 دن کا اوسط روزانہ خرچ: Rs ${avgDailyExpense.toStringAsFixed(0)}',
        details: 'یہ رجحان لاگت بڑھا سکتا ہے۔',
        type: AlertType.trend,
        priority: avgDailyExpense > 2000 ? AlertPriority.medium : AlertPriority.low,
        icon: Icons.show_chart,
        color: Colors.orange,
        timestamp: now,
        actionRequired: true,
        actionText: 'خرچ چیک کریں',
        suggestion: 'غیر ضروری خرچ کم کریں۔',
      ));
    }

    return alerts;
  }

  // 8. وقت پر مبنی انتباہات
  static List<Alert> _checkTimeBasedAlerts(Profession profession, DateTime now) {
    final alerts = <Alert>[];

    // سیزن کے اختتام کے قریب
    if (profession.season.isNotEmpty) {
      // Assume season format like "2024 Rabi" or "2024 Kharif"
      final seasonEndEstimate = _estimateSeasonEnd(profession.season);

      if (seasonEndEstimate != null) {
        final daysLeft = seasonEndEstimate.difference(now).inDays;

        if (daysLeft <= 30 && daysLeft > 0) {
          alerts.add(Alert(
            id: 'season_end_${DateTime.now().millisecondsSinceEpoch}',
            title: 'سیزن کا اختتام قریب ⏳',
            message: 'سیزن کے صرف $daysLeft دن باقی ہیں',
            details: 'آخری مراحل میں احتیاط برتیں۔',
            type: AlertType.time,
            priority: daysLeft <= 7 ? AlertPriority.high : AlertPriority.medium,
            icon: Icons.calendar_today,
            color: daysLeft <= 7 ? Colors.red : Colors.orange,
            timestamp: now,
            actionRequired: true,
            actionText: 'پلان بنائیں',
            suggestion: 'آخری پیداوار اور فروخت کا پلان تیار کریں۔',
          ));
        }
      }
    }

    return alerts;
  }

  // 9. خطرہ سطح کا حساب
  static AlertRiskLevel _calculateRiskLevel(int severityScore, int alertCount) {
    final riskScore = severityScore * alertCount;

    if (riskScore >= 20) return AlertRiskLevel.critical;
    if (riskScore >= 15) return AlertRiskLevel.high;
    if (riskScore >= 10) return AlertRiskLevel.medium;
    if (riskScore >= 5) return AlertRiskLevel.low;
    return AlertRiskLevel.none;
  }

  // 10. سیزن کے اختتام کا اندازہ
  static DateTime? _estimateSeasonEnd(String season) {
    try {
      final parts = season.split(' ');
      if (parts.length < 2) return null;

      final year = int.tryParse(parts[0]);
      final seasonName = parts[1].toLowerCase();

      if (year == null) return null;

      if (seasonName.contains('rabi')) {
        // Rabi season: November to April
        return DateTime(year, 4, 30);
      } else if (seasonName.contains('kharif')) {
        // Kharif season: May to October
        return DateTime(year, 10, 31);
      }
    } catch (e) {
      // Don't print in production
    }

    return null;
  }

  // 11. فیصد کے لحاظ سے رنگ
  static Color _getPercentageColor(double percentage) {
    if (percentage >= 100) return Colors.red;
    if (percentage >= 90) return Colors.orange;
    if (percentage >= 80) return Colors.yellow;
    return Colors.green;
  }

  // 12. انتباہات کو ترتیب دیں (ترجیح اور وقت کے لحاظ سے)
  static List<Alert> sortAlerts(List<Alert> alerts) {
    alerts.sort((a, b) {
      // First by priority
      final priorityCompare = b.priority.value.compareTo(a.priority.value);
      if (priorityCompare != 0) return priorityCompare;

      // Then by timestamp (newest first)
      return b.timestamp.compareTo(a.timestamp);
    });

    return alerts;
  }

  // 13. خلاصہ پیغام
  static String generateSummaryMessage(AlertAnalysis analysis) {
    if (analysis.totalAlerts == 0) {
      return '✅ تمام معاملات ٹھیک ہیں۔ کوئی انتباہ نہیں۔';
    }

    final buffer = StringBuffer();
    buffer.write('⚠️ ${analysis.totalAlerts} انتباہ${analysis.totalAlerts > 1 ? 'ات' : ''} ');
    buffer.write('(${analysis.highPriorityAlerts} اہم)');

    if (analysis.riskLevel == AlertRiskLevel.critical) {
      buffer.write('\n🔴 **خطرہ کی سطح: سنگین** - فوری توجہ درکار');
    } else if (analysis.riskLevel == AlertRiskLevel.high) {
      buffer.write('\n🟠 **خطرہ کی سطح: زیادہ** - جلد کارروائی کریں');
    }

    return buffer.toString();
  }
}

// 🔥 نئی ماڈل کلاسیں

class AlertAnalysis {
  final Profession profession;
  final List<Alert> alerts;
  final int totalAlerts;
  final int highPriorityAlerts;
  final int mediumPriorityAlerts;
  final int lowPriorityAlerts;
  final int severityScore;
  final AlertRiskLevel riskLevel;
  final DateTime lastUpdated;

  AlertAnalysis({
    required this.profession,
    required this.alerts,
    required this.totalAlerts,
    required this.highPriorityAlerts,
    required this.mediumPriorityAlerts,
    required this.lowPriorityAlerts,
    required this.severityScore,
    required this.riskLevel,
    required this.lastUpdated,
  });

  bool get hasAlerts => totalAlerts > 0;
  bool get hasCriticalAlerts => riskLevel == AlertRiskLevel.critical;
  bool get needsImmediateAttention => highPriorityAlerts > 0 || hasCriticalAlerts;
}

class Alert {
  final String id;
  final String title;
  final String message;
  final String details;
  final AlertType type;
  final AlertPriority priority;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  final bool actionRequired;
  final String actionText;
  final String suggestion;

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.details,
    required this.type,
    required this.priority,
    required this.icon,
    required this.color,
    required this.timestamp,
    required this.actionRequired,
    required this.actionText,
    required this.suggestion,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes} منٹ پہلے';
    if (diff.inHours < 24) return '${diff.inHours} گھنٹے پہلے';
    return '${diff.inDays} دن پہلے';
  }
}

enum AlertType {
  budget,
  cost,
  production,
  financial,
  comparison,
  trend,
  time,
  positive,
}

enum AlertPriority {
  low(1),
  medium(2),
  high(3);

  final int value;
  const AlertPriority(this.value);
}

enum AlertRiskLevel {
  none,
  low,
  medium,
  high,
  critical,
}