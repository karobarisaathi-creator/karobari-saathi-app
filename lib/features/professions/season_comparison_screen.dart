// lib/features/professions/season_comparison_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SeasonComparisonScreen extends StatefulWidget {
  final Profession seasonA;
  final Profession? seasonB;

  const SeasonComparisonScreen({
    super.key,
    required this.seasonA,
    this.seasonB,
  });

  @override
  State<SeasonComparisonScreen> createState() => _SeasonComparisonScreenState();
}

class _SeasonComparisonScreenState extends State<SeasonComparisonScreen> {
  late Profession _newSeason;
  late Profession _oldSeason;

  @override
  void initState() {
    super.initState();
    if (widget.seasonB == null) {
      _newSeason = widget.seasonA;
      _oldSeason = widget.seasonA;
      return;
    }
    // Sort seasons so newer season is seasonA and older is seasonB
    if (widget.seasonA.createdAt.isAfter(widget.seasonB!.createdAt)) {
      _newSeason = widget.seasonA;
      _oldSeason = widget.seasonB!;
    } else {
      _newSeason = widget.seasonB!;
      _oldSeason = widget.seasonA;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final isSingleSeason = widget.seasonB == null;
    final hasAgricultureData = _newSeason.areaAcres > 0 ||
        _oldSeason.areaAcres > 0 ||
        _newSeason.productionMun > 0 ||
        _oldSeason.productionMun > 0;

    final areaA = _newSeason.areaAcres > 0 ? _newSeason.areaAcres : 1.0;
    final areaB = _oldSeason.areaAcres > 0 ? _oldSeason.areaAcres : 1.0;

    final costPerAcreA = _newSeason.totalExpense / areaA;
    final costPerAcreB = _oldSeason.totalExpense / areaB;
    final costDiff = costPerAcreA - costPerAcreB;

    final prodPerAcreA = _newSeason.productionMun / areaA;
    final prodPerAcreB = _oldSeason.productionMun / areaB;
    final prodDiff = prodPerAcreA - prodPerAcreB;

    final profitPerAcreA = _newSeason.netProfit / areaA;
    final profitPerAcreB = _oldSeason.netProfit / areaB;
    final profitDiff = profitPerAcreA - profitPerAcreB;

    final rateA = _newSeason.productionMun > 0
        ? _newSeason.totalIncome / _newSeason.productionMun
        : 0.0;
    final rateB = _oldSeason.productionMun > 0
        ? _oldSeason.totalIncome / _oldSeason.productionMun
        : 0.0;
    final rateDiff = rateA - rateB;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: CustomAppBar(
        title: isSingleSeason
            ? (isUrdu ? 'سیزن کی تفصیل' : 'Season Details')
            : (isUrdu ? 'سیزن کا موازنہ' : 'Season Comparison'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🏷️ Season Selector Pills Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSeasonPill(
                    _newSeason.season.isNotEmpty
                        ? _newSeason.season
                        : _newSeason.name,
                    const Color(0xFF2563EB),
                  ),
                  if (!isSingleSeason) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isUrdu ? 'بمقابلہ' : 'VS',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    _buildSeasonPill(
                      _oldSeason.season.isNotEmpty
                          ? _oldSeason.season
                          : _oldSeason.name,
                      const Color(0xFFD97706),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (isSingleSeason)
              _buildSingleSeasonDetails(_newSeason, isUrdu, fontFamily)
            else if (hasAgricultureData) ...[
              // 💡 Summary Card
              _buildSummaryCard(
                costDiff: costDiff,
                prodDiff: prodDiff,
                profitDiff: profitDiff,
                rateDiff: rateDiff,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 14),

              // 📊 Key Metrics Table
              _buildMetricsTable(
                areaA: areaA,
                areaB: areaB,
                costPerAcreA: costPerAcreA,
                costPerAcreB: costPerAcreB,
                costDiff: costDiff,
                prodPerAcreA: prodPerAcreA,
                prodPerAcreB: prodPerAcreB,
                prodDiff: prodDiff,
                rateA: rateA,
                rateB: rateB,
                rateDiff: rateDiff,
                profitPerAcreA: profitPerAcreA,
                profitPerAcreB: profitPerAcreB,
                profitDiff: profitDiff,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 14),
            ] else
              _buildGeneralComparison(isUrdu, fontFamily),
            const SizedBox(height: 16),

            // Footer Note
            Text(
              isSingleSeason
                  ? (isUrdu
                      ? 'اس سیزن کے درج شدہ آمدن اور اخراجات کی تفصیل۔'
                      : 'Recorded income and expenses for this season.')
                  : isUrdu
                      ? 'صرف بند شدہ سیزن کا موازنہ ہوتا ہے۔ پارٹیوں کا ادھار اس میں شامل نہیں۔ سبز کا مطلب آپ کے لیے بہتر، سرخ کا مطلب کمزور۔'
                      : 'Comparison is based on closed seasons. Green indicates improvement, red indicates decline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey[600],
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSeasonDetails(
    Profession season,
    bool isUrdu,
    String fontFamily,
  ) {
    final metrics = <MapEntry<String, double>>[
      MapEntry(isUrdu ? 'کل آمدن' : 'Total Income', season.totalIncome),
      MapEntry(isUrdu ? 'کل خرچ' : 'Total Expense', season.totalExpense),
      MapEntry(isUrdu ? 'خالص منافع' : 'Net Profit', season.netProfit),
      if (season.areaAcres > 0)
        MapEntry(isUrdu ? 'رقبہ (ایکڑ)' : 'Area (Acres)', season.areaAcres),
      if (season.productionMun > 0)
        MapEntry(
            isUrdu ? 'پیداوار (من)' : 'Production (Mun)', season.productionMun),
    ];
    return _buildValueCard(metrics, fontFamily);
  }

  Widget _buildGeneralComparison(bool isUrdu, String fontFamily) {
    final metrics = <MapEntry<String, double>>[
      MapEntry(isUrdu ? 'کل آمدن' : 'Total Income', _newSeason.totalIncome),
      MapEntry(isUrdu ? 'کل خرچ' : 'Total Expense', _newSeason.totalExpense),
      MapEntry(isUrdu ? 'خالص منافع' : 'Net Profit', _newSeason.netProfit),
    ];
    return _buildValueCard(
      metrics,
      fontFamily,
      previousValues: [
        _oldSeason.totalIncome,
        _oldSeason.totalExpense,
        _oldSeason.netProfit,
      ],
    );
  }

  Widget _buildValueCard(
    List<MapEntry<String, double>> metrics,
    String fontFamily, {
    List<double>? previousValues,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Column(
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            if (index > 0) const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    metrics[index].key,
                    style: TextStyle(
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                if (previousValues != null)
                  Text(
                    '${previousValues[index].toStringAsFixed(0)}  →  ',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                Text(
                  metrics[index].value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeasonPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required double costDiff,
    required double prodDiff,
    required double profitDiff,
    required double rateDiff,
    required bool isUrdu,
    required String fontFamily,
  }) {
    final costStr = costDiff < 0
        ? '${costDiff.abs().toStringAsFixed(0)} کم'
        : '${costDiff.toStringAsFixed(0)} زیادہ';
    final prodStr = prodDiff >= 0
        ? '${prodDiff.toStringAsFixed(0)} من فی ایکڑ زیادہ'
        : '${prodDiff.abs().toStringAsFixed(0)} من فی ایکڑ کم';
    final profitStr = profitDiff >= 0
        ? '${profitDiff.toStringAsFixed(0)} بڑھا'
        : '${profitDiff.abs().toStringAsFixed(0)} کم ہوا';

    final text = isUrdu
        ? '${_newSeason.season} میں فی ایکڑ خرچ $costStr رہا اور پیداوار $prodStr۔ منافع فی ایکڑ $profitStr۔'
        : 'In ${_newSeason.season}, cost per acre was $costStr with production $prodStr and profit $profitStr.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.info(),
            size: 20,
            color: const Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrdu ? 'خلاصہ' : 'Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E40AF),
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1E3A8A),
                    fontFamily: fontFamily,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsTable({
    required double areaA,
    required double areaB,
    required double costPerAcreA,
    required double costPerAcreB,
    required double costDiff,
    required double prodPerAcreA,
    required double prodPerAcreB,
    required double prodDiff,
    required double rateA,
    required double rateB,
    required double rateDiff,
    required double profitPerAcreA,
    required double profitPerAcreB,
    required double profitDiff,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'اہم اعداد' : 'Key Metrics',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 12),

          // Table Header
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  isUrdu ? 'تفصیل' : 'Metric',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _newSeason.season,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _oldSeason.season,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isUrdu ? 'فرق' : 'Diff',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Rows
          _buildRow(
            label: isUrdu ? 'رقبہ (ایکڑ)' : 'Area (Acres)',
            valA: areaA.toStringAsFixed(0),
            valB: areaB.toStringAsFixed(0),
            diffVal: areaA - areaB,
            isLowerBetter: false,
            fontFamily: fontFamily,
          ),
          _buildRow(
            label: isUrdu ? 'کل خرچ' : 'Total Expense',
            valA: _newSeason.totalExpense.toStringAsFixed(0),
            valB: _oldSeason.totalExpense.toStringAsFixed(0),
            diffVal: _newSeason.totalExpense - _oldSeason.totalExpense,
            isLowerBetter: true,
            fontFamily: fontFamily,
          ),
          _buildRow(
            label: isUrdu ? 'فی ایکڑ خرچ' : 'Cost / Acre',
            valA: costPerAcreA.toStringAsFixed(0),
            valB: costPerAcreB.toStringAsFixed(0),
            diffVal: costDiff,
            isLowerBetter: true,
            fontFamily: fontFamily,
          ),
          _buildRow(
            label: isUrdu ? 'پیداوار (من فی ایکڑ)' : 'Yield / Acre',
            valA: prodPerAcreA.toStringAsFixed(0),
            valB: prodPerAcreB.toStringAsFixed(0),
            diffVal: prodDiff,
            isLowerBetter: false,
            fontFamily: fontFamily,
          ),
          _buildRow(
            label: isUrdu ? 'اوسط بہاؤ فی من' : 'Avg Rate / Mun',
            valA: rateA.toStringAsFixed(0),
            valB: rateB.toStringAsFixed(0),
            diffVal: rateDiff,
            isLowerBetter: false,
            fontFamily: fontFamily,
          ),
          _buildRow(
            label: isUrdu ? 'منافع فی ایکڑ' : 'Profit / Acre',
            valA: profitPerAcreA.toStringAsFixed(0),
            valB: profitPerAcreB.toStringAsFixed(0),
            diffVal: profitDiff,
            isLowerBetter: false,
            fontFamily: fontFamily,
          ),
          _buildRow(
            label: isUrdu ? 'کل منافع' : 'Total Profit',
            valA: _newSeason.netProfit.toStringAsFixed(0),
            valB: _oldSeason.netProfit.toStringAsFixed(0),
            diffVal: _newSeason.netProfit - _oldSeason.netProfit,
            isLowerBetter: false,
            fontFamily: fontFamily,
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String valA,
    required String valB,
    required double diffVal,
    required bool isLowerBetter,
    required String fontFamily,
  }) {
    final isGood = isLowerBetter ? diffVal < 0 : diffVal > 0;
    final sign = diffVal >= 0 ? '+' : '';
    final pillBg = isGood ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final pillText = isGood ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              valA,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              valB,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$sign${diffVal.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: pillText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
